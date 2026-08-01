import Foundation

@MainActor
enum AppCompositionRoot {
    static func makeModel() -> AppModel {
        let environment = AppEnvironment.compiled
        let logger = ApplePrivacySafeLogger(subsystem: "com.satyamshree.spc")
        let namespace = ProcessInfo.processInfo.environment["SPC_LOCAL_STORE_NAMESPACE"] ?? "primary"
        let keychain = KeychainSessionStore(
            keychain: SystemKeychainClient(),
            service: "com.satyamshree.spc.authentication",
            account: "supabase-session"
        )

        let authentication: any OAuthSessionServicing
        let remote: (any RemoteMutationGateway)?
        let disablesAuthentication = ProcessInfo.processInfo.environment[
            "SPC_DISABLE_AUTH_CONFIGURATION"
        ] == "1"
        #if DEBUG
        if let value = ProcessInfo.processInfo.environment["SPC_UI_TEST_AUTHENTICATED_USER_ID"],
           let userID = UUID(uuidString: value)
        {
            authentication = UITestOAuthSessionService(userID: userID)
            remote = nil
        } else {
            if !disablesAuthentication,
               let configuration = SupabasePublicConfiguration.load(from: .main)
            {
                let client = configuration.makeClient()
                authentication = SupabaseOAuthSessionService(
                    client: client,
                    sessionStore: keychain
                )
                remote = SupabaseRemoteMutationGateway(
                    client: client,
                    identifier: SystemIdentifierGenerator()
                )
            } else {
                authentication = UnavailableOAuthSessionService()
                remote = nil
                logger.record(.configurationUnavailable, category: .configuration)
            }
        }
        #else
        if !disablesAuthentication,
           let configuration = SupabasePublicConfiguration.load(from: .main)
        {
            let client = configuration.makeClient()
            authentication = SupabaseOAuthSessionService(
                client: client,
                sessionStore: keychain
            )
            remote = SupabaseRemoteMutationGateway(
                client: client,
                identifier: SystemIdentifierGenerator()
            )
        } else {
            authentication = UnavailableOAuthSessionService()
            remote = nil
            logger.record(.configurationUnavailable, category: .configuration)
        }
        #endif

        return AppModel(
            environment: environment,
            accessPolicy: AccessPolicy(),
            store: IntegratedPhase1Store(
                location: LocalStoreLocation(namespace: namespace),
                remote: remote
            ),
            authentication: authentication,
            logger: logger
        )
    }
}
