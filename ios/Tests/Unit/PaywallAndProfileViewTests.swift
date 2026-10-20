import Foundation
import SwiftUI
import XCTest
@testable import SleepParalysisCompanion

@MainActor
final class PaywallAndProfileViewTests: XCTestCase {

    // MARK: - Paywall Presentation & Dismissal

    func testPaywallViewCreationAndDismissal() {
        let model = makeTestAppModel()

        XCTAssertFalse(model.isPaywallPresented)
        model.presentPaywall()
        XCTAssertTrue(model.isPaywallPresented)

        let view = PaywallView(model: model)
        XCTAssertNotNil(view.body)

        model.dismissPaywall()
        XCTAssertFalse(model.isPaywallPresented)
    }

    // MARK: - Paywall Purchase Flow

    func testPaywallPurchaseAnnualSuccessDismissesPaywall() async {
        let mockService = MockSubscriptionService()
        let model = makeTestAppModel(subscriptionService: mockService)

        model.presentPaywall()
        XCTAssertTrue(model.isPaywallPresented)

        await model.purchase(tier: .annual)

        XCTAssertFalse(model.isPaywallPresented)
        XCTAssertNil(model.purchaseErrorMessage)
        XCTAssertTrue(model.subscriptionEntitlement.isActive)
        XCTAssertEqual(model.subscriptionEntitlement.activeTier, .annual)
    }

    func testPaywallPurchaseMonthlySuccessDismissesPaywall() async {
        let mockService = MockSubscriptionService()
        let model = makeTestAppModel(subscriptionService: mockService)

        model.presentPaywall()
        XCTAssertTrue(model.isPaywallPresented)

        await model.purchase(tier: .monthly)

        XCTAssertFalse(model.isPaywallPresented)
        XCTAssertNil(model.purchaseErrorMessage)
        XCTAssertTrue(model.subscriptionEntitlement.isActive)
        XCTAssertEqual(model.subscriptionEntitlement.activeTier, .monthly)
    }

    func testPaywallPurchaseLifetimeSuccessDismissesPaywall() async {
        let mockService = MockSubscriptionService()
        let model = makeTestAppModel(subscriptionService: mockService)

        model.presentPaywall()
        XCTAssertTrue(model.isPaywallPresented)

        await model.purchase(tier: .lifetime)

        XCTAssertFalse(model.isPaywallPresented)
        XCTAssertNil(model.purchaseErrorMessage)
        XCTAssertTrue(model.subscriptionEntitlement.isActive)
        XCTAssertTrue(model.subscriptionEntitlement.hasLifetimeAccess)
    }

    // MARK: - Paywall Restore Flow

    func testPaywallRestoreWhenActiveDismissesPaywall() async {
        let activeStatus = SubscriptionEntitlementStatus.active(
            tier: .annual,
            expirationDate: Date().addingTimeInterval(86400 * 365),
            isInTrial: false,
            isAutoRenewOn: true
        )
        let mockService = MockSubscriptionService(initialStatus: activeStatus)
        let model = makeTestAppModel(subscriptionService: mockService)

        model.presentPaywall()
        XCTAssertTrue(model.isPaywallPresented)

        await model.restorePurchases()

        XCTAssertFalse(model.isPaywallPresented)
        XCTAssertNil(model.purchaseErrorMessage)
        XCTAssertTrue(model.subscriptionEntitlement.isActive)
    }

    func testPaywallRestoreWhenInactiveLeavesPaywallPresentedWithError() async {
        let mockService = MockSubscriptionService(initialStatus: .inactive)
        let model = makeTestAppModel(subscriptionService: mockService)

        model.presentPaywall()
        XCTAssertTrue(model.isPaywallPresented)

        await model.restorePurchases()

        XCTAssertTrue(model.isPaywallPresented)
        XCTAssertEqual(model.purchaseErrorMessage, "No active subscription found to restore.")
    }

    // MARK: - MeProfileView Dynamic Entitlement Rendering

