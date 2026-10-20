import Foundation
import XCTest
@testable import SleepParalysisCompanion

@MainActor
final class AppModelAccessPolicyTests: XCTestCase {

    // MARK: - Entitlement Initialization and Reactive Streaming

    func testAppModelInitializesWithInactiveEntitlementAndUpdatesReactively() async {
        let mockService = MockSubscriptionService(initialStatus: .inactive)
        let model = makeTestAppModel(subscriptionService: mockService)

        XCTAssertFalse(model.subscriptionEntitlement.isActive)
        XCTAssertEqual(model.subscriptionEntitlement.premiumAccess, .unavailable)

        model.activate()

        // Wait for activate to complete refresh and subscribe
        await waitForAppModel {
            !model.availableProducts.isEmpty
        }

        // Publish active entitlement update from service
        let activeStatus = SubscriptionEntitlementStatus.active(
            tier: .annual,
            expirationDate: Date().addingTimeInterval(86400 * 365),
            isInTrial: false,
            isAutoRenewOn: true,
        )
        await mockService.setEntitlement(activeStatus)

        // Verify AppModel reactively updates its published state
        await waitForAppModel {
            model.subscriptionEntitlement.isActive && model.subscriptionEntitlement.activeTier == .annual
        }

        XCTAssertTrue(model.subscriptionEntitlement.isActive)
        XCTAssertEqual(model.subscriptionEntitlement.premiumAccess, .active)
        XCTAssertEqual(model.subscriptionEntitlement.activeTier, .annual)
    }

    // MARK: - Capability Access Checking (Gating)

    func testCheckAccessReturnsFalseWhenInactiveAndTrueWhenActive() async {
        let mockService = MockSubscriptionService(initialStatus: .inactive)
        let model = makeTestAppModel(subscriptionService: mockService)

        // When inactive: all premium capabilities must be gated (return false)
        XCTAssertFalse(model.checkAccess(for: .grounding))
        XCTAssertFalse(model.checkAccess(for: .preparation))
        XCTAssertFalse(model.checkAccess(for: .history))

        // Activate entitlement
        await mockService.setEntitlement(.active)
        model.activate()

        await waitForAppModel {
            model.subscriptionEntitlement.isActive
        }

        // When active: all premium capabilities must be granted (return true)
        XCTAssertTrue(model.checkAccess(for: .grounding))
        XCTAssertTrue(model.checkAccess(for: .preparation))
        XCTAssertTrue(model.checkAccess(for: .history))
    }

    // MARK: - Gated Execution

    func testExecuteGatedOpensPaywallWhenInactiveAndExecutesClosureWhenActive() async {
        let mockService = MockSubscriptionService(initialStatus: .inactive)
        let model = makeTestAppModel(subscriptionService: mockService)

        var closureExecuted = false
        XCTAssertFalse(model.isPaywallPresented)

        // When unentitled: closure must not execute; paywall must be presented
        model.executeGated(capability: .history) {
            closureExecuted = true
        }

        XCTAssertFalse(closureExecuted)
        XCTAssertTrue(model.isPaywallPresented)

        // Dismiss paywall
        model.dismissPaywall()
        XCTAssertFalse(model.isPaywallPresented)

        // Test with .preparation (personal audio) when unentitled
        model.executeGated(capability: .preparation) {
            closureExecuted = true
        }
        XCTAssertFalse(closureExecuted)
        XCTAssertTrue(model.isPaywallPresented)

        // Dismiss paywall
        model.dismissPaywall()
        XCTAssertFalse(model.isPaywallPresented)

        // Test with .grounding when unentitled
        model.executeGated(capability: .grounding) {
            closureExecuted = true
        }
        XCTAssertFalse(closureExecuted)
        XCTAssertTrue(model.isPaywallPresented)

        // Now activate premium
        await mockService.setEntitlement(.active)
        model.activate()

        await waitForAppModel {
            model.subscriptionEntitlement.isActive
        }

        // When entitled: closure must execute and paywall remains dismissed
        model.dismissPaywall()
        closureExecuted = false

        model.executeGated(capability: .history) {
            closureExecuted = true
        }

        XCTAssertTrue(closureExecuted)
        XCTAssertFalse(model.isPaywallPresented)

        closureExecuted = false
        model.executeGated(capability: .grounding) {
            closureExecuted = true
        }
        XCTAssertTrue(closureExecuted)
        XCTAssertFalse(model.isPaywallPresented)
    }

    // MARK: - Always Free Utilities Contract

    func testUtilitiesRemainAllowedRegardlessOfEntitlementStatus() async {
        let mockService = MockSubscriptionService(initialStatus: .inactive)
        let model = makeTestAppModel(subscriptionService: mockService)

        let utilities: [AppUtility] = [
            .alarm,
            .privacy,
            .legal,
            .support,
            .dataExport,
            .dataDeletion,
            .accountDeletion,
            .purchaseRestoration,
            .subscriptionManagement,
            .refundHelp,
            .accessStatus,
        ]

        // 1. Inactive status
        for utility in utilities {
            XCTAssertTrue(
                model.checkAccess(for: utility),
                "Utility \(utility) must remain 100% accessible when unentitled.",
            )
            let presentation = AccessPolicyPresenter(policy: model.accessPolicy).utility(utility)
            XCTAssertEqual(
                presentation.decision,
                .allowed,
                "AccessDecision for \(utility) must always be .allowed.",
            )
        }

        // 2. Active status
        await mockService.setEntitlement(.active)
        model.activate()
        await waitForAppModel { model.subscriptionEntitlement.isActive }

        for utility in utilities {
            XCTAssertTrue(
                model.checkAccess(for: utility),
                "Utility \(utility) must remain accessible when entitled.",
            )
        }

        // 3. Revoked status
        await mockService.setEntitlement(.revoked)
        model.activate()
        await waitForAppModel { !model.subscriptionEntitlement.isActive }

        for utility in utilities {
            XCTAssertTrue(
                model.checkAccess(for: utility),
                "Utility \(utility) must remain accessible even when revoked.",
            )
        }
    }

