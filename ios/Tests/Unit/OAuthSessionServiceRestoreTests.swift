import Foundation
@testable import SleepParalysisCompanion
import Supabase
import XCTest

final class ScriptedSupabaseAuthRefresher: SupabaseAuthRefreshing, @unchecked Sendable {
    enum Behavior: Sendable {
        case success(Session)
        case failure(any Error)
    }

    private let lock = NSLock()
    private var behavior: Behavior
    private var _refreshCallCount = 0
    private var _lastRefreshTokenPassed: String?

    init(behavior: Behavior) {
        self.behavior = behavior
    }

    var refreshCallCount: Int {
        get async {
            lock.lock()
            defer { lock.unlock() }
            return _refreshCallCount
        }
    }

    var lastRefreshTokenPassed: String? {
        get async {
            lock.lock()
            defer { lock.unlock() }
            return _lastRefreshTokenPassed
        }
    }

    func setBehavior(_ behavior: Behavior) {
        lock.lock()
        defer { lock.unlock() }
        self.behavior = behavior
    }

    func refreshSession(refreshToken: String) async throws -> Session {
        lock.lock()
        _refreshCallCount += 1
        _lastRefreshTokenPassed = refreshToken
        let currentBehavior = behavior
        lock.unlock()

        switch currentBehavior {
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
        let freshIdentity = AuthenticationIdentityRecord(
            userID: testUserID,
            provider: .apple,
            expiresAt: fixedNow.addingTimeInterval(3600) // > now + 60s
        )
        try store.writeIdentity(freshIdentity)

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
        guard case let .fresh(material)? = result else {
            XCTFail("Expected .fresh result, got \(String(describing: result))")
            return
        }
        XCTAssertEqual(material.userID, testUserID)
        XCTAssertEqual(material.provider, .apple)
        let callCount = await refresher.refreshCallCount
        XCTAssertEqual(callCount, 0)
        XCTAssertEqual(try store.readIdentity(), freshIdentity)
    }

    func testStaleSessionSuccessfulRefreshWritesBackAndReturnsUpdatedMaterial() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        let staleIdentity = AuthenticationIdentityRecord(
            userID: testUserID,
            provider: .google,
            expiresAt: fixedNow.addingTimeInterval(30) // <= now + 60s
        )
        try store.writeIdentity(staleIdentity)

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

        XCTAssertEqual(callCount, 1)
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

        let storedIdentity = try store.readIdentity()
        XCTAssertEqual(storedIdentity?.userID, testUserID)
        XCTAssertEqual(storedIdentity?.provider, .google)
    }

