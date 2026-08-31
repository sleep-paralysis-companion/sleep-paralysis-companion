import AuthenticationServices
import Foundation
@testable import SleepParalysisCompanion
import Supabase
import XCTest

final class SpyPrivacySafeLogger: PrivacySafeLogging, @unchecked Sendable {
    struct Entry: Equatable, Sendable {
        let event: AppLogEvent
        let category: AppLogCategory
    }

    private let lock = NSLock()
    private var _entries: [Entry] = []

    var entries: [Entry] {
        lock.lock()
        defer { lock.unlock() }
        return _entries
    }

    var events: [AppLogEvent] {
        entries.map(\.event)
    }

    func record(_ event: AppLogEvent, category: AppLogCategory) {
        lock.lock()
        defer { lock.unlock() }
        _entries.append(Entry(event: event, category: category))
    }
}

actor ScriptedSupabaseOAuthAuthenticator: SupabaseOAuthAuthenticating {
    enum Behavior {
        case success(Session)
        case failure(any Error)
    }

    private var behavior: Behavior
    private(set) var callCount = 0
    private(set) var lastProviderPassed: AuthenticationProvider?

    init(behavior: Behavior) {
        self.behavior = behavior
    }

    func setBehavior(_ behavior: Behavior) {
        self.behavior = behavior
    }

    func signInWithOAuth(provider: AuthenticationProvider) async throws -> Session {
        callCount += 1
        lastProviderPassed = provider
        switch behavior {
        case let .success(session):
            return session
        case let .failure(error):
            throw error
        }
    }
}

actor ScriptedOAuthSessionService: OAuthSessionServicing {
    var isConfigured: Bool
    private var result: Result<AuthenticationSessionMaterial, any Error>

    init(
        isConfigured: Bool = true,
        result: Result<AuthenticationSessionMaterial, any Error>
    ) {
        self.isConfigured = isConfigured
        self.result = result
    }

    func setResult(_ result: Result<AuthenticationSessionMaterial, any Error>) {
        self.result = result
    }

    func restore() async throws -> SessionRestoreResult? {
        nil
    }

    func signIn(provider: AuthenticationProvider) async throws -> AuthenticationSessionMaterial {
        _ = provider
        switch result {
        case let .success(material):
            return material
        case let .failure(error):
            throw error
        }
    }

    func signOut() async throws {
    }

    func reauthenticateForDeletion() async throws -> ReauthenticatedSession {
        throw AuthenticationError.cancelled
    }
}

final class OAuthSessionServiceSignInTests: XCTestCase {
    private let fixedNow = Date(timeIntervalSince1970: 1_753_660_800)
    private let testUserID = UUID(
        uuid: (0x33, 0x33, 0x33, 0x33, 0x33, 0x33, 0x43, 0x33, 0x83, 0x33, 0x33, 0x33, 0x33, 0x33, 0x33, 0x33)
    )

    private func makeClient() -> SupabaseClient {
        SupabaseClient(
            supabaseURL: URL(string: "https://example.supabase.co")!,
            supabaseKey: "test-anon-key"
        )
    }

