import AuthenticationServices
import Foundation
import Supabase

nonisolated protocol OAuthSessionServicing: AccountDeletionSessionSigningOut {
    var isConfigured: Bool { get }
    func restore() async throws -> AuthenticationSessionMaterial?
    func signIn(provider: AuthenticationProvider) async throws -> AuthenticationSessionMaterial
    func reauthenticateForDeletion() async throws -> ReauthenticatedSession
}

actor UnavailableOAuthSessionService: OAuthSessionServicing {
    nonisolated let isConfigured = false

    func restore() async throws -> AuthenticationSessionMaterial? {
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

        func restore() async throws -> AuthenticationSessionMaterial? {
            session()
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

actor SupabaseOAuthSessionService: OAuthSessionServicing {
    nonisolated let isConfigured = true

    private let client: SupabaseClient
    private let sessionStore: any SessionSecretStore

    init(client: SupabaseClient, sessionStore: any SessionSecretStore) {
        self.client = client
        self.sessionStore = sessionStore
    }

    func restore() async throws -> AuthenticationSessionMaterial? {
        guard let stored = try sessionStore.read() else { return nil }
        do {
            let session = try await client.auth.refreshSession(refreshToken: stored.refreshToken)
            let material = Self.material(from: session, provider: stored.provider)
            try sessionStore.write(material)
            return material
        } catch {
            try? sessionStore.delete()
            throw AuthenticationError.expired
        }
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
