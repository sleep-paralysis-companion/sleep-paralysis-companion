import Foundation
import GRDB
@testable import SleepParalysisCompanion
import XCTest

final class LocalDatabaseTests: XCTestCase {
    func testInitialRemoteUpsertIsIdempotentUntilAcknowledged() async throws {
        let database = try await seededDatabase()
        let operation = SynchronizationOperation(
            id: UUID(),
            profileID: Phase1BFixture.profileID,
            entityType: .profile,
            entityID: Phase1BFixture.profileID,
            operation: .upsert,
            idempotencyKey: UUID(),
            baseRevision: 0,
            localRevision: 1,
            state: .pending,
            attemptCount: 0,
            nextAttemptAt: nil,
            lastErrorCategory: nil,
            createdAt: Phase1BFixture.now,
            updatedAt: Phase1BFixture.now
        )

        try await database.enqueueInitialUpsertIfNeeded(operation)
        var duplicate = operation
        duplicate = SynchronizationOperation(
            id: UUID(),
            profileID: duplicate.profileID,
            entityType: duplicate.entityType,
            entityID: duplicate.entityID,
            operation: duplicate.operation,
            idempotencyKey: UUID(),
            baseRevision: duplicate.baseRevision,
            localRevision: duplicate.localRevision,
            state: duplicate.state,
            attemptCount: duplicate.attemptCount,
            nextAttemptAt: duplicate.nextAttemptAt,
            lastErrorCategory: duplicate.lastErrorCategory,
            createdAt: duplicate.createdAt,
            updatedAt: duplicate.updatedAt
        )
        try await database.enqueueInitialUpsertIfNeeded(duplicate)

        let operations = try await database.operations(profileID: Phase1BFixture.profileID)
        XCTAssertEqual(operations.filter { $0.entityType == .profile }.count, 1)
    }

    func testLatestUpsertSupersedesOlderPendingRevision() async throws {
        let database = try await seededDatabase()
        let first = Phase1BFixture.operation()
        try await database.enqueueLatestUpsert(first)
        let second = SynchronizationOperation(
            id: UUID(),
            profileID: first.profileID,
            entityType: first.entityType,
            entityID: first.entityID,
            operation: .upsert,
            idempotencyKey: UUID(),
            baseRevision: 1,
            localRevision: 2,
            state: .pending,
            attemptCount: 0,
            nextAttemptAt: nil,
            lastErrorCategory: nil,
            createdAt: Phase1BFixture.now.addingTimeInterval(1),
            updatedAt: Phase1BFixture.now.addingTimeInterval(1)
        )
        try await database.enqueueLatestUpsert(second)

        let operations = try await database.operations(profileID: Phase1BFixture.profileID)
        XCTAssertEqual(operations.first(where: { $0.id == first.id })?.state, .deleted)
        XCTAssertEqual(operations.first(where: { $0.id == second.id })?.state, .pending)
    }

    func testCleanDatabaseCreationAndCoreCRUD() async throws {
        let database = try LocalDatabase(path: temporaryDatabasePath())
        try await database.createProfile(Phase1BFixture.profile(), settings: Phase1BFixture.settings())

        let version = try await database.schemaVersion()
        let profile = try await database.profile(id: Phase1BFixture.profileID)
        let settings = try await database.settings(profileID: Phase1BFixture.profileID)
        XCTAssertEqual(version, LocalSchema.currentVersion)
        XCTAssertEqual(profile, Phase1BFixture.profile())
        XCTAssertEqual(settings, Phase1BFixture.settings())
    }

    func testRelaunchPersistence() async throws {
        let path = temporaryDatabasePath()
        var database: LocalDatabase? = try LocalDatabase(path: path)
        try await database?.createProfile(Phase1BFixture.profile(), settings: Phase1BFixture.settings())
        try await database?.submitCheckIn(Phase1BFixture.checkIn(), draftID: nil)
        database = nil

        let reopened = try LocalDatabase(path: path)
        let checkIns = try await reopened.checkIns(profileID: Phase1BFixture.profileID)
        XCTAssertEqual(checkIns, [Phase1BFixture.checkIn()])
    }

    func testPartnerContactPersistsLocallyForTheAuthenticatedProfile() async throws {
        let database = try LocalDatabase(path: temporaryDatabasePath())
        var profile = Phase1BFixture.profile()
        profile.ownership = .accountLinked
        profile.accountUserID = Phase1BFixture.userID
        profile.accountLinkState = .linked
        try await database.createProfile(profile, settings: Phase1BFixture.settings())

        let contact = try XCTUnwrap(PartnerContact(name: "Alex", phoneNumber: "+1 555 123 4567"))
        try await database.savePartnerContact(
            contact,
            profileID: profile.id,
            authenticatedUserID: Phase1BFixture.userID
        )
        let storedContact = try await database.partnerContact(profileID: profile.id)
        XCTAssertEqual(storedContact, contact)

        try await database.deletePartnerContact(
            profileID: profile.id,
            authenticatedUserID: Phase1BFixture.userID
        )
        let deletedContact = try await database.partnerContact(profileID: profile.id)
        XCTAssertNil(deletedContact)
    }

