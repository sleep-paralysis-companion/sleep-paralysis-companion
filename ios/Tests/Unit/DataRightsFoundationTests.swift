import Foundation
import os
@testable import SleepParalysisCompanion
import XCTest

final class RecordingProtection: ProtectedFileApplying {
    private let protectedPaths = OSAllocatedUnfairLock(initialState: [String]())
    private let shouldFail: Bool

    init(shouldFail: Bool = false) {
        self.shouldFail = shouldFail
    }

    func applyProtection(to url: URL, kind: ProtectedFileKind) throws {
        _ = kind
        if shouldFail {
            throw CocoaError(.fileWriteNoPermission)
        }
        protectedPaths.withLock { $0.append(url.path) }
    }

    var paths: [String] {
        protectedPaths.withLock { $0 }
    }
}

actor RecordingAlarmRemoval: AppCreatedAlarmRemoving {
    private(set) var count = 0

    func removeAllAppCreatedAlarms() async throws {
        count += 1
    }
}

actor RecordingFileRemoval: ProtectedLocalFilesRemoving {
    private(set) var count = 0

    func removeDownloadedAudioAndExports() async throws {
        count += 1
    }
}

actor ScriptedAccountDeletionGateway: AccountDeletionGateway {
    private var failuresRemaining: Int
    private(set) var requestIDs: [UUID] = []
    private(set) var retryTokens: [String?] = []

    init(failuresRemaining: Int = 0) {
        self.failuresRemaining = failuresRemaining
    }

    func deleteAccount(
        requestID: UUID,
        accessToken: String,
        retryToken: String?
    ) async throws -> String? {
        _ = accessToken
        requestIDs.append(requestID)
        retryTokens.append(retryToken)
        if failuresRemaining > 0 {
            failuresRemaining -= 1
            throw AccountDeletionGatewayError.recoverable(
                retryToken: "ephemeral-retry-proof"
            )
        }
        return nil
    }
}

actor RecordingAccountDeletionSessionSignOut: AccountDeletionSessionSigningOut {
    private(set) var count = 0

    func signOut() async throws {
        count += 1
    }
}

final class DataRightsFoundationTests: XCTestCase {
    func testExportIsDeterministicProtectedAndContainsOnlyApprovedFiles() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let protection = RecordingProtection()
        let service = LocalExportService(
            clock: FixedClock(value: Phase1BFixture.now),
            identifier: FixedIdentifierGenerator(value: Phase1BFixture.key),
            protection: protection
        )
        let snapshot = LocalExportSnapshot(
            appVersion: "0.1.0",
            profileCreatedAt: Phase1BFixture.now,
            policyVersions: ["privacy": "v1"],
            settings: Phase1BFixture.settings(),
            alarm: nil,
            checkIns: [Phase1BFixture.checkIn()],
            persona: nil,
            scope: .localOnly
        )

        let first = try service.create(
            snapshot: snapshot,
            profileID: Phase1BFixture.profileID,
            in: directory
        )
        let firstBytes = try Data(contentsOf: first.archiveURL)
        let second = try service.create(
            snapshot: snapshot,
            profileID: Phase1BFixture.profileID,
            in: directory
        )
        let secondBytes = try Data(contentsOf: second.archiveURL)
        let visibleBytes = try XCTUnwrap(searchableArchiveText(firstBytes))