    func testStaleSessionURLErrorPreservesKeychainAndReturnsStoredSession() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        let staleIdentity = AuthenticationIdentityRecord(
            userID: testUserID,
            provider: .apple,
            expiresAt: fixedNow.addingTimeInterval(-100) // expired
        )
        try store.writeIdentity(staleIdentity)

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
        guard case let .preservedOffline(material, classification)? = result else {
            XCTFail("Expected .preservedOffline, got \(String(describing: result))")
            return
        }
        XCTAssertEqual(classification, .network)
        XCTAssertEqual(material.userID, testUserID)
        XCTAssertEqual(try store.readIdentity(), staleIdentity)
    }

    func testStaleSessionPOSIXNetworkErrorPreservesKeychainAndReturnsStoredSession() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        let staleIdentity = AuthenticationIdentityRecord(
            userID: testUserID,
            provider: .apple,
            expiresAt: fixedNow.addingTimeInterval(-100)
        )
        try store.writeIdentity(staleIdentity)

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
        guard case let .preservedOffline(material, classification)? = result else {
            XCTFail("Expected .preservedOffline, got \(String(describing: result))")
            return
        }
        XCTAssertEqual(classification, .network)
        XCTAssertEqual(material.userID, testUserID)
        XCTAssertEqual(try store.readIdentity(), staleIdentity)
    }

    func testStaleSessionCFNetworkErrorPreservesKeychainAndReturnsStoredSession() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        let staleIdentity = AuthenticationIdentityRecord(
            userID: testUserID,
            provider: .apple,
            expiresAt: fixedNow.addingTimeInterval(-100)
        )
        try store.writeIdentity(staleIdentity)

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
        guard case let .preservedOffline(material, classification)? = result else {
            XCTFail("Expected .preservedOffline, got \(String(describing: result))")
            return
        }
        XCTAssertEqual(classification, .network)
        XCTAssertEqual(material.userID, testUserID)
        XCTAssertEqual(try store.readIdentity(), staleIdentity)
    }

    func testStaleSessionDefinitiveRejectionInvalidGrantPurgesKeychainAndThrowsExpired() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        let staleIdentity = AuthenticationIdentityRecord(
            userID: testUserID,
            provider: .apple,
            expiresAt: fixedNow.addingTimeInterval(-100)
        )
        try store.writeIdentity(staleIdentity)

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
        XCTAssertNil(try store.readIdentity())
    }

    func testStaleSessionDefinitiveRejectionUnauthorized401PurgesKeychainAndThrowsExpired() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        let staleIdentity = AuthenticationIdentityRecord(
            userID: testUserID,
            provider: .apple,
            expiresAt: fixedNow.addingTimeInterval(-100)
        )
        try store.writeIdentity(staleIdentity)

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

        XCTAssertNil(try store.readIdentity())
    }

    func testStaleSessionDefinitiveRejectionForbidden403PurgesKeychainAndThrowsExpired() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        let staleIdentity = AuthenticationIdentityRecord(
            userID: testUserID,
            provider: .apple,
            expiresAt: fixedNow.addingTimeInterval(-100)
        )
        try store.writeIdentity(staleIdentity)

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

        XCTAssertNil(try store.readIdentity())
    }

    func testStaleSessionUnclassifiedServerErrorPreservesKeychainAndReturnsStoredSession() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        let staleIdentity = AuthenticationIdentityRecord(
            userID: testUserID,
            provider: .apple,
            expiresAt: fixedNow.addingTimeInterval(-100)
        )
        try store.writeIdentity(staleIdentity)

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
        guard case let .preservedOffline(material, classification)? = result else {
            XCTFail("Expected .preservedOffline, got \(String(describing: result))")
            return
        }
        XCTAssertEqual(classification, .unclassified)
        XCTAssertEqual(material.userID, testUserID)
        XCTAssertEqual(try store.readIdentity(), staleIdentity)
    }

    func testStaleSessionUnclassifiedRateLimitPreservesKeychainAndReturnsStoredSession() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        let staleIdentity = AuthenticationIdentityRecord(
            userID: testUserID,
            provider: .apple,
            expiresAt: fixedNow.addingTimeInterval(-100)
        )
        try store.writeIdentity(staleIdentity)

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
        guard case let .preservedOffline(material, classification)? = result else {
            XCTFail("Expected .preservedOffline, got \(String(describing: result))")
            return
        }
        XCTAssertEqual(classification, .unclassified)
        XCTAssertEqual(material.userID, testUserID)
        XCTAssertEqual(try store.readIdentity(), staleIdentity)
    }

    func testStaleSessionUnclassifiedBare404PreservesKeychainAndReturnsStoredSessionOffline() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        let staleIdentity = AuthenticationIdentityRecord(
            userID: testUserID,
            provider: .apple,
            expiresAt: fixedNow.addingTimeInterval(-100)
        )
        try store.writeIdentity(staleIdentity)

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
        guard case let .preservedOffline(material, classification)? = result else {
            XCTFail("Expected .preservedOffline, got \(String(describing: result))")
            return
        }
        XCTAssertEqual(classification, .unclassified)
        XCTAssertEqual(material.userID, testUserID)
        XCTAssertEqual(try store.readIdentity(), staleIdentity)
    }

    func testStaleSessionUnclassifiedBare422PreservesStoredSessionOffline() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        let staleIdentity = AuthenticationIdentityRecord(
            userID: testUserID,
            provider: .apple,
            expiresAt: fixedNow.addingTimeInterval(-100)
        )
        try store.writeIdentity(staleIdentity)

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
        guard case let .preservedOffline(material, classification)? = result else {
            XCTFail("Expected .preservedOffline, got \(String(describing: result))")
            return
        }
        XCTAssertEqual(classification, .unclassified)
        XCTAssertEqual(material.userID, testUserID)
        XCTAssertEqual(try store.readIdentity(), staleIdentity)
    }

    func testStaleSessionKeywordRejectionIn404PurgesKeychainAndThrowsExpired() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        let staleIdentity = AuthenticationIdentityRecord(
            userID: testUserID,
            provider: .apple,
            expiresAt: fixedNow.addingTimeInterval(-100)
        )
        try store.writeIdentity(staleIdentity)

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
        XCTAssertNil(try store.readIdentity())
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
