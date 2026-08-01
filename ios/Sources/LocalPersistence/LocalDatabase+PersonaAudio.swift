import Foundation
import GRDB

extension LocalDatabase {
    func exportSnapshot(
        appVersion: String,
        policyVersions: [String: String],
        profileID: UUID,
        authenticatedUserID: UUID,
        scope: ExportScope
    ) throws -> LocalExportSnapshot {
        try assertAuthenticatedOwner(profileID: profileID, userID: authenticatedUserID)
        guard let profile = try profile(id: profileID), let settings = try settings(profileID: profileID) else {
            throw LocalDatabaseError.constraintViolation
        }
        return try LocalExportSnapshot(
            appVersion: appVersion,
            profileCreatedAt: profile.createdAt,
            policyVersions: policyVersions,
            settings: settings,
            alarm: pool.read { database in
                try AlarmPreferenceRecord.fetchOne(
                    database,
                    sql: "SELECT * FROM alarm_preferences WHERE profileID = ? ORDER BY updatedAt DESC LIMIT 1",
                    arguments: [profileID.uuidString]
                )?.domainValue()
            },
            checkIns: checkIns(profileID: profileID),
            persona: personaAnswerAggregate(profileID: profileID, authenticatedUserID: authenticatedUserID)
                .map(PersonaExport.init),
            scope: scope
        )
    }

    func questionnaireDraft(
        profileID: UUID,
        authenticatedUserID: UUID
    ) throws -> QuestionnaireDraft? {
        try assertAuthenticatedOwner(profileID: profileID, userID: authenticatedUserID)
        return try pool.read { database in
            try QuestionnaireDraftRecord.fetchOne(
                database,
                sql: "SELECT * FROM questionnaire_drafts WHERE profileID = ? AND accountUserID = ?",
                arguments: [profileID.uuidString, authenticatedUserID.uuidString]
            )?.domainValue()
        }
    }

    func saveQuestionnaireDraft(_ draft: QuestionnaireDraft) throws {
        try assertAuthenticatedOwner(profileID: draft.profileID, userID: draft.accountUserID)
        try write { database in
            if let existing = try QuestionnaireDraftRecord.fetchOne(
                database,
                sql: "SELECT * FROM questionnaire_drafts WHERE profileID = ?",
                arguments: [draft.profileID.uuidString]
            ) {
                guard existing.accountUserID == draft.accountUserID.uuidString else {
                    throw PersonaAudioValidationError.wrongAccount
                }
                // A profile has one current draft. A caller can safely replace
                // it (for example after a restored flow allocates a fresh opaque
                // id) without a uniqueness error; all answers remain explicit.
                if existing.id != draft.id.uuidString {
                    _ = try QuestionnaireDraftRecord.deleteOne(database, key: existing.id)
                    try QuestionnaireDraftRecord(draft).insert(database)
                } else {
                    try QuestionnaireDraftRecord(draft).update(database)
                }
            } else {
                try QuestionnaireDraftRecord(draft).insert(database)
            }
        }
    }

