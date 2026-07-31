import AppIntents
import Foundation

nonisolated enum ManualEpisodeActivation {
    static let userDefaultsKey = "spc.manualEpisodeActivation.pending"
}

struct ManualEpisodeIntent: AppIntent {
    static let title: LocalizedStringResource = "I just had an episode"
    static let description = IntentDescription(
        "Opens Paralux manual visual grounding and the selected device-local recovery audio."
    )
    static let openAppWhenRun = true
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: ManualEpisodeActivation.userDefaultsKey)
        return .result()
    }
}
