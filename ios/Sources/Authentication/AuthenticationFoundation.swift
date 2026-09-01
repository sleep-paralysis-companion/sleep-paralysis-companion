import CryptoKit
import Foundation
import Security

/// # Authentication Foundation (Stack A — Native ID-Token & Deletion Foundation)
///
/// This file defines the core types, models, cryptographic challenge generation, and coordinator
/// for the Phase 1B hand-hardened native identity stack and data-rights foundation.
///
/// ## Architecture & Invariant Ownership
/// - **Challenge & Proofs**: `OAuthChallengeFactory` generates cryptographically secure state,
///   raw/hashed nonces, and PKCE verifiers (`OAuthChallenge`).
/// - **Native Credential Exchange**: `AuthenticationCoordinator` coordinates native OpenID Connect
///   ID-token exchanges (`signInWithIdToken`), validating client-side challenge state and raw nonces
///   before invoking `AuthenticationGateway`.
/// - **Account Guard**: `AuthenticationCoordinator.complete` and `reauthenticate` enforce
///   `expectedFormerUserID` checks to reject account mismatches and prevent cross-account profile linkage.
/// - **Storage Post-S4**: At rest, only `AuthenticationIdentityRecord` (non-secret: `userID`, `provider`,
///   `expiresAt`) is persisted in `SessionSecretStore` (`KeychainSessionStore`). Secret tokens exist only
///   in the SDK-managed Keychain bridge (`SupabaseKeychainLocalStorage`).
/// - **Live Consumers**: Consumed by `SignOutCoordinator` (`DeletionFoundation.swift`) and verified via
///   `AuthenticationFoundationTests` and `DataRightsFoundationTests`. Interactive Web OAuth sign-in in the
///   app shell delegates to Stack B (`SupabaseOAuthSessionService`).
///
/// See `docs/PHASE_SIGN_IN_FLOW.md` for the authoritative architectural narrative.
nonisolated enum SessionKeychainIdentity {
    static let service = "app.sleepcompanion.spc.authentication"
    static let account = "supabase-identity"
    static let identityAccount = "supabase-identity"
    static let legacyAccount = "supabase-session"
}

nonisolated struct AuthenticationIdentityRecord: Equatable, Codable, Sendable {
    let userID: UUID
    let provider: AuthenticationProvider
    let expiresAt: Date

    init(
        userID: UUID,
        provider: AuthenticationProvider,
        expiresAt: Date
    ) {
        self.userID = userID
        self.provider = provider
        self.expiresAt = expiresAt
    }

    init(session: AuthenticationSessionMaterial) {
        self.init(
            userID: session.userID,
            provider: session.provider,
            expiresAt: session.expiresAt
        )
    }
}

nonisolated struct AuthenticationSessionMaterial: Equatable, Codable, Sendable {
    let userID: UUID
    let provider: AuthenticationProvider
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
}

nonisolated struct OAuthChallenge: Equatable, Sendable {
    let provider: AuthenticationProvider
    let state: String
    let rawNonce: String
    let hashedNonce: String
    let codeVerifier: String
    let codeChallenge: String
}

nonisolated struct NativeIdentityCredential: Equatable, Sendable {
    let provider: AuthenticationProvider
    let idToken: String
    let returnedState: String
    let rawNonce: String
}

nonisolated enum ProviderGrantCredential: Sendable {
    case appleAuthorizationCode(String)
    case googleOAuthAccessToken(String)

    var provider: AuthenticationProvider {
        switch self {
        case .appleAuthorizationCode:
            .apple
        case .googleOAuthAccessToken:
            .google
        }
    }
}

nonisolated struct ProviderGrantRevocationRequest: Sendable {
    let userID: UUID
    let provider: AuthenticationProvider
    let credential: ProviderGrantCredential
}

nonisolated struct RecentReauthentication: Equatable, Sendable {
    let userID: UUID
    let provider: AuthenticationProvider
    let authenticatedAt: Date

    func isValid(now: Date, maximumAge: TimeInterval = 5 * 60) -> Bool {
        authenticatedAt <= now && now.timeIntervalSince(authenticatedAt) <= maximumAge
    }
}

