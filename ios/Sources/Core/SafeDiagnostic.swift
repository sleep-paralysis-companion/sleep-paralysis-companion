import Foundation

nonisolated struct SafeDiagnostic: Equatable, Sendable {
    let code: Code

    nonisolated enum Code: String, Sendable {
        case configurationUnavailable = "configuration_unavailable"
        case productionResourceRejected = "production_resource_rejected"
    }

    var userMessage: String {
        String(localized: "This part of the app is not available in this build.")
    }
}
