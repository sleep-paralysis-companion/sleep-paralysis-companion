import Foundation
import StoreKit
import StoreKitTest
import XCTest
@testable import SleepParalysisCompanion

final class StoreKitSubscriptionServiceTests: XCTestCase {
    var session: SKTestSession!
    var service: StoreKitSubscriptionService!

    override func setUp() async throws {
        try await super.setUp()
        // Initialize SKTestSession using the offline Products.storekit configuration
        session = try SKTestSession(configurationFileNamed: "Products")
        session.disableDialogs = true
        session.clearTransactions()
        session.resetToDefaultState()

        service = StoreKitSubscriptionService(autoStartListener: false)
    }

    override func tearDown() async throws {
        await service?.stopTransactionListener()
        service = nil
        session?.clearTransactions()
        session = nil
        try await super.tearDown()
    }

    // MARK: - Product Fetching

    func testProductFetching_returnsAllThreeProductsWithCorrectIdentifiers() async throws {
        let products = try await service.loadProducts()

        XCTAssertEqual(products.count, 3, "Expected exactly 3 products configured in Products.storekit")

        let productIDs = Set(products.map(\.id))
        XCTAssertTrue(productIDs.contains(SubscriptionProductTier.monthly.productID))
        XCTAssertTrue(productIDs.contains(SubscriptionProductTier.annual.productID))
        XCTAssertTrue(productIDs.contains(SubscriptionProductTier.lifetime.productID))

        // Verify monthly tier
        let monthlyProduct = try XCTUnwrap(products.first(where: { $0.id == SubscriptionProductTier.monthly.productID }))
        XCTAssertEqual(monthlyProduct.type, .autoRenewable)
        let monthlySubscription = try XCTUnwrap(monthlyProduct.subscription)
        XCTAssertEqual(monthlySubscription.subscriptionPeriod.unit, .month)
        XCTAssertEqual(monthlySubscription.subscriptionPeriod.value, 1)
        let monthlyIntro = try XCTUnwrap(monthlySubscription.introductoryOffer)
        XCTAssertEqual(monthlyIntro.paymentMode, .freeTrial)
        XCTAssertEqual(monthlyIntro.period.unit, .day)
        XCTAssertEqual(monthlyIntro.period.value, 3)

        // Verify annual tier
        let annualProduct = try XCTUnwrap(products.first(where: { $0.id == SubscriptionProductTier.annual.productID }))
        XCTAssertEqual(annualProduct.type, .autoRenewable)
        let annualSubscription = try XCTUnwrap(annualProduct.subscription)
        XCTAssertEqual(annualSubscription.subscriptionPeriod.unit, .year)
        XCTAssertEqual(annualSubscription.subscriptionPeriod.value, 1)
        let annualIntro = try XCTUnwrap(annualSubscription.introductoryOffer)
        XCTAssertEqual(annualIntro.paymentMode, .freeTrial)
        XCTAssertEqual(annualIntro.period.unit, .day)
        XCTAssertEqual(annualIntro.period.value, 3)

        // Verify lifetime tier
        let lifetimeProduct = try XCTUnwrap(products.first(where: { $0.id == SubscriptionProductTier.lifetime.productID }))
        XCTAssertEqual(lifetimeProduct.type, .nonConsumable)
        XCTAssertNil(lifetimeProduct.subscription)
    }

    // MARK: - Monthly Purchase & Trial

    func testPurchaseMonthlySubscription_activatesTrialAndEntitlement() async throws {
        let initialStatus = await service.currentEntitlement
        XCTAssertFalse(initialStatus.isActive)

        let outcome = try await service.purchase(tier: .monthly)
        guard case .success(let transaction) = outcome else {
            XCTFail("Expected purchase outcome to be .success, got: \(outcome)")
            return
        }

        XCTAssertEqual(transaction.productID, SubscriptionProductTier.monthly.productID)

        let status = await service.currentEntitlement
        XCTAssertTrue(status.isActive)
        XCTAssertEqual(status.activeTier, .monthly)
        XCTAssertTrue(status.isInTrial, "New monthly purchase should activate the 3-day free trial")
        XCTAssertTrue(status.isSubscriptionActive)
        XCTAssertFalse(status.hasLifetimeAccess)
        XCTAssertNotNil(status.expirationDate)
        XCTAssertEqual(status.premiumAccess, .active)
    }

