import Foundation
@testable import SleepParalysisCompanion
import XCTest

struct FixedPayloadProvider: OutboundPayloadProviding {
    let ownerUserID: UUID

    func payload(
        for operation: SynchronizationOperation,
        authenticatedUserID: UUID
    ) async throws -> RemoteMutationPayload {
        guard ownerUserID == authenticatedUserID else {
            throw AuthenticationError.wrongAccount
        }
        return .checkIn(
            RemoteCheckInDTO(
                id: operation.entityID,
                ownerUserID: ownerUserID,
                reportedForLocalDate: "2026-07-27",
                reportedTimezoneID: "UTC",
                occurrence: "no",
                perceivedIntensity: nil,
                presentState: nil,
                note: nil,
                createdAt: Phase1BFixture.now,
                updatedAt: Phase1BFixture.now,
                revision: operation.localRevision,
                deletedAt: nil
            )
        )
    }
}

actor ScriptedRemoteMutationGateway: RemoteMutationGateway {
    enum Behavior {
        case acknowledge
        case stale
        case failure(RemoteMutationError)
        case suspend
    }

    private let behavior: Behavior
    private(set) var callCount = 0

    init(_ behavior: Behavior) {
        self.behavior = behavior
    }

    func apply(_ request: RemoteMutationRequest) async throws -> RemoteMutationAcknowledgment {
        callCount += 1
        switch behavior {
        case .acknowledge:
            return RemoteMutationAcknowledgment(
                idempotencyKey: request.operation.idempotencyKey,
                entityID: request.operation.entityID,
                acceptedRevision: request.operation.localRevision,
                serverMutationID: Phase1BFixture.uuid("77777777-7777-4777-8777-777777777777")
            )
        case .stale:
            return RemoteMutationAcknowledgment(
                idempotencyKey: request.operation.idempotencyKey,
                entityID: request.operation.entityID,
                acceptedRevision: request.operation.localRevision + 1,
                serverMutationID: Phase1BFixture.uuid("77777777-7777-4777-8777-777777777777")
            )
        case let .failure(error):
            throw error
        case .suspend:
            try await Task.sleep(for: .seconds(60))
            throw RemoteMutationError.network
        }
    }
}

final class SynchronizationEngineTests: XCTestCase {
    func testOfflineGuestHasNoOutboundWork() async throws {
        let database = try await seededDatabase()
        let remote = ScriptedRemoteMutationGateway(.acknowledge)
        let engine = makeEngine(database: database, remote: remote)

        let didWork = try await engine.synchronizeNext(
            profileID: Phase1BFixture.profileID,
            authenticatedUserID: Phase1BFixture.userID
        )
        let callCount = await remote.callCount
        XCTAssertFalse(didWork)
        XCTAssertEqual(callCount, 0)
    }

    func testSuccessfulMutationBecomesSynced() async throws {
        let database = try await databaseWithOperation()
        let remote = ScriptedRemoteMutationGateway(.acknowledge)
        let engine = makeEngine(database: database, remote: remote)

        let didWork = try await engine.synchronizeNext(
            profileID: Phase1BFixture.profileID,
            authenticatedUserID: Phase1BFixture.userID
        )
        XCTAssertTrue(didWork)
        let operations = try await database.operations(profileID: Phase1BFixture.profileID)
        XCTAssertEqual(operations.first?.state, .synced)
        XCTAssertEqual(operations.first?.attemptCount, 1)
    }

    func testNetworkFailureUsesDeterministicCappedBackoff() async throws {
        let database = try await databaseWithOperation()
        let engine = makeEngine(
            database: database,
            remote: ScriptedRemoteMutationGateway(.failure(.network)),
            random: FixedUnitRandom(value: 1)
        )
        _ = try await engine.synchronizeNext(
            profileID: Phase1BFixture.profileID,
            authenticatedUserID: Phase1BFixture.userID
        )
        let operation = try await database.operations(profileID: Phase1BFixture.profileID).first
        XCTAssertEqual(operation?.state, .failedRecoverable)
        XCTAssertEqual(operation?.lastErrorCategory, .network)
        XCTAssertEqual(operation?.nextAttemptAt, Phase1BFixture.now.addingTimeInterval(2.5))
    }

    func testBackendOutageRetriesWithoutChangingIdempotencyKey() async throws {
        let database = try await databaseWithOperation()
        let engine = makeEngine(
            database: database,
            remote: ScriptedRemoteMutationGateway(.failure(.backendUnavailable))
        )
        _ = try await engine.synchronizeNext(
            profileID: Phase1BFixture.profileID,
            authenticatedUserID: Phase1BFixture.userID
        )
        let operation = try await database.operations(profileID: Phase1BFixture.profileID).first
        XCTAssertEqual(operation?.state, .failedRecoverable)
        XCTAssertEqual(operation?.idempotencyKey, Phase1BFixture.key)
    }

