import Foundation
import StoreKit

/// Protocol defining the interface for StoreKit 2 subscription and purchase operations.
///
/// Enables complete mocking in test suites and SwiftUI previews without requiring
/// a live StoreKit environment or `.storekit` test configuration.
nonisolated protocol SubscriptionServiceProtocol: Sendable {
    var currentEntitlement: SubscriptionEntitlementStatus { get async }
    var availableProducts: [Product] { get async }
    var availableTiers: [SubscriptionProductTier] { get async }
    var entitlementUpdates: AsyncStream<SubscriptionEntitlementStatus> { get async }

    func loadProducts() async throws -> [Product]
    func product(for tier: SubscriptionProductTier) async throws -> Product
    func purchase(_ product: Product) async throws -> PurchaseOutcome
    func purchase(tier: SubscriptionProductTier) async throws -> PurchaseOutcome
    func refreshEntitlements() async -> SubscriptionEntitlementStatus
    func restorePurchases() async throws -> SubscriptionEntitlementStatus
    func startTransactionListener() async
    func stopTransactionListener() async
}

/// Native StoreKit 2 implementation of `SubscriptionServiceProtocol`.
///
/// Responsibilities:
/// - Fetches and caches dynamic products for all supported tiers.
/// - Cryptographically verifies transactions via `checkVerified(_:)`.
/// - Listens for external/background transaction updates via `Transaction.updates`.
/// - Inspects active entitlements via `Transaction.currentEntitlements`.
/// - Executes purchases and handles success, pending, cancellation, and failures.
/// - Synchronizes prior transactions via `AppStore.sync()`.
///
/// Concurrency & Safety:
/// - Isolated as an `actor` conforming to `Sendable` under Swift 6 strict concurrency.
/// - Strictly requires `VerificationResult.verified` before granting any entitlement.
/// - Zero third-party dependencies (pure native StoreKit 2).
actor StoreKitSubscriptionService: SubscriptionServiceProtocol {
    static func live() -> StoreKitSubscriptionService {
        StoreKitSubscriptionService()
    }

    private(set) var currentEntitlement: SubscriptionEntitlementStatus = .inactive
    private(set) var availableProducts: [Product] = []

    var availableTiers: [SubscriptionProductTier] {
        availableProducts.compactMap { SubscriptionProductTier(productID: $0.id) }
    }

    private var updatesTask: Task<Void, Never>?
    private var entitlementContinuations: [UUID: AsyncStream<SubscriptionEntitlementStatus>.Continuation] = [:]

    init(autoStartListener: Bool = true) {
        if autoStartListener {
            self.updatesTask = Task { [weak self] in
                guard let self else { return }
                await self.listenForTransactions()
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: - Entitlement Stream

    var entitlementUpdates: AsyncStream<SubscriptionEntitlementStatus> {
        AsyncStream { continuation in
            let id = UUID()
            self.addContinuation(continuation, id: id)
            continuation.onTermination = { [weak self] _ in
                Task { [weak self] in
                    await self?.removeContinuation(id: id)
                }
            }
            continuation.yield(self.currentEntitlement)
        }
    }

    private func addContinuation(
        _ continuation: AsyncStream<SubscriptionEntitlementStatus>.Continuation,
        id: UUID
    ) {
        entitlementContinuations[id] = continuation
    }

    private func removeContinuation(id: UUID) {
        entitlementContinuations.removeValue(forKey: id)
    }

    private func notifyEntitlementChanged(_ status: SubscriptionEntitlementStatus) {
        self.currentEntitlement = status
        for continuation in entitlementContinuations.values {
            continuation.yield(status)
        }
    }

    // MARK: - Product Fetching

    func loadProducts() async throws -> [Product] {
        let productIDs = SubscriptionProductTier.allProductIDs
        do {
            let fetched = try await Product.products(for: productIDs)
            let sorted = fetched.sorted { product1, product2 in
                let tier1 = SubscriptionProductTier(productID: product1.id)
                let tier2 = SubscriptionProductTier(productID: product2.id)
                return (tier1?.sortOrder ?? 0) < (tier2?.sortOrder ?? 0)
            }
            self.availableProducts = sorted
            return sorted
        } catch {
            throw SubscriptionError.networkError(
                "Failed to fetch products from App Store: \(error.localizedDescription)"
            )
        }
    }

    func product(for tier: SubscriptionProductTier) async throws -> Product {
        if let cached = availableProducts.first(where: { $0.id == tier.productID }) {
            return cached
        }
        let fetched = try await loadProducts()
        if let match = fetched.first(where: { $0.id == tier.productID }) {
            return match
        }
        throw SubscriptionError.productNotFound(tier.productID)
    }

    // MARK: - Transaction Listener

    func startTransactionListener() async {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            guard let self else { return }
            await self.listenForTransactions()
        }
    }

    func stopTransactionListener() async {
        updatesTask?.cancel()
        updatesTask = nil
    }

    func listenForTransactions() async {
        for await result in Transaction.updates {
            do {
                let transaction = try checkVerified(result)
                await transaction.finish()
                _ = await refreshEntitlements()
            } catch {
                // Cryptographic verification failed; do not finish, do not unlock.
            }
        }
    }

    // MARK: - Entitlements Refresh

    func refreshEntitlements() async -> SubscriptionEntitlementStatus {
        var highestTier: SubscriptionProductTier?
        var highestExpirationDate: Date?
        var hasLifetime = false
        var lifetimePurchaseDate: Date?
        var lifetimeTxID: UInt64?
        var activeInTrial = false
        var activeAutoRenew = true
        var activeOriginalPurchaseDate: Date?
        var activeLatestTxID: UInt64?

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else {
                continue
            }

            if transaction.revocationDate != nil {
                continue
            }

            guard let tier = SubscriptionProductTier(productID: transaction.productID) else {
                continue
            }

            if tier == .lifetime {
                hasLifetime = true
                lifetimePurchaseDate = transaction.purchaseDate
                lifetimeTxID = transaction.id
            } else if tier.isSubscription {
                if let expiration = transaction.expirationDate, expiration > Date() {
                    let shouldSelectTier: Bool
                    if let existing = highestTier {
                        shouldSelectTier = tier.sortOrder > existing.sortOrder
                    } else {
                        shouldSelectTier = true
                    }

                    if shouldSelectTier {
                        highestTier = tier
                        highestExpirationDate = expiration
                        activeInTrial = transaction.offer?.type == .introductory
                        activeOriginalPurchaseDate = transaction.originalPurchaseDate
                        activeLatestTxID = transaction.id

                        if let product = availableProducts.first(where: { $0.id == tier.productID }),
                           let statuses = try? await product.subscription?.status {
                            for status in statuses {
                                if case .verified(let renewalInfo) = status.renewalInfo {
                                    activeAutoRenew = renewalInfo.willAutoRenew
                                }
                            }
                        }
                    }
                }
            }
        }

        let newStatus: SubscriptionEntitlementStatus
        if hasLifetime {
            newStatus = .lifetime(
                purchaseDate: lifetimePurchaseDate ?? Date(),
                transactionID: lifetimeTxID
            )
        } else if let activeTier = highestTier, let expiration = highestExpirationDate {
            newStatus = .active(
                tier: activeTier,
                expirationDate: expiration,
                isInTrial: activeInTrial,
                isAutoRenewOn: activeAutoRenew,
                originalPurchaseDate: activeOriginalPurchaseDate,
                latestTransactionID: activeLatestTxID
            )
        } else {
            newStatus = .inactive
        }

        notifyEntitlementChanged(newStatus)
        return newStatus
    }

    // MARK: - Purchases

    func purchase(_ product: Product) async throws -> PurchaseOutcome {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                _ = await refreshEntitlements()
                return .success(transaction)
            case .pending:
                return .pending
            case .userCancelled:
                return .userCancelled
            @unknown default:
                return .failed(.unknown("Unknown purchase result encountered."))
            }
        } catch let error as SubscriptionError {
            return .failed(error)
        } catch {
            return .failed(.purchaseFailed(error.localizedDescription))
        }
    }

    func purchase(tier: SubscriptionProductTier) async throws -> PurchaseOutcome {
        let targetProduct = try await product(for: tier)
        return try await purchase(targetProduct)
    }

    // MARK: - Restore Purchases

    func restorePurchases() async throws -> SubscriptionEntitlementStatus {
        do {
            try await AppStore.sync()
            return await refreshEntitlements()
        } catch {
            throw SubscriptionError.restoreFailed(
                "Failed to restore App Store purchases: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Verification

    nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let verificationError):
            throw SubscriptionError.unverifiedTransaction(
                "Cryptographic signature check failed: \(verificationError.localizedDescription)"
            )
        case .verified(let safe):
            return safe
        }
    }
}

