import Foundation
import Supabase

nonisolated protocol ProviderGrantRevoking: Sendable {
    func revoke(provider: AuthenticationProvider, accessToken: String) async throws
}

actor SupabaseAuthenticationGateway: AuthenticationGateway {
    private let client: SupabaseClient
    private let providerRevoker: any ProviderGrantRevoking

    init(client: SupabaseClient, providerRevoker: any ProviderGrantRevoking) {
        self.client = client
        self.providerRevoker = providerRevoker
    }

    func exchange(
        credential: NativeIdentityCredential,
        challenge: OAuthChallenge
    ) async throws -> AuthenticationSessionMaterial {
        let provider: OpenIDConnectCredentials.Provider = switch credential.provider {
        case .apple:
            .apple
        case .google:
            .google
        }
        let session = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: provider,
                idToken: credential.idToken,
                nonce: challenge.rawNonce
            )
        )
        return material(from: session, provider: credential.provider)
    }

    func refresh(_ session: AuthenticationSessionMaterial) async throws -> AuthenticationSessionMaterial {
        let refreshed = try await client.auth.refreshSession(refreshToken: session.refreshToken)
        guard refreshed.user.id == session.userID else {
            throw AuthenticationError.wrongAccount
        }
        return material(from: refreshed, provider: session.provider)
    }

    func revoke(_ session: AuthenticationSessionMaterial) async throws {
        try await providerRevoker.revoke(provider: session.provider, accessToken: session.accessToken)
    }

    func signOut(_ session: AuthenticationSessionMaterial) async throws {
        _ = session
        try await client.auth.signOut()
    }

    private func material(
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
