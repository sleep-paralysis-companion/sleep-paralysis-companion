import XCTest
@testable import SleepParalysisCompanion

final class AccessPolicyTests: XCTestCase {
    private let policy = AccessPolicy()

    func testMandatoryUtilitiesIgnorePremiumState() {
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
        let capability = ProductCapability.futureGrounding
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
        let capability = ProductCapability.futureHistory
        let platform = PlatformCapabilities(supported: [capability])
        let release = ReleaseGates(enabled: [capability])
        let external = ExternalAvailability(available: [capability])

        XCTAssertEqual(
            policy.decision(
                for: capability,
                platform: platform,
                release: release,
                premium: .unknown,
                external: external
            ),
            .premiumRequired
        )
    }

    func testFoundationDetailsAreNotPremiumGated() {
        let capability = ProductCapability.foundationDetails

        XCTAssertEqual(
            policy.decision(
                for: capability,
                platform: PlatformCapabilities(supported: [capability]),
                release: ReleaseGates(enabled: [capability]),
                premium: .unavailable,
                external: ExternalAvailability(available: [capability])
            ),
            .allowed
        )
    }
}
