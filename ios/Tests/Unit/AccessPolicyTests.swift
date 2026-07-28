@testable import SleepParalysisCompanion
import XCTest

final class AccessPolicyTests: XCTestCase {
    private let policy = AccessPolicy()

    func testMandatoryUtilitiesIncludingAlarmIgnorePremiumState() {
        for utility in AppUtility.allCases {
            XCTAssertEqual(
                policy.decision(for: utility, premium: .unavailable),
                .allowed,
                "\(utility) must remain available without premium access."
            )
            XCTAssertEqual(
                policy.decision(for: utility, premium: .unknown),
                .allowed,
                "\(utility) must remain available when premium state is unknown."
            )
        }
    }

    func testCapabilityRequiresAllAvailabilityAuthorities() {
        let capability = ProductCapability.grounding
        let supported = PlatformCapabilities(supported: [capability])
        let released = ReleaseGates(enabled: [capability])
        let available = ExternalAvailability(available: [capability])

        XCTAssertEqual(
            policy.decision(
                for: capability,
                platform: supported,
                release: released,
                premium: .active,
                external: available
            ),
            .allowed
        )
        XCTAssertEqual(
            policy.decision(
                for: capability,
                platform: supported,
                release: ReleaseGates(enabled: []),
                premium: .active,
                external: available
            ),
            .unavailable
        )
    }

    func testPremiumCapabilityNeverGuessesUnknownAccess() {
        let capability = ProductCapability.history
        XCTAssertEqual(
            policy.decision(
                for: capability,
                platform: PlatformCapabilities(supported: [capability]),
                release: ReleaseGates(enabled: [capability]),
                premium: .unknown,
                external: ExternalAvailability(available: [capability])
            ),
            .premiumRequired
        )
    }

    func testPresentationNeverInventsTrialEligibility() {
        let presentation = AccessPolicyPresenter(policy: policy).utility(.alarm)

        XCTAssertEqual(presentation.decision, .allowed)
        XCTAssertNil(presentation.trialEligibility)
    }

    func testPhase1CUnavailableCapabilityHasNoCommerceClaim() {
        let presentation = AccessPolicyPresenter(policy: policy).capability(
            .preparation,
            platform: PlatformCapabilities(supported: []),
            release: ReleaseGates(enabled: []),
            premium: .unknown,
            external: ExternalAvailability(available: [])
        )

        XCTAssertEqual(presentation.decision, .unavailable)
        XCTAssertNil(presentation.trialEligibility)
    }
}