    func testTransactionalProfileAndSettingsCreationRollsBack() async throws {
        let database = try LocalDatabase(path: temporaryDatabasePath())
        var invalid = Phase1BFixture.settings()
        invalid.revision = 0

        await XCTAssertThrowsErrorAsync {
            try await database.createProfile(Phase1BFixture.profile(), settings: invalid)
        }
        let profile = try await database.profile(id: Phase1BFixture.profileID)
        XCTAssertNil(profile)
    }

    func testAlarmCatalogAndCacheCRUD() async throws {
        let database = try await seededDatabase()
        let alarm = AlarmPreference(
            id: Phase1BFixture.entityID,
            profileID: Phase1BFixture.profileID,
            systemAlarmID: nil,
            alarmSoundFileName: "SPCWakeUpGentleLoop.caf",
            localHour: 22,
            localMinute: 30,
            weekdaysMask: 62,
            snoozeMinutes: 10,
            enabledIntent: true,
            systemState: .notScheduled,
            lastScheduleResult: .none,
            createdAt: Phase1BFixture.now,
            updatedAt: Phase1BFixture.now,
            revision: 1
        )
        try await database.saveAlarm(alarm)
        let alarms = try await database.alarms(profileID: Phase1BFixture.profileID)
        XCTAssertEqual(alarms, [alarm])

        let catalog = AudioCatalogItem(
            id: "synthetic-audio",
            version: 1,
            localeIdentifier: "en",
            integritySHA256: String(repeating: "a", count: 64),
            byteCount: 10,
            durationMilliseconds: 1000,
            provenanceReference: "TEST-AUDIO",
            rightsReference: "TEST-RIGHTS",
            approvalReference: "TEST-APPROVAL"
        )
        let cache = AudioCacheMetadata(
            assetID: catalog.id,
            catalogVersion: 1,
            state: .verified,
            relativeFileName: "synthetic.bin",
            verifiedAt: Phase1BFixture.now,
            byteCount: 10
        )
        try await database.saveAudioCatalogItem(catalog)
        try await database.saveAudioCacheMetadata(cache)
        let storedCatalog = try await database.audioCatalogItem(id: catalog.id)
        let storedCache = try await database.audioCacheMetadata(assetID: catalog.id)
        XCTAssertEqual(storedCatalog, catalog)
        XCTAssertEqual(storedCache, cache)
    }

    func testDraftRetentionPurgesAfterSevenDays() async throws {
        let database = try await seededDatabase()
        let oldDraft = CheckInDraft(
            id: Phase1BFixture.entityID,
            profileID: Phase1BFixture.profileID,
            reportedForLocalDate: "2026-07-20",
            reportedTimezoneID: "UTC",
            occurrence: nil,
            perceivedIntensity: nil,
            presentState: nil,
            note: nil,
            draftUpdatedAt: Phase1BFixture.now.addingTimeInterval(-8 * 86400)
        )
        try await database.saveDraft(oldDraft)
        let drafts = try await database.drafts(profileID: Phase1BFixture.profileID)
        XCTAssertEqual(drafts, [oldDraft])
        let count = try await database.purgeDrafts(
            olderThan: Phase1BFixture.now.addingTimeInterval(-7 * 86400)
        )
        XCTAssertEqual(count, 1)
    }

    func testSubmittedCheckInConstraints() async throws {
        let database = try await seededDatabase()
        var invalid = Phase1BFixture.checkIn()
        invalid.occurrence = .no
        invalid.perceivedIntensity = .severe
        await XCTAssertThrowsErrorAsync {
            try await database.submitCheckIn(invalid, draftID: nil)
        }

        var longNote = Phase1BFixture.checkIn()
        longNote.note = String(repeating: "x", count: 501)
        await XCTAssertThrowsErrorAsync {
            try await database.submitCheckIn(longNote, draftID: nil)
        }

        let expected = Phase1BFixture.checkIn()
        try await database.submitCheckIn(expected, draftID: nil)
        let stored = try await database.checkIn(
            id: expected.id,
            profileID: expected.profileID
        )
        XCTAssertEqual(stored?.spcOutcome, .calmer)
        XCTAssertEqual(stored?.postEpisodeSupport, .calmingAudio)
        XCTAssertNil(stored?.sleepHelpOutcome)
    }

