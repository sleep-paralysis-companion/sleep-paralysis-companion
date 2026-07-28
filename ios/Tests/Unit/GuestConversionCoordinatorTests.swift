import Foundation
@testable import SleepParalysisCompanion
import XCTest

actor ScriptedGuestConversionGateway: GuestConversionGateway {
    let summary: RemoteAccountSummary
    private var failuresRemaining: Int
    private let suspends: Bool
    private(set) var conversionIDs: [UUID] = []

    init(
        summary: RemoteAccountSummary,
        failuresRemaining: Int = 0,
        suspends: Bool = false
    ) {
        self.summary = summary
        self.failuresRemaining = failuresRemaining
        self.suspends = suspends
    }

    func inspectAccount(userID: UUID) async throws -> RemoteAccountSummary {
        _ = userID
        if suspends {
            try await Task.sleep(for: .seconds(60))
        }
        return summary
    }

    func convert(
        conversionID: UUID,
        profileID: UUID,
        userID: UUID,
        mergeChoice: GuestMergeChoice?
    ) async throws -> GuestConversionCommit {
        _ = profileID
        _ = mergeChoice
        conversionIDs.append(conversionID)
        if failuresRemaining > 0 {
            failuresRemaining -= 1
            throw RemoteMutationError.backendUnavailable
        }
        return GuestConversionCommit(
            conversionID: conversionID,
            userID: userID,
            committedAt: Phase1BFixture.now
        )
    }
}

final class GuestConversionCoordinatorTests: XCTestCase {
    func testEmptyRemoteAccountConvertsAtomically() async throws {
        let database = try await seededDatabase()
        let coordinator = makeCoordinator(
            database: database,
            remote: ScriptedGuestConversionGateway(summary: emptySummary)
        )
        let result = try await coordinator.start(
            profileID: Phase1BFixture.profileID,
            session: Phase1BFixture.session()
        )

        let profile = try await database.profile(id: Phase1BFixture.profileID)
        let binding = try await database.accountBinding(profileID: Phase1BFixture.profileID)
        XCTAssertEqual(result, .linked)
        XCTAssertEqual(profile?.ownership, .accountLinked)
        XCTAssertEqual(profile?.accountUserID, Phase1BFixture.userID)
        XCTAssertEqual(binding?.userID, Phase1BFixture.userID)
    }

    func testExistingRemoteDataRequiresExplicitMergeChoice() async throws {
        let database = try await seededDatabase()
        let summary = RemoteAccountSummary(
            submittedCheckInCount: 3,
            hasSettingsDifference: true,
            hasAlarmDifference: false,
            lastSynchronizedAt: Phase1BFixture.now
        )
        let coordinator = makeCoordinator(
            database: database,
            remote: ScriptedGuestConversionGateway(summary: summary)
        )
        let result = try await coordinator.start(
            profileID: Phase1BFixture.profileID,
            session: Phase1BFixture.session()
        )

        XCTAssertEqual(result, .awaitingMergeChoice(summary))
        let profile = try await database.profile(id: Phase1BFixture.profileID)
        XCTAssertEqual(profile?.accountLinkState, .awaitingMergeChoice)
        XCTAssertNil(profile?.accountUserID)
    }

    func testMergeChoiceCompletesExistingAccountConversion() async throws {
        let database = try await seededDatabase()
        let gateway = ScriptedGuestConversionGateway(
            summary: RemoteAccountSummary(
                submittedCheckInCount: 1,
                hasSettingsDifference: true,
                hasAlarmDifference: true,
                lastSynchronizedAt: Phase1BFixture.now
            )
        )
        let coordinator = makeCoordinator(database: database, remote: gateway)
        _ = try await coordinator.start(
            profileID: Phase1BFixture.profileID,
            session: Phase1BFixture.session()
        )
        let result = try await coordinator.continueConversion(
            profileID: Phase1BFixture.profileID,
            session: Phase1BFixture.session(),
            choice: .devicePreferences
        )
        XCTAssertEqual(result, .linked)
    }

    func testCancelChoiceRollsBackToFullyUsableGuest() async throws {
        let database = try await seededDatabase()
        let gateway = ScriptedGuestConversionGateway(
            summary: RemoteAccountSummary(
                submittedCheckInCount: 1,
                hasSettingsDifference: false,
                hasAlarmDifference: false,
                lastSynchronizedAt: nil
            )
        )
        let coordinator = makeCoordinator(database: database, remote: gateway)
        _ = try await coordinator.start(
            profileID: Phase1BFixture.profileID,
            session: Phase1BFixture.session()
        )
        let result = try await coordinator.continueConversion(
            profileID: Phase1BFixture.profileID,
            session: Phase1BFixture.session(),
            choice: .cancel
        )

        let profile = try await database.profile(id: Phase1BFixture.profileID)
        XCTAssertEqual(result, .stayedLocal)
        XCTAssertEqual(profile?.ownership, .guestLocal)
        XCTAssertEqual(profile?.accountLinkState, .localOnly)
    }