    // MARK: - Annual Purchase & Trial

    func testPurchaseAnnualSubscription_activatesTrialAndEntitlement() async throws {
        let outcome = try await service.purchase(tier: .annual)
        guard case .success(let transaction) = outcome else {
            XCTFail("Expected purchase outcome to be .success, got: \(outcome)")
            return
        }

        XCTAssertEqual(transaction.productID, SubscriptionProductTier.annual.productID)

        let status = await service.currentEntitlement
        XCTAssertTrue(status.isActive)
        XCTAssertEqual(status.activeTier, .annual)
        XCTAssertTrue(status.isInTrial, "New annual purchase should activate the 3-day free trial")
        XCTAssertTrue(status.isSubscriptionActive)
        XCTAssertFalse(status.hasLifetimeAccess)
        XCTAssertNotNil(status.expirationDate)
        XCTAssertEqual(status.premiumAccess, .active)
    }

    // MARK: - Lifetime Purchase

    func testPurchaseLifetime_activatesPermanentEntitlementWithoutTrial() async throws {
        let outcome = try await service.purchase(tier: .lifetime)
        guard case .success(let transaction) = outcome else {
            XCTFail("Expected purchase outcome to be .success, got: \(outcome)")
            return
        }

        XCTAssertEqual(transaction.productID, SubscriptionProductTier.lifetime.productID)

        let status = await service.currentEntitlement
        XCTAssertTrue(status.isActive)
        XCTAssertEqual(status.activeTier, .lifetime)
        XCTAssertFalse(status.isInTrial, "Lifetime access does not have a trial period")
        XCTAssertTrue(status.hasLifetimeAccess)
        XCTAssertFalse(status.isSubscriptionActive)
        XCTAssertNil(status.expirationDate, "Lifetime access should never have an expiration date")
        XCTAssertEqual(status.premiumAccess, .active)
    }

    // MARK: - Subscription Expiration Revocation

    func testEntitlementRevocation_whenSubscriptionExpires() async throws {
        let outcome = try await service.purchase(tier: .monthly)
        XCTAssertTrue(outcome.isSuccess)

        let activeStatus = await service.currentEntitlement
        XCTAssertTrue(activeStatus.isActive)

        // Simulate subscription expiration in StoreKitTest session
        try session.expireSubscription(productIdentifier: SubscriptionProductTier.monthly.productID)

        // Refresh entitlements after expiration
        let refreshedStatus = await service.refreshEntitlements()
        XCTAssertFalse(refreshedStatus.isActive, "Expired subscription must not grant active entitlement")
        XCTAssertNil(refreshedStatus.activeTier)
        XCTAssertEqual(refreshedStatus.premiumAccess, .unavailable)
    }

    // MARK: - Refund Revocation

    func testEntitlementRevocation_whenPurchaseRefunded() async throws {
        let outcome = try await service.purchase(tier: .lifetime)
        guard case .success(let transaction) = outcome else {
            XCTFail("Expected purchase outcome to be .success")
            return
        }

        let activeStatus = await service.currentEntitlement
        XCTAssertTrue(activeStatus.isActive)

        // Simulate refund in StoreKitTest session
        try session.refundTransaction(identifier: Int(transaction.id))

        // Refresh entitlements after refund
        let refundedStatus = await service.refreshEntitlements()
        XCTAssertFalse(refundedStatus.isActive, "Refunded transaction must not grant active entitlement")
        XCTAssertNil(refundedStatus.activeTier)
        XCTAssertEqual(refundedStatus.premiumAccess, .unavailable)
    }

    // MARK: - Restore Purchases Flow