    // MARK: - Purchase Flow & Error Handling

    func testPurchaseFailureSetsUserFacingErrorMessageWithoutLeakingTechnicalTokens() async {
        let mockService = MockSubscriptionService(initialStatus: .inactive)
        let model = makeTestAppModel(subscriptionService: mockService)

        // Simulate purchase failure
        let technicalErrorMessage = "StoreKit.SKErrorDomain Code=0 (raw_token: 0xDEADBEEF, Bearer eyJhbGciOi...)"
        await mockService.setSimulatedPurchaseError(SubscriptionError.purchaseFailed(technicalErrorMessage))

        model.presentPaywall()
        XCTAssertTrue(model.isPaywallPresented)

        await model.purchase(tier: .monthly)

        // Verify paywall remains open, error message is user-facing
        XCTAssertTrue(model.isPaywallPresented)
        guard let errorMsg = model.purchaseErrorMessage else {
            XCTFail("Expected purchaseErrorMessage to be set")
            return
        }

        XCTAssertFalse(errorMsg.isEmpty)
        // Ensure no internal tokens or sensitive prefixes leak
        XCTAssertFalse(errorMsg.contains("eyJ"))
        XCTAssertFalse(errorMsg.contains("0xDEADBEEF"))
        XCTAssertFalse(errorMsg.contains("Bearer"))
        XCTAssertFalse(model.isPurchasing)
    }

    func testPurchaseCancellationLeavesErrorNilAndPaywallPresented() async {
        let mockService = MockSubscriptionService(initialStatus: .inactive)
        let model = makeTestAppModel(subscriptionService: mockService)

        await mockService.setSimulatedOutcome(.userCancelled)
        model.presentPaywall()

        await model.purchase(tier: .annual)

        // Cancellation should not show an error banner
        XCTAssertNil(model.purchaseErrorMessage)
        XCTAssertTrue(model.isPaywallPresented)
        XCTAssertFalse(model.isPurchasing)
        XCTAssertFalse(model.subscriptionEntitlement.isActive)
    }

    func testPurchaseSuccessDismissesPaywallAndClearsErrorMessage() async {
        let mockService = MockSubscriptionService(initialStatus: .inactive)
        let model = makeTestAppModel(subscriptionService: mockService)

        model.presentPaywall()
        XCTAssertTrue(model.isPaywallPresented)

        // Mock purchase succeeds by default in MockSubscriptionService
        await model.purchase(tier: .annual)

        XCTAssertFalse(model.isPaywallPresented)
        XCTAssertNil(model.purchaseErrorMessage)
        XCTAssertFalse(model.isPurchasing)
        XCTAssertTrue(model.subscriptionEntitlement.isActive)
        XCTAssertEqual(model.subscriptionEntitlement.activeTier, .annual)
    }

    // MARK: - Restore Purchases Flow

    func testRestorePurchasesWhenActiveDismissesPaywall() async {
        let activeStatus = SubscriptionEntitlementStatus.lifetime()
        let mockService = MockSubscriptionService(initialStatus: activeStatus)
        let model = makeTestAppModel(subscriptionService: mockService)

        model.presentPaywall()
        XCTAssertTrue(model.isPaywallPresented)

        await model.restorePurchases()

        XCTAssertFalse(model.isPaywallPresented)
        XCTAssertNil(model.purchaseErrorMessage)
        XCTAssertFalse(model.isRestoring)
        XCTAssertTrue(model.subscriptionEntitlement.hasLifetimeAccess)
    }

    func testRestorePurchasesWhenInactiveShowsClearMessage() async {
        let mockService = MockSubscriptionService(initialStatus: .inactive)
        let model = makeTestAppModel(subscriptionService: mockService)

        model.presentPaywall()
        await model.restorePurchases()

        XCTAssertTrue(model.isPaywallPresented)
        XCTAssertEqual(model.purchaseErrorMessage, "No active subscription found to restore.")
        XCTAssertFalse(model.isRestoring)
        XCTAssertFalse(model.subscriptionEntitlement.isActive)
    }

    func testRestorePurchasesWhenErrorShowsUserFriendlyMessage() async {
        let mockService = MockSubscriptionService(initialStatus: .inactive)
        let model = makeTestAppModel(subscriptionService: mockService)

        await mockService.setSimulatedRestoreError(SubscriptionError.restoreFailed("Network timeout"))

        model.presentPaywall()
        await model.restorePurchases()

        XCTAssertTrue(model.isPaywallPresented)
        XCTAssertEqual(model.purchaseErrorMessage, "Network timeout")
        XCTAssertFalse(model.isRestoring)
    }
}

// MARK: - MockSubscriptionService Test Helpers

extension MockSubscriptionService {
    func setSimulatedPurchaseError(_ error: Error?) {
        self.simulatedPurchaseError = error
    }

    func setSimulatedOutcome(_ outcome: PurchaseOutcome?) {
        self.simulatedOutcome = outcome
    }

    func setSimulatedRestoreError(_ error: Error?) {
        self.simulatedRestoreError = error
    }
}