    private func makeSyntheticSession(
        userID: UUID,
        accessToken: String = "synthetic-signin-access",
        refreshToken: String = "synthetic-signin-refresh",
        expiresAt: TimeInterval
    ) throws -> Session {
        let json = """
        {
            "access_token": "\(accessToken)",
            "token_type": "bearer",
            "expires_in": 3600,
            "expires_at": \(Int(expiresAt)),
            "refresh_token": "\(refreshToken)",
            "user": {
                "id": "\(userID.uuidString.lowercased())",
                "aud": "authenticated",
                "role": "authenticated",
                "email": "user@example.com",
                "app_metadata": {},
                "user_metadata": {},
                "created_at": "2026-01-01T00:00:00Z",
                "updated_at": "2026-01-01T00:00:00Z"
            }
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Session.self, from: Data(json.utf8))
    }

    func testSuccessfulSignInLogsStartedAndSucceededAndWritesSession() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        let expiry = fixedNow.addingTimeInterval(3600)
        let sdkSession = try makeSyntheticSession(
            userID: testUserID,
            expiresAt: expiry.timeIntervalSince1970
        )
        let authenticator = ScriptedSupabaseOAuthAuthenticator(behavior: .success(sdkSession))
        let spyLogger = SpyPrivacySafeLogger()
        let service = SupabaseOAuthSessionService(
            client: makeClient(),
            sessionStore: store,
            oauthAuthenticator: authenticator,
            logger: spyLogger,
            clock: FixedClock(value: fixedNow)
        )

        let material = try await service.signIn(provider: .apple)

        XCTAssertEqual(material.userID, testUserID)
        XCTAssertEqual(material.provider, .apple)
        XCTAssertEqual(material.accessToken, "synthetic-signin-access")
        XCTAssertEqual(material.refreshToken, "synthetic-signin-refresh")
        XCTAssertEqual(try store.read(), material)

        let loggedEvents = spyLogger.entries
        XCTAssertEqual(loggedEvents.count, 2)
        XCTAssertEqual(loggedEvents[0].event, .signInStarted)
        XCTAssertEqual(loggedEvents[0].category, .authentication)
        XCTAssertEqual(loggedEvents[1].event, .signInSucceeded)
        XCTAssertEqual(loggedEvents[1].category, .authentication)
    }

    func testUserCancelledASWebAuthenticationSessionThrowsCancelledAndLogsNothingExtra() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        let cancelError = NSError(
            domain: ASWebAuthenticationSessionErrorDomain,
            code: ASWebAuthenticationSessionError.canceledLogin.rawValue,
            userInfo: nil
        )
        let authenticator = ScriptedSupabaseOAuthAuthenticator(behavior: .failure(cancelError))
        let spyLogger = SpyPrivacySafeLogger()
        let service = SupabaseOAuthSessionService(
            client: makeClient(),
            sessionStore: store,
            oauthAuthenticator: authenticator,
            logger: spyLogger,
            clock: FixedClock(value: fixedNow)
        )

        do {
            _ = try await service.signIn(provider: .google)
            XCTFail("Expected AuthenticationError.cancelled to be thrown")
        } catch let error as AuthenticationError {
            XCTAssertEqual(error, .cancelled)
        } catch {
            XCTFail("Unexpected error thrown: \(error)")
        }

        let loggedEvents = spyLogger.entries
        XCTAssertEqual(loggedEvents.count, 1)
        XCTAssertEqual(loggedEvents[0].event, .signInStarted)
        XCTAssertEqual(loggedEvents[0].category, .authentication)
        XCTAssertNil(try store.read())
    }

    func testCancellationErrorThrowsCancelledAndLogsNothingExtra() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        let authenticator = ScriptedSupabaseOAuthAuthenticator(behavior: .failure(CancellationError()))
        let spyLogger = SpyPrivacySafeLogger()
        let service = SupabaseOAuthSessionService(
            client: makeClient(),
            sessionStore: store,
            oauthAuthenticator: authenticator,
            logger: spyLogger,
            clock: FixedClock(value: fixedNow)
        )

        do {
            _ = try await service.signIn(provider: .apple)
            XCTFail("Expected AuthenticationError.cancelled to be thrown")
        } catch let error as AuthenticationError {
            XCTAssertEqual(error, .cancelled)
        } catch {
            XCTFail("Unexpected error thrown: \(error)")
        }

        let loggedEvents = spyLogger.entries
        XCTAssertEqual(loggedEvents.count, 1)
        XCTAssertEqual(loggedEvents[0].event, .signInStarted)
    }

    func testNetworkURLErrorThrowsNetworkUnavailableAndLogsEvent() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        let authenticator = ScriptedSupabaseOAuthAuthenticator(
            behavior: .failure(URLError(.notConnectedToInternet))
        )
        let spyLogger = SpyPrivacySafeLogger()
        let service = SupabaseOAuthSessionService(
            client: makeClient(),
            sessionStore: store,
            oauthAuthenticator: authenticator,
            logger: spyLogger,
            clock: FixedClock(value: fixedNow)
        )

        do {
            _ = try await service.signIn(provider: .apple)
            XCTFail("Expected AuthenticationError.networkUnavailable to be thrown")
        } catch let error as AuthenticationError {
            XCTAssertEqual(error, .networkUnavailable)
        } catch {
            XCTFail("Unexpected error thrown: \(error)")
        }

        let loggedEvents = spyLogger.entries
        XCTAssertEqual(loggedEvents.count, 2)
        XCTAssertEqual(loggedEvents[0].event, .signInStarted)
        XCTAssertEqual(loggedEvents[1].event, .signInNetworkUnavailable)
        XCTAssertEqual(loggedEvents[1].category, .authentication)
    }

    func testNetworkPOSIXErrorThrowsNetworkUnavailableAndLogsEvent() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        let posixError = NSError(
            domain: NSPOSIXErrorDomain,
            code: Int(POSIXErrorCode.ECONNREFUSED.rawValue),
            userInfo: nil
        )
        let authenticator = ScriptedSupabaseOAuthAuthenticator(behavior: .failure(posixError))
        let spyLogger = SpyPrivacySafeLogger()
        let service = SupabaseOAuthSessionService(
            client: makeClient(),
            sessionStore: store,
            oauthAuthenticator: authenticator,
            logger: spyLogger,
            clock: FixedClock(value: fixedNow)
        )

        do {
            _ = try await service.signIn(provider: .google)
            XCTFail("Expected AuthenticationError.networkUnavailable to be thrown")
        } catch let error as AuthenticationError {
            XCTAssertEqual(error, .networkUnavailable)
        } catch {
            XCTFail("Unexpected error thrown: \(error)")
        }

        XCTAssertEqual(spyLogger.events, [.signInStarted, .signInNetworkUnavailable])
    }

    func testNetworkCFErrorThrowsNetworkUnavailableAndLogsEvent() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        let cfError = NSError(
            domain: "kCFErrorDomainCFNetwork",
            code: 2,
            userInfo: nil
        )
        let authenticator = ScriptedSupabaseOAuthAuthenticator(behavior: .failure(cfError))
        let spyLogger = SpyPrivacySafeLogger()
        let service = SupabaseOAuthSessionService(
            client: makeClient(),
            sessionStore: store,
            oauthAuthenticator: authenticator,
            logger: spyLogger,
            clock: FixedClock(value: fixedNow)
        )

        do {
            _ = try await service.signIn(provider: .apple)
            XCTFail("Expected AuthenticationError.networkUnavailable to be thrown")
        } catch let error as AuthenticationError {
            XCTAssertEqual(error, .networkUnavailable)
        } catch {
            XCTFail("Unexpected error thrown: \(error)")
        }

        XCTAssertEqual(spyLogger.events, [.signInStarted, .signInNetworkUnavailable])
    }

    func testServerRejectedHTTP400InvalidGrantThrowsServerRejectedAndLogsEvent() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        let error = NSError(
            domain: "AuthError",
            code: 400,
            userInfo: [NSLocalizedDescriptionKey: "invalid_grant: bad code"]
        )
        let authenticator = ScriptedSupabaseOAuthAuthenticator(behavior: .failure(error))
        let spyLogger = SpyPrivacySafeLogger()
        let service = SupabaseOAuthSessionService(
            client: makeClient(),
            sessionStore: store,
            oauthAuthenticator: authenticator,
            logger: spyLogger,
            clock: FixedClock(value: fixedNow)
        )

        do {
            _ = try await service.signIn(provider: .google)
            XCTFail("Expected AuthenticationError.serverRejected to be thrown")
        } catch let error as AuthenticationError {
            XCTAssertEqual(error, .serverRejected)
        } catch {
            XCTFail("Unexpected error thrown: \(error)")
        }

        XCTAssertEqual(spyLogger.events, [.signInStarted, .signInServerRejected])
    }

    func testServerRejectedHTTP401UnauthorizedThrowsServerRejectedAndLogsEvent() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        let error = NSError(
            domain: "AuthError",
            code: 401,
            userInfo: [NSLocalizedDescriptionKey: "Unauthorized request"]
        )
        let authenticator = ScriptedSupabaseOAuthAuthenticator(behavior: .failure(error))
        let spyLogger = SpyPrivacySafeLogger()
        let service = SupabaseOAuthSessionService(
            client: makeClient(),
            sessionStore: store,
            oauthAuthenticator: authenticator,
            logger: spyLogger,
            clock: FixedClock(value: fixedNow)
        )

        do {
            _ = try await service.signIn(provider: .apple)
            XCTFail("Expected AuthenticationError.serverRejected to be thrown")
        } catch let error as AuthenticationError {
            XCTAssertEqual(error, .serverRejected)
        } catch {
            XCTFail("Unexpected error thrown: \(error)")
        }

        XCTAssertEqual(spyLogger.events, [.signInStarted, .signInServerRejected])
    }

    func testServerRejectedHTTP403AccessDeniedThrowsServerRejectedAndLogsEvent() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        let error = NSError(
            domain: "AuthError",
            code: 403,
            userInfo: [NSLocalizedDescriptionKey: "access_denied: User denied consent"]
        )
        let authenticator = ScriptedSupabaseOAuthAuthenticator(behavior: .failure(error))
        let spyLogger = SpyPrivacySafeLogger()
        let service = SupabaseOAuthSessionService(
            client: makeClient(),
            sessionStore: store,
            oauthAuthenticator: authenticator,
            logger: spyLogger,
            clock: FixedClock(value: fixedNow)
        )

        do {
            _ = try await service.signIn(provider: .google)
            XCTFail("Expected AuthenticationError.serverRejected to be thrown")
        } catch let error as AuthenticationError {
            XCTAssertEqual(error, .serverRejected)
        } catch {
            XCTFail("Unexpected error thrown: \(error)")
        }

        XCTAssertEqual(spyLogger.events, [.signInStarted, .signInServerRejected])
    }

    func testPresentationContextNotProvidedThrowsExternalProviderUnavailableAndLogsEvent() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        let error = NSError(
            domain: ASWebAuthenticationSessionErrorDomain,
            code: ASWebAuthenticationSessionError.presentationContextNotProvided.rawValue,
            userInfo: nil
        )
        let authenticator = ScriptedSupabaseOAuthAuthenticator(behavior: .failure(error))
        let spyLogger = SpyPrivacySafeLogger()
        let service = SupabaseOAuthSessionService(
            client: makeClient(),
            sessionStore: store,
            oauthAuthenticator: authenticator,
            logger: spyLogger,
            clock: FixedClock(value: fixedNow)
        )

        do {
            _ = try await service.signIn(provider: .apple)
            XCTFail("Expected AuthenticationError.externalProviderUnavailable to be thrown")
        } catch let error as AuthenticationError {
            XCTAssertEqual(error, .externalProviderUnavailable)
        } catch {
            XCTFail("Unexpected error thrown: \(error)")
        }

        XCTAssertEqual(spyLogger.events, [.signInStarted, .signInProviderUnavailable])
    }

    func testServer500ThrowsExternalProviderUnavailableAndLogsEvent() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        let error = NSError(
            domain: "AuthError",
            code: 500,
            userInfo: [NSLocalizedDescriptionKey: "Internal Server Error"]
        )
        let authenticator = ScriptedSupabaseOAuthAuthenticator(behavior: .failure(error))
        let spyLogger = SpyPrivacySafeLogger()
        let service = SupabaseOAuthSessionService(
            client: makeClient(),
            sessionStore: store,
            oauthAuthenticator: authenticator,
            logger: spyLogger,
            clock: FixedClock(value: fixedNow)
        )

        do {
            _ = try await service.signIn(provider: .apple)
            XCTFail("Expected AuthenticationError.externalProviderUnavailable to be thrown")
        } catch let error as AuthenticationError {
            XCTAssertEqual(error, .externalProviderUnavailable)
        } catch {
            XCTFail("Unexpected error thrown: \(error)")
        }

        XCTAssertEqual(spyLogger.events, [.signInStarted, .signInProviderUnavailable])
    }

    func testKeychainWriteFailureThrowsKeychainFailureAndLogsEvent() async throws {
        final class FailingKeychain: KeychainClient {
            func read(service _: String, account _: String) throws -> Data? {
                nil
            }

            func write(_: Data, service _: String, account _: String) throws {
                throw AuthenticationError.keychainFailure
            }

            func delete(service _: String, account _: String) throws {
            }
        }

        let store = KeychainSessionStore(keychain: FailingKeychain())
        let sdkSession = try makeSyntheticSession(
            userID: testUserID,
            expiresAt: fixedNow.addingTimeInterval(3600).timeIntervalSince1970
        )
        let authenticator = ScriptedSupabaseOAuthAuthenticator(behavior: .success(sdkSession))
        let spyLogger = SpyPrivacySafeLogger()
        let service = SupabaseOAuthSessionService(
            client: makeClient(),
            sessionStore: store,
            oauthAuthenticator: authenticator,
            logger: spyLogger,
            clock: FixedClock(value: fixedNow)
        )

        do {
            _ = try await service.signIn(provider: .apple)
            XCTFail("Expected AuthenticationError.keychainFailure to be thrown")
        } catch let error as AuthenticationError {
            XCTAssertEqual(error, .keychainFailure)
        } catch {
            XCTFail("Unexpected error thrown: \(error)")
        }

        XCTAssertEqual(spyLogger.events, [.signInStarted, .signInFailedUnclassified])
    }

    func testSignOutLogsSignOutCompleted() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        let spyLogger = SpyPrivacySafeLogger()
        let service = SupabaseOAuthSessionService(
            client: makeClient(),
            sessionStore: store,
            logger: spyLogger,
            clock: FixedClock(value: fixedNow)
        )

        try await service.signOut()

        XCTAssertEqual(spyLogger.events, [.signOutCompleted])
        XCTAssertEqual(spyLogger.entries.first?.category, .authentication)
    }

    func testRestorePurgedOnRejectionLogsRestorePurgedOnRejection() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        let staleSession = AuthenticationSessionMaterial(
            userID: testUserID,
            provider: .apple,
            accessToken: "stored-access",
            refreshToken: "stored-refresh",
            expiresAt: fixedNow.addingTimeInterval(-100)
        )
        try store.write(staleSession)

        let invalidGrantError = NSError(
            domain: "AuthError",
            code: 400,
            userInfo: [NSLocalizedDescriptionKey: "invalid_grant: Refresh token not found"]
        )
        let refresher = ScriptedSupabaseAuthRefresher(behavior: .failure(invalidGrantError))
        let spyLogger = SpyPrivacySafeLogger()
        let service = SupabaseOAuthSessionService(
            client: makeClient(),
            sessionStore: store,
            authRefresher: refresher,
            logger: spyLogger,
            clock: FixedClock(value: fixedNow)
        )

        do {
            _ = try await service.restore()
            XCTFail("Expected AuthenticationError.expired to be thrown")
        } catch let error as AuthenticationError {
            XCTAssertEqual(error, .expired)
        } catch {
            XCTFail("Unexpected error thrown: \(error)")
        }

        XCTAssertEqual(spyLogger.events, [.restorePurgedOnRejection])
        XCTAssertEqual(spyLogger.entries.first?.category, .authentication)
        XCTAssertNil(try store.read())
    }

    func testTaxonomyMappingFunctionTableCoverage() {
        // 1. Cancellation
        XCTAssertEqual(
            SupabaseOAuthSessionService.classifySignInError(CancellationError()),
            .cancelled
        )
        XCTAssertEqual(
            SupabaseOAuthSessionService.classifySignInError(
                NSError(
                    domain: ASWebAuthenticationSessionErrorDomain,
                    code: ASWebAuthenticationSessionError.canceledLogin.rawValue
                )
            ),
            .cancelled
        )

        // 2. Network transport
        XCTAssertEqual(
            SupabaseOAuthSessionService.classifySignInError(URLError(.notConnectedToInternet)),
            .networkUnavailable
        )
        XCTAssertEqual(
            SupabaseOAuthSessionService.classifySignInError(URLError(.timedOut)),
            .networkUnavailable
        )
        XCTAssertEqual(
            SupabaseOAuthSessionService.classifySignInError(
                NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotConnectToHost)
            ),
            .networkUnavailable
        )
        XCTAssertEqual(
            SupabaseOAuthSessionService.classifySignInError(
                NSError(domain: "kCFErrorDomainCFNetwork", code: 2)
            ),
            .networkUnavailable
        )
        XCTAssertEqual(
            SupabaseOAuthSessionService.classifySignInError(
                NSError(domain: NSPOSIXErrorDomain, code: Int(POSIXErrorCode.ECONNREFUSED.rawValue))
            ),
            .networkUnavailable
        )

        // 3. Server rejections
        XCTAssertEqual(
            SupabaseOAuthSessionService.classifySignInError(
                NSError(domain: "AuthError", code: 400, userInfo: nil)
            ),
            .serverRejected
        )
        XCTAssertEqual(
            SupabaseOAuthSessionService.classifySignInError(
                NSError(domain: "AuthError", code: 401, userInfo: nil)
            ),
            .serverRejected
        )
        XCTAssertEqual(
            SupabaseOAuthSessionService.classifySignInError(
                NSError(domain: "AuthError", code: 403, userInfo: nil)
            ),
            .serverRejected
        )
        XCTAssertEqual(
            SupabaseOAuthSessionService.classifySignInError(
                NSError(domain: "AuthError", code: 422, userInfo: nil)
            ),
            .serverRejected
        )
        XCTAssertEqual(
            SupabaseOAuthSessionService.classifySignInError(
                NSError(
                    domain: "Custom",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "access_denied by provider"]
                )
            ),
            .serverRejected
        )
        XCTAssertEqual(
            SupabaseOAuthSessionService.classifySignInError(
                NSError(
                    domain: "Custom",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "invalid_grant error"]
                )
            ),
            .serverRejected
        )

        // 4. Provider / Web-sheet / 5xx / fallback
        XCTAssertEqual(
            SupabaseOAuthSessionService.classifySignInError(
                NSError(
                    domain: ASWebAuthenticationSessionErrorDomain,
                    code: ASWebAuthenticationSessionError.presentationContextNotProvided.rawValue
                )
            ),
            .externalProviderUnavailable
        )
        XCTAssertEqual(
            SupabaseOAuthSessionService.classifySignInError(
                NSError(domain: "AuthError", code: 500, userInfo: nil)
            ),
            .externalProviderUnavailable
        )
        XCTAssertEqual(
            SupabaseOAuthSessionService.classifySignInError(
                NSError(domain: "AuthError", code: 503, userInfo: nil)
            ),
            .externalProviderUnavailable
        )
        XCTAssertEqual(
            SupabaseOAuthSessionService.classifySignInError(
                NSError(
                    domain: "UnknownDomain",
                    code: 999,
                    userInfo: [NSLocalizedDescriptionKey: "Unexpected internal fault"]
                )
            ),
            .externalProviderUnavailable
        )
    }

    @MainActor
    func testAppModelSignInCancelledIsQuiet() async {
        let authService = ScriptedOAuthSessionService(
            result: .failure(AuthenticationError.cancelled)
        )
        let model = makeAppModel(authService: authService)
        model.signIn(provider: .apple)

        await waitForAppModel {
            model.authenticationState == .cancelled
        }
        XCTAssertNil(model.feedbackMessage)
    }

    @MainActor
    func testAppModelSignInNetworkUnavailableShowsOfflineCopy() async {
        let authService = ScriptedOAuthSessionService(
            result: .failure(AuthenticationError.networkUnavailable)
        )
        let model = makeAppModel(authService: authService)
        model.signIn(provider: .apple)

        await waitForAppModel {
            model.authenticationState == .failed
        }
        XCTAssertEqual(
            model.feedbackMessage,
            "Network connection is unavailable. Check your connection and try again."
        )
    }

    @MainActor
    func testAppModelSignInServerRejectedShowsCalmRejectionCopy() async {
        let authService = ScriptedOAuthSessionService(
            result: .failure(AuthenticationError.serverRejected)
        )
        let model = makeAppModel(authService: authService)
        model.signIn(provider: .google)

        await waitForAppModel {
            model.authenticationState == .failed
        }
        XCTAssertEqual(
            model.feedbackMessage,
            "Sign-in was rejected by the server. Try again later."
        )
    }

    @MainActor
    func testAppModelSignInExternalProviderUnavailableShowsConfigurationCopy() async {
        let authService = ScriptedOAuthSessionService(
            result: .failure(AuthenticationError.externalProviderUnavailable)
        )
        let model = makeAppModel(authService: authService)
        model.signIn(provider: .apple)

        await waitForAppModel {
            model.authenticationState == .failed
        }
        XCTAssertEqual(
            model.feedbackMessage,
            "Sign-in did not finish. Check the provider configuration and try again."
        )
    }

    @MainActor
    func testAppModelSignInWrongAccountShowsAccountMismatchCopy() async {
        let authService = ScriptedOAuthSessionService(
            result: .failure(AuthenticationError.wrongAccount)
        )
        let model = makeAppModel(authService: authService)
        model.signIn(provider: .apple)

        await waitForAppModel {
            model.authenticationState == .failed && model.accountAccessState == .wrongAccount
        }
        XCTAssertEqual(
            model.feedbackMessage,
            "This account does not match the protected profile on this device."
        )
    }

    @MainActor
    private func makeAppModel(authService: any OAuthSessionServicing) -> AppModel {
        let store = IntegratedPhase1Store(
            location: LocalStoreLocation(namespace: "test-auth-\(UUID().uuidString)")
        )
        return AppModel(
            environment: AppEnvironment(
                isProduction: false,
                buildVariant: "test",
                bundleIdentifier: "app.sleepcompanion.spc"
            ),
            accessPolicy: AccessPolicy(),
            store: store,
            authentication: authService,
            logger: NoOpPrivacySafeLogger()
        )
    }
}