    func testRestorePurchases_restoresExistingEntitlements() async throws {
        // Simulate a purchase outside this service instance (e.g. on another device or prior install)
        _ = try await session.buyProduct(identifier: SubscriptionProductTier.annual.productID)

        // Fresh service instance before restoration
        let newService = StoreKitSubscriptionService(autoStartListener: false)
        let initialStatus = await newService.currentEntitlement
        XCTAssertFalse(initialStatus.isActive, "Service before refresh or restore starts inactive")

        // Trigger restore purchases
        let restoredStatus = try await newService.restorePurchases()
        XCTAssertTrue(restoredStatus.isActive, "Restore purchases must activate valid existing entitlements")
        XCTAssertEqual(restoredStatus.activeTier, .annual)
        XCTAssertEqual(restoredStatus.premiumAccess, .active)
    }

    // MARK: - Domain Models & Enums

    func testSubscriptionProductTier_propertiesAndIdentification() {
        XCTAssertEqual(SubscriptionProductTier.allCases.count, 3)
        XCTAssertEqual(SubscriptionProductTier.allProductIDs.count, 3)

        let monthly = SubscriptionProductTier(productID: "app.sleepcompanion.spc.premium.monthly")
        XCTAssertEqual(monthly, .monthly)
        XCTAssertTrue(monthly?.isSubscription ?? false)
        XCTAssertFalse(monthly?.isLifetime ?? true)
        XCTAssertTrue(monthly?.hasIntroductoryTrial ?? false)

        let annual = SubscriptionProductTier(productID: "app.sleepcompanion.spc.premium.annual")
        XCTAssertEqual(annual, .annual)
        XCTAssertTrue(annual?.isSubscription ?? false)
        XCTAssertFalse(annual?.isLifetime ?? true)
        XCTAssertTrue(annual?.hasIntroductoryTrial ?? false)

        let lifetime = SubscriptionProductTier(productID: "app.sleepcompanion.spc.premium.lifetime")
        XCTAssertEqual(lifetime, .lifetime)
        XCTAssertFalse(lifetime?.isSubscription ?? true)
        XCTAssertTrue(lifetime?.isLifetime ?? false)
        XCTAssertFalse(lifetime?.hasIntroductoryTrial ?? true)

        XCTAssertNil(SubscriptionProductTier(productID: "invalid.tier.id"))
    }

    func testSubscriptionError_descriptionsAvoidTechnicalJargon() {
        let errors: [SubscriptionError] = [
            .productNotFound("id"),
            .unverifiedTransaction("reason"),
            .purchaseFailed(""),
            .restoreFailed(""),
            .networkError(""),
            .userCancelled,
            .unknown("")
        ]

        for error in errors {
            let description = error.errorDescription ?? ""
            XCTAssertFalse(description.isEmpty)
            // Ensure no technical internal jargon leaks
            XCTAssertFalse(description.contains("SKError"))
            XCTAssertFalse(description.contains("JWS"))
            XCTAssertFalse(description.contains("ASN.1"))
        }
    }

    // MARK: - Mock Service Tests

    func testMockSubscriptionService_simulatesTiersAndPurchases() async throws {
        let mock = MockSubscriptionService()
        let initial = await mock.currentEntitlement
        XCTAssertFalse(initial.isActive)

        await mock.setEntitlement(.inactive)
        let cancelOutcome = try await mock.purchase(tier: .monthly)
        guard case .userCancelled = cancelOutcome else {
            XCTFail("Expected default mock outcome to be .userCancelled")
            return
        }

        // Simulate setting lifetime entitlement
        await mock.setEntitlement(.lifetime())
        let lifetimeStatus = await mock.currentEntitlement
        XCTAssertTrue(lifetimeStatus.isActive)
        XCTAssertEqual(lifetimeStatus.activeTier, .lifetime)
        XCTAssertTrue(lifetimeStatus.hasLifetimeAccess)

        // Simulate setting active monthly subscription
        await mock.setEntitlement(.active(
            tier: .monthly,
            expirationDate: Date().addingTimeInterval(3600),
            isInTrial: true,
            isAutoRenewOn: true
        ))
        let monthlyStatus = await mock.currentEntitlement
        XCTAssertTrue(monthlyStatus.isActive)
        XCTAssertEqual(monthlyStatus.activeTier, .monthly)
        XCTAssertTrue(monthlyStatus.isInTrial)
    }
}