nonisolated struct ReauthenticatedSession: Equatable, Sendable {
    let session: AuthenticationSessionMaterial
    let proof: RecentReauthentication
}

nonisolated enum SignOutAuthenticationResult: Equatable, Sendable {
    case signedOut
    case signedOutProviderGrantNotRevoked
}

nonisolated enum AuthenticationError: Error, Equatable, Sendable {
    case cancelled
    case invalidState
    case invalidNonce
    case missingChallenge
    case unsupportedProvider
    case providerCollision
    case wrongAccount
    case expired
    case revoked
    case keychainFailure
    case externalProviderUnavailable
    case networkUnavailable
    case serverRejected
}

nonisolated enum AuthenticationProviderPolicy {
    static func parse(_ value: String) throws -> AuthenticationProvider {
        guard let provider = AuthenticationProvider(rawValue: value) else {
            throw AuthenticationError.unsupportedProvider
        }
        return provider
    }
}

nonisolated protocol SecureRandomBytes: Sendable {
    func bytes(count: Int) throws -> [UInt8]
}

nonisolated struct SystemSecureRandomBytes: SecureRandomBytes {
    func bytes(count: Int) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: count)
        guard SecRandomCopyBytes(kSecRandomDefault, count, &bytes) == errSecSuccess else {
            throw AuthenticationError.externalProviderUnavailable
        }
        return bytes
    }
}

