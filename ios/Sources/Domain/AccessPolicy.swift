enum AppUtility: Hashable, CaseIterable, Sendable {
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

enum ProductCapability: Hashable, Sendable {
    case foundationDetails
    case futureGrounding
    case futureHistory
}

enum PremiumAccess: Equatable, Sendable {
    case unavailable
    case active
    case unknown
}

struct PlatformCapabilities: Equatable, Sendable {
    var supported: Set<ProductCapability>
}

struct ReleaseGates: Equatable, Sendable {
    var enabled: Set<ProductCapability>
}

struct ExternalAvailability: Equatable, Sendable {
    var available: Set<ProductCapability>
}

enum AccessDecision: Equatable, Sendable {
    case allowed
    case unavailable
    case premiumRequired
}

struct AccessPolicy: Sendable {
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

        if capability == .foundationDetails {
            return .allowed
        }

        return premium == .active ? .allowed : .premiumRequired
    }
}
