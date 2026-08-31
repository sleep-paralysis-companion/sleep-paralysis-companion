import OSLog

nonisolated enum AppLogCategory: String, CaseIterable, Sendable {
    case lifecycle
    case configuration
    case navigation
    case authentication
}

nonisolated enum AppLogEvent: String, CaseIterable, Sendable {
    case appActivated = "app_activated"
    case appDeactivated = "app_deactivated"
    case configurationUnavailable = "configuration_unavailable"
    case routeChanged = "route_changed"
    case signInStarted = "sign_in_started"
    case signInSucceeded = "sign_in_succeeded"
    case signInNetworkUnavailable = "sign_in_network_unavailable"
    case signInProviderUnavailable = "sign_in_provider_unavailable"
    case signInServerRejected = "sign_in_server_rejected"
    case signInFailedUnclassified = "sign_in_failed_unclassified"
    case restorePurgedOnRejection = "restore_purged_on_rejection"
    case signOutCompleted = "sign_out_completed"
}

nonisolated struct SensitiveLogValue<Value: Sendable>: CustomStringConvertible, Sendable {
    private let value: Value

    init(_ value: Value) {
        self.value = value
    }

    var description: String {
        _ = value
        return "<redacted>"
    }
}

nonisolated protocol PrivacySafeLogging: Sendable {
    func record(_ event: AppLogEvent, category: AppLogCategory)
}

nonisolated struct NoOpPrivacySafeLogger: PrivacySafeLogging {
    init() {
    }

    func record(_: AppLogEvent, category _: AppLogCategory) {
    }
}

nonisolated struct ApplePrivacySafeLogger: PrivacySafeLogging {
    private let subsystem: String

    init(subsystem: String) {
        self.subsystem = subsystem
    }

    func record(_ event: AppLogEvent, category: AppLogCategory) {
        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        logger.notice("\(event.rawValue, privacy: .public)")
    }
}