    func completeQuestionnaireDraft(
        profileID: UUID,
        authenticatedUserID: UUID,
        calculatedAt: Date,
        operationID: UUID = UUID(),
        idempotencyKey: UUID = UUID()
    ) throws -> PersonaAnswerAggregate {
        try assertAuthenticatedOwner(profileID: profileID, userID: authenticatedUserID)
        var completed: PersonaAnswerAggregate?
        try write { database in
            guard let draft = try QuestionnaireDraftRecord.fetchOne(
                database,
                sql: "SELECT * FROM questionnaire_drafts WHERE profileID = ? AND accountUserID = ?",
                arguments: [profileID.uuidString, authenticatedUserID.uuidString]
            ) else {
                if let existing = try PersonaAnswerAggregateRecord.fetchOne(
                    database,
                    sql: "SELECT * FROM persona_answer_aggregates WHERE profileID = ? AND accountUserID = ?",
                    arguments: [profileID.uuidString, authenticatedUserID.uuidString]
                ) {
                    completed = try existing.domainValue()
                    return
                }
                throw PersonaAudioValidationError.incompleteQuestionnaire
            }
            let value = try draft.domainValue()
            guard let episodeFrequency = value.episodeFrequency,
                  let postEpisodeFeeling = value.postEpisodeFeeling,
                  let calmingPersonContext = value.calmingPersonContext
            else {
                throw PersonaAudioValidationError.incompleteQuestionnaire
            }
            let existing = try PersonaAnswerAggregateRecord.fetchOne(
                database,
                sql: "SELECT * FROM persona_answer_aggregates WHERE profileID = ? AND accountUserID = ?",
                arguments: [profileID.uuidString, authenticatedUserID.uuidString]
            )
            if let existing, existing.episodeFrequency == episodeFrequency.rawValue,
               existing.postEpisodeFeeling == postEpisodeFeeling.rawValue,
               existing.calmingPersonContext == calmingPersonContext.rawValue
            {
                _ = try QuestionnaireDraftRecord.deleteOne(database, key: draft.id)
                completed = try existing.domainValue()
                return
            }
            let aggregate = PersonaAnswerAggregate(
                id: existing.flatMap { UUID(uuidString: $0.id) } ?? profileID,
                profileID: profileID,
                accountUserID: authenticatedUserID,
                episodeFrequency: episodeFrequency,
                postEpisodeFeeling: postEpisodeFeeling,
                calmingPersonContext: calmingPersonContext,
                derivedPersona: PersonaRouting.derive(
                    episodeFrequency: episodeFrequency,
                    postEpisodeFeeling: postEpisodeFeeling,
                    calmingPersonContext: calmingPersonContext
                ),
                routingRuleVersion: PersonaRouting.initialRuleVersion,
                calculatedAt: calculatedAt,
                createdAt: existing.map { Date(timeIntervalSince1970: $0.createdAt) } ?? calculatedAt,
                updatedAt: calculatedAt,
                revision: (existing?.revision ?? 0) + 1
            )
            try PersonaAnswerAggregateRecord(aggregate).save(database)
            _ = try QuestionnaireDraftRecord.deleteOne(database, key: draft.id)
            try supersedePendingPersonaUpserts(database, profileID: profileID)
            try personaUpsertOperation(
                database, profileID: profileID, aggregate: aggregate,
                operationID: operationID, idempotencyKey: idempotencyKey, at: calculatedAt
            )
            completed = aggregate
        }
        guard let completed else { throw LocalDatabaseError.constraintViolation }
        return completed
    }

    func personaAnswerAggregate(
        profileID: UUID,
        authenticatedUserID: UUID
    ) throws -> PersonaAnswerAggregate? {
        try assertAuthenticatedOwner(profileID: profileID, userID: authenticatedUserID)
        return try pool.read { database in
            try PersonaAnswerAggregateRecord.fetchOne(
                database,
                sql: "SELECT * FROM persona_answer_aggregates WHERE profileID = ? AND accountUserID = ?",
                arguments: [profileID.uuidString, authenticatedUserID.uuidString]
            )?.domainValue()
        }
    }

    func replacePersonaAnswerAggregate(_ aggregate: PersonaAnswerAggregate) throws {
        try assertAuthenticatedOwner(profileID: aggregate.profileID, userID: aggregate.accountUserID)
        guard aggregate.id == aggregate.profileID,
              aggregate.routingRuleVersion == PersonaRouting.initialRuleVersion,
              aggregate.revision > 0,
              aggregate.derivedPersona == PersonaRouting.derive(
                  episodeFrequency: aggregate.episodeFrequency,
                  postEpisodeFeeling: aggregate.postEpisodeFeeling,
                  calmingPersonContext: aggregate.calmingPersonContext
              )
        else {
            throw PersonaAudioValidationError.invalidPersona
        }
        try write { database in
            let existing = try PersonaAnswerAggregateRecord.fetchOne(
                database,
                sql: "SELECT * FROM persona_answer_aggregates WHERE profileID = ? AND accountUserID = ?",
                arguments: [aggregate.profileID.uuidString, aggregate.accountUserID.uuidString]
            )
            if let existing,
               existing.episodeFrequency == aggregate.episodeFrequency.rawValue,
               existing.postEpisodeFeeling == aggregate.postEpisodeFeeling.rawValue,
               existing.calmingPersonContext == aggregate.calmingPersonContext.rawValue
            {
                return
            }
            let revised = PersonaAnswerAggregate(
                id: aggregate.profileID, profileID: aggregate.profileID, accountUserID: aggregate.accountUserID,
                episodeFrequency: aggregate.episodeFrequency, postEpisodeFeeling: aggregate.postEpisodeFeeling,
                calmingPersonContext: aggregate.calmingPersonContext,
                derivedPersona: PersonaRouting.derive(
                    episodeFrequency: aggregate.episodeFrequency,
                    postEpisodeFeeling: aggregate.postEpisodeFeeling,
                    calmingPersonContext: aggregate.calmingPersonContext
                ),
                routingRuleVersion: PersonaRouting.initialRuleVersion, calculatedAt: aggregate.calculatedAt,
                createdAt: existing.map { Date(timeIntervalSince1970: $0.createdAt) } ?? aggregate.createdAt,
                updatedAt: aggregate.updatedAt, revision: (existing?.revision ?? 0) + 1
            )
            try PersonaAnswerAggregateRecord(revised).save(database)
            try supersedePendingPersonaUpserts(database, profileID: aggregate.profileID)
            try personaUpsertOperation(
                database,
                profileID: aggregate.profileID,
                aggregate: revised,
                operationID: UUID(),
                idempotencyKey: UUID(),
                at: aggregate.updatedAt
            )
        }
    }

