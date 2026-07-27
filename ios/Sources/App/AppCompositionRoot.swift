import Foundation

@MainActor
enum AppCompositionRoot {
    static func makeModel() -> AppModel {
        let environment = AppEnvironment.compiled
        let logger = ApplePrivacySafeLogger(subsystem: "com.satyamshree.spc")
        let values = BundlePublicConfigurationLoader().load(from: .main)

        if case .unavailable = AppConfiguration.resolve(
            environment: environment,
            values: values
        ) {
            logger.record(.configurationUnavailable, category: .configuration)
        }

        return AppModel(
            environment: environment,
            accessPolicy: AccessPolicy(),
            logger: logger
        )
    }
}
