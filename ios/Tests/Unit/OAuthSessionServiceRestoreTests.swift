import Foundation
@testable import SleepParalysisCompanion
import Supabase
import XCTest

actor ScriptedSupabaseAuthRefresher: SupabaseAuthRefreshing {
    enum Behavior {
        case success(Session)
        case failure(any Error)
    }

    private var behavior: Behavior
    private(set) var refreshCallCount = 0
    private(set) var lastRefreshTokenPassed: String?

    init(behavior: Behavior) {
        self.behavior = behavior
    }

    func setBehavior(_ behavior: Behavior) {
        self.behavior = behavior
    }

    func refreshSession(refreshToken: String) async throws -> Session {
        refreshCallCount += 1
        lastRefreshTokenPassed = refreshToken
        switch behavior {
        case let .success(session):
            return session
        case let .failure(error):
            throw error
        }
    }
}

final class OAuthSessionServiceRestoreTests: XCTestCase {
    private let fixedNow = Date(timeIntervalSince1970: 1_753_660_800)
    private let testUserID = UUID(
        uuid: (0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x42, 0x22, 0x82, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22)
    ) // 22222222-2222-4222-8222-222222222222

    private func makeClient() -> SupabaseClient {
        SupabaseClient(
            supabaseURL: URL(string: "https://example.supabase.co")!,
            supabaseKey: "test-anon-key"
        )
    }

    private func makeSyntheticSession(
        userID: UUID,
        accessToken: String = "synthetic-refreshed-access",
        refreshToken: String = "synthetic-refreshed-refresh",
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

    func testNoStoredSessionReturnsNil() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        let refresher = ScriptedSupabaseAuthRefresher(
            behavior: .failure(URLError(.notConnectedToInternet))
        )
        let service = SupabaseOAuthSessionService(
            client: makeClient(),
            sessionStore: store,
            authRefresher: refresher,
            clock: FixedClock(value: fixedNow)
        )

        let result = try await service.restore()
        XCTAssertNil(result)
        let callCount = await refresher.refreshCallCount
        XCTAssertEqual(callCount, 0)
    }

    func testFreshSessionRestoresWithoutNetworkOrKeychainModification() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        let freshSession = AuthenticationSessionMaterial(
            userID: testUserID,
            provider: .apple,
            accessToken: "stored-access",
            refreshToken: "stored-refresh",
            expiresAt: fixedNow.addingTimeInterval(3600) // > now + 60s
        )
        try store.write(freshSession)

        let refresher = ScriptedSupabaseAuthRefresher(
            behavior: .failure(URLError(.notConnectedToInternet))
        )
        let service = SupabaseOAuthSessionService(
            client: makeClient(),
            sessionStore: store,
            authRefresher: refresher,
            clock: FixedClock(value: fixedNow)
        )

