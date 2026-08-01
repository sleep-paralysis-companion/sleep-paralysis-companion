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
                serverMutationID: Phase1BFixture.uuid("77777777-7777-4777-8777-777777777777"),
                acknowledgedAt: nil,
                purgeAfter: nil
            )
        case .stale:
            return RemoteMutationAcknowledgment(
                idempotencyKey: request.operation.idempotencyKey,
                entityID: request.operation.entityID,
                acceptedRevision: request.operation.localRevision + 1,
                serverMutationID: Phase1BFixture.uuid("77777777-7777-4777-8777-777777777777"),
                acknowledgedAt: nil,
                purgeAfter: nil
            )
        case let .failure(error):
            throw error
        case .suspend:
            try await Task.sleep(for: .seconds(60))
            throw RemoteMutationError.network
        }
    }
}

actor TombstoneContractRPCExecutor: RemoteMutationRPCExecuting {
    private(set) var callCount = 0
    private(set) var receiptCount = 0
    private(set) var remoteTombstoneCount = 0
    private(set) var lastParameters: RemoteMutationRPCParameters?
    private var acceptedIdempotencyKeys: Set<UUID> = []

    func execute(_ parameters: RemoteMutationRPCParameters) async throws -> RemoteMutationRPCResult {
        callCount += 1
        guard parameters.entityType == "tombstone",
              parameters.operation == SyncOperationKind.delete.rawValue,
              parameters.baseRevision == 1,
              parameters.entityRevision == 2,
              case let .tombstone(payload) = parameters.payload,
              payload.id == parameters.entityID,
              payload.ownerUserID == Phase1BFixture.userID,
              payload.entityType == "checkin",
              payload.entityID == Phase1BFixture.entityID,
              payload.deletedRevision == parameters.entityRevision
        else {
            throw RemoteMutationError.validation
        }

        lastParameters = parameters
        if acceptedIdempotencyKeys.insert(parameters.idempotencyKey).inserted {
            receiptCount += 1
            remoteTombstoneCount += 1
        }
        return RemoteMutationRPCResult(
            serverMutationID: parameters.receiptID,
            acceptedRevision: parameters.entityRevision,
            acknowledgedAt: Phase1BFixture.now.addingTimeInterval(120),
            purgeAfter: Phase1BFixture.now.addingTimeInterval(31 * 86400)
        )
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
        } catch is CancellationError {
            XCTAssertTrue(task.isCancelled)
        }

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

    func testDeletionContractUsesTombstoneIdentityThroughDatabasePayloadAndGateway() async throws {
        let database = try await linkedDatabase()
        try await database.submitCheckIn(Phase1BFixture.checkIn(), draftID: nil)
        let tombstoneID = Phase1BFixture.uuid("66666666-6666-4666-8666-666666666666")
        try await database.deleteCheckIn(
            DeleteCheckInRequest(
                id: Phase1BFixture.entityID,
                profileID: Phase1BFixture.profileID,
                date: Phase1BFixture.now.addingTimeInterval(60),
                tombstoneID: tombstoneID,
                operationID: Phase1BFixture.operationID,
                idempotencyKey: Phase1BFixture.key
            )
        )

        let executor = TombstoneContractRPCExecutor()
        let gateway = SupabaseRemoteMutationGateway(
            executor: executor,
            identifier: FixedIdentifierGenerator(
                value: Phase1BFixture.uuid("77777777-7777-4777-8777-777777777777")
            )
        )
        let engine = SynchronizationEngine(
            database: database,
            payloadProvider: LocalDatabaseOutboundPayloadProvider(database: database),
            remote: gateway,
            clock: FixedClock(value: Phase1BFixture.now.addingTimeInterval(120)),
            random: FixedUnitRandom(value: 0)
        )

        let firstAttemptDidWork = try await engine.synchronizeNext(
            profileID: Phase1BFixture.profileID,
            authenticatedUserID: Phase1BFixture.userID
        )
        let secondAttemptDidWork = try await engine.synchronizeNext(
            profileID: Phase1BFixture.profileID,
            authenticatedUserID: Phase1BFixture.userID
        )
        XCTAssertTrue(firstAttemptDidWork)
        XCTAssertFalse(secondAttemptDidWork)

        let operations = try await database.operations(profileID: Phase1BFixture.profileID)
        let tombstone = try await database.tombstone(
            id: tombstoneID,
            profileID: Phase1BFixture.profileID
        )
        let revision = try await database.entityRevision(
            profileID: Phase1BFixture.profileID,
            entityType: .tombstone,
            entityID: tombstoneID
        )
        let deletedCheckIn = try await database.checkIn(
            id: Phase1BFixture.entityID,
            profileID: Phase1BFixture.profileID
        )
        let parameters = await executor.lastParameters
        let callCount = await executor.callCount
        let receiptCount = await executor.receiptCount
        let remoteTombstoneCount = await executor.remoteTombstoneCount

        XCTAssertEqual(operations.first?.entityID, tombstoneID)
        XCTAssertEqual(operations.first?.state, .deleted)
        XCTAssertEqual(parameters?.entityID, tombstoneID)
        XCTAssertEqual(parameters?.payload.entityID, tombstoneID)
        XCTAssertEqual(tombstone?.id, tombstoneID)
        XCTAssertNotNil(tombstone?.acknowledgedAt)
        XCTAssertEqual(revision?.entityID, tombstoneID)
        XCTAssertEqual(revision?.acknowledgedRemoteRevision, 2)
        XCTAssertNotNil(deletedCheckIn?.deletedAt)
        XCTAssertEqual(callCount, 1)
        XCTAssertEqual(receiptCount, 1)
        XCTAssertEqual(remoteTombstoneCount, 1)
    }

    func testProductionPayloadProviderRejectsForgedAuthenticatedOwner() async throws {
        let database = try await linkedDatabase()
        try await database.submitCheckIn(Phase1BFixture.checkIn(), draftID: nil)
        let provider = LocalDatabaseOutboundPayloadProvider(database: database)

        do {
            _ = try await provider.payload(
                for: Phase1BFixture.operation(),
                authenticatedUserID: Phase1BFixture.uuid(
                    "99999999-9999-4999-8999-999999999999"
                )
            )
            XCTFail("Expected forged owner rejection.")
        } catch let error as RemoteMutationError {
            XCTAssertEqual(error, .authorization)
        }
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
        XCTAssertEqual(
            resolver.resolve(
                entityType: .persona,
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

    private func linkedDatabase() async throws -> LocalDatabase {
        let database = try LocalDatabase(path: temporaryDatabasePath())
        var profile = Phase1BFixture.profile()
        profile.ownership = .accountLinked
        profile.accountUserID = Phase1BFixture.userID
        profile.accountLinkState = .linked
        try await database.createProfile(profile, settings: Phase1BFixture.settings())
        return database
    }

    private func databaseWithOperation() async throws -> LocalDatabase {
        let database = try await seededDatabase()
        try await database.enqueue(Phase1BFixture.operation())
        return database
    }
}