nonisolated struct OAuthChallengeFactory: Sendable {
    private let random: any SecureRandomBytes

    init(random: any SecureRandomBytes) {
        self.random = random
    }

    func make(for provider: AuthenticationProvider) throws -> OAuthChallenge {
        let state = try base64URL(random.bytes(count: 32))
        let nonce = try base64URL(random.bytes(count: 32))
        let verifier = try base64URL(random.bytes(count: 48))
        return OAuthChallenge(
            provider: provider,
            state: state,
            rawNonce: nonce,
            hashedNonce: sha256Hex(nonce),
            codeVerifier: verifier,
            codeChallenge: sha256Base64URL(verifier)
        )
    }

    private func sha256Hex(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func sha256Base64URL(_ value: String) -> String {
        base64URL(Array(SHA256.hash(data: Data(value.utf8))))
    }

    private func base64URL(_ bytes: [UInt8]) -> String {
        Data(bytes)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

nonisolated protocol AuthenticationGateway: Sendable {
    func exchange(
        credential: NativeIdentityCredential,
        challenge: OAuthChallenge
    ) async throws -> AuthenticationSessionMaterial
    func refresh(_ session: AuthenticationSessionMaterial) async throws -> AuthenticationSessionMaterial
    func revokeProviderGrant(_ request: ProviderGrantRevocationRequest) async throws
    func signOut(_ session: AuthenticationSessionMaterial) async throws
}

nonisolated protocol SessionSecretStore: Sendable {
    func readIdentity() throws -> AuthenticationIdentityRecord?
    func writeIdentity(_ identity: AuthenticationIdentityRecord) throws
    func readLegacyMaterial() throws -> AuthenticationSessionMaterial?
    func deleteLegacyMaterial() throws
    func delete() throws
}

actor AuthenticationCoordinator {
    private let challengeFactory: OAuthChallengeFactory
    private let gateway: any AuthenticationGateway
    private let sessionStore: any SessionSecretStore
    private var pendingChallenge: OAuthChallenge?

    init(
        challengeFactory: OAuthChallengeFactory,
        gateway: any AuthenticationGateway,
        sessionStore: any SessionSecretStore
    ) {
        self.challengeFactory = challengeFactory
        self.gateway = gateway
        self.sessionStore = sessionStore
    }

    func begin(provider: AuthenticationProvider) throws -> OAuthChallenge {
        let challenge = try challengeFactory.make(for: provider)
        pendingChallenge = challenge
        return challenge
    }

    func cancel() {
        pendingChallenge = nil
    }

    func complete(
        credential: NativeIdentityCredential,
        expectedFormerUserID: UUID?
    ) async throws -> AuthenticationSessionMaterial {
        guard let challenge = pendingChallenge else {
            throw AuthenticationError.missingChallenge
        }
        guard challenge.provider == credential.provider,
              challenge.state == credential.returnedState
        else {
            throw AuthenticationError.invalidState
        }
        guard challenge.rawNonce == credential.rawNonce else {
            throw AuthenticationError.invalidNonce
        }
        try Task.checkCancellation()
        let session = try await gateway.exchange(credential: credential, challenge: challenge)
        try Task.checkCancellation()
        if let expectedFormerUserID, expectedFormerUserID != session.userID {
            try? await gateway.signOut(session)
            throw AuthenticationError.wrongAccount
        }
        do {
            try sessionStore.writeIdentity(AuthenticationIdentityRecord(session: session))
        } catch {
            try? await gateway.signOut(session)
            throw AuthenticationError.keychainFailure
        }
        pendingChallenge = nil
        return session
    }

    func refresh(now: Date) async throws -> AuthenticationSessionMaterial {
        guard let stored = try sessionStore.readIdentity() else {
            throw AuthenticationError.expired
        }
        try Task.checkCancellation()
        if stored.expiresAt > now.addingTimeInterval(60) {
            return AuthenticationSessionMaterial(
                userID: stored.userID,
                provider: stored.provider,
                accessToken: "",
                refreshToken: "",
                expiresAt: stored.expiresAt
            )
        }
        let material = AuthenticationSessionMaterial(
            userID: stored.userID,
            provider: stored.provider,
            accessToken: "",
            refreshToken: "",
            expiresAt: stored.expiresAt
        )
        let refreshed = try await gateway.refresh(material)
        try sessionStore.writeIdentity(AuthenticationIdentityRecord(session: refreshed))
        return refreshed
    }

    func reauthenticate(
        credential: NativeIdentityCredential,
        currentSession: AuthenticationSessionMaterial,
        authenticatedAt: Date
    ) async throws -> ReauthenticatedSession {
        guard let challenge = pendingChallenge else {
            throw AuthenticationError.missingChallenge
        }
        guard challenge.provider == credential.provider,
              challenge.provider == currentSession.provider,
              challenge.state == credential.returnedState
        else {
            throw AuthenticationError.invalidState
        }
        guard challenge.rawNonce == credential.rawNonce else {
            throw AuthenticationError.invalidNonce
        }

        try Task.checkCancellation()
        let refreshed = try await gateway.exchange(
            credential: credential,
            challenge: challenge
        )
        try Task.checkCancellation()
        guard refreshed.userID == currentSession.userID,
              refreshed.provider == currentSession.provider
        else {
            try? await gateway.signOut(refreshed)
            throw AuthenticationError.wrongAccount
        }
        do {
            try sessionStore.writeIdentity(AuthenticationIdentityRecord(session: refreshed))
        } catch {
            try? await gateway.signOut(refreshed)
            throw AuthenticationError.keychainFailure
        }
        pendingChallenge = nil
        return ReauthenticatedSession(
            session: refreshed,
            proof: RecentReauthentication(
                userID: refreshed.userID,
                provider: refreshed.provider,
                authenticatedAt: authenticatedAt
            )
        )
    }

    func signOut(
        providerRevocationCredential: ProviderGrantCredential?
    ) async throws -> SignOutAuthenticationResult {
        let identity = try sessionStore.readIdentity()
        var providerRevocationFailed = false
        if let identity {
            if let providerRevocationCredential {
                guard providerRevocationCredential.provider == identity.provider else {
                    throw AuthenticationError.providerCollision
                }
                do {
                    try await gateway.revokeProviderGrant(
                        ProviderGrantRevocationRequest(
                            userID: identity.userID,
                            provider: identity.provider,
                            credential: providerRevocationCredential
                        )
                    )
                } catch {
                    providerRevocationFailed = true
                }
            }
            let material = AuthenticationSessionMaterial(
                userID: identity.userID,
                provider: identity.provider,
                accessToken: "",
                refreshToken: "",
                expiresAt: identity.expiresAt
            )
            try await gateway.signOut(material)
        }
        do {
            try sessionStore.delete()
        } catch {
            throw AuthenticationError.keychainFailure
        }
        return providerRevocationFailed ? .signedOutProviderGrantNotRevoked : .signedOut
    }
}
