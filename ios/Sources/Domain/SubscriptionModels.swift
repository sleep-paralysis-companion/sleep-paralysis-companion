import Foundation
import StoreKit

/// Strongly typed representation of the subscription products supported by
/// Sleep Paralysis Companion.
///
/// Products:
/// - Monthly auto-renewable subscription with 3-day free trial ($8.99 USD)
/// - Annual auto-renewable subscription with 3-day free trial ($59.99 USD)
/// - Lifelong non-consumable access ($149.99 USD)
nonisolated enum SubscriptionProductTier: String, CaseIterable, Identifiable, Sendable, Hashable, Codable {
    case monthly = "app.sleepcompanion.spc.premium.monthly"
    case annual = "app.sleepcompanion.spc.premium.annual"
    case lifetime = "app.sleepcompanion.spc.premium.lifetime"

    var id: String {
        rawValue
    }

    var productID: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .monthly:
            return "Monthly"
        case .annual:
            return "Annual"
        case .lifetime:
            return "Lifetime Access"
        }
    }

    var referencePriceUSD: String {
        switch self {
        case .monthly:
            return "$8.99"
        case .annual:
            return "$59.99"
        case .lifetime:
            return "$149.99"
        }
    }

    var isSubscription: Bool {
        self == .monthly || self == .annual
    }

    var isLifetime: Bool {
        self == .lifetime
    }

    var hasIntroductoryTrial: Bool {
        self == .monthly || self == .annual
    }

    var sortOrder: Int {
        switch self {
        case .monthly:
            return 1
        case .annual:
            return 2
        case .lifetime:
            return 3
        }
    }

    static let allProductIDs: Set<String> = Set(allCases.map(\.rawValue))

    init?(productID: String) {
        self.init(rawValue: productID)
    }
}

/// Strongly typed errors for subscription and in-app purchase operations.
///
/// User-facing messages are kept clear and calm, avoiding technical jargon
/// while maintaining precise error categorization for debugging and telemetry.
nonisolated enum SubscriptionError: Error, Equatable, Sendable, LocalizedError {
    case productNotFound(String)
    case unverifiedTransaction(String)
    case purchaseFailed(String)
    case restoreFailed(String)
    case networkError(String)
    case userCancelled
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "The selected subscription option is currently unavailable. Please try again later."
        case .unverifiedTransaction:
            return "We could not verify this transaction with the App Store. Please try again."
        case .purchaseFailed(let message):
            return message.isEmpty
                ? "The purchase could not be completed. Please try again."
                : message
        case .restoreFailed(let message):
            return message.isEmpty
                ? "We were unable to restore your purchases. Please try again later."
                : message
        case .networkError:
            return "A connection error occurred. Please check your internet connection and try again."
        case .userCancelled:
            return "The purchase was cancelled."
        case .unknown(let message):
            return message.isEmpty
                ? "An unexpected error occurred. Please try again."
                : message
        }
    }
}

/// Result of an in-app purchase attempt through StoreKit 2.
nonisolated enum PurchaseOutcome: Sendable {
    case success(Transaction)
    case mockSuccess(SubscriptionProductTier)
    case pending
    case userCancelled
    case failed(SubscriptionError)

    var isSuccess: Bool {
        switch self {
        case .success, .mockSuccess:
            return true
        default:
            return false
        }
    }

    var transaction: Transaction? {
        if case let .success(transaction) = self {
            return transaction
        }
        return nil
    }

    var error: SubscriptionError? {
        if case let .failed(error) = self {
            return error
        }
        return nil
    }
}

typealias Product = StoreKit.Product

/// Current entitlement and premium status of the user.
///
/// Encapsulates whether premium access is active, which tier is active,
/// expiration date, free trial status, auto-renewal state, and revocation flag.
nonisolated struct SubscriptionEntitlementStatus: Equatable, Sendable {
    let isActive: Bool
    let activeTier: SubscriptionProductTier?
    let expirationDate: Date?
    let isInTrial: Bool
    let isAutoRenewOn: Bool
    let isRevoked: Bool
    let originalPurchaseDate: Date?
    let latestTransactionID: UInt64?

    static let inactive = SubscriptionEntitlementStatus(
        isActive: false,
        activeTier: nil,
        expirationDate: nil,
        isInTrial: false,
        isAutoRenewOn: false,
        isRevoked: false,
        originalPurchaseDate: nil,
        latestTransactionID: nil
    )

    static let active = SubscriptionEntitlementStatus.active(
        tier: .annual,
        expirationDate: Date().addingTimeInterval(86400 * 365),
        isInTrial: false,
        isAutoRenewOn: true
    )

    static let revoked = SubscriptionEntitlementStatus(
        isActive: false,
        activeTier: nil,
        expirationDate: nil,
        isInTrial: false,
        isAutoRenewOn: false,
        isRevoked: true,
        originalPurchaseDate: nil,
        latestTransactionID: nil
    )

    static func active(
        tier: SubscriptionProductTier,
        expirationDate: Date?,
        isInTrial: Bool,
        isAutoRenewOn: Bool,
        originalPurchaseDate: Date? = nil,
        latestTransactionID: UInt64? = nil
    ) -> SubscriptionEntitlementStatus {
        SubscriptionEntitlementStatus(
            isActive: true,
            activeTier: tier,
            expirationDate: expirationDate,
            isInTrial: isInTrial,
            isAutoRenewOn: isAutoRenewOn,
            isRevoked: false,
            originalPurchaseDate: originalPurchaseDate,
            latestTransactionID: latestTransactionID
        )
    }

    static func lifetime(
        purchaseDate: Date = Date(),
        transactionID: UInt64? = nil
    ) -> SubscriptionEntitlementStatus {
        SubscriptionEntitlementStatus(
            isActive: true,
            activeTier: .lifetime,
            expirationDate: nil,
            isInTrial: false,
            isAutoRenewOn: false,
            isRevoked: false,
            originalPurchaseDate: purchaseDate,
            latestTransactionID: transactionID
        )
    }

    var hasLifetimeAccess: Bool {
        isActive && activeTier == .lifetime
    }

    var isSubscriptionActive: Bool {
        isActive && (activeTier == .monthly || activeTier == .annual)
    }

    var premiumAccess: PremiumAccess {
        isActive ? .active : .unavailable
    }
}
