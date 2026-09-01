import AuthenticationServices
import Foundation
import Supabase

nonisolated enum SessionRestoreResult: Equatable, Sendable {
    case fresh(AuthenticationSessionMaterial)
    case refreshed(AuthenticationSessionMaterial)
    case preservedOffline(AuthenticationSessionMaterial, classification: SessionRefreshErrorClassification)

    var session: AuthenticationSessionMaterial {
        switch self {
        case let .fresh(material),
             let .refreshed(material),
             let .preservedOffline(material, _):
            material
        }
    }
}

nonisolated protocol OAuthSessionServicing: AccountDeletionSessionSigningOut {
    var isConfigured: Bool { get }
    func restore() async throws -> SessionRestoreResult?
    func signIn(provider: AuthenticationProvider) async throws -> AuthenticationSessionMaterial
    func reauthenticateForDeletion() async throws -> ReauthenticatedSession
}

actor UnavailableOAuthSessionService: OAuthSessionServicing {
    nonisolated let isConfigured = false

    func restore() async throws -> SessionRestoreResult? {
        nil
    }

    func signIn(provider: AuthenticationProvider) async throws -> AuthenticationSessionMaterial {
        _ = provider
        throw Phase1ActionError.configurationRequired
    }

    func signOut() async throws {}
    func reauthenticateForDeletion() async throws -> ReauthenticatedSession {
        throw Phase1ActionError.configurationRequired
    }
}

#if DEBUG
    actor UITestOAuthSessionService: OAuthSessionServicing {
        nonisolated let isConfigured = true
        private let userID: UUID

        init(userID: UUID) {
            self.userID = userID
        }

        func restore() async throws -> SessionRestoreResult? {
            .fresh(session())
        }

        func signIn(provider: AuthenticationProvider) async throws -> AuthenticationSessionMaterial {
            _ = provider
            return session()
        }

        func signOut() async throws {}

        func reauthenticateForDeletion() async throws -> ReauthenticatedSession {
            let material = session()
            return ReauthenticatedSession(
                session: material,
                proof: RecentReauthentication(
                    userID: material.userID,
                    provider: material.provider,
                    authenticatedAt: Date()
                )
            )
        }

        private func session() -> AuthenticationSessionMaterial {
            AuthenticationSessionMaterial(
                userID: userID,
                provider: .apple,
                accessToken: "ui-test-only",
                refreshToken: "ui-test-only",
                expiresAt: Date.distantFuture
            )
        }
    }
#endif

nonisolated protocol SupabaseAuthRefreshing: Sendable {
    func refreshSession(refreshToken: String) async throws -> Session
}

actor DefaultSupabaseAuthRefresher: SupabaseAuthRefreshing {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func refreshSession(refreshToken: String) async throws -> Session {
        try await client.auth.refreshSession(refreshToken: refreshToken)
    }
}

nonisolated protocol SupabaseOAuthAuthenticating: Sendable {
    func signInWithOAuth(provider: AuthenticationProvider) async throws -> Session
}

actor DefaultSupabaseOAuthAuthenticator: SupabaseOAuthAuthenticating {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func signInWithOAuth(provider: AuthenticationProvider) async throws -> Session {
        switch provider {
        case .apple:
            try await client.auth.signInWithOAuth(provider: .apple)
        case .google:
            try await client.auth.signInWithOAuth(provider: .google)
        }
    }
}

nonisolated enum SessionRefreshErrorClassification: Equatable, Sendable {
    case network
    case definitiveRejection
    case unclassified
}