    func testIndividualDeletionCreatesTombstoneAndStableQueueOperation() async throws {
        let database = try await seededDatabase()
        try await database.submitCheckIn(Phase1BFixture.checkIn(), draftID: nil)
        try await database.deleteCheckIn(
            DeleteCheckInRequest(
                id: Phase1BFixture.entityID,
                profileID: Phase1BFixture.profileID,
                date: Phase1BFixture.now.addingTimeInterval(60),
                tombstoneID: Phase1BFixture.uuid(
                    "66666666-6666-4666-8666-666666666666"
                ),
                operationID: Phase1BFixture.operationID,
                idempotencyKey: Phase1BFixture.key
            )
        )

        let visible = try await database.checkIns(profileID: Phase1BFixture.profileID)
        XCTAssertTrue(visible.isEmpty)
        let includingDeleted = try await database.checkIns(
            profileID: Phase1BFixture.profileID,
            includeDeleted: true
        )
        XCTAssertNotNil(includingDeleted.first?.deletedAt)
        let operations = try await database.operations(profileID: Phase1BFixture.profileID)
        XCTAssertEqual(operations.count, 1)
        XCTAssertEqual(
            operations.first?.entityID,
            Phase1BFixture.uuid("66666666-6666-4666-8666-666666666666")
        )
        XCTAssertEqual(operations.first?.idempotencyKey, Phase1BFixture.key)
        let tombstones = try await database.tombstones(profileID: Phase1BFixture.profileID)
        XCTAssertEqual(tombstones.count, 1)
        try await database.acknowledgeTombstone(
            id: tombstones[0].id,
            at: Phase1BFixture.now.addingTimeInterval(120),
            purgeAfter: Phase1BFixture.now.addingTimeInterval(31 * 86400)
        )
        let acknowledged = try await database.tombstones(profileID: Phase1BFixture.profileID)
        XCTAssertNotNil(acknowledged[0].acknowledgedAt)
    }

    func testRevisionPolicyAndExportMetadataCRUD() async throws {
        let database = try await seededDatabase()
        let revision = EntityRevision(
            profileID: Phase1BFixture.profileID,
            entityType: .checkIn,
            entityID: Phase1BFixture.entityID,
            localRevision: 1,
            acknowledgedRemoteRevision: 1,
            lastRemoteMutationID: Phase1BFixture.operationID
        )
        let notice = PolicyNoticeState(
            profileID: Phase1BFixture.profileID,
            noticeKind: "privacy",
            version: "2026-07",
            seenAt: Phase1BFixture.now
        )
        let export = ExportMetadata(
            id: Phase1BFixture.operationID,
            profileID: Phase1BFixture.profileID,
            generatedAt: Phase1BFixture.now,
            expiresAt: Phase1BFixture.now.addingTimeInterval(86400),
            scope: .localOnly,
            manifestVersion: 1
        )

        try await database.saveEntityRevision(revision)
        try await database.savePolicyNotice(notice)
        try await database.saveExportMetadata(export)

        let storedRevision = try await database.entityRevision(
            profileID: Phase1BFixture.profileID,
            entityType: .checkIn,
            entityID: Phase1BFixture.entityID
        )
        let storedNotice = try await database.policyNotice(
            profileID: Phase1BFixture.profileID,
            kind: "privacy"
        )
        let storedExports = try await database.exportMetadata(
            profileID: Phase1BFixture.profileID
        )
        XCTAssertEqual(storedRevision, revision)
        XCTAssertEqual(storedNotice, notice)
        XCTAssertEqual(storedExports, [export])
    }

    func testOnlyOneLocalProfileCanExistPerInstallation() async throws {
        let database = try await seededDatabase()
        let secondID = Phase1BFixture.uuid("99999999-9999-4999-8999-999999999999")
        let second = LocalProfile(
            id: secondID,
            createdAt: Phase1BFixture.now,
            onboardingCompletedAt: nil,
            productNoticeVersion: "v1",
            productNoticeSeenAt: Phase1BFixture.now,
            ownership: .guestLocal,
            accountUserID: nil,
            accountLinkState: .localOnly
        )
        var settings = Phase1BFixture.settings()
        settings = AppSettings(
            profileID: secondID,
            preferredGroundingAssetID: settings.preferredGroundingAssetID,
            preferredModality: settings.preferredModality,
            hapticsEnabled: settings.hapticsEnabled,
            lastSelectedHistoryPeriod: settings.lastSelectedHistoryPeriod,
            diagnosticsEnabled: settings.diagnosticsEnabled,
            updatedAt: settings.updatedAt,
            revision: settings.revision
        )
        await XCTAssertThrowsErrorAsync {
            try await database.createProfile(second, settings: settings)
        }
    }

