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
            return material
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
    private let clock: any Phase1BClock

    init(
        client: SupabaseClient,
        sessionStore: any SessionSecretStore,
        authRefresher: (any SupabaseAuthRefreshing)? = nil,
        clock: any Phase1BClock = SystemPhase1BClock()
    ) {
        self.client = client
        self.sessionStore = sessionStore
        self.authRefresher = authRefresher ?? DefaultSupabaseAuthRefresher(client: client)
        self.clock = clock
    }

    func restore() async throws -> SessionRestoreResult? {
        guard let stored = try sessionStore.read() else { return nil }
        let now = clock.now()
        if stored.expiresAt > now.addingTimeInterval(60) {
            return .fresh(stored)
        }

        let session: Session
        do {
            session = try await authRefresher.refreshSession(refreshToken: stored.refreshToken)
        } catch {
            let classification = Self.classifyRefreshError(error)
            switch classification {
            case .network, .unclassified:
                return .preservedOffline(stored, classification: classification)
            case .definitiveRejection:
                try? sessionStore.delete()
                throw AuthenticationError.expired
            }
        }

        let material = Self.material(from: session, provider: stored.provider)
        do {
            try sessionStore.write(material)
            return .refreshed(material)
        } catch {
            return .preservedOffline(stored, classification: .unclassified)
        }
    }

    // | Error Pattern / Class                               | Classification       | Action & Rationale                                             |
    // | --------------------------------------------------- | -------------------- | -------------------------------------------------------------- |
    // | URLError / NSURLErrorDomain / CFNetwork / POSIX     | .network             | Preserve stored session; offline or transient network issue.    |
    // | Keywords ("invalid_grant", "session_not_found", …)  | .definitiveRejection | Purge stored session & throw .expired; token invalid/revoked.  |
    // | Bare HTTP 401, 403, 400                             | .definitiveRejection | Purge stored session & throw .expired; auth endpoint rejected. |
    // | Bare HTTP 404, 422, 429, 5xx, decoding / other      | .unclassified        | Preserve stored session (fail-safe); avoid accidental lockouts.|
    nonisolated static func classifyRefreshError(_ error: any Error) -> SessionRefreshErrorClassification {
        if error is URLError {
            return .network
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return .network
        }
        if nsError.domain == (kCFErrorDomainCFNetwork as String) || nsError.domain == "kCFErrorDomainCFNetwork" {
            return .network
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
                return .network
            }
        }

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

        for pattern in definitivePatterns {
            if description.contains(pattern) {
                return .definitiveRejection
            }
        }

        if let statusCode, statusCode == 401 || statusCode == 403 {
            return .definitiveRejection
        }

        if let statusCode, statusCode == 400 {
            return .definitiveRejection
        }

        return .unclassified
    }

    func signIn(provider: AuthenticationProvider) async throws -> AuthenticationSessionMaterial {
        do {
            let material = try await authenticate(provider: provider)
            try sessionStore.write(material)
            return material
        } catch is CancellationError {
            throw AuthenticationError.cancelled
        } catch let error as ASWebAuthenticationSessionError
            where error.code == .canceledLogin
        {
            throw AuthenticationError.cancelled
        } catch {
            throw AuthenticationError.externalProviderUnavailable
        }
    }

    func signOut() async throws {
        try await client.auth.signOut()
        try sessionStore.delete()
    }

    func reauthenticateForDeletion() async throws -> ReauthenticatedSession {
        guard let stored = try sessionStore.read() else {
            throw AuthenticationError.expired
        }
        do {
            let refreshed = try await authenticate(provider: stored.provider)
            guard refreshed.userID == stored.userID,
                  refreshed.provider == stored.provider
            else {
                try? await client.auth.signOut()
                try? sessionStore.write(stored)
                throw AuthenticationError.wrongAccount
            }
            try sessionStore.write(refreshed)
            return ReauthenticatedSession(
                session: refreshed,
                proof: RecentReauthentication(
                    userID: refreshed.userID,
                    provider: refreshed.provider,
                    authenticatedAt: Date()
                )
            )
        } catch is CancellationError {
            throw AuthenticationError.cancelled
        } catch let error as AuthenticationError {
            throw error
        } catch let error as ASWebAuthenticationSessionError
            where error.code == .canceledLogin
        {
            throw AuthenticationError.cancelled
        } catch {
            throw AuthenticationError.externalProviderUnavailable
        }
    }

    private func authenticate(
        provider: AuthenticationProvider
    ) async throws -> AuthenticationSessionMaterial {
        let session: Session = switch provider {
        case .apple:
            try await client.auth.signInWithOAuth(provider: .apple)
        case .google:
            try await client.auth.signInWithOAuth(provider: .google)
        }
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
