import AuthenticationServices
import CryptoKit
import Foundation
@testable import SleepParalysisCompanion
import Supabase
import XCTest

final class AppleSignInNonceTests: XCTestCase {
    func testRawNonceGeneratesNonEmptyStringAndCorrectSHA256Output() throws {
        let rawNonce = try NativeAppleSignInHandler.generateRawNonce()
        XCTAssertFalse(rawNonce.isEmpty)
        XCTAssertEqual(rawNonce.count, 32)

        let hashedNonce = NativeAppleSignInHandler.sha256Hex(rawNonce)
        XCTAssertEqual(hashedNonce.count, 64)

        // Verify SHA256 output matches standard CryptoKit digest
        let expectedDigest = SHA256.hash(data: Data(rawNonce.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        XCTAssertEqual(hashedNonce, expectedDigest)
    }

    func testConsecutiveNoncesAreCryptographicallyUnique() throws {
        let nonce1 = try NativeAppleSignInHandler.generateRawNonce()
        let nonce2 = try NativeAppleSignInHandler.generateRawNonce()
        XCTAssertNotEqual(nonce1, nonce2)

        let hash1 = NativeAppleSignInHandler.sha256Hex(nonce1)
        let hash2 = NativeAppleSignInHandler.sha256Hex(nonce2)
        XCTAssertNotEqual(hash1, hash2)
    }

    func testASAuthorizationErrorCanceledMapsToAuthenticationErrorCancelled() {
        let canceledError = NSError(
            domain: ASAuthorizationErrorDomain,
            code: ASAuthorizationError.canceled.rawValue,
            userInfo: nil
        )
        let mapped = NativeAppleSignInHandler.mapError(canceledError)
        XCTAssertEqual(mapped, .cancelled)
    }

    func testOtherASAuthorizationErrorsMapToExternalProviderUnavailable() {
        let failedError = NSError(
            domain: ASAuthorizationErrorDomain,
            code: ASAuthorizationError.failed.rawValue,
            userInfo: nil
        )
        let mapped = NativeAppleSignInHandler.mapError(failedError)
        XCTAssertEqual(mapped, .externalProviderUnavailable)

        let invalidResponse = NSError(
            domain: ASAuthorizationErrorDomain,
            code: ASAuthorizationError.invalidResponse.rawValue,
            userInfo: nil
        )
        let mappedInvalid = NativeAppleSignInHandler.mapError(invalidResponse)
        XCTAssertEqual(mappedInvalid, .externalProviderUnavailable)
    }

    func testCancellationErrorMapsToCancelled() {
        let mapped = NativeAppleSignInHandler.mapError(CancellationError())
        XCTAssertEqual(mapped, .cancelled)
    }

    func testAuthenticationErrorPreserved() {
        let mapped = NativeAppleSignInHandler.mapError(AuthenticationError.wrongAccount)
        XCTAssertEqual(mapped, .wrongAccount)
    }

    func testClassifySignInErrorMapsASAuthorizationCanceledToCancelled() {
        let canceledError = NSError(
            domain: ASAuthorizationErrorDomain,
            code: ASAuthorizationError.canceled.rawValue,
            userInfo: nil
        )
        let classified = SupabaseOAuthSessionService.classifySignInError(canceledError)
        XCTAssertEqual(classified, .cancelled)
    }

    func testClassifySignInErrorMapsOtherASAuthorizationErrorToExternalProviderUnavailable() {
        let failedError = NSError(
            domain: ASAuthorizationErrorDomain,
            code: ASAuthorizationError.notHandled.rawValue,
            userInfo: nil
        )
        let classified = SupabaseOAuthSessionService.classifySignInError(failedError)
        XCTAssertEqual(classified, .externalProviderUnavailable)
    }

    func testDefaultAuthenticatorDelegatesAppleSignInToHandler() async throws {
        struct MockAppleHandler: NativeAppleSignInHandling {
            let errorToThrow: (any Error)?

            func signIn() async throws -> NativeAppleSignInResult {
                if let errorToThrow {
                    throw errorToThrow
                }
                return NativeAppleSignInResult(
                    idToken: "mock-id-token",
                    rawNonce: "mock-raw-nonce"
                )
            }
        }

        let baseURL = try XCTUnwrap(URL(string: "https://example.supabase.co"))
        let client = SupabaseClient(
            supabaseURL: baseURL,
            supabaseKey: "test-anon-key"
        )
        let mockHandler = MockAppleHandler(errorToThrow: AuthenticationError.cancelled)
        let authenticator = DefaultSupabaseOAuthAuthenticator(
            client: client,
            appleSignInHandler: mockHandler
        )

        do {
            _ = try await authenticator.signInWithOAuth(provider: .apple)
            XCTFail("Expected AuthenticationError.cancelled to be thrown")
        } catch let error as AuthenticationError {
            XCTAssertEqual(error, .cancelled)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