    func deletePersonaAnswerAggregate(
        profileID: UUID,
        authenticatedUserID: UUID,
        deletedAt: Date,
        tombstoneID: UUID,
        operationID: UUID,
        idempotencyKey: UUID
    ) throws {
        try assertAuthenticatedOwner(profileID: profileID, userID: authenticatedUserID)
        try write { database in
            guard let aggregate = try PersonaAnswerAggregateRecord.fetchOne(
                database, sql: "SELECT * FROM persona_answer_aggregates WHERE profileID = ? AND accountUserID = ?",
                arguments: [profileID.uuidString, authenticatedUserID.uuidString]
            )
            else {
                return
            }
            _ = try PersonaAnswerAggregateRecord.deleteOne(database, key: profileID.uuidString)
            try supersedePendingPersonaUpserts(database, profileID: profileID)
            let deletedRevision = aggregate.revision + 1
            try DeletionTombstoneRecord(
                id: tombstoneID.uuidString,
                profileID: profileID.uuidString,
                entityType: SyncEntityType.persona.rawValue,
                entityID: aggregate.id,
                deletedRevision: deletedRevision,
                deletedAt: deletedAt.timeIntervalSince1970,
                acknowledgedAt: nil,
                purgeAfter: deletedAt.addingTimeInterval(30 * 86400).timeIntervalSince1970
            ).save(database)
            try SynchronizationOperationRecord(
                id: operationID.uuidString,
                profileID: profileID.uuidString,
                entityType: SyncEntityType.tombstone.rawValue,
                entityID: tombstoneID.uuidString,
                operation: SyncOperationKind.delete.rawValue,
                idempotencyKey: idempotencyKey.uuidString,
                baseRevision: aggregate.revision,
                localRevision: deletedRevision,
                state: SynchronizationState.pending.rawValue,
                attemptCount: 0,
                nextAttemptAt: nil,
                lastErrorCategory: nil,
                createdAt: deletedAt.timeIntervalSince1970,
                updatedAt: deletedAt.timeIntervalSince1970
            ).insert(database)
        }
    }

    func savePersonalAudioClipMetadata(
        _ metadata: PersonalAudioClipMetadata,
        authenticatedUserID: UUID
    ) throws {
        try assertAuthenticatedOwner(profileID: metadata.profileID, userID: authenticatedUserID)
        guard metadata.protectionVersion > 0,
              PersonalAudioPolicy.validates(
                  source: metadata.source,
                  storageFormat: metadata.storageFormat,
                  byteCount: metadata.byteCount,
                  durationMilliseconds: metadata.durationMilliseconds
              )
        else {
            throw PersonaAudioValidationError.invalidAudioMetadata
        }
        try write { database in
            let existing = try PersonalAudioClipMetadataRecord.fetchOne(database, key: metadata.id.uuidString)
            if let existing, existing.profileID != metadata.profileID.uuidString {
                throw PersonaAudioValidationError.wrongAccount
            }
            if existing == nil {
                let count = try Int.fetchOne(
                    database,
                    sql: "SELECT count(*) FROM personal_audio_clip_metadata WHERE profileID = ?",
                    arguments: [metadata.profileID.uuidString]
                ) ?? 0
                guard count < PersonalAudioPolicy.maximumClipCount else {
                    throw PersonaAudioValidationError.maximumPersonalAudioClipsReached
                }
            }
            try PersonalAudioClipMetadataRecord(metadata).save(database)
        }
    }

