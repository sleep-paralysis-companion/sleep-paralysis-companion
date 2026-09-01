import Foundation
@testable import SleepParalysisCompanion
import Supabase
import XCTest

final class OAuthSessionServiceMigrationTests: XCTestCase {
    private let fixedNow = Date(timeIntervalSince1970: 1_753_660_800)
    private let testUserID = UUID(
        uuid: (0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x42, 0x22, 0x82, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22)
    )

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

    func testLegacySessionMaterialMigrationSuccess() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        let legacySession = AuthenticationSessionMaterial(
            userID: testUserID,
            provider: .apple,
            accessToken: "legacy-access",
            refreshToken: "legacy-refresh-token",
            expiresAt: fixedNow.addingTimeInterval(300)
        )

        // Populate legacy account
        let legacyData = try JSONEncoder().encode(legacySession)
        try keychain.write(
            legacyData,
            service: SessionKeychainIdentity.service,
            account: SessionKeychainIdentity.legacyAccount
        )

        XCTAssertNotNil(try store.readLegacyMaterial())
        XCTAssertNil(try store.readIdentity())

        let updatedExpiry = fixedNow.addingTimeInterval(7200)
        let refreshedSDKSession = try makeSyntheticSession(
            userID: testUserID,
            accessToken: "migrated-access",
            refreshToken: "migrated-refresh",
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
        let callCount = refresher.refreshCallCount
        let passedToken = refresher.lastRefreshTokenPassed

        XCTAssertEqual(callCount, 1)
        XCTAssertEqual(passedToken, "legacy-refresh-token")

        guard case let .refreshed(material)? = result else {
            XCTFail("Expected .refreshed result from migration, got \(String(describing: result))")
            return
        }
        XCTAssertEqual(material.userID, testUserID)
        XCTAssertEqual(material.provider, .apple)
        XCTAssertEqual(material.accessToken, "migrated-access")
        XCTAssertEqual(material.refreshToken, "migrated-refresh")

        // Assert legacy entry deleted and identity record written
        XCTAssertNil(try store.readLegacyMaterial())
        let savedIdentity = try store.readIdentity()
        XCTAssertEqual(savedIdentity?.userID, testUserID)
        XCTAssertEqual(savedIdentity?.provider, .apple)
    }

    func testLegacySessionMaterialMigrationOfflinePreservesLegacyMaterial() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        let legacySession = AuthenticationSessionMaterial(
            userID: testUserID,
            provider: .apple,
            accessToken: "legacy-access",
            refreshToken: "legacy-refresh-token",
            expiresAt: fixedNow.addingTimeInterval(300)
        )

        let legacyData = try JSONEncoder().encode(legacySession)
        try keychain.write(
            legacyData,
            service: SessionKeychainIdentity.service,
            account: SessionKeychainIdentity.legacyAccount
        )

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
        XCTAssertEqual(result, .preservedOffline(legacySession, classification: .network))

        // Assert legacy material is preserved for next launch
        XCTAssertEqual(try store.readLegacyMaterial(), legacySession)
        XCTAssertNil(try store.readIdentity())
    }

    func testLegacySessionMaterialMigrationPurgedOnDefinitiveRejection() async throws {
        let keychain = LockedKeychain()
        let store = KeychainSessionStore(keychain: keychain)
        let legacySession = AuthenticationSessionMaterial(
            userID: testUserID,
            provider: .apple,
            accessToken: "legacy-access",
            refreshToken: "legacy-refresh-token",
            expiresAt: fixedNow.addingTimeInterval(300)
        )

        let legacyData = try JSONEncoder().encode(legacySession)
        try keychain.write(
            legacyData,
            service: SessionKeychainIdentity.service,
            account: SessionKeychainIdentity.legacyAccount
        )

        let invalidGrantError = NSError(
            domain: "AuthError",
            code: 400,
            userInfo: [NSLocalizedDescriptionKey: "invalid_grant: refresh token expired"]
        )
        let refresher = ScriptedSupabaseAuthRefresher(behavior: .failure(invalidGrantError))
        let logger = SpyPrivacySafeLogger()
        let service = SupabaseOAuthSessionService(
            client: makeClient(),
            sessionStore: store,
            authRefresher: refresher,
            logger: logger,
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

        XCTAssertNil(try store.readLegacyMaterial())
        XCTAssertNil(try store.readIdentity())
        XCTAssertTrue(logger.events.contains(.restorePurgedOnRejection))
    }
}
