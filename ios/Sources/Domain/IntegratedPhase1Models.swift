import Foundation

nonisolated enum FeatureIntroductionPage: Int, CaseIterable, Identifiable, Sendable {
    case gentleWake
    case postEpisodeSupport
    case familiarVoice

    var id: Int {
        rawValue
    }
}

nonisolated enum AuthenticationPresentationState: Equatable, Sendable {
    case ready
    case processing(AuthenticationProvider)
    case cancelled
    case failed
    case configurationRequired
    case sessionExpired
}

nonisolated struct SleepSchedule: Codable, Equatable, Sendable {
    var sleepHour: Int
    var sleepMinute: Int
    var wakeHour: Int
    var wakeMinute: Int
    var weekdaysMask: Int
    var reminderLeadMinutes: Int
    var isEnabled: Bool

    static let defaultValue = SleepSchedule(
        sleepHour: 22,
        sleepMinute: 30,
        wakeHour: 6,
        wakeMinute: 30,
        weekdaysMask: 0b0111_1111,
        reminderLeadMinutes: 15,
        isEnabled: true
    )

    var isValid: Bool {
        (0 ... 23).contains(sleepHour)
            && (0 ... 59).contains(sleepMinute)
            && (0 ... 23).contains(wakeHour)
            && (0 ... 59).contains(wakeMinute)
            && (0 ... 127).contains(weekdaysMask)
            && [0, 5, 10, 15, 30, 60].contains(reminderLeadMinutes)
    }
}

nonisolated enum ReminderAuthorizationState: String, Codable, Sendable {
    case notDetermined
    case authorized
    case denied
    case provisional
    case unavailable
}

nonisolated enum RecoveryAudioChoice: Equatable, Sendable {
    case personal(PersonalAudioClipMetadata)
    case provided(ProvidedRecoveryAudio)
    case unavailable
}

nonisolated struct ProvidedRecoveryAudio: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let detail: String
    let bundledResourceName: String?

    static let approvedCatalog = [
        ProvidedRecoveryAudio(
            id: "grounding-short",
            title: "Grounding audio",
            detail: "A short Sleep Paralysis Companion-provided recovery track.",
            bundledResourceName: nil
        ),
        ProvidedRecoveryAudio(
            id: "wind-down",
            title: "Wind-down audio",
            detail: "A longer Sleep Paralysis Companion-provided sleep preparation track.",
            bundledResourceName: nil
        ),
    ]

    var isBundled: Bool {
        bundledResourceName != nil
    }
}

nonisolated enum GroundingPlaybackState: Equatable, Sendable {
    case idle
    case playing(String)
    case paused(String)
    case visualFallback
    case failed
}

nonisolated struct MorningCheckInForm: Equatable, Sendable {
    var occurrence: EpisodeOccurrence?
    var presentState: PresentState?
    var perceivedIntensity: PerceivedIntensity?
    var note = ""

    var canSubmit: Bool {
        guard let occurrence else { return false }
        if occurrence == .no {
            return true
        }
        return presentState != nil
    }
}

nonisolated enum Phase1ActionError: Error, Equatable, Sendable {
    case authenticationRequired
    case configurationRequired
    case invalidQuestionnaire
    case invalidSchedule
    case permissionDenied
    case audioUnavailable
    case persistenceFailed
    case accountMismatch
    case unsupported
}
