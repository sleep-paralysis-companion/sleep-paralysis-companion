import Foundation

@MainActor
enum AppCompositionRoot {
    static func makeModel() -> AppModel {
        let environment = AppEnvironment.compiled
        let logger = ApplePrivacySafeLogger(subsystem: "com.satyamshree.spc")
        let values = BundlePublicConfigurationLoader().load(from: .main)
        let namespace = ProcessInfo.processInfo.environment["SPC_LOCAL_STORE_NAMESPACE"] ?? "primary"

        if case .unavailable = AppConfiguration.resolve(
            environment: environment,
            values: values
        ) {
            logger.record(.configurationUnavailable, category: .configuration)
        }

        return AppModel(
            environment: environment,
            accessPolicy: AccessPolicy(),
            profileStore: LocalOnboardingProfileStore(
                location: LocalStoreLocation(namespace: namespace)
            ),
            logger: logger
        )
    }
}