    func testAuthenticationFailurePausesWithoutAutomaticRetry() async throws {
        let database = try await databaseWithOperation()
        let engine = makeEngine(
            database: database,
            remote: ScriptedRemoteMutationGateway(.failure(.authentication))
        )
        _ = try await engine.synchronizeNext(
            profileID: Phase1BFixture.profileID,
            authenticatedUserID: Phase1BFixture.userID
        )
        let operation = try await database.operations(profileID: Phase1BFixture.profileID).first
        XCTAssertEqual(operation?.state, .authRequired)
        XCTAssertNil(operation?.nextAttemptAt)
    }

    func testValidationAndAuthorizationFailuresDoNotRetryIndefinitely() async throws {
        for failure in [RemoteMutationError.validation, RemoteMutationError.authorization] {
            let database = try await databaseWithOperation()
            let engine = makeEngine(
                database: database,
                remote: ScriptedRemoteMutationGateway(.failure(failure))
            )
            _ = try await engine.synchronizeNext(
                profileID: Phase1BFixture.profileID,
                authenticatedUserID: Phase1BFixture.userID
            )
            let operation = try await database.operations(profileID: Phase1BFixture.profileID).first
            XCTAssertEqual(operation?.state, .conflicted)
            XCTAssertNil(operation?.nextAttemptAt)
        }
    }

    func testStaleResponseIsRejected() async throws {
        let database = try await databaseWithOperation()
        let engine = makeEngine(database: database, remote: ScriptedRemoteMutationGateway(.stale))
        _ = try await engine.synchronizeNext(
            profileID: Phase1BFixture.profileID,
            authenticatedUserID: Phase1BFixture.userID
        )
        let operation = try await database.operations(profileID: Phase1BFixture.profileID).first
        XCTAssertEqual(operation?.state, .conflicted)
        XCTAssertEqual(operation?.lastErrorCategory, .conflict)
    }

    func testCancellationReturnsOperationToRecoverableState() async throws {
        let database = try await databaseWithOperation()
        let engine = makeEngine(database: database, remote: ScriptedRemoteMutationGateway(.suspend))
        let task = Task {
            try await engine.synchronizeNext(
                profileID: Phase1BFixture.profileID,
                authenticatedUserID: Phase1BFixture.userID
            )
        }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected cancellation.")
        } catch is CancellationError {}

        let operation = try await database.operations(profileID: Phase1BFixture.profileID).first
        XCTAssertEqual(operation?.state, .failedRecoverable)
        XCTAssertEqual(operation?.lastErrorCategory, .cancelled)
    }

    func testReplayedLocalEnqueueDoesNotDuplicateSemanticOperation() async throws {
        let database = try await seededDatabase()
        let operation = Phase1BFixture.operation()
        try await database.enqueue(operation)
        try await database.enqueue(operation)
        let operations = try await database.operations(profileID: Phase1BFixture.profileID)
        XCTAssertEqual(operations.count, 1)
    }

    func testOneInFlightMutationPerEntity() async throws {
        let database = try await databaseWithOperation()
        let first = try await database.claimNextOperation(
            profileID: Phase1BFixture.profileID,
            now: Phase1BFixture.now
        )
        let second = try await database.claimNextOperation(
            profileID: Phase1BFixture.profileID,
            now: Phase1BFixture.now
        )
        XCTAssertNotNil(first)
        XCTAssertNil(second)
    }

    func testEntitySpecificConflictRulesNeverUseTimestampAuthority() {
        let resolver = EntityConflictResolver()
        XCTAssertEqual(
            resolver.resolve(
                entityType: .checkIn,
                sameStableID: false,
                sameContent: false,
                deleteBaseIncludesEdit: false
            ),
            .union
        )
        XCTAssertEqual(
            resolver.resolve(
                entityType: .checkIn,
                sameStableID: true,
                sameContent: true,
                deleteBaseIncludesEdit: false
            ),
            .deduplicated
        )
        XCTAssertEqual(
            resolver.resolve(
                entityType: .tombstone,
                sameStableID: true,
                sameContent: false,
                deleteBaseIncludesEdit: true
            ),
            .delete
        )
        XCTAssertEqual(
            resolver.resolve(
                entityType: .alarm,
                sameStableID: true,
                sameContent: false,
                deleteBaseIncludesEdit: false
            ),
            .requiresChoice([.useDevice, .useAccount])
        )
    }

    private func makeEngine(
        database: LocalDatabase,
        remote: ScriptedRemoteMutationGateway,
        random: any UnitIntervalRandom = FixedUnitRandom(value: 0)
    ) -> SynchronizationEngine {
        SynchronizationEngine(
            database: database,
            payloadProvider: FixedPayloadProvider(ownerUserID: Phase1BFixture.userID),
            remote: remote,
            clock: FixedClock(value: Phase1BFixture.now),
            random: random
        )
    }

    private func seededDatabase() async throws -> LocalDatabase {
        let database = try LocalDatabase(path: temporaryDatabasePath())
        try await database.createProfile(Phase1BFixture.profile(), settings: Phase1BFixture.settings())
        return database
    }

    private func databaseWithOperation() async throws -> LocalDatabase {
        let database = try await seededDatabase()
        try await database.enqueue(Phase1BFixture.operation())
        return database
    }
}
