import Foundation
import GRDB

actor LocalDatabase {
    private let pool: DatabasePool
    private let writeFault: any LocalWriteFaultInjecting

    init(
        path: String,
        writeFault: any LocalWriteFaultInjecting = NoLocalWriteFault()
    ) throws {
        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        configuration.busyMode = .timeout(2)
        configuration.label = "SPC.LocalDatabase"

        do {
            let databasePool = try DatabasePool(path: path, configuration: configuration)
            let storedVersion = try databasePool.read { database -> Int? in
                guard try database.tableExists("spc_schema_metadata") else {
                    return nil
                }
                return try Int.fetchOne(
                    database,
                    sql: "SELECT schema_version FROM spc_schema_metadata WHERE singleton = 1"
                )
            }
            if let storedVersion, storedVersion > LocalSchema.currentVersion {
                throw LocalDatabaseError.unsupportedNewerSchema(
                    found: storedVersion,
                    supported: LocalSchema.currentVersion
                )
            }
            try LocalSchema.migrator().migrate(databasePool)
            pool = databasePool
            self.writeFault = writeFault
        } catch let error as LocalDatabaseError {
            throw error
        } catch let error as DatabaseError where error.resultCode == .SQLITE_NOTADB {
            throw LocalDatabaseError.corruptOrUnreadable
        } catch {
            throw LocalDatabaseError.migrationFailed
        }
    }

    func schemaVersion() throws -> Int {
        try pool.read { database in
            guard let version = try Int.fetchOne(
                database,
                sql: "SELECT schema_version FROM spc_schema_metadata WHERE singleton = 1"
            ) else {
                throw LocalDatabaseError.corruptOrUnreadable
            }
            return version
        }
    }

    func createProfile(_ profile: LocalProfile, settings: AppSettings) throws {
        guard profile.id == settings.profileID else {
            throw LocalDatabaseError.constraintViolation
        }
        try write {
            try LocalProfileRecord(profile).insert($0)
            try AppSettingsRecord(settings).insert($0)
        }
    }

    func profile(id: UUID) throws -> LocalProfile? {
        try pool.read { database in
            try LocalProfileRecord.fetchOne(database, key: id.uuidString)?.domainValue()
        }
    }

    func saveProfile(_ profile: LocalProfile) throws {
        try write { try LocalProfileRecord(profile).save($0) }
    }

    func settings(profileID: UUID) throws -> AppSettings? {
        try pool.read { database in
            try AppSettingsRecord.fetchOne(database, key: profileID.uuidString)?.domainValue()
        }
    }

    func saveSettings(_ settings: AppSettings) throws {
        try write { try AppSettingsRecord(settings).save($0) }
    }

    func saveAlarm(_ alarm: AlarmPreference) throws {
        guard (0 ... 23).contains(alarm.localHour),
              (0 ... 59).contains(alarm.localMinute),
              (0 ... 127).contains(alarm.weekdaysMask)
        else {
            throw Phase1BValidationError.invalidAlarmTime
        }
        try write { try AlarmPreferenceRecord(alarm).save($0) }
    }

    func alarms(profileID: UUID) throws -> [AlarmPreference] {
        try pool.read { database in
            try AlarmPreferenceRecord
                .filter(Column("profileID") == profileID.uuidString)
                .order(Column("createdAt"))
                .fetchAll(database)
                .map { try $0.domainValue() }
        }
    }

    func saveAudioCatalogItem(_ item: AudioCatalogItem) throws {
        let record = AudioCatalogRecord(
            id: item.id,
            version: item.version,
            localeIdentifier: item.localeIdentifier,
            integritySHA256: item.integritySHA256,
            byteCount: item.byteCount,
            durationMilliseconds: item.durationMilliseconds,
            provenanceReference: item.provenanceReference,
            rightsReference: item.rightsReference,
            approvalReference: item.approvalReference
        )
        try write { try record.save($0) }
    }

    func audioCatalogItem(id: String) throws -> AudioCatalogItem? {
        try pool.read { database in
            guard let record = try AudioCatalogRecord.fetchOne(database, key: id) else {
                return nil
            }
            return AudioCatalogItem(
                id: record.id,
                version: record.version,
                localeIdentifier: record.localeIdentifier,
                integritySHA256: record.integritySHA256,
                byteCount: record.byteCount,
                durationMilliseconds: record.durationMilliseconds,
                provenanceReference: record.provenanceReference,
                rightsReference: record.rightsReference,
                approvalReference: record.approvalReference
            )
        }
    }

    func saveAudioCacheMetadata(_ metadata: AudioCacheMetadata) throws {
        let record = AudioCacheRecord(
            assetID: metadata.assetID,
            catalogVersion: metadata.catalogVersion,
            state: metadata.state.rawValue,
            relativeFileName: metadata.relativeFileName,
            verifiedAt: metadata.verifiedAt?.timeIntervalSince1970,
            byteCount: metadata.byteCount
        )
        try write { try record.save($0) }
    }

    func audioCacheMetadata(assetID: String) throws -> AudioCacheMetadata? {
        try pool.read { database in
            guard let record = try AudioCacheRecord.fetchOne(database, key: assetID),
                  let state = AudioCacheState(rawValue: record.state)
            else {
                return nil
            }
            return AudioCacheMetadata(
                assetID: record.assetID,
                catalogVersion: record.catalogVersion,
                state: state,
                relativeFileName: record.relativeFileName,
                verifiedAt: record.verifiedAt.map(Date.init(timeIntervalSince1970:)),
                byteCount: record.byteCount
            )
        }
    }

    func saveDraft(_ draft: CheckInDraft) throws {
        try validateNote(draft.note)
        let record = CheckInDraftRecord(
            id: draft.id.uuidString,
            profileID: draft.profileID.uuidString,
            reportedForLocalDate: draft.reportedForLocalDate,
            reportedTimezoneID: draft.reportedTimezoneID,
            occurrence: draft.occurrence?.rawValue,
            perceivedIntensity: draft.perceivedIntensity?.rawValue,
            presentState: draft.presentState?.rawValue,
            note: normalizedNote(draft.note),
            draftUpdatedAt: draft.draftUpdatedAt.timeIntervalSince1970
        )
        try write { try record.save($0) }
    }

    func drafts(profileID: UUID) throws -> [CheckInDraft] {
        try pool.read { database in
            try CheckInDraftRecord
                .filter(Column("profileID") == profileID.uuidString)
                .order(Column("draftUpdatedAt"))
                .fetchAll(database)
                .compactMap { record in
                    guard let id = UUID(uuidString: record.id),
                          let storedProfileID = UUID(uuidString: record.profileID)
                    else {
                        return nil
                    }
                    return CheckInDraft(
                        id: id,
                        profileID: storedProfileID,
                        reportedForLocalDate: record.reportedForLocalDate,
                        reportedTimezoneID: record.reportedTimezoneID,
                        occurrence: record.occurrence.flatMap(EpisodeOccurrence.init(rawValue:)),
                        perceivedIntensity: record.perceivedIntensity.flatMap(
                            PerceivedIntensity.init(rawValue:)
                        ),
                        presentState: record.presentState.flatMap(PresentState.init(rawValue:)),
                        note: record.note,
                        draftUpdatedAt: Date(timeIntervalSince1970: record.draftUpdatedAt)
                    )
                }
        }
    }

    @discardableResult
    func purgeDrafts(olderThan cutoff: Date) throws -> Int {
        try pool.write { database in
            try CheckInDraftRecord
                .filter(Column("draftUpdatedAt") < cutoff.timeIntervalSince1970)
                .deleteAll(database)
        }
    }

    func submitCheckIn(_ checkIn: SubmittedCheckIn, draftID: UUID?) throws {
        try validate(checkIn)
        try write { database in
            try SubmittedCheckInRecord(checkIn).save(database)
            if let draftID {
                _ = try CheckInDraftRecord.deleteOne(database, key: draftID.uuidString)
            }
        }
    }

    func checkIns(profileID: UUID, includeDeleted: Bool = false) throws -> [SubmittedCheckIn] {
        try pool.read { database in
            var request = SubmittedCheckInRecord
                .filter(Column("profileID") == profileID.uuidString)
            if !includeDeleted {
                request = request.filter(Column("deletedAt") == nil)
            }
            return try request
                .order(Column("reportedForLocalDate").desc)
                .fetchAll(database)
                .map { try $0.domainValue() }
        }
    }

    func deleteCheckIn(
        id: UUID,
        profileID: UUID,
        at date: Date,
        tombstoneID: UUID,
        operationID: UUID,
        idempotencyKey: UUID
    ) throws {
        try write { database in
            guard var record = try SubmittedCheckInRecord.fetchOne(database, key: id.uuidString),
                  record.profileID == profileID.uuidString
            else {
                return
            }
            record.deletedAt = date.timeIntervalSince1970
            record.updatedAt = date.timeIntervalSince1970
            record.revision += 1
            try record.update(database)

            let tombstone = DeletionTombstoneRecord(
                id: tombstoneID.uuidString,
                profileID: profileID.uuidString,
                entityType: SyncEntityType.checkIn.rawValue,
                entityID: id.uuidString,
                deletedRevision: record.revision,
                deletedAt: date.timeIntervalSince1970,
                acknowledgedAt: nil,
                purgeAfter: date.addingTimeInterval(30 * 86400).timeIntervalSince1970
            )
            try tombstone.save(database)

            let operation = SynchronizationOperationRecord(
                id: operationID.uuidString,
                profileID: profileID.uuidString,
                entityType: SyncEntityType.tombstone.rawValue,
                entityID: id.uuidString,
                operation: SyncOperationKind.delete.rawValue,
                idempotencyKey: idempotencyKey.uuidString,
                baseRevision: record.revision - 1,
                localRevision: record.revision,
                state: SynchronizationState.pending.rawValue,
                attemptCount: 0,
                nextAttemptAt: nil,
                lastErrorCategory: nil,
                createdAt: date.timeIntervalSince1970,
                updatedAt: date.timeIntervalSince1970
            )
            try operation.save(database)
        }
    }

    func saveAccountBinding(_ binding: AccountBinding) throws {
        let record = AccountBindingRecord(
            profileID: binding.profileID.uuidString,
            userID: binding.userID.uuidString,
            provider: binding.provider.rawValue,
            maskedIdentifier: binding.maskedIdentifier,
            linkedAt: binding.linkedAt.timeIntervalSince1970,
            sessionExpiresAt: binding.sessionExpiresAt.timeIntervalSince1970,
            requiresReauthentication: binding.requiresReauthentication
        )
        try write { try record.save($0) }
    }

    func accountBinding(profileID: UUID) throws -> AccountBinding? {
        try pool.read { database in
            guard let record = try AccountBindingRecord.fetchOne(database, key: profileID.uuidString),
                  let owner = UUID(uuidString: record.profileID),
                  let userID = UUID(uuidString: record.userID),
                  let provider = AuthenticationProvider(rawValue: record.provider)
            else {
                return nil
            }
            return AccountBinding(
                profileID: owner,
                userID: userID,
                provider: provider,
                maskedIdentifier: record.maskedIdentifier,
                linkedAt: Date(timeIntervalSince1970: record.linkedAt),
                sessionExpiresAt: Date(timeIntervalSince1970: record.sessionExpiresAt),
                requiresReauthentication: record.requiresReauthentication
            )
        }
    }

    func protectFormerAccountData(profileID: UUID, expectedUserID: UUID) throws {
        try write { database in
            guard var profile = try LocalProfileRecord.fetchOne(
                database,
                key: profileID.uuidString
            ), profile.accountUserID == expectedUserID.uuidString else {
                throw AuthenticationError.wrongAccount
            }
            profile.ownership = ProfileOwnership.formerAccountProtected.rawValue
            profile.accountLinkState = AccountLinkState.authRequired.rawValue
            try profile.update(database)
            _ = try AccountBindingRecord.deleteOne(database, key: profileID.uuidString)
        }
    }

    func profileVisibleToSignedInUser(profileID: UUID, userID: UUID?) throws -> LocalProfile? {
        guard let profile = try profile(id: profileID) else {
            return nil
        }
        switch profile.ownership {
        case .guestLocal:
            return userID == nil ? profile : nil
        case .accountLinked:
            return profile.accountUserID == userID ? profile : nil
        case .formerAccountProtected:
            return profile.accountUserID == userID ? profile : nil
        }
    }

    func removeProfileFromDevice(profileID: UUID, expectedUserID: UUID) throws {
        try write { database in
            guard let profile = try LocalProfileRecord.fetchOne(
                database,
                key: profileID.uuidString
            ), profile.accountUserID == expectedUserID.uuidString else {
                throw AuthenticationError.wrongAccount
            }
            _ = try LocalProfileRecord.deleteOne(database, key: profileID.uuidString)
        }
    }

    func enqueue(_ operation: SynchronizationOperation) throws {
        try write { try SynchronizationOperationRecord(operation).insert($0, onConflict: .ignore) }
    }

    func claimNextOperation(profileID: UUID, now: Date) throws -> SynchronizationOperation? {
        try pool.write { database in
            guard var record = try SynchronizationOperationRecord.fetchOne(
                database,
                sql: """
                SELECT * FROM sync_operations
                WHERE profileID = ?
                  AND state IN ('pending', 'failedRecoverable')
                  AND (nextAttemptAt IS NULL OR nextAttemptAt <= ?)
                  AND NOT EXISTS (
                    SELECT 1 FROM sync_operations inflight
                    WHERE inflight.profileID = sync_operations.profileID
                      AND inflight.entityType = sync_operations.entityType
                      AND inflight.entityID = sync_operations.entityID
                      AND inflight.state = 'syncing'
                  )
                ORDER BY createdAt, id
                LIMIT 1
                """,
                arguments: [profileID.uuidString, now.timeIntervalSince1970]
            ) else {
                return nil
            }
            record.state = SynchronizationState.syncing.rawValue
            record.attemptCount += 1
            record.updatedAt = now.timeIntervalSince1970
            try record.update(database)
            return try record.domainValue()
        }
    }

    func saveOperation(_ operation: SynchronizationOperation) throws {
        try write { try SynchronizationOperationRecord(operation).update($0) }
    }

    func operations(profileID: UUID) throws -> [SynchronizationOperation] {
        try pool.read { database in
            try SynchronizationOperationRecord
                .filter(Column("profileID") == profileID.uuidString)
                .order(Column("createdAt"))
                .fetchAll(database)
                .map { try $0.domainValue() }
        }
    }

    func saveEntityRevision(_ revision: EntityRevision) throws {
        guard revision.localRevision > 0 else {
            throw Phase1BValidationError.invalidRevision
        }
        try write { database in
            try EntityRevisionRecord(
                profileID: revision.profileID.uuidString,
                entityType: revision.entityType.rawValue,
                entityID: revision.entityID.uuidString,
                localRevision: revision.localRevision,
                acknowledgedRemoteRevision: revision.acknowledgedRemoteRevision,
                lastRemoteMutationID: revision.lastRemoteMutationID?.uuidString
            ).save(database)
        }
    }

    func entityRevision(
        profileID: UUID,
        entityType: SyncEntityType,
        entityID: UUID
    ) throws -> EntityRevision? {
        try pool.read { database in
            guard let record = try EntityRevisionRecord.fetchOne(
                database,
                key: [
                    "profileID": profileID.uuidString,
                    "entityType": entityType.rawValue,
                    "entityID": entityID.uuidString,
                ]
            ) else {
                return nil
            }
            return EntityRevision(
                profileID: profileID,
                entityType: entityType,
                entityID: entityID,
                localRevision: record.localRevision,
                acknowledgedRemoteRevision: record.acknowledgedRemoteRevision,
                lastRemoteMutationID: record.lastRemoteMutationID.flatMap(UUID.init(uuidString:))
            )
        }
    }

    func tombstones(profileID: UUID) throws -> [DeletionTombstone] {
        try pool.read { database in
            try DeletionTombstoneRecord
                .filter(Column("profileID") == profileID.uuidString)
                .order(Column("deletedAt"))
                .fetchAll(database)
                .compactMap { record in
                    guard let id = UUID(uuidString: record.id),
                          let entityID = UUID(uuidString: record.entityID),
                          let entityType = SyncEntityType(rawValue: record.entityType)
                    else {
                        return nil
                    }
                    return DeletionTombstone(
                        id: id,
                        profileID: profileID,
                        entityType: entityType,
                        entityID: entityID,
                        deletedRevision: record.deletedRevision,
                        deletedAt: Date(timeIntervalSince1970: record.deletedAt),
                        acknowledgedAt: record.acknowledgedAt.map(Date.init(timeIntervalSince1970:)),
                        purgeAfter: Date(timeIntervalSince1970: record.purgeAfter)
                    )
                }
        }
    }

    func acknowledgeTombstone(id: UUID, at date: Date, purgeAfter: Date) throws {
        try write { database in
            guard var record = try DeletionTombstoneRecord.fetchOne(
                database,
                key: id.uuidString
            ), purgeAfter >= date else {
                throw LocalDatabaseError.constraintViolation
            }
            record.acknowledgedAt = date.timeIntervalSince1970
            record.purgeAfter = purgeAfter.timeIntervalSince1970
            try record.update(database)
        }
    }

    @discardableResult
    func purgeAcknowledgedTombstones(before cutoff: Date) throws -> Int {
        try pool.write { database in
            try DeletionTombstoneRecord
                .filter(Column("acknowledgedAt") != nil)
                .filter(Column("purgeAfter") <= cutoff.timeIntervalSince1970)
                .deleteAll(database)
        }
    }

    func savePolicyNotice(_ notice: PolicyNoticeState) throws {
        try write { database in
            try PolicyNoticeRecord(
                profileID: notice.profileID.uuidString,
                noticeKind: notice.noticeKind,
                version: notice.version,
                seenAt: notice.seenAt.timeIntervalSince1970
            ).save(database)
        }
    }

    func policyNotice(profileID: UUID, kind: String) throws -> PolicyNoticeState? {
        try pool.read { database in
            guard let record = try PolicyNoticeRecord.fetchOne(
                database,
                key: ["profileID": profileID.uuidString, "noticeKind": kind]
            ) else {
                return nil
            }
            return PolicyNoticeState(
                profileID: profileID,
                noticeKind: record.noticeKind,
                version: record.version,
                seenAt: Date(timeIntervalSince1970: record.seenAt)
            )
        }
    }

    func saveExportMetadata(_ metadata: ExportMetadata) throws {
        try write { database in
            try ExportMetadataRecord(
                id: metadata.id.uuidString,
                profileID: metadata.profileID.uuidString,
                generatedAt: metadata.generatedAt.timeIntervalSince1970,
                expiresAt: metadata.expiresAt.timeIntervalSince1970,
                scope: metadata.scope.rawValue,
                manifestVersion: metadata.manifestVersion
            ).save(database)
        }
    }

    func exportMetadata(profileID: UUID) throws -> [ExportMetadata] {
        try pool.read { database in
            try ExportMetadataRecord
                .filter(Column("profileID") == profileID.uuidString)
                .order(Column("generatedAt"))
                .fetchAll(database)
                .compactMap { record in
                    guard let id = UUID(uuidString: record.id),
                          let scope = ExportScope(rawValue: record.scope)
                    else {
                        return nil
                    }
                    return ExportMetadata(
                        id: id,
                        profileID: profileID,
                        generatedAt: Date(timeIntervalSince1970: record.generatedAt),
                        expiresAt: Date(timeIntervalSince1970: record.expiresAt),
                        scope: scope,
                        manifestVersion: record.manifestVersion
                    )
                }
        }
    }

    func beginConversion(_ checkpoint: ConversionCheckpoint) throws {
        try write { database in
            guard var profile = try LocalProfileRecord.fetchOne(
                database,
                key: checkpoint.profileID.uuidString
            ), profile.accountUserID == nil else {
                throw AuthenticationError.wrongAccount
            }
            profile.accountLinkState = AccountLinkState.authenticating.rawValue
            try profile.update(database)
            try ConversionCheckpointRecord(
                conversionID: checkpoint.conversionID.uuidString,
                profileID: checkpoint.profileID.uuidString,
                expectedUserID: checkpoint.expectedUserID.uuidString,
                state: checkpoint.state.rawValue,
                mergeChoice: checkpoint.mergeChoice?.rawValue,
                startedAt: checkpoint.startedAt.timeIntervalSince1970,
                updatedAt: checkpoint.updatedAt.timeIntervalSince1970
            ).insert(database)
        }
    }

    func saveConversionCheckpoint(_ checkpoint: ConversionCheckpoint) throws {
        try write { database in
            try ConversionCheckpointRecord(
                conversionID: checkpoint.conversionID.uuidString,
                profileID: checkpoint.profileID.uuidString,
                expectedUserID: checkpoint.expectedUserID.uuidString,
                state: checkpoint.state.rawValue,
                mergeChoice: checkpoint.mergeChoice?.rawValue,
                startedAt: checkpoint.startedAt.timeIntervalSince1970,
                updatedAt: checkpoint.updatedAt.timeIntervalSince1970
            ).save(database)
            guard var profile = try LocalProfileRecord.fetchOne(
                database,
                key: checkpoint.profileID.uuidString
            ) else {
                throw LocalDatabaseError.constraintViolation
            }
            profile.accountLinkState = checkpoint.state.rawValue
            try profile.update(database)
        }
    }

    func conversionCheckpoint(profileID: UUID) throws -> ConversionCheckpoint? {
        try pool.read { database in
            guard let record = try ConversionCheckpointRecord.fetchOne(
                database,
                sql: "SELECT * FROM conversion_checkpoints WHERE profileID = ?",
                arguments: [profileID.uuidString]
            ),
                let conversionID = UUID(uuidString: record.conversionID),
                let storedProfileID = UUID(uuidString: record.profileID),
                let expectedUserID = UUID(uuidString: record.expectedUserID),
                let state = AccountLinkState(rawValue: record.state)
            else {
                return nil
            }
            return ConversionCheckpoint(
                conversionID: conversionID,
                profileID: storedProfileID,
                expectedUserID: expectedUserID,
                state: state,
                mergeChoice: record.mergeChoice.flatMap(GuestMergeChoice.init(rawValue:)),
                startedAt: Date(timeIntervalSince1970: record.startedAt),
                updatedAt: Date(timeIntervalSince1970: record.updatedAt)
            )
        }
    }

    func finalizeConversion(binding: AccountBinding, conversionID: UUID) throws {
        try write { database in
            guard let checkpoint = try ConversionCheckpointRecord.fetchOne(
                database,
                key: conversionID.uuidString
            ),
                checkpoint.expectedUserID == binding.userID.uuidString,
                checkpoint.profileID == binding.profileID.uuidString,
                var profile = try LocalProfileRecord.fetchOne(
                    database,
                    key: binding.profileID.uuidString
                )
            else {
                throw AuthenticationError.wrongAccount
            }
            profile.accountUserID = binding.userID.uuidString
            profile.ownership = ProfileOwnership.accountLinked.rawValue
            profile.accountLinkState = AccountLinkState.linked.rawValue
            try profile.update(database)
            try AccountBindingRecord(
                profileID: binding.profileID.uuidString,
                userID: binding.userID.uuidString,
                provider: binding.provider.rawValue,
                maskedIdentifier: binding.maskedIdentifier,
                linkedAt: binding.linkedAt.timeIntervalSince1970,
                sessionExpiresAt: binding.sessionExpiresAt.timeIntervalSince1970,
                requiresReauthentication: binding.requiresReauthentication
            ).save(database)
            _ = try ConversionCheckpointRecord.deleteOne(database, key: conversionID.uuidString)
        }
    }

    func cancelConversion(profileID: UUID) throws {
        try write { database in
            guard var profile = try LocalProfileRecord.fetchOne(
                database,
                key: profileID.uuidString
            ), profile.accountUserID == nil else {
                throw AuthenticationError.wrongAccount
            }
            profile.ownership = ProfileOwnership.guestLocal.rawValue
            profile.accountLinkState = AccountLinkState.localOnly.rawValue
            try profile.update(database)
            _ = try ConversionCheckpointRecord
                .filter(Column("profileID") == profileID.uuidString)
                .deleteAll(database)
        }
    }

    func deleteAllLocalData() throws {
        try write { database in
            try database.execute(sql: "DELETE FROM local_profiles")
            try database.execute(sql: "DELETE FROM audio_cache")
            try database.execute(sql: "DELETE FROM audio_catalog")
        }
    }

    private func write(_ body: (Database) throws -> Void) throws {
        do {
            try writeFault.beforeWrite()
            try pool.write(body)
        } catch let error as Phase1BValidationError {
            throw error
        } catch let error as AuthenticationError {
            throw error
        } catch let error as DatabaseError where error.extendedResultCode == .SQLITE_CONSTRAINT_CHECK
            || error.extendedResultCode == .SQLITE_CONSTRAINT_UNIQUE
            || error.extendedResultCode == .SQLITE_CONSTRAINT_FOREIGNKEY
        {
            throw LocalDatabaseError.constraintViolation
        } catch {
            throw LocalDatabaseError.writeFailed
        }
    }

    private func validate(_ checkIn: SubmittedCheckIn) throws {
        guard checkIn.revision > 0 else {
            throw Phase1BValidationError.invalidRevision
        }
        guard checkIn.reportedForLocalDate.range(
            of: #"^\d{4}-\d{2}-\d{2}$"#,
            options: .regularExpression
        ) != nil else {
            throw Phase1BValidationError.invalidLocalDate
        }
        if checkIn.occurrence == .no, checkIn.perceivedIntensity != nil {
            throw Phase1BValidationError.intensityWithoutOccurrence
        }
        try validateNote(checkIn.note)
    }

    private func validateNote(_ note: String?) throws {
        guard let note else {
            return
        }
        let normalized = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized.count <= 500 else {
            throw Phase1BValidationError.invalidNote
        }
    }

    private func normalizedNote(_ note: String?) -> String? {
        note?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

nonisolated protocol LocalWriteFaultInjecting: Sendable {
    func beforeWrite() throws
}

nonisolated struct NoLocalWriteFault: LocalWriteFaultInjecting {
    func beforeWrite() throws {}
}
