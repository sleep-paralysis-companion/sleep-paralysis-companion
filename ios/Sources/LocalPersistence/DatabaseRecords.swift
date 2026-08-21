import Foundation
import GRDB

nonisolated struct LocalProfileRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "local_profiles"

    var id: String
    var createdAt: Double
    var onboardingCompletedAt: Double?
    var productNoticeVersion: String
    var productNoticeSeenAt: Double
    var ownership: String
    var accountUserID: String?
    var accountLinkState: String
    var displayName: String?
    var revision: Int64
}

nonisolated struct AppSettingsRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "app_settings"

    var profileID: String
    var preferredGroundingAssetID: String?
    var preferredModality: String
    var hapticsEnabled: Bool
    var lastSelectedHistoryPeriod: String
    var diagnosticsEnabled: Bool
    var defaultSleepSupport: String
    var defaultPostEpisodeSupport: String
    var updatedAt: Double
    var revision: Int64
}

nonisolated struct PartnerContactRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "partner_contacts"

    var profileID: String
    var name: String?
    var phoneNumber: String
    var updatedAt: Double
}

nonisolated struct AlarmPreferenceRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "alarm_preferences"

    var id: String
    var profileID: String
    var systemAlarmID: String?
    var alarmSoundFileName: String?
    var localHour: Int
    var localMinute: Int
    var weekdaysMask: Int
    var snoozeMinutes: Int?
    var enabledIntent: Bool
    var systemState: String
    var lastScheduleResult: String
    var createdAt: Double
    var updatedAt: Double
    var revision: Int64
    var scheduleName: String
    var scheduleKind: String
    var sleepHour: Int?
    var sleepMinute: Int?
    var oneTimeLocalDate: String?
    var bedtimeReminderLeadMinutes: Int?
    var prewakeLeadMinutes: Int?
    var wakeAudioKind: String
    var wakeAudioReference: String
    var displayOrder: Int
}

nonisolated struct AudioCatalogRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "audio_catalog"

    var id: String
    var version: Int
    var localeIdentifier: String
    var integritySHA256: String
    var byteCount: Int64
    var durationMilliseconds: Int64
    var provenanceReference: String
    var rightsReference: String
    var approvalReference: String
}

nonisolated struct AudioCacheRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "audio_cache_v2"

    var assetID: String
    var catalogVersion: Int
    var state: String
    var relativeFileName: String?
    var verifiedAt: Double?
    var byteCount: Int64
    var progress: Double
    var failureReason: String?
    var lastAccessedAt: Double?
}

nonisolated struct SubmittedCheckInRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "submitted_checkins"

    var id: String
    var profileID: String
    var reportedForLocalDate: String
    var reportedTimezoneID: String
    var occurrence: String
    var perceivedIntensity: String?
    var presentState: String?
    var spcOutcome: String?
    var postEpisodeSupport: String?
    var sleepHelpOutcome: String?
    var note: String?
    var createdAt: Double
    var updatedAt: Double
    var revision: Int64
    var deletedAt: Double?
}

nonisolated struct CheckInDraftRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "checkin_drafts"

    var id: String
    var profileID: String
    var reportedForLocalDate: String?
    var reportedTimezoneID: String?
    var occurrence: String?
    var perceivedIntensity: String?
    var presentState: String?
    var note: String?
    var draftUpdatedAt: Double
}

nonisolated struct AccountBindingRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "account_bindings"

    var profileID: String
    var userID: String
    var provider: String
    var maskedIdentifier: String?
    var linkedAt: Double
    var sessionExpiresAt: Double
    var requiresReauthentication: Bool
}

nonisolated struct SynchronizationOperationRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "sync_operations"

    var id: String
    var profileID: String
    var entityType: String
    var entityID: String
    var operation: String
    var idempotencyKey: String
    var baseRevision: Int64
    var localRevision: Int64
    var state: String
    var attemptCount: Int
    var nextAttemptAt: Double?
    var lastErrorCategory: String?
    var createdAt: Double
    var updatedAt: Double
}

nonisolated struct EntityRevisionRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "entity_revisions"

    var profileID: String
    var entityType: String
    var entityID: String
    var localRevision: Int64
    var acknowledgedRemoteRevision: Int64?
    var lastRemoteMutationID: String?
}

nonisolated struct DeletionTombstoneRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "deletion_tombstones"

    var id: String
    var profileID: String
    var entityType: String
    var entityID: String
    var deletedRevision: Int64
    var deletedAt: Double
    var acknowledgedAt: Double?
    var purgeAfter: Double
}

nonisolated struct PolicyNoticeRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "policy_notices"

    var profileID: String
    var noticeKind: String
    var version: String
    var seenAt: Double
}

nonisolated struct ExportMetadataRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "export_metadata"

    var id: String
    var profileID: String
    var generatedAt: Double
    var expiresAt: Double
    var scope: String
    var manifestVersion: Int
}

nonisolated struct ConversionCheckpointRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "conversion_checkpoints"

    var conversionID: String
    var profileID: String
    var expectedUserID: String
    var state: String
    var mergeChoice: String?
    var startedAt: Double
    var updatedAt: Double
}

nonisolated struct QuestionnaireDraftRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "questionnaire_drafts"

    var id: String
    var profileID: String
    var accountUserID: String
    var episodeFrequency: String?
    var postEpisodeFeeling: String?
    var calmingPersonContext: String?
    var createdAt: Double
    var updatedAt: Double
}

nonisolated struct PersonaAnswerAggregateRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "persona_answer_aggregates"

    var id: String
    var profileID: String
    var accountUserID: String
    var episodeFrequency: String
    var postEpisodeFeeling: String
    var calmingPersonContext: String
    var derivedPersona: String
    var routingRuleVersion: String
    var calculatedAt: Double
    var createdAt: Double
    var updatedAt: Double
    var revision: Int64
}

nonisolated struct PersonalAudioClipMetadataRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "personal_audio_clip_metadata"

    var id: String
    var profileID: String
    var source: String
    var storageFormat: String
    var byteCount: Int64
    var durationMilliseconds: Int64?
    var createdOrImportedAt: Double
    var availability: String
    var protectionVersion: Int
}

nonisolated struct LocalRecoveryAudioDefaultRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "local_recovery_audio_defaults"

    var profileID: String
    var personalClipID: String?
    var catalogItemID: String?
    var updatedAt: Double
}
