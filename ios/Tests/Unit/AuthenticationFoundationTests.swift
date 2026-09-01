import Foundation
@testable import SleepParalysisCompanion
import XCTest

actor ScriptedAuthenticationGateway: AuthenticationGateway {
    enum Behavior {
        case success(AuthenticationSessionMaterial)
        case failure(AuthenticationError)
    }

    private let behavior: Behavior
    private let revokeFailure: AuthenticationError?
    private(set) var refreshCount = 0
    private(set) var revokeCount = 0
    private(set) var signOutCount = 0
    private(set) var revokedProvider: AuthenticationProvider?

    init(
        behavior: Behavior,
        revokeFailure: AuthenticationError? = nil
    ) {
        self.behavior = behavior
        self.revokeFailure = revokeFailure
    }

    func exchange(
        credential: NativeIdentityCredential,
        challenge: OAuthChallenge
    ) async throws -> AuthenticationSessionMaterial {
        _ = credential
        _ = challenge
        switch behavior {
        case let .success(session):
            return session
        case let .failure(error):
            throw error
        }
    }

    func refresh(_ session: AuthenticationSessionMaterial) async throws -> AuthenticationSessionMaterial {
        refreshCount += 1
        var refreshed = session
        refreshed = AuthenticationSessionMaterial(
            userID: session.userID,
            provider: session.provider,
            accessToken: "refreshed-access",
            refreshToken: "refreshed-token",
            expiresAt: session.expiresAt.addingTimeInterval(3600)
        )
        return refreshed
    }

    func revokeProviderGrant(_ request: ProviderGrantRevocationRequest) async throws {
        revokeCount += 1
        revokedProvider = request.provider
        if let revokeFailure {
            throw revokeFailure
        }
    }

    func signOut(_ session: AuthenticationSessionMaterial) async throws {
        _ = session
        signOutCount += 1
    }
}

final class AuthenticationFoundationTests: XCTestCase {
    func testOnlyAppleAndGoogleProvidersAreAccepted() throws {
        XCTAssertEqual(try AuthenticationProviderPolicy.parse("apple"), .apple)
        XCTAssertEqual(try AuthenticationProviderPolicy.parse("google"), .google)
        for excluded in ["email", "password", "phone", "sms", "otp", "anonymous"] {
            XCTAssertThrowsError(try AuthenticationProviderPolicy.parse(excluded)) { error in
                XCTAssertEqual(error as? AuthenticationError, .unsupportedProvider)
            }
        }
    }

    func testChallengeCreatesStateNonceAndPKCEProofs() throws {
        let factory = OAuthChallengeFactory(random: FixedSecureRandom(byte: 7))
        let challenge = try factory.make(for: .apple)

        XCTAssertFalse(challenge.state.isEmpty)
        XCTAssertFalse(challenge.rawNonce.isEmpty)
        XCTAssertEqual(challenge.hashedNonce.count, 64)
        XCTAssertFalse(challenge.codeVerifier.isEmpty)
        XCTAssertFalse(challenge.codeChallenge.isEmpty)
        XCTAssertNotEqual(challenge.rawNonce, challenge.hashedNonce)
    }

    func testCallbackValidatesStateAndNonceBeforeExchange() async throws {
        let gateway = ScriptedAuthenticationGateway(behavior: .success(Phase1BFixture.session()))
        let coordinator = makeCoordinator(gateway: gateway)
        let challenge = try await coordinator.begin(provider: .apple)

        await XCTAssertThrowsErrorAsync {
            _ = try await coordinator.complete(
                credential: NativeIdentityCredential(
                    provider: .apple,
                    idToken: "synthetic",
                    returnedState: "wrong",
                    rawNonce: challenge.rawNonce
                ),
                expectedFormerUserID: nil
            )
        }
        await XCTAssertThrowsErrorAsync {
            _ = try await coordinator.complete(
                credential: NativeIdentityCredential(
                    provider: .apple,
                    idToken: "synthetic",
                    returnedState: challenge.state,
                    rawNonce: "wrong"
                ),
                expectedFormerUserID: nil
            )
        }
    }

    func testSuccessfulCallbackPersistsSessionOnlyInSecretStore() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        let gateway = ScriptedAuthenticationGateway(behavior: .success(Phase1BFixture.session()))
        let coordinator = AuthenticationCoordinator(
            challengeFactory: OAuthChallengeFactory(random: FixedSecureRandom(byte: 3)),
            gateway: gateway,
            sessionStore: store
        )
        let challenge = try await coordinator.begin(provider: .apple)
        let session = try await coordinator.complete(
            credential: NativeIdentityCredential(
                provider: .apple,
                idToken: "synthetic",
                returnedState: challenge.state,
                rawNonce: challenge.rawNonce
            ),
            expectedFormerUserID: nil
        )

