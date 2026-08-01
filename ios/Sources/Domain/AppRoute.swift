import Foundation

nonisolated enum AppTab: String, CaseIterable, Codable, Hashable, Sendable {
    case home
    case history
    case settings
}

nonisolated enum AppRoute: String, CaseIterable, Codable, Hashable, Sendable {
    case grounding
    case audioLibrary
    case sleepSchedule
    case morningCheckIn
    case checkInDetail
    case editQuestionnaire
    case accessibility
    case dataPrivacy
    case helpLegal
    case account
}

nonisolated enum AppSheet: String, Codable, Hashable, Identifiable, Sendable {
    case audioImport
    case structuredExport

    var id: String {
        rawValue
    }
}

nonisolated enum LaunchDestination: Equatable, Sendable {
    case loading
    case splash
    case introduction(Int)
    case authentication
    case question(QuestionnaireQuestion)
    case recommendedSetup
    case personalAudio
    case sleepSchedule
    case home
    case recoverableError
}

nonisolated enum AccountAccessState: Equatable, Sendable {
    case signedOut
    case signedInMatching
    case wrongAccount
    case authenticationRequired
    case expired
}

/// Retained only so superseded source/evidence fixtures remain buildable.
nonisolated enum ProductNoticePresentation: Equatable, Sendable {
    case initial
    case updated
}

nonisolated struct RouteRestorationEnvelope: Codable, Equatable, Sendable {
    static let currentVersion = 2

    let version: Int
    let profileID: UUID
    let selectedTab: AppTab
    let path: [AppRoute]
    let sheet: AppSheet?

    init(profileID: UUID, selectedTab: AppTab, path: [AppRoute], sheet: AppSheet?) {
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
        guard url.scheme?.lowercased() == "spc" else { return nil }
        return switch url.host?.lowercased() {
        case "grounding", "episode": .grounding
        case "audio": .audioLibrary
        case "schedule": .sleepSchedule
        case "checkin": .morningCheckIn
        case "privacy": .dataPrivacy
        case "help": .helpLegal
        case "account": .account
        default: nil
        }
    }
}
