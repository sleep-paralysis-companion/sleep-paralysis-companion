nonisolated enum AppUtility: Hashable, CaseIterable, Sendable {
    case alarm
    case privacy
    case legal
    case support
    case dataExport
    case dataDeletion
    case accountDeletion
    case purchaseRestoration
    case subscriptionManagement
    case refundHelp
    case accessStatus
}

nonisolated enum ProductCapability: Hashable, Sendable {
    case grounding
    case preparation
    case history
}

nonisolated enum PremiumAccess: Equatable, Sendable {
    case unavailable
    case active
    case unknown
}

nonisolated struct PlatformCapabilities: Equatable, Sendable {
    var supported: Set<ProductCapability>
}

nonisolated struct ReleaseGates: Equatable, Sendable {
    var enabled: Set<ProductCapability>
}

nonisolated struct ExternalAvailability: Equatable, Sendable {
    var available: Set<ProductCapability>
}

nonisolated enum AccessDecision: Equatable, Sendable {
    case allowed
    case unavailable
    case premiumRequired
}

nonisolated struct AccessPolicy: Sendable {
    func decision(
        for utility: AppUtility,
        premium: PremiumAccess
    ) -> AccessDecision {
        _ = utility
        _ = premium
        return .allowed
    }

    func decision(
        for capability: ProductCapability,
        platform: PlatformCapabilities,
        release: ReleaseGates,
        premium: PremiumAccess,
        external: ExternalAvailability
    ) -> AccessDecision {
        guard platform.supported.contains(capability),
              release.enabled.contains(capability),
              external.available.contains(capability)
        else {
            return .unavailable
        }

        return premium == .active ? .allowed : .premiumRequired
    }
}

nonisolated struct AccessPolicyPresentation: Equatable, Sendable {
    let decision: AccessDecision
    let trialEligibility: Bool?
}

nonisolated struct AccessPolicyPresenter: Sendable {
    private let policy: AccessPolicy

    init(policy: AccessPolicy) {
        self.policy = policy
    }

    func utility(_ utility: AppUtility) -> AccessPolicyPresentation {
        AccessPolicyPresentation(
            decision: policy.decision(for: utility, premium: .unknown),
            trialEligibility: nil
        )
    }

    func capability(
        _ capability: ProductCapability,
        platform: PlatformCapabilities,
        release: ReleaseGates,
        premium: PremiumAccess,
        external: ExternalAvailability
    ) -> AccessPolicyPresentation {
        AccessPolicyPresentation(
            decision: policy.decision(
                for: capability,
                platform: platform,
                release: release,
                premium: premium,
                external: external
            ),
            trialEligibility: nil
        )
    }
}