    func personalAudioClipMetadata(
        profileID: UUID,
        authenticatedUserID: UUID
    ) throws -> [PersonalAudioClipMetadata] {
        try assertAuthenticatedOwner(profileID: profileID, userID: authenticatedUserID)
        return try pool.read { database in
            try PersonalAudioClipMetadataRecord
                .filter(Column("profileID") == profileID.uuidString)
                .order(Column("createdOrImportedAt"))
                .fetchAll(database)
                .map { try $0.domainValue() }
        }
    }

    func setLocalRecoveryAudioDefault(
        _ value: LocalRecoveryAudioDefault,
        profileID: UUID,
        authenticatedUserID: UUID,
        updatedAt: Date
    ) throws {
        try assertAuthenticatedOwner(profileID: profileID, userID: authenticatedUserID)
        try write { database in
            let record: LocalRecoveryAudioDefaultRecord
            switch value {
            case let .personalClip(clipID):
                guard let clip = try PersonalAudioClipMetadataRecord.fetchOne(database, key: clipID.uuidString),
                      clip.profileID == profileID.uuidString,
                      clip.availability == PersonalAudioAvailability.ready.rawValue
                else {
                    throw PersonaAudioValidationError.invalidDefaultSelection
                }
                record = LocalRecoveryAudioDefaultRecord(
                    profileID: profileID.uuidString,
                    personalClipID: clipID.uuidString,
                    catalogItemID: nil,
                    updatedAt: updatedAt.timeIntervalSince1970
                )
            case let .catalogItem(itemID):
                guard try AudioCatalogRecord.fetchOne(database, key: itemID) != nil else {
                    throw PersonaAudioValidationError.invalidDefaultSelection
                }
                record = LocalRecoveryAudioDefaultRecord(
                    profileID: profileID.uuidString,
                    personalClipID: nil,
                    catalogItemID: itemID,
                    updatedAt: updatedAt.timeIntervalSince1970
                )
            }
            try record.save(database)
        }
    }

    func localRecoveryAudioDefault(
        profileID: UUID,
        authenticatedUserID: UUID
    ) throws -> LocalRecoveryAudioDefault? {
        try assertAuthenticatedOwner(profileID: profileID, userID: authenticatedUserID)
        return try pool.read { database in
            guard let record = try LocalRecoveryAudioDefaultRecord.fetchOne(database, key: profileID.uuidString) else {
                return nil
            }
            if let personalClipID = record.personalClipID.flatMap(UUID.init(uuidString:)) {
                return .personalClip(personalClipID)
            }
            if let catalogItemID = record.catalogItemID {
                return .catalogItem(catalogItemID)
            }
            throw LocalDatabaseError.corruptOrUnreadable
        }
    }

    func deletePersonalAudioClipMetadata(
        id: UUID,
        profileID: UUID,
        authenticatedUserID: UUID
    ) throws {
        try assertAuthenticatedOwner(profileID: profileID, userID: authenticatedUserID)
        try write { database in
            guard let record = try PersonalAudioClipMetadataRecord.fetchOne(database, key: id.uuidString),
                  record.profileID == profileID.uuidString
            else {
                return
            }
            _ = try PersonalAudioClipMetadataRecord.deleteOne(database, key: id.uuidString)
        }
    }

    private func supersedePendingPersonaUpserts(_ database: Database, profileID: UUID) throws {
        try database.execute(
            sql: "UPDATE sync_operations SET state = 'deleted' WHERE profileID = ? AND entityType = 'persona' AND operation = 'upsert' AND state IN ('pending', 'failedRecoverable')",
            arguments: [profileID.uuidString]
        )
    }

    private func personaUpsertOperation(
        _ database: Database, profileID: UUID, aggregate: PersonaAnswerAggregate,
        operationID: UUID, idempotencyKey: UUID, at: Date
    ) throws {
        try SynchronizationOperationRecord(
            id: operationID.uuidString, profileID: profileID.uuidString,
            entityType: SyncEntityType.persona.rawValue, entityID: aggregate.id.uuidString,
            operation: SyncOperationKind.upsert.rawValue, idempotencyKey: idempotencyKey.uuidString,
            baseRevision: aggregate.revision - 1, localRevision: aggregate.revision,
            state: SynchronizationState.pending.rawValue, attemptCount: 0, nextAttemptAt: nil,
            lastErrorCategory: nil, createdAt: at.timeIntervalSince1970, updatedAt: at.timeIntervalSince1970
        ).insert(database)
    }

    private func assertAuthenticatedOwner(profileID: UUID, userID: UUID) throws {
        guard let profile = try profile(id: profileID), profile.accountUserID == userID else {
            throw PersonaAudioValidationError.wrongAccount
        }
    }
}