    func testMeProfileViewFreeUserState() {
        let mockService = MockSubscriptionService(initialStatus: .inactive)
        let model = makeTestAppModel(subscriptionService: mockService)

        XCTAssertFalse(model.subscriptionEntitlement.isActive)

        let profileView = MeProfileView(model: model)
        XCTAssertNotNil(profileView.body)

        // Verifying opening paywall from MeProfileView works
        XCTAssertFalse(model.isPaywallPresented)
        model.presentPaywall()
        XCTAssertTrue(model.isPaywallPresented)
    }

    func testMeProfileViewActiveTrialState() {
        let trialStatus = SubscriptionEntitlementStatus.active(
            tier: .annual,
            expirationDate: Date().addingTimeInterval(86400 * 3),
            isInTrial: true,
            isAutoRenewOn: true
        )
        let mockService = MockSubscriptionService(initialStatus: trialStatus)
        let model = makeTestAppModel(subscriptionService: mockService)
        model.subscriptionEntitlement = trialStatus

        XCTAssertTrue(model.subscriptionEntitlement.isActive)
        XCTAssertTrue(model.subscriptionEntitlement.isInTrial)
        XCTAssertEqual(model.subscriptionEntitlement.activeTier, .annual)

        let profileView = MeProfileView(model: model)
        XCTAssertNotNil(profileView.body)
    }

    func testMeProfileViewActiveMonthlyState() {
        let monthlyStatus = SubscriptionEntitlementStatus.active(
            tier: .monthly,
            expirationDate: Date().addingTimeInterval(86400 * 30),
            isInTrial: false,
            isAutoRenewOn: true
        )
        let mockService = MockSubscriptionService(initialStatus: monthlyStatus)
        let model = makeTestAppModel(subscriptionService: mockService)
        model.subscriptionEntitlement = monthlyStatus

        XCTAssertTrue(model.subscriptionEntitlement.isActive)
        XCTAssertFalse(model.subscriptionEntitlement.isInTrial)
        XCTAssertEqual(model.subscriptionEntitlement.activeTier, .monthly)

        let profileView = MeProfileView(model: model)
        XCTAssertNotNil(profileView.body)
    }

    func testMeProfileViewLifetimeState() {
        let lifetimeStatus = SubscriptionEntitlementStatus.lifetime()
        let mockService = MockSubscriptionService(initialStatus: lifetimeStatus)
        let model = makeTestAppModel(subscriptionService: mockService)
        model.subscriptionEntitlement = lifetimeStatus

        XCTAssertTrue(model.subscriptionEntitlement.isActive)
        XCTAssertTrue(model.subscriptionEntitlement.hasLifetimeAccess)

        let profileView = MeProfileView(model: model)
        XCTAssertNotNil(profileView.body)
    }

    // MARK: - Product Tier Definitions & Metadata

    func testSubscriptionTierMetadata() {
        XCTAssertEqual(SubscriptionProductTier.allCases.count, 3)

        XCTAssertEqual(SubscriptionProductTier.annual.productID, "app.sleepcompanion.spc.premium.annual")
        XCTAssertEqual(SubscriptionProductTier.annual.referencePriceUSD, "$59.99")
        XCTAssertTrue(SubscriptionProductTier.annual.hasIntroductoryTrial)
        XCTAssertTrue(SubscriptionProductTier.annual.isSubscription)
        XCTAssertFalse(SubscriptionProductTier.annual.isLifetime)

        XCTAssertEqual(SubscriptionProductTier.monthly.productID, "app.sleepcompanion.spc.premium.monthly")
        XCTAssertEqual(SubscriptionProductTier.monthly.referencePriceUSD, "$8.99")
        XCTAssertTrue(SubscriptionProductTier.monthly.hasIntroductoryTrial)
        XCTAssertTrue(SubscriptionProductTier.monthly.isSubscription)
        XCTAssertFalse(SubscriptionProductTier.monthly.isLifetime)

        XCTAssertEqual(SubscriptionProductTier.lifetime.productID, "app.sleepcompanion.spc.premium.lifetime")
        XCTAssertEqual(SubscriptionProductTier.lifetime.referencePriceUSD, "$149.99")
        XCTAssertFalse(SubscriptionProductTier.lifetime.hasIntroductoryTrial)
        XCTAssertFalse(SubscriptionProductTier.lifetime.isSubscription)
        XCTAssertTrue(SubscriptionProductTier.lifetime.isLifetime)
    }
}
