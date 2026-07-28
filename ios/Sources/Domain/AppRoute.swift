import Foundation

nonisolated enum AppTab: String, CaseIterable, Codable, Hashable, Sendable {
    case home
    case history
    case settings
}

nonisolated enum AppRoute: String, CaseIterable, Codable, Hashable, Sendable {
    case alarm
    case grounding
    case preparation
    case permissionEducation
    case syncAccount
    case dataPrivacy
    case helpLegal
}

nonisolated enum AppSheet: String, Codable, Hashable, Identifiable, Sendable {
    case accessUnavailable

    var id: String {
        rawValue
    }
}

nonisolated enum ProductNoticePresentation: Equatable, Sendable {
    case initial
    case updated
}

nonisolated enum LaunchDestination: Equatable, Sendable {
    case loading
    case welcome
    case productNotice(ProductNoticePresentation)
    case home
    case recoverableError
}

nonisolated enum AccountAccessState: Equatable, Sendable {
    case guest
    case signedInMatching
    case wrongAccount
    case authenticationRequired
}

nonisolated struct RouteRestorationEnvelope: Codable, Equatable, Sendable {
    static let currentVersion = 1

    let version: Int
    let profileID: UUID
    let selectedTab: AppTab
    let path: [AppRoute]
    let sheet: AppSheet?

    init(
        profileID: UUID,
        selectedTab: AppTab,
        path: [AppRoute],
        sheet: AppSheet?
    ) {
        version = Self.currentVersion
        self.profileID = profileID
        self.selectedTab = selectedTab
        self.path = path
        self.sheet = sheet
    }
}

nonisolated struct RouteRestorationCodec: Sendable {
    func encode(_ envelope: RouteRestorationEnvelope) -> String? {
        try? JSONEncoder().encode(envelope).base64EncodedString()
    }

    func decode(_ value: String, profileID: UUID) -> RouteRestorationEnvelope? {
        guard let data = Data(base64Encoded: value),
              let envelope = try? JSONDecoder().decode(RouteRestorationEnvelope.self, from: data),
              envelope.version == RouteRestorationEnvelope.currentVersion,
              envelope.profileID == profileID
        else {
            return nil
        }
        return envelope
    }
}

nonisolated struct DeepLinkResolver: Sendable {
    func route(for url: URL) -> AppRoute? {
        guard url.scheme?.lowercased() == "spc" else {
            return nil
        }
        switch url.host?.lowercased() {
        case "alarm":
            return .alarm
        case "privacy":
            return .dataPrivacy
        case "help":
            return .helpLegal
        case "sync":
            return .syncAccount
        default:
            return nil
        }
    }
}
