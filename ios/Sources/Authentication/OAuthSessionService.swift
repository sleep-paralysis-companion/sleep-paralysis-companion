import AuthenticationServices
import Foundation
import Supabase

nonisolated protocol OAuthSessionServicing: Sendable {
    var isConfigured: Bool { get }
    func restore() async throws -> AuthenticationSessionMaterial?
    func signIn(provider: AuthenticationProvider) async throws -> AuthenticationSessionMaterial
    func signOut() async throws
    func deleteRemoteAccount() async throws
}

actor UnavailableOAuthSessionService: OAuthSessionServicing {
    nonisolated let isConfigured = false

    func restore() async throws -> AuthenticationSessionMaterial? { nil }
    func signIn(provider: AuthenticationProvider) async throws -> AuthenticationSessionMaterial {
        _ = provider
        throw Phase1ActionError.configurationRequired
    }
    func signOut() async throws {}
    func deleteRemoteAccount() async throws {
        throw Phase1ActionError.configurationRequired
    }
}

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
            let session: Session = switch provider {
            case .apple:
                try await client.auth.signInWithOAuth(provider: .apple)
            case .google:
                try await client.auth.signInWithOAuth(provider: .google)
            }
            let material = Self.material(from: session, provider: provider)
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

    func deleteRemoteAccount() async throws {
        guard let stored = try sessionStore.read() else {
            throw AuthenticationError.expired
        }
        let refreshed = try await signIn(provider: stored.provider)
        guard refreshed.userID == stored.userID else {
            try? await client.auth.signOut()
            throw AuthenticationError.wrongAccount
        }
        let gateway = SupabaseAccountDeletionGateway(client: client)
        try await gateway.deleteAccount(
            requestID: UUID(),
            accessToken: refreshed.accessToken,
            retryToken: nil
        )
        try sessionStore.delete()
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