    func testWriteFailureDoesNotDestroyPriorDataAndRelaunchRecovers() async throws {
        let path = temporaryDatabasePath()
        let healthy = try LocalDatabase(path: path)
        try await healthy.createProfile(Phase1BFixture.profile(), settings: Phase1BFixture.settings())

        let failing = try LocalDatabase(path: path, writeFault: FailingLocalWrite())
        await XCTAssertThrowsErrorAsync {
            try await failing.saveSettings(Phase1BFixture.settings(revision: 2))
        }

        let reopened = try LocalDatabase(path: path)
        let revision = try await reopened.settings(profileID: Phase1BFixture.profileID)?.revision
        XCTAssertEqual(revision, 1)
    }

    func testUnsupportedNewerSchemaFailsWithoutReset() throws {
        let path = temporaryDatabasePath()
        let queue = try DatabaseQueue(path: path)
        try queue.write { database in
            try database.execute(
                sql: """
                CREATE TABLE spc_schema_metadata (
                    singleton INTEGER PRIMARY KEY,
                    schema_version INTEGER NOT NULL
                );
                INSERT INTO spc_schema_metadata VALUES (1, 99);
                CREATE TABLE preserved_user_data (value TEXT);
                INSERT INTO preserved_user_data VALUES ('preserve');
                """
            )
        }
        XCTAssertThrowsError(try LocalDatabase(path: path)) { error in
            XCTAssertEqual(
                error as? LocalDatabaseError,
                .unsupportedNewerSchema(found: 99, supported: 6)
            )
        }
        let preserved = try queue.read {
            try String.fetchOne($0, sql: "SELECT value FROM preserved_user_data")
        }
        XCTAssertEqual(preserved, "preserve")
    }

    func testCorruptDatabaseIsNotSilentlyDeleted() throws {
        let url = URL(fileURLWithPath: temporaryDatabasePath())
        let bytes = Data("not-a-sqlite-database".utf8)
        try bytes.write(to: url)

        XCTAssertThrowsError(try LocalDatabase(path: url.path))
        XCTAssertEqual(try Data(contentsOf: url), bytes)
    }

    func testMigrationFromCommittedV1ToV6() async throws {
        let path = temporaryDatabasePath()
        let queue = try DatabaseQueue(path: path)
        try LocalSchema.migrator().migrate(queue, upTo: "v1_core_local_data")

        let migrated = try LocalDatabase(path: path)
        let version = try await migrated.schemaVersion()
        XCTAssertEqual(version, 6)
    }

    func testMigrationFromCommittedV2ToV6() async throws {
        let path = temporaryDatabasePath()
        let queue = try DatabaseQueue(path: path)
        try LocalSchema.migrator().migrate(queue, upTo: "v2_sync_security_foundation")

        let migrated = try LocalDatabase(path: path)
        let version = try await migrated.schemaVersion()
        XCTAssertEqual(version, 6)
    }

    func testMigrationFromCommittedV3ToV6PreservesNoFabricatedPersonaData() async throws {
        let path = temporaryDatabasePath()
        let queue = try DatabaseQueue(path: path)
        try LocalSchema.migrator().migrate(queue, upTo: "v3_persona_and_local_personal_audio")

        let migrated = try LocalDatabase(path: path)
        var profile = Phase1BFixture.profile()
        profile.ownership = .accountLinked
        profile.accountUserID = Phase1BFixture.userID
        profile.accountLinkState = .linked
        try await migrated.createProfile(profile, settings: Phase1BFixture.settings())
        let version = try await migrated.schemaVersion()
        let persona = try await migrated.personaAnswerAggregate(
            profileID: Phase1BFixture.profileID,
            authenticatedUserID: Phase1BFixture.userID
        )
        XCTAssertEqual(version, 6)
        XCTAssertNil(persona)
    }

    func testInterruptedMigrationRollsBackItsTransaction() throws {
        let queue = try DatabaseQueue()
        var migrator = DatabaseMigrator()
        migrator.registerMigration("interrupted") { database in
            try database.create(table: "partial_conversion") {
                $0.column("id", .integer).primaryKey()
            }
            throw CocoaError(.fileWriteUnknown)
        }
        XCTAssertThrowsError(try migrator.migrate(queue))
        let tableExists = try queue.read { try $0.tableExists("partial_conversion") }
        XCTAssertFalse(tableExists)
    }

    private func seededDatabase() async throws -> LocalDatabase {
        let database = try LocalDatabase(path: temporaryDatabasePath())
        try await database.createProfile(Phase1BFixture.profile(), settings: Phase1BFixture.settings())
        return database
    }
}

func XCTAssertThrowsErrorAsync(
    _ expression: () async throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await expression()
        XCTFail("Expected an error.", file: file, line: line)
    } catch {
        _ = error
    }
}
