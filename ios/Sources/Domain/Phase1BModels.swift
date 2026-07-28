import Foundation

nonisolated enum ProfileOwnership: String, Codable, Sendable {
    case guestLocal
    case accountLinked
    case formerAccountProtected
}

nonisolated enum AccountLinkState: String, Codable, Sendable {
    case localOnly
    case authenticating
    case awaitingMergeChoice
    case converting
    case linked
    case conflict
    case authRequired
    case failedRecoverable
}

nonisolated struct LocalProfile: Equatable, Codable, Sendable {
    let id: UUID
    let createdAt: Date
    var onboardingCompletedAt: Date?
    var productNoticeVersion: String
    var productNoticeSeenAt: Date
    var ownership: ProfileOwnership
    var accountUserID: UUID?
    var accountLinkState: AccountLinkState
}

nonisolated enum GroundingModality: String, Codable, CaseIterable, Sendable {
    case audio
    case visual
    case silent
}

nonisolated enum HistoryPeriod: String, Codable, CaseIterable, Sendable {
    case sevenDays
    case thirtyDays
    case all
}

nonisolated struct AppSettings: Equatable, Codable, Sendable {
    let profileID: UUID
    var preferredGroundingAssetID: String?
    var preferredModality: GroundingModality
    var hapticsEnabled: Bool
    var lastSelectedHistoryPeriod: HistoryPeriod
    var diagnosticsEnabled: Bool
    var updatedAt: Date
    var revision: Int64
}

nonisolated enum AlarmSystemState: String, Codable, CaseIterable, Sendable {
    case notScheduled
    case scheduled
    case denied
    case unsupported
    case failed
    case needsAttention
}

nonisolated enum AlarmScheduleResult: String, Codable, CaseIterable, Sendable {
    case none
    case success
    case denied
    case unsupported
    case failed
}

nonisolated struct AlarmPreference: Equatable, Codable, Sendable {
    let id: UUID
    let profileID: UUID
    var systemAlarmID: String?
    var localHour: Int
    var localMinute: Int
    var weekdaysMask: Int
    var snoozeMinutes: Int?
    var enabledIntent: Bool
    var systemState: AlarmSystemState
    var lastScheduleResult: AlarmScheduleResult
    let createdAt: Date
    var updatedAt: Date
    var revision: Int64
}

nonisolated struct AudioCatalogItem: Equatable, Codable, Sendable {
    let id: String
    var version: Int
    var localeIdentifier: String
    var integritySHA256: String
    var byteCount: Int64
    var durationMilliseconds: Int64
    var provenanceReference: String
    var rightsReference: String
    var approvalReference: String
}

nonisolated enum AudioCacheState: String, Codable, CaseIterable, Sendable {
    case notCached
    case downloading
    case verified
    case invalid
    case revoked
}

nonisolated struct AudioCacheMetadata: Equatable, Codable, Sendable {
    let assetID: String
    var catalogVersion: Int
    var state: AudioCacheState
    var relativeFileName: String?
    var verifiedAt: Date?
    var byteCount: Int64
}

nonisolated enum EpisodeOccurrence: String, Codable, CaseIterable, Sendable {
    case yes
    case no
}

nonisolated enum PerceivedIntensity: String, Codable, CaseIterable, Sendable {
    case mild
    case moderate
    case severe
    case extreme
}

nonisolated enum PresentState: String, Codable, CaseIterable, Sendable {
    case fineNow = "fine_now"
    case stillShaken = "still_shaken"
    case exhausted
}

nonisolated struct SubmittedCheckIn: Equatable, Codable, Sendable {
    let id: UUID
    let profileID: UUID
    var reportedForLocalDate: String
    var reportedTimezoneID: String
    var occurrence: EpisodeOccurrence
    var perceivedIntensity: PerceivedIntensity?
    var presentState: PresentState?
    var note: String?
    let createdAt: Date
    var updatedAt: Date
    var revision: Int64
    var deletedAt: Date?
}

nonisolated struct CheckInDraft: Equatable, Codable, Sendable {
    let id: UUID
    let profileID: UUID
    var reportedForLocalDate: String?
    var reportedTimezoneID: String?
    var occurrence: EpisodeOccurrence?
    var perceivedIntensity: PerceivedIntensity?
    var presentState: PresentState?
    var note: String?
    var draftUpdatedAt: Date
}

nonisolated enum AuthenticationProvider: String, Codable, CaseIterable, Sendable {
    case apple
    case google
}

nonisolated struct AccountBinding: Equatable, Codable, Sendable {
    let profileID: UUID
    let userID: UUID
    let provider: AuthenticationProvider
    var maskedIdentifier: String?
    var linkedAt: Date
    var sessionExpiresAt: Date
    var requiresReauthentication: Bool
}

nonisolated enum SyncEntityType: String, Codable, CaseIterable, Sendable {
    case profile
    case settings
    case alarm
    case checkIn
    case persona
    case tombstone

    var remoteName: String {
        switch self {
        case .checkIn:
            "checkin"
        default:
            rawValue
        }
    }
}

nonisolated enum SyncOperationKind: String, Codable, CaseIterable, Sendable {
    case upsert
    case delete
    case convert
}

nonisolated enum SynchronizationState: String, Codable, CaseIterable, Sendable {
    case pending
    case syncing
    case synced
    case conflicted
    case failedRecoverable
    case authRequired
    case deleted
}

nonisolated enum SyncErrorCategory: String, Codable, CaseIterable, Sendable {
    case network
    case backendUnavailable
    case authentication
    case authorization
    case validation
    case conflict
    case cancelled
}

nonisolated struct SynchronizationOperation: Equatable, Codable, Sendable {
    let id: UUID
    let profileID: UUID
    let entityType: SyncEntityType
    let entityID: UUID
    let operation: SyncOperationKind
    let idempotencyKey: UUID
    let baseRevision: Int64
    let localRevision: Int64
    var state: SynchronizationState
    var attemptCount: Int
    var nextAttemptAt: Date?
    var lastErrorCategory: SyncErrorCategory?
    let createdAt: Date
    var updatedAt: Date
}

nonisolated struct EntityRevision: Equatable, Codable, Sendable {
    let profileID: UUID
    let entityType: SyncEntityType
    let entityID: UUID
    var localRevision: Int64
    var acknowledgedRemoteRevision: Int64?
    var lastRemoteMutationID: UUID?
}

nonisolated struct DeletionTombstone: Equatable, Codable, Sendable {
    let id: UUID
    let profileID: UUID
    let entityType: SyncEntityType
    let entityID: UUID
    let deletedRevision: Int64
    let deletedAt: Date
    var acknowledgedAt: Date?
    var purgeAfter: Date
}

nonisolated struct PolicyNoticeState: Equatable, Codable, Sendable {
    let profileID: UUID
    let noticeKind: String
    var version: String
    var seenAt: Date
}

nonisolated enum ExportScope: String, Codable, CaseIterable, Sendable {
    case localOnly
    case lastSyncedLocalSnapshot
    case serverReconciled
}

nonisolated struct ExportMetadata: Equatable, Codable, Sendable {
    let id: UUID
    let profileID: UUID
    let generatedAt: Date
    let expiresAt: Date
    let scope: ExportScope
    let manifestVersion: Int
}

nonisolated enum Phase1BValidationError: Error, Equatable, Sendable {
    case invalidNote
    case invalidLocalDate
    case invalidAlarmTime
    case intensityWithoutOccurrence
    case invalidRevision
    case wrongAccount
    case unsupportedProvider
}