        XCTAssertEqual(firstBytes, secondBytes)
        XCTAssertTrue(firstBytes.starts(with: [0x50, 0x4B, 0x03, 0x04]))
        XCTAssertEqual(
            first.includedFileNames,
            ["manifest.json", "settings.json", "alarm.json", "checkins.json", "checkins.csv"]
        )
        XCTAssertFalse(visibleBytes.contains("synthetic-access"))
        XCTAssertFalse(visibleBytes.contains("provider-revocation-proof"))
        XCTAssertFalse(visibleBytes.contains("sync_operations"))
        XCTAssertFalse(visibleBytes.contains("tombstone"))
        XCTAssertEqual(protection.paths.count, 4)
    }

    func testExportOmitsDeletedEntriesAndAbandonedDraftsByConstruction() throws {
        var deleted = Phase1BFixture.checkIn()
        deleted.deletedAt = Phase1BFixture.now
        let service = LocalExportService(
            clock: FixedClock(value: Phase1BFixture.now),
            identifier: FixedIdentifierGenerator(value: Phase1BFixture.key),
            protection: RecordingProtection()
        )
        let artifact = try service.create(
            snapshot: LocalExportSnapshot(
                appVersion: "0.1.0",
                profileCreatedAt: Phase1BFixture.now,
                policyVersions: [:],
                settings: Phase1BFixture.settings(),
                alarm: nil,
                checkIns: [deleted],
                persona: nil,
                scope: .lastSyncedLocalSnapshot
            ),
            profileID: Phase1BFixture.profileID,
            in: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        )
        let bytes = try XCTUnwrap(
            searchableArchiveText(Data(contentsOf: artifact.archiveURL))
        )
        XCTAssertFalse(bytes.contains(Phase1BFixture.entityID.uuidString))
        XCTAssertFalse(bytes.contains("draft"))
    }

    func testPersonaExportIsIncludedOnlyAsTheApprovedRedactedProjection() throws {
        let aggregate = PersonaAnswerAggregate(
            id: Phase1BFixture.profileID,
            profileID: Phase1BFixture.profileID,
            accountUserID: Phase1BFixture.userID,
            episodeFrequency: .weekly,
            postEpisodeFeeling: .awakeScared,
            calmingPersonContext: .alone,
            derivedPersona: .frequentIntenseNoCalmingPerson,
            routingRuleVersion: PersonaRouting.initialRuleVersion,
            calculatedAt: Phase1BFixture.now,
            createdAt: Phase1BFixture.now,
            updatedAt: Phase1BFixture.now,
            revision: 1
        )
        let service = LocalExportService(
            clock: FixedClock(value: Phase1BFixture.now),
            identifier: FixedIdentifierGenerator(value: Phase1BFixture.key),
            protection: RecordingProtection()
        )
        let artifact = try service.create(
            snapshot: LocalExportSnapshot(
                appVersion: "0.1.0",
                profileCreatedAt: Phase1BFixture.now,
                policyVersions: [:],
                settings: Phase1BFixture.settings(),
                alarm: nil,
                checkIns: [],
                persona: PersonaExport(aggregate),
                scope: .localOnly
            ),
            profileID: Phase1BFixture.profileID,
            in: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        )
        let personaData = try XCTUnwrap(
            uncompressedZIPEntry(named: "persona.json", in: Data(contentsOf: artifact.archiveURL))
        )
        let persona = try XCTUnwrap(
            JSONSerialization.jsonObject(with: personaData) as? [String: Any]
        )
        XCTAssertTrue(artifact.includedFileNames.contains("persona.json"))
        XCTAssertEqual(
            Set(persona.keys),
            Set([
                "episode_frequency", "post_episode_feeling", "calming_person_context",
                "derived_persona", "routing_rule_version", "calculated_at",
            ])
        )
        XCTAssertEqual(persona["episode_frequency"] as? String, "weekly")
        XCTAssertEqual(persona["post_episode_feeling"] as? String, "awake_scared")
        XCTAssertEqual(persona["calming_person_context"] as? String, "alone")
        XCTAssertEqual(persona["derived_persona"] as? String, "frequent_intense_no_calming_person")
        XCTAssertEqual(persona["routing_rule_version"] as? String, PersonaRouting.initialRuleVersion)
        XCTAssertNotNil(persona["calculated_at"] as? String)
    }

    func testExportProtectionFailureFailsClosed() {
        let service = LocalExportService(
            clock: FixedClock(value: Phase1BFixture.now),
            identifier: FixedIdentifierGenerator(value: Phase1BFixture.key),
            protection: RecordingProtection(shouldFail: true)
        )
        XCTAssertThrowsError(
            try service.create(
                snapshot: LocalExportSnapshot(
                    appVersion: "0.1.0",
                    profileCreatedAt: Phase1BFixture.now,
                    policyVersions: [:],
                    settings: Phase1BFixture.settings(),
                    alarm: nil,
                    checkIns: [],
                    persona: nil,
                    scope: .localOnly
                ),
                profileID: Phase1BFixture.profileID,
                in: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            )
        )
    }

    func testLocalDeletionReconcilesDatabaseKeychainAlarmsAndFiles() async throws {
        let database = try LocalDatabase(path: temporaryDatabasePath())
        try await database.createProfile(Phase1BFixture.profile(), settings: Phase1BFixture.settings())
        let keychain = LockedKeychain()
        let sessionStore = KeychainSessionStore(keychain: keychain)
        try sessionStore.writeIdentity(AuthenticationIdentityRecord(session: Phase1BFixture.session()))
        let alarms = RecordingAlarmRemoval()
        let files = RecordingFileRemoval()
        let coordinator = LocalDataDeletionCoordinator(
            database: database,
            sessionStore: sessionStore,
            alarms: alarms,
            files: files
        )

        try await coordinator.deleteAllLocalData()
        let profile = try await database.profile(id: Phase1BFixture.profileID)
        let alarmCount = await alarms.count
        let fileCount = await files.count
        XCTAssertNil(profile)
        XCTAssertNil(try sessionStore.readIdentity())
        XCTAssertEqual(alarmCount, 1)
        XCTAssertEqual(fileCount, 1)
    }

    func testAccountDeletionRequiresRecentMatchingReauthentication() async throws {
        let coordinator = try await accountDeletionCoordinator(
            gateway: ScriptedAccountDeletionGateway()
        )
        await XCTAssertThrowsErrorAsync {
            try await coordinator.deleteAccount(
                session: Phase1BFixture.session(),
                reauthentication: RecentReauthentication(
                    userID: Phase1BFixture.userID,
                    provider: .apple,
                    authenticatedAt: Phase1BFixture.now.addingTimeInterval(-301)
                ),
                removeLocalData: false
            )
        }
        let state = await coordinator.state
        XCTAssertEqual(state, .reauthenticationRequired)
    }

    func testAccountDeletionCompletionFeedbackConfirmsRemoteAndLocalCompletion() {
        XCTAssertTrue(AccountDeletionFeedback.completed.contains("account was deleted"))
        XCTAssertTrue(AccountDeletionFeedback.completed.contains("Local data was removed"))
        XCTAssertTrue(AccountDeletionFeedback.completed.contains("signed out"))
    }

    func testAccountDeletionRejectsReauthenticationFromDifferentProvider() async throws {
        let coordinator = try await accountDeletionCoordinator(
            gateway: ScriptedAccountDeletionGateway()
        )
        do {
            try await coordinator.deleteAccount(
                session: Phase1BFixture.session(),
                reauthentication: RecentReauthentication(
                    userID: Phase1BFixture.userID,
                    provider: .google,
                    authenticatedAt: Phase1BFixture.now
                ),
                removeLocalData: false
            )
            XCTFail("Expected provider mismatch rejection.")
        } catch let error as DeletionError {
            XCTAssertEqual(error, .wrongAccount)
        }
    }

    func testAccountDeletionRejectsReauthenticationFromDifferentAccount() async throws {
        let coordinator = try await accountDeletionCoordinator(
            gateway: ScriptedAccountDeletionGateway()
        )
        do {
            try await coordinator.deleteAccount(
                session: Phase1BFixture.session(),
                reauthentication: RecentReauthentication(
                    userID: Phase1BFixture.uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"),
                    provider: .apple,
                    authenticatedAt: Phase1BFixture.now
                ),
                removeLocalData: false
            )
            XCTFail("Expected account mismatch rejection.")
        } catch let error as DeletionError {
            XCTAssertEqual(error, .wrongAccount)
        }
    }

    func testInterruptedAccountDeletionRetriesWithSameRequestID() async throws {
        let gateway = ScriptedAccountDeletionGateway(failuresRemaining: 1)
        let signOut = RecordingAccountDeletionSessionSignOut()
        let coordinator = try await accountDeletionCoordinator(
            gateway: gateway,
            sessionSignOut: signOut
        )
        let reauthentication = RecentReauthentication(
            userID: Phase1BFixture.userID,
            provider: .apple,
            authenticatedAt: Phase1BFixture.now
        )
        await XCTAssertThrowsErrorAsync {
            try await coordinator.deleteAccount(
                session: Phase1BFixture.session(),
                reauthentication: reauthentication,
                removeLocalData: false
            )
        }
        try await coordinator.deleteAccount(
            session: Phase1BFixture.session(),
            reauthentication: reauthentication,
            removeLocalData: false
        )
        let requestIDs = await gateway.requestIDs
        let retryTokens = await gateway.retryTokens
        let state = await coordinator.state
        XCTAssertEqual(requestIDs.count, 2)
        XCTAssertEqual(Set(requestIDs).count, 1)
        XCTAssertNil(retryTokens[0])
        XCTAssertEqual(retryTokens[1], "ephemeral-retry-proof")
        XCTAssertEqual(state, .completed)
        let signOutCount = await signOut.count
        XCTAssertEqual(signOutCount, 1)
    }

    func testRecoverableDeletionRetriesWithSameRequestIDAndRetryToken() async throws {
        let gateway = ScriptedAccountDeletionGateway(failuresRemaining: 1)
        let signOut = RecordingAccountDeletionSessionSignOut()
        let coordinator = try await accountDeletionCoordinator(
            gateway: gateway,
            sessionSignOut: signOut
        )
        let validProof = RecentReauthentication(
            userID: Phase1BFixture.userID,
            provider: .apple,
            authenticatedAt: Phase1BFixture.now
        )

        await XCTAssertThrowsErrorAsync {
            try await coordinator.deleteAccount(
                session: Phase1BFixture.session(),
                reauthentication: validProof,
                removeLocalData: false
            )
        }
        try await coordinator.deleteAccount(
            session: Phase1BFixture.session(),
            reauthentication: RecentReauthentication(
                userID: Phase1BFixture.userID,
                provider: .apple,
                authenticatedAt: Phase1BFixture.now.addingTimeInterval(-301)
            ),
            removeLocalData: false
        )

        let requestIDs = await gateway.requestIDs
        let retryTokens = await gateway.retryTokens
        XCTAssertEqual(requestIDs, [Phase1BFixture.key, Phase1BFixture.key])
        XCTAssertNil(retryTokens[0])
        XCTAssertEqual(retryTokens[1], "ephemeral-retry-proof")
        let state = await coordinator.state
        XCTAssertEqual(state, .completed)
    }

    func testAccountDeletionDoesNotCleanLocalDataBeforeRemoteSuccess() async throws {
        let database = try LocalDatabase(path: temporaryDatabasePath())
        try await database.createProfile(Phase1BFixture.profile(), settings: Phase1BFixture.settings())
        let keychain = LockedKeychain()
        let sessionStore = KeychainSessionStore(keychain: keychain)
        try sessionStore.writeIdentity(AuthenticationIdentityRecord(session: Phase1BFixture.session()))
        let alarms = RecordingAlarmRemoval()
        let files = RecordingFileRemoval()
        let local = LocalDataDeletionCoordinator(
            database: database,
            sessionStore: sessionStore,
            alarms: alarms,
            files: files
        )
        let gateway = ScriptedAccountDeletionGateway(failuresRemaining: 1)
        let signOut = RecordingAccountDeletionSessionSignOut()
        let coordinator = AccountDeletionCoordinator(
            remote: gateway,
            localDeletion: local,
            sessionSignOut: signOut,
            identifier: FixedIdentifierGenerator(value: Phase1BFixture.key),
            clock: FixedClock(value: Phase1BFixture.now)
        )
        let reauthentication = RecentReauthentication(
            userID: Phase1BFixture.userID,
            provider: .apple,
            authenticatedAt: Phase1BFixture.now
        )

        await XCTAssertThrowsErrorAsync {
            try await coordinator.deleteAccount(
                session: Phase1BFixture.session(),
                reauthentication: reauthentication,
                removeLocalData: true
            )
        }
        let firstAlarmCount = await alarms.count
        let firstFileCount = await files.count
        let firstSignOutCount = await signOut.count
        XCTAssertEqual(firstAlarmCount, 0)
        XCTAssertEqual(firstFileCount, 0)
        XCTAssertEqual(firstSignOutCount, 0)

        try await coordinator.deleteAccount(
            session: Phase1BFixture.session(),
            reauthentication: reauthentication,
            removeLocalData: true
        )
        let finalAlarmCount = await alarms.count
        let finalFileCount = await files.count
        let finalSignOutCount = await signOut.count
        XCTAssertEqual(finalAlarmCount, 1)
        XCTAssertEqual(finalFileCount, 1)
        XCTAssertEqual(finalSignOutCount, 1)
        XCTAssertNil(try sessionStore.readIdentity())
        let profile = try await database.profile(id: Phase1BFixture.profileID)
        XCTAssertNil(profile)
    }

    func testSignOutProtectsFormerAccountDataFromDifferentAccount() async throws {
        let database = try LocalDatabase(path: temporaryDatabasePath())
        var linkedProfile = Phase1BFixture.profile()
        linkedProfile.ownership = .accountLinked
        linkedProfile.accountUserID = Phase1BFixture.userID
        linkedProfile.accountLinkState = .linked
        try await database.createProfile(linkedProfile, settings: Phase1BFixture.settings())

        let keychain = LockedKeychain()
        let sessionStore = KeychainSessionStore(keychain: keychain)
        try sessionStore.writeIdentity(AuthenticationIdentityRecord(session: Phase1BFixture.session()))
        let authentication = AuthenticationCoordinator(
            challengeFactory: OAuthChallengeFactory(random: FixedSecureRandom(byte: 7)),
            gateway: ScriptedAuthenticationGateway(
                behavior: .success(Phase1BFixture.session())
            ),
            sessionStore: sessionStore
        )
        let coordinator = SignOutCoordinator(
            database: database,
            authentication: authentication
        )

        try await coordinator.signOut(
            SignOutRequest(
                profileID: Phase1BFixture.profileID,
                userID: Phase1BFixture.userID,
                pendingWork: true,
                pendingChoice: .keepLocallyAndSignOut,
                localChoice: .keepProtectedLocalCopy,
                providerRevocationCredential: nil
            )
        )

        let formerOwner = try await database.profileVisibleToSignedInUser(
            profileID: Phase1BFixture.profileID,
            userID: Phase1BFixture.userID
        )
        let differentOwner = try await database.profileVisibleToSignedInUser(
            profileID: Phase1BFixture.profileID,
            userID: Phase1BFixture.uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        )
        XCTAssertEqual(formerOwner?.ownership, .formerAccountProtected)
        XCTAssertNil(differentOwner)
        XCTAssertNil(try sessionStore.readIdentity())
    }

    func testDiagnosticsBoundaryIsDisabledAndContentFree() {
        let recorder = DisabledDiagnosticsRecorder()
        recorder.record(
            DiagnosticRecord(
                event: .syncOperationResult,
                result: .failedRecoverable,
                coarseOperationCategory: "checkIn"
            )
        )
        XCTAssertEqual(DiagnosticEvent.allCases.count, 7)
    }

    private func accountDeletionCoordinator(
        gateway: ScriptedAccountDeletionGateway,
        sessionSignOut: RecordingAccountDeletionSessionSignOut = RecordingAccountDeletionSessionSignOut()
    ) async throws -> AccountDeletionCoordinator {
        let database = try LocalDatabase(path: temporaryDatabasePath())
        try await database.createProfile(Phase1BFixture.profile(), settings: Phase1BFixture.settings())
        let local = LocalDataDeletionCoordinator(
            database: database,
            sessionStore: KeychainSessionStore(keychain: LockedKeychain()),
            alarms: RecordingAlarmRemoval(),
            files: RecordingFileRemoval()
        )
        return AccountDeletionCoordinator(
            remote: gateway,
            localDeletion: local,
            sessionSignOut: sessionSignOut,
            identifier: FixedIdentifierGenerator(value: Phase1BFixture.key),
            clock: FixedClock(value: Phase1BFixture.now)
        )
    }

    private func searchableArchiveText(_ archive: Data) -> String? {
        let printableASCII = archive.map { byte in
            (0x20 ... 0x7E).contains(byte) ? byte : 0x20
        }
        return String(bytes: printableASCII, encoding: .utf8)
    }

    private func uncompressedZIPEntry(named expectedName: String, in archive: Data) -> Data? {
        var offset = 0
        while offset + 30 <= archive.count {
            guard littleEndianUInt32(archive, offset) == 0x0403_4B50 else { return nil }
            let compressedSize = Int(littleEndianUInt32(archive, offset + 18))
            let nameLength = Int(littleEndianUInt16(archive, offset + 26))
            let extraLength = Int(littleEndianUInt16(archive, offset + 28))
            let nameStart = offset + 30
            let dataStart = nameStart + nameLength + extraLength
            guard dataStart + compressedSize <= archive.count,
                  let name = String(data: archive.subdata(in: nameStart ..< nameStart + nameLength), encoding: .utf8)
            else { return nil }
            if name == expectedName {
                return archive.subdata(in: dataStart ..< dataStart + compressedSize)
            }
            offset = dataStart + compressedSize
        }
        return nil
    }

    private func littleEndianUInt16(_ data: Data, _ offset: Int) -> UInt16 {
        UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private func littleEndianUInt32(_ data: Data, _ offset: Int) -> UInt32 {
        UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
    }
}
