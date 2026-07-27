import OSLog

nonisolated enum AppLogCategory: String, Sendable {
    case lifecycle
    case configuration
    case navigation
}

nonisolated enum AppLogEvent: String, Sendable {
    case appActivated = "app_activated"
    case appDeactivated = "app_deactivated"
    case configurationUnavailable = "configuration_unavailable"
    case routeChanged = "route_changed"
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
