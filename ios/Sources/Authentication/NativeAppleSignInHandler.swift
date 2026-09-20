import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

/// # Native Apple Sign In Result
///
/// Encapsulates the verified Apple ID token, the raw nonce used during the cryptographic
/// challenge, and any profile metadata returned on first authorization.
struct NativeAppleSignInResult: Sendable, Equatable {
    let idToken: String
    let rawNonce: String
    let fullName: PersonNameComponents?
    let email: String?

    init(
        idToken: String,
        rawNonce: String,
        fullName: PersonNameComponents? = nil,
        email: String? = nil
    ) {
        self.idToken = idToken
        self.rawNonce = rawNonce
        self.fullName = fullName
        self.email = email
    }
}

/// # Native Apple Sign In Handling Protocol
protocol NativeAppleSignInHandling: Sendable {
    func signIn() async throws -> NativeAppleSignInResult
}

/// # Native Apple Sign In Handler
///
/// Coordinates native iOS Sign in with Apple using `AuthenticationServices` (`ASAuthorizationAppleIDProvider`).
/// Generates a cryptographically secure 32-character raw nonce, passes its SHA-256 digest to Apple,
/// presents the system authorization sheet, and returns the resulting identity token and raw nonce.
struct NativeAppleSignInHandler: NativeAppleSignInHandling, Sendable {
    private let rawNonceGenerator: @Sendable () throws -> String

    init(rawNonceGenerator: (@Sendable () throws -> String)? = nil) {
        self.rawNonceGenerator = rawNonceGenerator ?? { try Self.generateRawNonce() }
    }

    /// Generates a cryptographically secure 32-character random string using `SecRandomCopyBytes`.
    static func generateRawNonce(length: Int = 32) throws -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        guard errorCode == errSecSuccess else {
            throw AuthenticationError.externalProviderUnavailable
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }

    /// Computes the lowercase SHA-256 hexadecimal digest string using `CryptoKit.SHA256`.
    static func sha256Hex(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.map { String(format: "%02x", $0) }.joined()
    }

    /// Maps authorization or system errors to `AuthenticationError` taxonomy.
    static func mapError(_ error: any Error) -> AuthenticationError {
        if let asError = error as? ASAuthorizationError {
            switch asError.code {
            case .canceled:
                return .cancelled
            default:
                return .externalProviderUnavailable
            }
        }
        if let authError = error as? AuthenticationError {
            return authError
        }
        if error is CancellationError {
            return .cancelled
        }
        return .externalProviderUnavailable
    }

    func signIn() async throws -> NativeAppleSignInResult {
        let rawNonce = try rawNonceGenerator()
        let hashedNonce = Self.sha256Hex(rawNonce)
        return try await performSignIn(rawNonce: rawNonce, hashedNonce: hashedNonce)
    }

    @MainActor
    private func performSignIn(rawNonce: String, hashedNonce: String) async throws -> NativeAppleSignInResult {
        let coordinator = AppleSignInPresentationCoordinator(rawNonce: rawNonce)
        return try await coordinator.start(hashedNonce: hashedNonce)
    }
}

/// # Presentation & Coordination Delegate
///
/// Isolated to `@MainActor` to manage `ASAuthorizationController` presentation context
/// and delegate callbacks safely under Swift 6 strict concurrency.
@MainActor
private final class AppleSignInPresentationCoordinator: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding
{
    private var continuation: CheckedContinuation<NativeAppleSignInResult, any Error>?
    private let rawNonce: String
    private var retainedSelf: AppleSignInPresentationCoordinator?

    init(rawNonce: String) {
        self.rawNonce = rawNonce
        super.init()
    }

    func start(hashedNonce: String) async throws -> NativeAppleSignInResult {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                self.retainedSelf = self

                let provider = ASAuthorizationAppleIDProvider()
                let request = provider.createRequest()
                request.requestedScopes = [.fullName, .email]
                request.nonce = hashedNonce

                let controller = ASAuthorizationController(authorizationRequests: [request])
                controller.delegate = self
                controller.presentationContextProvider = self
                controller.performRequests()
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.continuation?.resume(throwing: AuthenticationError.cancelled)
                self.continuation = nil
                self.retainedSelf = nil
            }
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            if let window = windowScene.windows.first(where: \.isKeyWindow) {
                return window
            }
            if let window = windowScene.windows.first {
                return window
            }
        }
        return UIWindow()
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        defer {
            retainedSelf = nil
        }
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation?.resume(throwing: AuthenticationError.externalProviderUnavailable)
            continuation = nil
            return
        }
        guard let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8),
              !idToken.isEmpty
        else {
            continuation?.resume(throwing: AuthenticationError.externalProviderUnavailable)
            continuation = nil
            return
        }

        let result = NativeAppleSignInResult(
            idToken: idToken,
            rawNonce: rawNonce,
            fullName: credential.fullName,
            email: credential.email
        )
        continuation?.resume(returning: result)
        continuation = nil
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: any Error
    ) {
        defer {
            retainedSelf = nil
        }
        let mapped = NativeAppleSignInHandler.mapError(error)
        continuation?.resume(throwing: mapped)
        continuation = nil
    }
}