actor SupabaseOAuthSessionService: OAuthSessionServicing {
    nonisolated let isConfigured = true

    private let client: SupabaseClient
    private let sessionStore: any SessionSecretStore
    private let authRefresher: any SupabaseAuthRefreshing
    private let oauthAuthenticator: any SupabaseOAuthAuthenticating
    private let logger: any PrivacySafeLogging
    private let clock: any Phase1BClock

    init(
        client: SupabaseClient,
        sessionStore: any SessionSecretStore,
        authRefresher: (any SupabaseAuthRefreshing)? = nil,
        oauthAuthenticator: (any SupabaseOAuthAuthenticating)? = nil,
        logger: any PrivacySafeLogging = NoOpPrivacySafeLogger(),
        clock: any Phase1BClock = SystemPhase1BClock()
    ) {
        self.client = client
        self.sessionStore = sessionStore
        self.authRefresher = authRefresher ?? DefaultSupabaseAuthRefresher(client: client)
        self.oauthAuthenticator = oauthAuthenticator ?? DefaultSupabaseOAuthAuthenticator(client: client)
        self.logger = logger
        self.clock = clock
    }

    func restore() async throws -> SessionRestoreResult? {
        if let stored = try sessionStore.readIdentity() {
            return try await restoreStoredIdentity(stored)
        }
        if let legacy = try sessionStore.readLegacyMaterial() {
            return try await restoreLegacyMaterial(legacy)
        }
        return nil
    }

    private func restoreStoredIdentity(
        _ stored: AuthenticationIdentityRecord
    ) async throws -> SessionRestoreResult {
        let now = clock.now()
        if stored.expiresAt > now.addingTimeInterval(60) {
            let sdkSession = await currentSDKSession()
            if let sdkSession, sdkSession.user.id == stored.userID {
                let material = Self.material(from: sdkSession, provider: stored.provider)
                return .fresh(material)
            }
            let fallback = AuthenticationSessionMaterial(
                userID: stored.userID,
                provider: stored.provider,
                accessToken: sdkSession?.accessToken ?? "",
                refreshToken: sdkSession?.refreshToken ?? "",
                expiresAt: stored.expiresAt
            )
            return .fresh(fallback)
        }

        let sdkSession = await currentSDKSession()
        let session: Session
        do {
            session = try await fetchRefreshedSession(refreshToken: sdkSession?.refreshToken)
        } catch {
            let classification = Self.classifyRefreshError(error)
            switch classification {
            case .network, .unclassified:
                if let sdkSession {
                    let material = Self.material(from: sdkSession, provider: stored.provider)
                    return .preservedOffline(material, classification: classification)
                }
                let fallback = AuthenticationSessionMaterial(
                    userID: stored.userID,
                    provider: stored.provider,
                    accessToken: "",
                    refreshToken: "",
                    expiresAt: stored.expiresAt
                )
                return .preservedOffline(fallback, classification: classification)
            case .definitiveRejection:
                try? sessionStore.delete()
                try? await client.auth.signOut()
                logger.record(.restorePurgedOnRejection, category: .authentication)
                throw AuthenticationError.expired
            }
        }

        guard session.user.id == stored.userID else {
            try? sessionStore.delete()
            try? await client.auth.signOut()
            throw AuthenticationError.wrongAccount
        }

        let updatedIdentity = AuthenticationIdentityRecord(
            userID: session.user.id,
            provider: stored.provider,
            expiresAt: Date(timeIntervalSince1970: TimeInterval(session.expiresAt))
        )
        do {
            try sessionStore.writeIdentity(updatedIdentity)
            let material = Self.material(from: session, provider: stored.provider)
            return .refreshed(material)
        } catch {
            let material = Self.material(from: session, provider: stored.provider)
            return .preservedOffline(material, classification: .unclassified)
        }
    }

    private func restoreLegacyMaterial(
        _ legacy: AuthenticationSessionMaterial
    ) async throws -> SessionRestoreResult {
        let session: Session
        do {
            session = try await authRefresher.refreshSession(refreshToken: legacy.refreshToken)
        } catch {
            let classification = Self.classifyRefreshError(error)
            switch classification {
            case .network, .unclassified:
                return .preservedOffline(legacy, classification: classification)
            case .definitiveRejection:
                try? sessionStore.delete()
                try? await client.auth.signOut()
                logger.record(.restorePurgedOnRejection, category: .authentication)
                throw AuthenticationError.expired
            }
        }

        guard session.user.id == legacy.userID else {
            try? sessionStore.delete()
            try? await client.auth.signOut()
            throw AuthenticationError.wrongAccount
        }

        let newIdentity = AuthenticationIdentityRecord(
            userID: session.user.id,
            provider: legacy.provider,
            expiresAt: Date(timeIntervalSince1970: TimeInterval(session.expiresAt))
        )
        do {
            try sessionStore.writeIdentity(newIdentity)
            try sessionStore.deleteLegacyMaterial()
        } catch {
            let material = Self.material(from: session, provider: legacy.provider)
            return .refreshed(material)
        }

        let material = Self.material(from: session, provider: legacy.provider)
        return .refreshed(material)
    }

    private func fetchRefreshedSession(refreshToken: String?) async throws -> Session {
        if let refreshToken {
            try await authRefresher.refreshSession(refreshToken: refreshToken)
        } else {
            try await client.auth.refreshSession()
        }
    }

    /// Determines if an error represents an unreachable host or transport failure.
    nonisolated static func isNetworkError(_ error: any Error) -> Bool {
        if error is URLError {
            return true
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return true
        }
        if nsError.domain == (kCFErrorDomainCFNetwork as String) || nsError.domain == "kCFErrorDomainCFNetwork" {
            return true
        }
        if nsError.domain == NSPOSIXErrorDomain {
            let networkPOSIXCodes: Set<Int32> = [
                POSIXErrorCode.ECONNREFUSED.rawValue,
                POSIXErrorCode.ECONNRESET.rawValue,
                POSIXErrorCode.ENETDOWN.rawValue,
                POSIXErrorCode.ENETUNREACH.rawValue,
                POSIXErrorCode.EHOSTUNREACH.rawValue,
                POSIXErrorCode.ETIMEDOUT.rawValue,
                POSIXErrorCode.ENOTCONN.rawValue,
            ]
            if networkPOSIXCodes.contains(Int32(nsError.code)) {
                return true
            }
        }
        return false
    }

    /// Refresh-failure classification (S1 contract):
    /// - URLError / NSURLErrorDomain / CFNetwork / POSIX → .network: preserve stored session (offline or transient).
    /// - Keywords ("invalid_grant", "session_not_found", …) → .definitiveRejection: purge session; throw .expired.
    /// - Bare HTTP 401, 403, 400 → .definitiveRejection: purge session; throw .expired; endpoint rejected token.
    /// - Bare HTTP 404, 422, 429, 5xx, decoding / other → .unclassified: preserve stored session (fail-safe).
    nonisolated static func classifyRefreshError(_ error: any Error) -> SessionRefreshErrorClassification {
        if isNetworkError(error) {
            return .network
        }

        let nsError = error as NSError
        let statusCode = (nsError.userInfo["statusCode"] as? Int)
            ?? (nsError.userInfo["status"] as? Int)
            ?? (nsError.userInfo["HTTPStatusCode"] as? Int)
            ?? ((nsError.code >= 400 && nsError.code < 600) ? nsError.code : nil)

        if let statusCode, statusCode == 429 || (statusCode >= 500 && statusCode < 600) {
            return .unclassified
        }

        let description = String(describing: error).lowercased()
        let definitivePatterns = [
            "invalid_grant",
            "invalid_request",
            "invalid_token",
            "invalid refresh token",
            "refresh_token_not_found",
            "refresh token not found",
            "session_not_found",
            "session not found",
            "user_not_found",
            "user not found",
            "token is expired",
            "jwt expired",
            "bad_jwt",
            "token has expired",
            "revoked",
        ]

        for pattern in definitivePatterns where description.contains(pattern) {
            return .definitiveRejection
        }

        if let statusCode, statusCode == 401 || statusCode == 403 {
            return .definitiveRejection
        }

        if let statusCode, statusCode == 400 {
            return .definitiveRejection
        }

        return .unclassified
    }

    /// Sign-in failure classification (S2 contract):
    /// - CancellationError / ASWebAuthenticationSessionError.canceledLogin → .cancelled.
    /// - URLError / NSURLErrorDomain / CFNetwork / POSIX → .networkUnavailable.
    /// - HTTP 400..499, AuthError keywords ("access_denied", "invalid_grant", …) → .serverRejected.
    /// - Presentation context failures / 5xx / remaining network-less → .externalProviderUnavailable.
    nonisolated static func classifySignInError(_ error: any Error) -> AuthenticationError {
        if error is CancellationError {
            return .cancelled
        }

        if let asError = error as? ASWebAuthenticationSessionError {
            switch asError.code {
            case .canceledLogin:
                return .cancelled
            case .presentationContextNotProvided, .presentationContextInvalid:
                return .externalProviderUnavailable
            @unknown default:
                return .externalProviderUnavailable
            }
        }

        if let authError = error as? AuthenticationError {
            return authError
        }

        if isNetworkError(error) {
            return .networkUnavailable
        }

        let nsError = error as NSError
        let isHTTPCode = nsError.code >= 400 && nsError.code < 600 &&
            nsError.domain != NSPOSIXErrorDomain &&
            nsError.domain != NSURLErrorDomain &&
            nsError.domain != (kCFErrorDomainCFNetwork as String) &&
            nsError.domain != "kCFErrorDomainCFNetwork"
        let statusCode = (nsError.userInfo["statusCode"] as? Int)
            ?? (nsError.userInfo["status"] as? Int)
            ?? (nsError.userInfo["HTTPStatusCode"] as? Int)
            ?? (isHTTPCode ? nsError.code : nil)

        let description = String(describing: error).lowercased()
        let rejectionKeywords = [
            "invalid_grant",
            "invalid_request",
            "invalid_token",
            "invalid_client",
            "unauthorized_client",
            "unsupported_grant_type",
            "access_denied",
            "unauthorized",
            "forbidden",
            "user_not_found",
            "oauth_error",
            "bad_oauth_callback",
            "server_error",
            "bad_jwt",
            "session_not_found",
            "revoked",
        ]

        for keyword in rejectionKeywords where description.contains(keyword) {
            return .serverRejected
        }

        if let statusCode, statusCode >= 400, statusCode < 500 {
            return .serverRejected
        }

        return .externalProviderUnavailable
    }

    func signIn(provider: AuthenticationProvider) async throws -> AuthenticationSessionMaterial {
        logger.record(.signInStarted, category: .authentication)
        do {
            let material = try await authenticate(provider: provider)
            let identity = AuthenticationIdentityRecord(session: material)
            do {
                try sessionStore.writeIdentity(identity)
                try? sessionStore.deleteLegacyMaterial()
            } catch {
                try? await client.auth.signOut()
                throw AuthenticationError.keychainFailure
            }
            logger.record(.signInSucceeded, category: .authentication)
            return material
        } catch let error as AuthenticationError {
            logSignInOutcome(for: error)
            throw error
        } catch {
            let mapped = Self.classifySignInError(error)
            logSignInOutcome(for: mapped)
            throw mapped
        }
    }

    private func logSignInOutcome(for error: AuthenticationError) {
        switch error {
        case .cancelled:
            // Canceled login produces no log noise.
            break
        case .networkUnavailable:
            logger.record(.signInNetworkUnavailable, category: .authentication)
        case .externalProviderUnavailable:
            logger.record(.signInProviderUnavailable, category: .authentication)
        case .serverRejected:
            logger.record(.signInServerRejected, category: .authentication)
        case .keychainFailure, .invalidState, .invalidNonce, .missingChallenge,
             .unsupportedProvider, .providerCollision, .wrongAccount, .expired, .revoked:
            logger.record(.signInFailedUnclassified, category: .authentication)
        }
    }

    func signOut() async throws {
        try await client.auth.signOut()
        try sessionStore.delete()
        logger.record(.signOutCompleted, category: .authentication)
    }

    func reauthenticateForDeletion() async throws -> ReauthenticatedSession {
        let (storedProvider, storedUserID) = if let stored = try sessionStore.readIdentity() {
            (stored.provider, stored.userID)
        } else if let legacy = try sessionStore.readLegacyMaterial() {
            (legacy.provider, legacy.userID)
        } else {
            throw AuthenticationError.expired
        }

        do {
            let refreshed = try await authenticate(provider: storedProvider)
            guard refreshed.userID == storedUserID,
                  refreshed.provider == storedProvider
            else {
                try? await client.auth.signOut()
                throw AuthenticationError.wrongAccount
            }
            let identity = AuthenticationIdentityRecord(session: refreshed)
            do {
                try sessionStore.writeIdentity(identity)
                try? sessionStore.deleteLegacyMaterial()
            } catch {
                throw AuthenticationError.keychainFailure
            }
            return ReauthenticatedSession(
                session: refreshed,
                proof: RecentReauthentication(
                    userID: refreshed.userID,
                    provider: refreshed.provider,
                    authenticatedAt: Date()
                )
            )
        } catch let error as AuthenticationError {
            throw error
        } catch {
            throw Self.classifySignInError(error)
        }
    }

    private func currentSDKSession() async -> Session? {
        await client.auth.session
    }

    private func authenticate(
        provider: AuthenticationProvider
    ) async throws -> AuthenticationSessionMaterial {
        let session = try await oauthAuthenticator.signInWithOAuth(provider: provider)
        return Self.material(from: session, provider: provider)
    }

    private nonisolated static func material(
        from session: Session,
        provider: AuthenticationProvider
    ) -> AuthenticationSessionMaterial {
        AuthenticationSessionMaterial(
            userID: session.user.id,
            provider: provider,
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            expiresAt: Date(timeIntervalSince1970: TimeInterval(session.expiresAt))
        )
    }
}
