import AppIntents
import Foundation

nonisolated enum SleepSessionAudioAction: String, AppEnum, Codable, Sendable {
    case startOrResume
    case pause
    case resume

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Grounding audio action")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .startOrResume: "Start grounding audio",
        .pause: "Pause grounding audio",
        .resume: "Resume grounding audio",
    ]
}

@MainActor
final class SleepSessionAudioIntentBridge {
    static let shared = SleepSessionAudioIntentBridge()

    private var handler: (@MainActor (SleepSessionAudioAction) -> Bool)?

    private init() {}

    func install(handler: @escaping @MainActor (SleepSessionAudioAction) -> Bool) {
        self.handler = handler
    }

    func perform(_ action: SleepSessionAudioAction) -> Bool {
        handler?(action) ?? false
    }
}

nonisolated enum ManualEpisodeActivationError: Error, Equatable {
    case appGroupUnavailable
    case persistenceFailed
}

nonisolated struct ManualEpisodeActivationStore: Sendable {
    struct Activation: Codable, Equatable, Sendable {
        let id: UUID
        let requestedAt: Date
        let action: SleepSessionAudioAction?
    }

    static let appGroupInfoKey = "SPCAppGroupIdentifier"
    static let pendingKey = "spc.manualEpisodeActivation.pending.v2"
    private static let queueLimit = 8

    private let suiteName: String?

    init(suiteName: String?) {
        self.suiteName = suiteName?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func live(bundle: Bundle = .main) -> Self {
        Self(suiteName: bundle.object(forInfoDictionaryKey: appGroupInfoKey) as? String)
    }

    @discardableResult
    func enqueue(
        id: UUID = UUID(),
        requestedAt: Date = Date(),
        action: SleepSessionAudioAction = .startOrResume
    ) throws -> Activation {
        let defaults = try appGroupDefaults()
        var values = pending(in: defaults)
        let activation = Activation(id: id, requestedAt: requestedAt, action: action)
        if !values.contains(where: { $0.id == id }) {
            values.append(activation)
            values = Array(values.suffix(Self.queueLimit))
            try persist(values, in: defaults)
        }
        return activation
    }

    func firstPending() throws -> Activation? {
        try pending(in: appGroupDefaults()).first
    }

    @discardableResult
    func consume(id: UUID) throws -> Bool {
        let defaults = try appGroupDefaults()
        var values = pending(in: defaults)
        guard let index = values.firstIndex(where: { $0.id == id }) else {
            return false
        }
        values.remove(at: index)
        try persist(values, in: defaults)
        return true
    }

    private func appGroupDefaults() throws -> UserDefaults {
        guard let suiteName, !suiteName.isEmpty,
              let defaults = UserDefaults(suiteName: suiteName)
        else {
            throw ManualEpisodeActivationError.appGroupUnavailable
        }
        return defaults
    }

    private func pending(in defaults: UserDefaults) -> [Activation] {
        guard let data = defaults.data(forKey: Self.pendingKey),
              let values = try? JSONDecoder().decode([Activation].self, from: data)
        else {
            return []
        }
        return values
    }

    private func persist(_ values: [Activation], in defaults: UserDefaults) throws {
        do {
            if values.isEmpty {
                defaults.removeObject(forKey: Self.pendingKey)
            } else {
                try defaults.set(JSONEncoder().encode(values), forKey: Self.pendingKey)
            }
        } catch {
            throw ManualEpisodeActivationError.persistenceFailed
        }
    }
}

struct ManualEpisodeIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "I just had an episode"
    static let description = IntentDescription(
        "Opens Sleep Paralysis Companion manual visual grounding and the selected device-local recovery audio."
    )
    static let supportedModes: IntentModes = [.foreground]
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "Action")
    var action: SleepSessionAudioAction

    init() {
        action = .startOrResume
    }

    init(action: SleepSessionAudioAction) {
        self.action = action
    }

    func perform() async throws -> some IntentResult {
        try ManualEpisodeActivationStore.live().enqueue(action: action)
        return .result()
    }
}

struct SleepSessionPlaybackIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Control grounding audio"
    static let description = IntentDescription("Starts, pauses, or resumes grounding audio.")
    static let supportedModes: IntentModes = [.background]
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "Action")
    var action: SleepSessionAudioAction

    init() {
        action = .startOrResume
    }

    init(action: SleepSessionAudioAction) {
        self.action = action
    }

    func perform() async throws -> some IntentResult {
        let handled = await SleepSessionAudioIntentBridge.shared.perform(action)
        if !handled {
            try ManualEpisodeActivationStore.live().enqueue(action: action)
        }
        return .result()
    }
}