    func testPartialRemoteFailureIsRetrySafeWithSameConversionID() async throws {
        let database = try await seededDatabase()
        let gateway = ScriptedGuestConversionGateway(
            summary: emptySummary,
            failuresRemaining: 1
        )
        let firstCoordinator = makeCoordinator(database: database, remote: gateway)
        let first = try await firstCoordinator.start(
            profileID: Phase1BFixture.profileID,
            session: Phase1BFixture.session()
        )
        XCTAssertEqual(first, .failedRecoverable)

        let resumedCoordinator = makeCoordinator(database: database, remote: gateway)
        let resumed = try await resumedCoordinator.resume(
            profileID: Phase1BFixture.profileID,
            session: Phase1BFixture.session()
        )
        let IDs = await gateway.conversionIDs
        XCTAssertEqual(resumed, .linked)
        XCTAssertEqual(IDs.count, 2)
        XCTAssertEqual(Set(IDs).count, 1)
    }

    func testWrongUserCannotResumeConversion() async throws {
        let database = try await seededDatabase()
        let gateway = ScriptedGuestConversionGateway(
            summary: emptySummary,
            failuresRemaining: 1
        )
        let coordinator = makeCoordinator(database: database, remote: gateway)
        _ = try await coordinator.start(
            profileID: Phase1BFixture.profileID,
            session: Phase1BFixture.session()
        )
        let wrongSession = Phase1BFixture.session(
            userID: Phase1BFixture.uuid("99999999-9999-4999-8999-999999999999")
        )

        await XCTAssertThrowsErrorAsync {
            _ = try await coordinator.resume(
                profileID: Phase1BFixture.profileID,
                session: wrongSession
            )
        }
    }

    func testCancellationBeforeRemoteCommitRestoresGuestState() async throws {
        let database = try await seededDatabase()
        let gateway = ScriptedGuestConversionGateway(summary: emptySummary, suspends: true)
        let coordinator = makeCoordinator(database: database, remote: gateway)
        let task = Task {
            try await coordinator.start(
                profileID: Phase1BFixture.profileID,
                session: Phase1BFixture.session()
            )
        }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected cancellation.")
        } catch is CancellationError {}

        let profile = try await database.profile(id: Phase1BFixture.profileID)
        let checkpoint = try await database.conversionCheckpoint(profileID: Phase1BFixture.profileID)
        XCTAssertEqual(profile?.ownership, .guestLocal)
        XCTAssertEqual(profile?.accountLinkState, .localOnly)
        XCTAssertNil(checkpoint)
    }

    func testCompletedConversionCannotBeDuplicatedAfterRelaunch() async throws {
        let database = try await seededDatabase()
        let gateway = ScriptedGuestConversionGateway(summary: emptySummary)
        let coordinator = makeCoordinator(database: database, remote: gateway)
        _ = try await coordinator.start(
            profileID: Phase1BFixture.profileID,
            session: Phase1BFixture.session()
        )
        let relaunched = makeCoordinator(database: database, remote: gateway)
        let result = try await relaunched.resume(
            profileID: Phase1BFixture.profileID,
            session: Phase1BFixture.session()
        )
        let IDs = await gateway.conversionIDs
        XCTAssertEqual(result, .stayedLocal)
        XCTAssertEqual(IDs.count, 1)
    }

    private var emptySummary: RemoteAccountSummary {
        RemoteAccountSummary(
            submittedCheckInCount: 0,
            hasSettingsDifference: false,
            hasAlarmDifference: false,
            lastSynchronizedAt: nil
        )
    }

    private func seededDatabase() async throws -> LocalDatabase {
        let database = try LocalDatabase(path: temporaryDatabasePath())
        try await database.createProfile(Phase1BFixture.profile(), settings: Phase1BFixture.settings())
        return database
    }

    private func makeCoordinator(
        database: LocalDatabase,
        remote: ScriptedGuestConversionGateway
    ) -> GuestConversionCoordinator {
        GuestConversionCoordinator(
            database: database,
            remote: remote,
            identifier: FixedIdentifierGenerator(
                value: Phase1BFixture.uuid("88888888-8888-4888-8888-888888888888")
            ),
            clock: FixedClock(value: Phase1BFixture.now)
        )
    }
}
