import Foundation

nonisolated enum EpisodeFrequency: String, Codable, CaseIterable, Sendable {
    case rarely
    case monthly
    case weekly
    case almostNightly = "almost_nightly"
}

nonisolated enum PostEpisodeFeeling: String, Codable, CaseIterable, Sendable {
    case shakeItOff = "shake_it_off"
    case awakeScared = "awake_scared"
    case tooFrightenedToCloseEyes = "too_frightened_to_close_eyes"
}

nonisolated enum CalmingPersonContext: String, Codable, CaseIterable, Sendable {
    case besideMe = "beside_me"
    case notAlwaysPresent = "not_always_present"
    case alone
}

nonisolated enum DerivedPersona: String, Codable, CaseIterable, Sendable {
    case frequentIntensePersonNotAlwaysPresent = "frequent_intense_person_not_always_present"
    case frequentIntensePersonBesideUser = "frequent_intense_person_beside_user"
    case frequentIntenseNoCalmingPerson = "frequent_intense_no_calming_person"
    case generalDefault = "general_default"
}

nonisolated enum PersonaRouting {
    static let initialRuleVersion = "2026-07-29-v1"

    static func derive(
        episodeFrequency: EpisodeFrequency,
        postEpisodeFeeling: PostEpisodeFeeling,
        calmingPersonContext: CalmingPersonContext
    ) -> DerivedPersona {
        let isFrequentAndIntense =
            [.weekly, .almostNightly].contains(episodeFrequency)
                && [.awakeScared, .tooFrightenedToCloseEyes].contains(postEpisodeFeeling)
        guard isFrequentAndIntense else {
            return .generalDefault
        }
        switch calmingPersonContext {
        case .besideMe:
            return .frequentIntensePersonBesideUser
        case .notAlwaysPresent:
            return .frequentIntensePersonNotAlwaysPresent
        case .alone:
            return .frequentIntenseNoCalmingPerson
        }
    }
}

nonisolated enum QuestionnaireQuestion: String, Codable, CaseIterable, Sendable {
    case episodeFrequency
    case postEpisodeFeeling
    case calmingPersonContext
}

nonisolated struct QuestionnaireDraft: Equatable, Codable, Sendable {
    let id: UUID
    let profileID: UUID
    let accountUserID: UUID
    var episodeFrequency: EpisodeFrequency?
    var postEpisodeFeeling: PostEpisodeFeeling?
    var calmingPersonContext: CalmingPersonContext?
    let createdAt: Date
    var updatedAt: Date

    var firstUnansweredQuestion: QuestionnaireQuestion? {
        if episodeFrequency == nil {
            return .episodeFrequency
        }
        if postEpisodeFeeling == nil {
            return .postEpisodeFeeling
        }
        if calmingPersonContext == nil {
            return .calmingPersonContext
        }
        return nil
    }
}

nonisolated struct PersonaAnswerAggregate: Equatable, Codable, Sendable {
    let id: UUID
    let profileID: UUID
    let accountUserID: UUID
    let episodeFrequency: EpisodeFrequency
    let postEpisodeFeeling: PostEpisodeFeeling
    let calmingPersonContext: CalmingPersonContext
    let derivedPersona: DerivedPersona
    let routingRuleVersion: String
    let calculatedAt: Date
    let createdAt: Date
    var updatedAt: Date
    var revision: Int64
}

nonisolated enum PersonalAudioSource: String, Codable, CaseIterable, Sendable {
    case recorded
    case imported
}

nonisolated enum PersonalAudioStorageFormat: String, Codable, CaseIterable, Sendable {
    case m4a
    case mp3
    case wav
    case aiff
    case caf
}

nonisolated enum PersonalAudioAvailability: String, Codable, CaseIterable, Sendable {
    case ready
    case unavailable
    case corrupt
}

nonisolated struct PersonalAudioClipMetadata: Equatable, Codable, Sendable {
    let id: UUID
    let profileID: UUID
    let source: PersonalAudioSource
    let storageFormat: PersonalAudioStorageFormat
    let byteCount: Int64
    let durationMilliseconds: Int64?
    let createdOrImportedAt: Date
    var availability: PersonalAudioAvailability
    let protectionVersion: Int
}

nonisolated enum LocalRecoveryAudioDefault: Equatable, Codable, Sendable {
    case personalClip(UUID)
    case catalogItem(String)
}

nonisolated enum PersonalAudioPolicy {
    static let maximumClipCount = 10
    static let maximumDurationMilliseconds: Int64 = 180_000
    static let maximumByteCount: Int64 = 25 * 1024 * 1024

    static func validates(
        source: PersonalAudioSource,
        storageFormat: PersonalAudioStorageFormat,
        byteCount: Int64,
        durationMilliseconds: Int64?
    ) -> Bool {
        guard byteCount >= 0, byteCount <= maximumByteCount,
              durationMilliseconds == nil || (durationMilliseconds ?? -1) <= maximumDurationMilliseconds,
              durationMilliseconds == nil || (durationMilliseconds ?? -1) >= 0
        else {
            return false
        }
        return source != .recorded || storageFormat == .m4a
    }
}

nonisolated enum PersonaAudioValidationError: Error, Equatable, Sendable {
    case wrongAccount
    case incompleteQuestionnaire
    case invalidRoutingRule
    case invalidPersona
    case invalidAudioMetadata
    case maximumPersonalAudioClipsReached
    case invalidDefaultSelection
    case draftIdentityMismatch
}

/// Boundary for the later protected-file implementation. Implementations must
/// make file creation/removal and metadata/default mutations one recoverable
/// lifecycle; this delta deliberately stores neither a file location nor bytes.
nonisolated protocol PersonalAudioFileLifecycleManaging: Sendable {
    func prepareProtectedClipLifecycle(clipID: UUID, profileID: UUID) async throws
    func commitProtectedClipLifecycle(clipID: UUID, profileID: UUID) async throws
    func removeProtectedClipLifecycle(clipID: UUID, profileID: UUID) async throws
    func removeAllProtectedClipLifecycles(profileID: UUID) async throws
}
