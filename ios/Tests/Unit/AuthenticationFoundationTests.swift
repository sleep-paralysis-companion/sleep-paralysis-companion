import Foundation
@testable import SleepParalysisCompanion
import XCTest

actor ScriptedAuthenticationGateway: AuthenticationGateway {
    enum Behavior {
        case success(AuthenticationSessionMaterial)
        case failure(AuthenticationError)
    }

    private let behavior: Behavior
    private(set) var refreshCount = 0
    private(set) var revokeCount = 0
    private(set) var signOutCount = 0

    init(behavior: Behavior) {
        self.behavior = behavior
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

    func revoke(_ session: AuthenticationSessionMaterial) async throws {
        _ = session
        revokeCount += 1
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
        XCTAssertEqual(try store.read(), session)
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
        XCTAssertNil(try store.read())
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
        var expiring = Phase1BFixture.session()
        expiring = AuthenticationSessionMaterial(
            userID: expiring.userID,
            provider: expiring.provider,
            accessToken: expiring.accessToken,
            refreshToken: expiring.refreshToken,
            expiresAt: Phase1BFixture.now.addingTimeInterval(10)
        )
        try store.write(expiring)
        let gateway = ScriptedAuthenticationGateway(behavior: .success(expiring))
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

    func testSignOutRevokesAndCleansSession() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        try store.write(Phase1BFixture.session())
        let gateway = ScriptedAuthenticationGateway(behavior: .success(Phase1BFixture.session()))
        let coordinator = AuthenticationCoordinator(
            challengeFactory: OAuthChallengeFactory(random: FixedSecureRandom(byte: 2)),
            gateway: gateway,
            sessionStore: store
        )

        try await coordinator.signOut(revokeProvider: true)
        let revokeCount = await gateway.revokeCount
        let signOutCount = await gateway.signOutCount
        XCTAssertNil(try store.read())
        XCTAssertEqual(revokeCount, 1)
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