/// Test and preview mock conforming to `SubscriptionServiceProtocol`.
actor MockSubscriptionService: SubscriptionServiceProtocol {
    private(set) var currentEntitlement: SubscriptionEntitlementStatus = .inactive
    private(set) var availableProducts: [Product] = []

    var availableTiers: [SubscriptionProductTier] {
        if !availableProducts.isEmpty {
            return availableProducts.compactMap { SubscriptionProductTier(productID: $0.id) }
        }
        return SubscriptionProductTier.allCases
    }

    var simulatedOutcome: PurchaseOutcome?
    var simulatedLoadError: Error?
    var simulatedPurchaseError: Error?
    var simulatedRestoreError: Error?

    private var entitlementContinuations: [UUID: AsyncStream<SubscriptionEntitlementStatus>.Continuation] = [:]

    init(initialStatus: SubscriptionEntitlementStatus = .inactive) {
        self.currentEntitlement = initialStatus
    }

    init(initialEntitlement: SubscriptionEntitlementStatus) {
        self.currentEntitlement = initialEntitlement
    }

    var entitlementUpdates: AsyncStream<SubscriptionEntitlementStatus> {
        AsyncStream { continuation in
            let id = UUID()
            self.entitlementContinuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { [weak self] in
                    await self?.removeContinuation(id: id)
                }
            }
            continuation.yield(self.currentEntitlement)
        }
    }

    private func removeContinuation(id: UUID) {
        entitlementContinuations.removeValue(forKey: id)
    }

    func setEntitlement(_ status: SubscriptionEntitlementStatus) {
        self.currentEntitlement = status
        for continuation in entitlementContinuations.values {
            continuation.yield(status)
        }
    }

    func setAvailableProducts(_ products: [Product]) {
        self.availableProducts = products
    }

    func loadProducts() async throws -> [Product] {
        if let error = simulatedLoadError {
            throw error
        }
        return availableProducts
    }

    func product(for tier: SubscriptionProductTier) async throws -> Product {
        if let match = availableProducts.first(where: { $0.id == tier.productID }) {
            return match
        }
        throw SubscriptionError.productNotFound(tier.productID)
    }

    func purchase(_ product: Product) async throws -> PurchaseOutcome {
        if let error = simulatedPurchaseError {
            throw error
        }
        if let outcome = simulatedOutcome {
            if outcome.isSuccess {
                if let tier = SubscriptionProductTier(productID: product.id) {
                    if tier == .lifetime {
                        setEntitlement(.lifetime())
                    } else {
                        setEntitlement(.active(
                            tier: tier,
                            expirationDate: Date().addingTimeInterval(86400 * 30),
                            isInTrial: true,
                            isAutoRenewOn: true
                        ))
                    }
                }
            }
            return outcome
        }
        if let tier = SubscriptionProductTier(productID: product.id) {
            if tier == .lifetime {
                setEntitlement(.lifetime())
            } else {
                setEntitlement(.active(
                    tier: tier,
                    expirationDate: Date().addingTimeInterval(86400 * 30),
                    isInTrial: true,
                    isAutoRenewOn: true
                ))
            }
            return .mockSuccess(tier)
        }
        return .userCancelled
    }

    func purchase(tier: SubscriptionProductTier) async throws -> PurchaseOutcome {
        if let error = simulatedPurchaseError {
            throw error
        }
        if let outcome = simulatedOutcome {
            if outcome.isSuccess {
                if tier == .lifetime {
                    setEntitlement(.lifetime())
                } else {
                    setEntitlement(.active(
                        tier: tier,
                        expirationDate: Date().addingTimeInterval(86400 * 30),
                        isInTrial: true,
                        isAutoRenewOn: true
                    ))
                }
            }
            return outcome
        }
        if tier == .lifetime {
            setEntitlement(.lifetime())
        } else {
            setEntitlement(.active(
                tier: tier,
                expirationDate: Date().addingTimeInterval(86400 * 30),
                isInTrial: true,
                isAutoRenewOn: true
            ))
        }
        return .mockSuccess(tier)
    }

    func refreshEntitlements() async -> SubscriptionEntitlementStatus {
        currentEntitlement
    }

    func restorePurchases() async throws -> SubscriptionEntitlementStatus {
        if let error = simulatedRestoreError {
            throw error
        }
        return currentEntitlement
    }

    func startTransactionListener() async {}
    func stopTransactionListener() async {}
}