        XCTAssertEqual(session, Phase1BFixture.session())
        let storedIdentity = try store.readIdentity()
        XCTAssertEqual(storedIdentity?.userID, session.userID)
        XCTAssertEqual(storedIdentity?.provider, session.provider)
    }

    func testWrongFormerAccountIsRejectedWithoutSessionPersistence() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        let gateway = ScriptedAuthenticationGateway(behavior: .success(Phase1BFixture.session()))
        let coordinator = AuthenticationCoordinator(
            challengeFactory: OAuthChallengeFactory(random: FixedSecureRandom(byte: 4)),
            gateway: gateway,
            sessionStore: store
        )
        let challenge = try await coordinator.begin(provider: .apple)

        await XCTAssertThrowsErrorAsync {
            _ = try await coordinator.complete(
                credential: NativeIdentityCredential(
                    provider: .apple,
                    idToken: "synthetic",
                    returnedState: challenge.state,
                    rawNonce: challenge.rawNonce
                ),
                expectedFormerUserID: Phase1BFixture.profileID
            )
        }
        XCTAssertNil(try store.readIdentity())
        let signOutCount = await gateway.signOutCount
        XCTAssertEqual(signOutCount, 1)
    }

    func testProviderCollisionIsSurfaced() async throws {
        let gateway = ScriptedAuthenticationGateway(behavior: .failure(.providerCollision))
        let coordinator = makeCoordinator(gateway: gateway)
        let challenge = try await coordinator.begin(provider: .google)

        await XCTAssertThrowsErrorAsync {
            _ = try await coordinator.complete(
                credential: NativeIdentityCredential(
                    provider: .google,
                    idToken: "synthetic",
                    returnedState: challenge.state,
                    rawNonce: challenge.rawNonce
                ),
                expectedFormerUserID: nil
            )
        }
    }

    func testKeychainWriteFailureSignsRemoteSessionOut() async throws {
        let gateway = ScriptedAuthenticationGateway(behavior: .success(Phase1BFixture.session()))
        let coordinator = AuthenticationCoordinator(
            challengeFactory: OAuthChallengeFactory(random: FixedSecureRandom(byte: 5)),
            gateway: gateway,
            sessionStore: KeychainSessionStore(
                keychain: LockedKeychain(failure: .keychainFailure)
            )
        )
        let challenge = try await coordinator.begin(provider: .apple)

        await XCTAssertThrowsErrorAsync {
            _ = try await coordinator.complete(
                credential: NativeIdentityCredential(
                    provider: .apple,
                    idToken: "synthetic",
                    returnedState: challenge.state,
                    rawNonce: challenge.rawNonce
                ),
                expectedFormerUserID: nil
            )
        }
        let signOutCount = await gateway.signOutCount
        XCTAssertEqual(signOutCount, 1)
    }

    func testRefreshUsesStoredRefreshTokenOnlyWhenExpiring() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        let expiring = AuthenticationIdentityRecord(
            userID: Phase1BFixture.userID,
            provider: .apple,
            expiresAt: Phase1BFixture.now.addingTimeInterval(10)
        )
        try store.writeIdentity(expiring)
        let gateway = ScriptedAuthenticationGateway(behavior: .success(Phase1BFixture.session()))
        let coordinator = AuthenticationCoordinator(
            challengeFactory: OAuthChallengeFactory(random: FixedSecureRandom(byte: 1)),
            gateway: gateway,
            sessionStore: store
        )

        let refreshed = try await coordinator.refresh(now: Phase1BFixture.now)
        let refreshCount = await gateway.refreshCount
        XCTAssertEqual(refreshed.accessToken, "refreshed-access")
        XCTAssertEqual(refreshCount, 1)
    }

    func testSignOutUsesProviderCredentialAndSeparatelyCleansSupabaseSession() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        try store.writeIdentity(AuthenticationIdentityRecord(session: Phase1BFixture.session()))
        let gateway = ScriptedAuthenticationGateway(behavior: .success(Phase1BFixture.session()))
        let coordinator = AuthenticationCoordinator(
            challengeFactory: OAuthChallengeFactory(random: FixedSecureRandom(byte: 2)),
            gateway: gateway,
            sessionStore: store
        )

        let result = try await coordinator.signOut(
            providerRevocationCredential: .appleAuthorizationCode("ephemeral-proof")
        )
        let revokeCount = await gateway.revokeCount
        let signOutCount = await gateway.signOutCount
        let revokedProvider = await gateway.revokedProvider
        XCTAssertNil(try store.readIdentity())
        XCTAssertEqual(revokeCount, 1)
        XCTAssertEqual(signOutCount, 1)
        XCTAssertEqual(revokedProvider, .apple)
        XCTAssertEqual(result, .signedOut)
    }

    func testSignOutWithoutProviderCredentialSkipsRevocationAndStillSignsOut() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        try store.writeIdentity(AuthenticationIdentityRecord(session: Phase1BFixture.session()))
        let gateway = ScriptedAuthenticationGateway(behavior: .success(Phase1BFixture.session()))
        let coordinator = AuthenticationCoordinator(
            challengeFactory: OAuthChallengeFactory(random: FixedSecureRandom(byte: 2)),
            gateway: gateway,
            sessionStore: store
        )

        let result = try await coordinator.signOut(providerRevocationCredential: nil)

        XCTAssertEqual(result, .signedOut)
        XCTAssertNil(try store.readIdentity())
        let revokeCount = await gateway.revokeCount
        let signOutCount = await gateway.signOutCount
        XCTAssertEqual(revokeCount, 0)
        XCTAssertEqual(signOutCount, 1)
    }

    func testProviderRevocationFailureStillSignsOutAndPreservesGuestUsability() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        try store.writeIdentity(AuthenticationIdentityRecord(session: Phase1BFixture.session()))
        let gateway = ScriptedAuthenticationGateway(
            behavior: .success(Phase1BFixture.session()),
            revokeFailure: .externalProviderUnavailable
        )
        let coordinator = AuthenticationCoordinator(
            challengeFactory: OAuthChallengeFactory(random: FixedSecureRandom(byte: 2)),
            gateway: gateway,
            sessionStore: store
        )

        let result = try await coordinator.signOut(
            providerRevocationCredential: .appleAuthorizationCode("ephemeral-proof")
        )

        XCTAssertEqual(result, .signedOutProviderGrantNotRevoked)
        XCTAssertNil(try store.readIdentity())
        let revokeCount = await gateway.revokeCount
        let signOutCount = await gateway.signOutCount
        XCTAssertEqual(revokeCount, 1)
        XCTAssertEqual(signOutCount, 1)
    }

    func testProviderCredentialMustMatchSignedInProvider() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        let identity = AuthenticationIdentityRecord(session: Phase1BFixture.session())
        try store.writeIdentity(identity)
        let gateway = ScriptedAuthenticationGateway(behavior: .success(Phase1BFixture.session()))
        let coordinator = AuthenticationCoordinator(
            challengeFactory: OAuthChallengeFactory(random: FixedSecureRandom(byte: 2)),
            gateway: gateway,
            sessionStore: store
        )

        await XCTAssertThrowsErrorAsync {
            _ = try await coordinator.signOut(
                providerRevocationCredential: .googleOAuthAccessToken("ephemeral-proof")
            )
        }
        XCTAssertEqual(try store.readIdentity(), identity)
        let revokeCount = await gateway.revokeCount
        let signOutCount = await gateway.signOutCount
        XCTAssertEqual(revokeCount, 0)
        XCTAssertEqual(signOutCount, 0)
    }

    func testRecentReauthenticationRequiresMatchingAccountAndProvider() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        try store.writeIdentity(AuthenticationIdentityRecord(session: Phase1BFixture.session()))
        let gateway = ScriptedAuthenticationGateway(behavior: .success(Phase1BFixture.session()))
        let coordinator = AuthenticationCoordinator(
            challengeFactory: OAuthChallengeFactory(random: FixedSecureRandom(byte: 6)),
            gateway: gateway,
            sessionStore: store
        )
        let challenge = try await coordinator.begin(provider: .apple)
        let result = try await coordinator.reauthenticate(
            credential: NativeIdentityCredential(
                provider: .apple,
                idToken: "ephemeral-proof",
                returnedState: challenge.state,
                rawNonce: challenge.rawNonce
            ),
            currentSession: Phase1BFixture.session(),
            authenticatedAt: Phase1BFixture.now
        )

        XCTAssertEqual(result.session.userID, Phase1BFixture.userID)
        XCTAssertEqual(result.proof.userID, Phase1BFixture.userID)
        XCTAssertEqual(result.proof.provider, .apple)
        XCTAssertTrue(result.proof.isValid(now: Phase1BFixture.now))
    }

    func testWrongAccountReauthenticationStopsWithoutReplacingStoredSession() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        let identity = AuthenticationIdentityRecord(session: Phase1BFixture.session())
        try store.writeIdentity(identity)
        let different = Phase1BFixture.session(
            userID: Phase1BFixture.uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        )
        let gateway = ScriptedAuthenticationGateway(behavior: .success(different))
        let coordinator = AuthenticationCoordinator(
            challengeFactory: OAuthChallengeFactory(random: FixedSecureRandom(byte: 6)),
            gateway: gateway,
            sessionStore: store
        )
        let challenge = try await coordinator.begin(provider: .apple)

        await XCTAssertThrowsErrorAsync {
            _ = try await coordinator.reauthenticate(
                credential: NativeIdentityCredential(
                    provider: .apple,
                    idToken: "ephemeral-proof",
                    returnedState: challenge.state,
                    rawNonce: challenge.rawNonce
                ),
                currentSession: Phase1BFixture.session(),
                authenticatedAt: Phase1BFixture.now
            )
        }

        XCTAssertEqual(try store.readIdentity(), identity)
        let signOutCount = await gateway.signOutCount
        XCTAssertEqual(signOutCount, 1)
    }

    func testCancellationClearsPendingChallenge() async throws {
        let gateway = ScriptedAuthenticationGateway(behavior: .success(Phase1BFixture.session()))
        let coordinator = makeCoordinator(gateway: gateway)
        let challenge = try await coordinator.begin(provider: .apple)
        await coordinator.cancel()

        await XCTAssertThrowsErrorAsync {
            _ = try await coordinator.complete(
                credential: NativeIdentityCredential(
                    provider: .apple,
                    idToken: "synthetic",
                    returnedState: challenge.state,
                    rawNonce: challenge.rawNonce
                ),
                expectedFormerUserID: nil
            )
        }
    }

    func testKeychainSessionStoreIdentityRecordRoundTrip() throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        let identity = AuthenticationIdentityRecord(
            userID: Phase1BFixture.userID,
            provider: .apple,
            expiresAt: Phase1BFixture.now
        )

        XCTAssertNil(try store.readIdentity())
        try store.writeIdentity(identity)

        let rawData = try keychain.read(
            service: SessionKeychainIdentity.service,
            account: SessionKeychainIdentity.identityAccount
        )
        let rawDataUnwrapped = try XCTUnwrap(rawData)
        let rawString = String(decoding: rawDataUnwrapped, as: UTF8.self)

        // Verify tokens are absent from stored identity bytes.
        XCTAssertFalse(rawString.contains("accessToken"))
        XCTAssertFalse(rawString.contains("refreshToken"))
        XCTAssertTrue(rawString.contains("userID"))
        XCTAssertTrue(rawString.contains("provider"))

        XCTAssertEqual(try store.readIdentity(), identity)

        try store.delete()
        XCTAssertNil(try store.readIdentity())
        XCTAssertNil(
            try keychain.read(
                service: SessionKeychainIdentity.service,
                account: SessionKeychainIdentity.identityAccount
            )
        )
    }

    func testSupabaseKeychainLocalStorageRoundTrip() throws {
        let keychain = LockedKeychain()
        let storage = SupabaseKeychainLocalStorage(
            keychain: keychain,
            service: SupabaseKeychainLocalStorage.service(projectRef: "nfzvlvukbeapcnlmyecf")
        )

        XCTAssertNil(try storage.retrieve(key: "supabase.auth.token"))

        let sampleData = Data("sample-session-token-bytes".utf8)
        try storage.store(key: "supabase.auth.token", value: sampleData)

        let retrieved = try storage.retrieve(key: "supabase.auth.token")
        XCTAssertEqual(retrieved, sampleData)

        try storage.remove(key: "supabase.auth.token")
        XCTAssertNil(try storage.retrieve(key: "supabase.auth.token"))

        // Removing non-existent key is idempotent
        XCTAssertNoThrow(try storage.remove(key: "supabase.auth.token"))
    }

    func testSupabaseKeychainLocalStorageServiceNaming() {
        let service = SupabaseKeychainLocalStorage.service(
            bundleIdentifier: "app.sleepcompanion.spc",
            projectRef: "proj123"
        )
        XCTAssertEqual(service, "app.sleepcompanion.spc.supabase.auth.proj123")
    }

    func testKeychainSessionStoreLegacyMigrationCleanup() throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        let legacy = Phase1BFixture.session()

        // Manually write legacy format to legacy account
        let legacyData = try JSONEncoder().encode(legacy)
        try keychain.write(
            legacyData,
            service: SessionKeychainIdentity.service,
            account: SessionKeychainIdentity.legacyAccount
        )

        XCTAssertEqual(try store.readLegacyMaterial(), legacy)
        XCTAssertNil(try store.readIdentity())

        try store.deleteLegacyMaterial()
        XCTAssertNil(try store.readLegacyMaterial())
    }

    private func makeCoordinator(
        gateway: ScriptedAuthenticationGateway
    ) -> AuthenticationCoordinator {
        AuthenticationCoordinator(
            challengeFactory: OAuthChallengeFactory(random: FixedSecureRandom(byte: 9)),
            gateway: gateway,
            sessionStore: KeychainSessionStore(keychain: LockedKeychain())
        )
    }
}