        let result = try await service.restore()
        XCTAssertEqual(result, .fresh(freshSession))
        XCTAssertEqual(result?.session, freshSession)
        let callCount = await refresher.refreshCallCount
        XCTAssertEqual(callCount, 0)
        XCTAssertEqual(try store.read(), freshSession)
    }

    func testStaleSessionSuccessfulRefreshWritesBackAndReturnsUpdatedMaterial() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        let staleSession = AuthenticationSessionMaterial(
            userID: testUserID,
            provider: .google,
            accessToken: "old-access",
            refreshToken: "old-refresh",
            expiresAt: fixedNow.addingTimeInterval(30) // <= now + 60s
        )
        try store.write(staleSession)

        let updatedExpiry = fixedNow.addingTimeInterval(7200)
        let refreshedSDKSession = try makeSyntheticSession(
            userID: testUserID,
            accessToken: "new-access",
            refreshToken: "new-refresh",
            expiresAt: updatedExpiry.timeIntervalSince1970
        )
        let refresher = ScriptedSupabaseAuthRefresher(behavior: .success(refreshedSDKSession))
        let service = SupabaseOAuthSessionService(
            client: makeClient(),
            sessionStore: store,
            authRefresher: refresher,
            clock: FixedClock(value: fixedNow)
        )

        let result = try await service.restore()
        let callCount = await refresher.refreshCallCount
        let passedToken = await refresher.lastRefreshTokenPassed

        XCTAssertEqual(callCount, 1)
        XCTAssertEqual(passedToken, "old-refresh")
        guard case let .refreshed(updatedMaterial)? = result else {
            XCTFail("Expected .refreshed result, got \(String(describing: result))")
            return
        }
        XCTAssertEqual(updatedMaterial.userID, testUserID)
        XCTAssertEqual(updatedMaterial.provider, .google)
        XCTAssertEqual(updatedMaterial.accessToken, "new-access")
        XCTAssertEqual(updatedMaterial.refreshToken, "new-refresh")
        XCTAssertEqual(
            updatedMaterial.expiresAt.timeIntervalSince1970,
            Double(Int(updatedExpiry.timeIntervalSince1970))
        )

        let storedInKeychain = try store.read()
        XCTAssertEqual(storedInKeychain, updatedMaterial)
    }

    func testStaleSessionSuccessfulRefreshWithKeychainWriteFailurePreservesStoredSessionOffline() async throws {
        let staleSession = AuthenticationSessionMaterial(
            userID: testUserID,
            provider: .apple,
            accessToken: "stored-access",
            refreshToken: "stored-refresh",
            expiresAt: fixedNow.addingTimeInterval(-10)
        )
        let refreshedSDKSession = try makeSyntheticSession(
            userID: testUserID,
            accessToken: "new-access",
            refreshToken: "new-refresh",
            expiresAt: fixedNow.addingTimeInterval(3600).timeIntervalSince1970
        )
        let refresher = ScriptedSupabaseAuthRefresher(behavior: .success(refreshedSDKSession))

        // The store below reads the initially stored session and fails on write.
        final class WriteFailingKeychain: KeychainClient {
            private let underlying = LockedKeychain()
            init(initialSession: AuthenticationSessionMaterial) throws {
                try KeychainSessionStore(keychain: underlying).write(initialSession)
            }

            func read(service: String, account: String) throws -> Data? {
                try underlying.read(service: service, account: account)
            }

            func write(_: Data, service _: String, account _: String) throws {
                throw AuthenticationError.keychainFailure
            }

            func delete(service: String, account: String) throws {
                try underlying.delete(service: service, account: account)
            }
        }

        let store = try KeychainSessionStore(keychain: WriteFailingKeychain(initialSession: staleSession))
        let serviceWithFailingWrite = SupabaseOAuthSessionService(
            client: makeClient(),
            sessionStore: store,
            authRefresher: refresher,
            clock: FixedClock(value: fixedNow)
        )

        let result = try await serviceWithFailingWrite.restore()
        let callCount = await refresher.refreshCallCount

        XCTAssertEqual(callCount, 1)
        XCTAssertEqual(result, .preservedOffline(staleSession, classification: .unclassified))
        XCTAssertEqual(result?.session, staleSession)
    }

    func testStaleSessionURLErrorPreservesKeychainAndReturnsStoredSession() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        let staleSession = AuthenticationSessionMaterial(
            userID: testUserID,
            provider: .apple,
            accessToken: "stored-access",
            refreshToken: "stored-refresh",
            expiresAt: fixedNow.addingTimeInterval(-100) // expired
        )
        try store.write(staleSession)

        let refresher = ScriptedSupabaseAuthRefresher(
            behavior: .failure(URLError(.notConnectedToInternet))
        )
        let service = SupabaseOAuthSessionService(
            client: makeClient(),
            sessionStore: store,
            authRefresher: refresher,
            clock: FixedClock(value: fixedNow)
        )

        let result = try await service.restore()
        let callCount = await refresher.refreshCallCount

        XCTAssertEqual(callCount, 1)
        XCTAssertEqual(result, .preservedOffline(staleSession, classification: .network))
        XCTAssertEqual(result?.session, staleSession)
        XCTAssertEqual(try store.read(), staleSession)
    }

    func testStaleSessionPOSIXNetworkErrorPreservesKeychainAndReturnsStoredSession() async throws {
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

        let networkError = NSError(
            domain: NSPOSIXErrorDomain,
            code: Int(POSIXErrorCode.ECONNREFUSED.rawValue),
            userInfo: nil
        )
        let refresher = ScriptedSupabaseAuthRefresher(behavior: .failure(networkError))
        let service = SupabaseOAuthSessionService(
            client: makeClient(),
            sessionStore: store,
            authRefresher: refresher,
            clock: FixedClock(value: fixedNow)
        )

        let result = try await service.restore()
        XCTAssertEqual(result, .preservedOffline(staleSession, classification: .network))
        XCTAssertEqual(try store.read(), staleSession)
    }

    func testStaleSessionCFNetworkErrorPreservesKeychainAndReturnsStoredSession() async throws {
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

        let cfError = NSError(
            domain: "kCFErrorDomainCFNetwork",
            code: 2,
            userInfo: nil
        )
        let refresher = ScriptedSupabaseAuthRefresher(behavior: .failure(cfError))
        let service = SupabaseOAuthSessionService(
            client: makeClient(),
            sessionStore: store,
            authRefresher: refresher,
            clock: FixedClock(value: fixedNow)
        )

        let result = try await service.restore()
        XCTAssertEqual(result, .preservedOffline(staleSession, classification: .network))
        XCTAssertEqual(try store.read(), staleSession)
    }

    func testStaleSessionDefinitiveRejectionInvalidGrantPurgesKeychainAndThrowsExpired() async throws {
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
            userInfo: [NSLocalizedDescriptionKey: "invalid_grant: Invalid Refresh Token: Refresh Token Not Found"]
        )
        let refresher = ScriptedSupabaseAuthRefresher(behavior: .failure(invalidGrantError))
        let service = SupabaseOAuthSessionService(
            client: makeClient(),
            sessionStore: store,
            authRefresher: refresher,
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

        let callCount = await refresher.refreshCallCount
        XCTAssertEqual(callCount, 1)
        XCTAssertNil(try store.read())
    }

    func testStaleSessionDefinitiveRejectionUnauthorized401PurgesKeychainAndThrowsExpired() async throws {
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

        let unauthorizedError = NSError(
            domain: "AuthError",
            code: 401,
            userInfo: [NSLocalizedDescriptionKey: "Unauthorized"]
        )
        let refresher = ScriptedSupabaseAuthRefresher(behavior: .failure(unauthorizedError))
        let service = SupabaseOAuthSessionService(
            client: makeClient(),
            sessionStore: store,
            authRefresher: refresher,
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

        XCTAssertNil(try store.read())
    }

    func testStaleSessionDefinitiveRejectionForbidden403PurgesKeychainAndThrowsExpired() async throws {
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

        let forbiddenError = NSError(
            domain: "AuthError",
            code: 403,
            userInfo: [NSLocalizedDescriptionKey: "Forbidden"]
        )
        let refresher = ScriptedSupabaseAuthRefresher(behavior: .failure(forbiddenError))
        let service = SupabaseOAuthSessionService(
            client: makeClient(),
            sessionStore: store,
            authRefresher: refresher,
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

        XCTAssertNil(try store.read())
    }

    func testStaleSessionUnclassifiedServerErrorPreservesKeychainAndReturnsStoredSession() async throws {
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

        let server500Error = NSError(
            domain: "AuthError",
            code: 500,
            userInfo: [NSLocalizedDescriptionKey: "Internal Server Error"]
        )
        let refresher = ScriptedSupabaseAuthRefresher(behavior: .failure(server500Error))
        let service = SupabaseOAuthSessionService(
            client: makeClient(),
            sessionStore: store,
            authRefresher: refresher,
            clock: FixedClock(value: fixedNow)
        )

        let result = try await service.restore()
        XCTAssertEqual(result, .preservedOffline(staleSession, classification: .unclassified))
        XCTAssertEqual(try store.read(), staleSession)
    }

    func testStaleSessionUnclassifiedRateLimitPreservesKeychainAndReturnsStoredSession() async throws {
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

        let rateLimitError = NSError(
            domain: "AuthError",
            code: 429,
            userInfo: [NSLocalizedDescriptionKey: "Too Many Requests"]
        )
        let refresher = ScriptedSupabaseAuthRefresher(behavior: .failure(rateLimitError))
        let service = SupabaseOAuthSessionService(
            client: makeClient(),
            sessionStore: store,
            authRefresher: refresher,
            clock: FixedClock(value: fixedNow)
        )

        let result = try await service.restore()
        XCTAssertEqual(result, .preservedOffline(staleSession, classification: .unclassified))
        XCTAssertEqual(try store.read(), staleSession)
    }

    func testStaleSessionUnclassifiedBare404PreservesKeychainAndReturnsStoredSessionOffline() async throws {
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

        let notFound404Error = NSError(
            domain: "AuthError",
            code: 404,
            userInfo: [
                NSLocalizedDescriptionKey: "<html><head><title>404 Not Found</title></head>" +
                    "<body><h1>404 Not Found</h1></body></html>",
            ]
        )
        let refresher = ScriptedSupabaseAuthRefresher(behavior: .failure(notFound404Error))
        let service = SupabaseOAuthSessionService(
            client: makeClient(),
            sessionStore: store,
            authRefresher: refresher,
            clock: FixedClock(value: fixedNow)
        )

        let result = try await service.restore()
        XCTAssertEqual(result, .preservedOffline(staleSession, classification: .unclassified))
        XCTAssertEqual(result?.session, staleSession)
        XCTAssertEqual(try store.read(), staleSession)
    }

    func testStaleSessionUnclassifiedBare422PreservesStoredSessionOffline() async throws {
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

        let unprocessable422Error = NSError(
            domain: "AuthError",
            code: 422,
            userInfo: [NSLocalizedDescriptionKey: "Unprocessable Entity: proxy validation failed"]
        )
        let refresher = ScriptedSupabaseAuthRefresher(behavior: .failure(unprocessable422Error))
        let service = SupabaseOAuthSessionService(
            client: makeClient(),
            sessionStore: store,
            authRefresher: refresher,
            clock: FixedClock(value: fixedNow)
        )

        let result = try await service.restore()
        XCTAssertEqual(result, .preservedOffline(staleSession, classification: .unclassified))
        XCTAssertEqual(result?.session, staleSession)
        XCTAssertEqual(try store.read(), staleSession)
    }

    func testStaleSessionKeywordRejectionIn404PurgesKeychainAndThrowsExpired() async throws {
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

        let sessionNotFoundError = NSError(
            domain: "AuthError",
            code: 404,
            userInfo: [NSLocalizedDescriptionKey: "session_not_found: session not found in database"]
        )
        let refresher = ScriptedSupabaseAuthRefresher(behavior: .failure(sessionNotFoundError))
        let service = SupabaseOAuthSessionService(
            client: makeClient(),
            sessionStore: store,
            authRefresher: refresher,
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

        let callCount = await refresher.refreshCallCount
        XCTAssertEqual(callCount, 1)
        XCTAssertNil(try store.read())
    }

    func testClassifyRefreshErrorTableCoverage() {
        // 1. Network errors
        XCTAssertEqual(
            SupabaseOAuthSessionService.classifyRefreshError(URLError(.timedOut)),
            .network
        )
        XCTAssertEqual(
            SupabaseOAuthSessionService.classifyRefreshError(
                NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotConnectToHost)
            ),
            .network
        )
        XCTAssertEqual(
            SupabaseOAuthSessionService.classifyRefreshError(
                NSError(domain: "kCFErrorDomainCFNetwork", code: 2)
            ),
            .network
        )
        XCTAssertEqual(
            SupabaseOAuthSessionService.classifyRefreshError(
                NSError(domain: NSPOSIXErrorDomain, code: Int(POSIXErrorCode.ETIMEDOUT.rawValue))
            ),
            .network
        )

        // 2. Definitive rejection
        XCTAssertEqual(
            SupabaseOAuthSessionService.classifyRefreshError(
                NSError(domain: "AuthError", code: 401, userInfo: nil)
            ),
            .definitiveRejection
        )
        XCTAssertEqual(
            SupabaseOAuthSessionService.classifyRefreshError(
                NSError(domain: "AuthError", code: 403, userInfo: nil)
            ),
            .definitiveRejection
        )
        XCTAssertEqual(
            SupabaseOAuthSessionService.classifyRefreshError(
                NSError(domain: "AuthError", code: 400, userInfo: nil)
            ),
            .definitiveRejection
        )
        XCTAssertEqual(
            SupabaseOAuthSessionService.classifyRefreshError(
                NSError(domain: "Custom", code: 0, userInfo: [NSLocalizedDescriptionKey: "invalid_grant error"])
            ),
            .definitiveRejection
        )
        XCTAssertEqual(
            SupabaseOAuthSessionService.classifyRefreshError(
                NSError(domain: "Custom", code: 0, userInfo: [NSLocalizedDescriptionKey: "Refresh Token Not Found"])
            ),
            .definitiveRejection
        )
        XCTAssertEqual(
            SupabaseOAuthSessionService.classifyRefreshError(
                NSError(domain: "Custom", code: 0, userInfo: [NSLocalizedDescriptionKey: "Session Not Found"])
            ),
            .definitiveRejection
        )
        XCTAssertEqual(
            SupabaseOAuthSessionService.classifyRefreshError(
                NSError(domain: "Custom", code: 0, userInfo: [NSLocalizedDescriptionKey: "Token is expired"])
            ),
            .definitiveRejection
        )
        XCTAssertEqual(
            SupabaseOAuthSessionService.classifyRefreshError(
                NSError(domain: "AuthError", code: 404, userInfo: [NSLocalizedDescriptionKey: "session not found"])
            ),
            .definitiveRejection
        )
        XCTAssertEqual(
            SupabaseOAuthSessionService.classifyRefreshError(
                NSError(domain: "AuthError", code: 400, userInfo: [NSLocalizedDescriptionKey: "session not found"])
            ),
            .definitiveRejection
        )

        // 3. Unclassified / fail-safe
        XCTAssertEqual(
            SupabaseOAuthSessionService.classifyRefreshError(
                NSError(domain: "AuthError", code: 404, userInfo: nil)
            ),
            .unclassified
        )
        XCTAssertEqual(
            SupabaseOAuthSessionService.classifyRefreshError(
                NSError(
                    domain: "AuthError",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "<html>404 Not Found</html>"]
                )
            ),
            .unclassified
        )
        XCTAssertEqual(
            SupabaseOAuthSessionService.classifyRefreshError(
                NSError(domain: "AuthError", code: 422, userInfo: nil)
            ),
            .unclassified
        )
        XCTAssertEqual(
            SupabaseOAuthSessionService.classifyRefreshError(
                NSError(
                    domain: "AuthError",
                    code: 422,
                    userInfo: [NSLocalizedDescriptionKey: "Unprocessable proxy entity"]
                )
            ),
            .unclassified
        )
        XCTAssertEqual(
            SupabaseOAuthSessionService.classifyRefreshError(
                NSError(domain: "AuthError", code: 500, userInfo: nil)
            ),
            .unclassified
        )
        XCTAssertEqual(
            SupabaseOAuthSessionService.classifyRefreshError(
                NSError(domain: "AuthError", code: 503, userInfo: nil)
            ),
            .unclassified
        )
        XCTAssertEqual(
            SupabaseOAuthSessionService.classifyRefreshError(
                NSError(domain: "AuthError", code: 429, userInfo: nil)
            ),
            .unclassified
        )
        XCTAssertEqual(
            SupabaseOAuthSessionService.classifyRefreshError(
                NSError(domain: "UnknownDomain", code: 999, userInfo: [NSLocalizedDescriptionKey: "Something strange"])
            ),
            .unclassified
        )
    }
}
