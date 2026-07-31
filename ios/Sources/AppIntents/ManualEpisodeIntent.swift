import AppIntents
import Foundation

nonisolated enum ManualEpisodeActivationError: Error, Equatable {
    case appGroupUnavailable
    case persistenceFailed
}

nonisolated struct ManualEpisodeActivationStore: Sendable {
    struct Activation: Codable, Equatable, Sendable {
        let id: UUID
        let requestedAt: Date
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
        requestedAt: Date = Date()
    ) throws -> Activation {
        let defaults = try appGroupDefaults()
        var values = pending(in: defaults)
        let activation = Activation(id: id, requestedAt: requestedAt)
        if !values.contains(where: { $0.id == id }) {
            values.append(activation)
            values = Array(values.suffix(Self.queueLimit))
            try persist(values, in: defaults)
        }
        return activation
    }

    func firstPending() throws -> Activation? {
        pending(in: try appGroupDefaults()).first
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
                defaults.set(try JSONEncoder().encode(values), forKey: Self.pendingKey)
            }
        } catch {
            throw ManualEpisodeActivationError.persistenceFailed
        }
    }
}

struct ManualEpisodeIntent: AppIntent {
    static let title: LocalizedStringResource = "I just had an episode"
    static let description = IntentDescription(
        "Opens Paralux manual visual grounding and the selected device-local recovery audio."
    )
    static let openAppWhenRun = true
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    func perform() async throws -> some IntentResult {
        try ManualEpisodeActivationStore.live().enqueue()
        return .result()
    }
}
