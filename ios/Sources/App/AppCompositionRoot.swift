import Foundation

@MainActor
enum AppCompositionRoot {
    static func makeModel() -> AppModel {
        let environment = AppEnvironment.compiled
        let catalogAudioConfiguration = CatalogAudioRemoteConfiguration.load(from: .main)
        let logger = ApplePrivacySafeLogger(subsystem: "app.sleepcompanion.spc")
        let namespace = ProcessInfo.processInfo.environment["SPC_LOCAL_STORE_NAMESPACE"] ?? "primary"
        let keychain = KeychainSessionStore(
            keychain: SystemKeychainClient(),
            service: "app.sleepcompanion.spc.authentication",
            account: "supabase-session"
        )

        let authentication: any OAuthSessionServicing
        let accountDeletionGateway: (any AccountDeletionGateway)?
        let remote: (any RemoteMutationGateway)?
        let disablesAuthentication = ProcessInfo.processInfo.environment[
            "SPC_DISABLE_AUTH_CONFIGURATION"
        ] == "1"
        #if DEBUG
            let uiTestUserID = ProcessInfo.processInfo.environment["SPC_UI_TEST_AUTHENTICATED_USER_ID"]
                .flatMap(UUID.init(uuidString:))
            if let userID = uiTestUserID {
                authentication = UITestOAuthSessionService(userID: userID)
                accountDeletionGateway = nil
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
                    accountDeletionGateway = SupabaseAccountDeletionGateway(client: client)
                    remote = SupabaseRemoteMutationGateway(
                        client: client,
                        identifier: SystemIdentifierGenerator()
                    )
                } else {
                    authentication = UnavailableOAuthSessionService()
                    accountDeletionGateway = nil
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
                accountDeletionGateway = SupabaseAccountDeletionGateway(client: client)
                remote = SupabaseRemoteMutationGateway(
                    client: client,
                    identifier: SystemIdentifierGenerator()
                )
            } else {
                authentication = UnavailableOAuthSessionService()
                accountDeletionGateway = nil
                remote = nil
                logger.record(.configurationUnavailable, category: .configuration)
            }
        #endif

        let store: IntegratedPhase1Store
        #if DEBUG
            if uiTestUserID != nil {
                store = IntegratedPhase1Store(
                    location: LocalStoreLocation(namespace: namespace),
                    protection: UITestProtectedFileApplicator(),
                    preferences: AccountBoundPreferencesStore(keychain: UITestKeychainClient()),
                    remote: nil
                )
            } else {
                store = IntegratedPhase1Store(
                    location: LocalStoreLocation(namespace: namespace),
                    remote: remote
                )
            }
        #else
            store = IntegratedPhase1Store(
                location: LocalStoreLocation(namespace: namespace),
                remote: remote
            )
        #endif

        return AppModel(
            environment: environment,
            accessPolicy: AccessPolicy(),
            store: store,
            authentication: authentication,
            accountDeletionGateway: accountDeletionGateway,
            catalogAudioConfiguration: catalogAudioConfiguration,
            logger: logger
        )
    }
}

#if DEBUG
    private nonisolated struct UITestProtectedFileApplicator: ProtectedFileApplying {
        func applyProtection(to url: URL, kind: ProtectedFileKind) throws {
            _ = url
            _ = kind
        }
    }

    private nonisolated struct UITestKeychainClient: KeychainClient {
        func read(service: String, account: String) throws -> Data? {
            _ = service
            _ = account
            return nil
        }

        func write(_ data: Data, service: String, account: String) throws {
            _ = data
            _ = service
            _ = account
        }

        func delete(service: String, account: String) throws {
            _ = service
            _ = account
        }
    }
#endif
