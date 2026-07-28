import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    private(set) var launchDestination = LaunchDestination.loading
    private(set) var path: [AppRoute] = []
    private(set) var selectedTab = AppTab.home
    private(set) var presentedSheet: AppSheet?
    private(set) var isProcessingOnboarding = false
    private(set) var feedbackMessage: String?
    private(set) var accountAccessState = AccountAccessState.guest
    private(set) var profileID: UUID?

    let environment: AppEnvironment
    let accessPolicy: AccessPolicy

    private let profileStore: any OnboardingProfilePersisting
    private let dateProvider: any AppDateProviding
    private let identifierProvider: any AppIdentifierProviding
    private let logger: any PrivacySafeLogging
    private let restorationCodec: RouteRestorationCodec
    private let deepLinkResolver: DeepLinkResolver

    @ObservationIgnored
    private var activationTask: Task<Void, Never>?
    @ObservationIgnored
    private var onboardingTask: Task<Void, Never>?

    init(
        environment: AppEnvironment,
        accessPolicy: AccessPolicy,
        profileStore: any OnboardingProfilePersisting,
        dateProvider: any AppDateProviding = SystemAppDateProvider(),
        identifierProvider: any AppIdentifierProviding = SystemAppIdentifierProvider(),
        logger: any PrivacySafeLogging,
        restorationCodec: RouteRestorationCodec = RouteRestorationCodec(),
        deepLinkResolver: DeepLinkResolver = DeepLinkResolver()
    ) {
        self.environment = environment
        self.accessPolicy = accessPolicy
        self.profileStore = profileStore
        self.dateProvider = dateProvider
        self.identifierProvider = identifierProvider
        self.logger = logger
        self.restorationCodec = restorationCodec
        self.deepLinkResolver = deepLinkResolver
    }

    var restorationValue: String {
        guard let profileID, launchDestination == .home else {
            return ""
        }
        let envelope = RouteRestorationEnvelope(
            profileID: profileID,
            selectedTab: selectedTab,
            path: path,
            sheet: presentedSheet
        )
        return restorationCodec.encode(envelope) ?? ""
    }

    func activate(restoredState: String = "") {
        activationTask?.cancel()
        launchDestination = .loading
        activationTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            do {
                let profile = try await profileStore.loadProfile()
                guard !Task.isCancelled else {
                    return
                }
                applyLaunch(profile: profile, restoredState: restoredState)
                logger.record(.appActivated, category: .lifecycle)
            } catch {
                guard !Task.isCancelled else {
                    return
                }
                launchDestination = .recoverableError
                feedbackMessage = String(localized: "feedback.database.unavailable")
            }
        }
    }

    func deactivate() {
        activationTask?.cancel()
        activationTask = nil
        onboardingTask?.cancel()
        onboardingTask = nil
        logger.record(.appDeactivated, category: .lifecycle)
    }

    func send(_ intent: Intent) {
        switch intent {
        case .continueFromWelcome, .continueFromProductNotice, .retryLaunch:
            handleOnboarding(intent)
        case .open, .openDeepLink, .setPath, .selectTab, .present, .dismissSheet:
            handleNavigation(intent)
        case .authenticationChanged, .clearFeedback:
            handleContext(intent)
        }
    }

    private func handleOnboarding(_ intent: Intent) {
        switch intent {
        case .continueFromWelcome:
            guard launchDestination == .welcome else {
                return
            }
            feedbackMessage = nil
            launchDestination = .productNotice(.initial)
            resetNavigation()
        case .continueFromProductNotice:
            continueFromProductNotice()
        case .retryLaunch:
            activate()
        default:
            break
        }
    }

    private func handleNavigation(_ intent: Intent) {
        switch intent {
        case let .open(route):
            open(route)
        case let .openDeepLink(url):
            guard let route = deepLinkResolver.route(for: url) else {
                resetNavigation()
                return
            }
            open(route)
        case let .setPath(newPath):
            setPath(newPath)
        case let .selectTab(tab):
            selectedTab = tab
            path = []
            logger.record(.routeChanged, category: .navigation)
        case let .present(sheet):
            presentedSheet = sheet
        case .dismissSheet:
            presentedSheet = nil
        default:
            break
        }
    }

    private func handleContext(_ intent: Intent) {
        switch intent {
        case let .authenticationChanged(state):
            accountAccessState = state
            if state == .wrongAccount || state == .authenticationRequired {
                feedbackMessage = String(localized: "feedback.account.protected")
            }
        case .clearFeedback:
            feedbackMessage = nil
        default:
            break
        }
    }

    private func applyLaunch(profile: OnboardingProfile?, restoredState: String) {
        feedbackMessage = nil
        guard let profile else {
            profileID = nil
            launchDestination = .welcome
            resetNavigation()
            return
        }
        profileID = profile.localProfileID
        guard profile.onboardingCompletedAt != nil else {
            launchDestination = .productNotice(.initial)
            resetNavigation()
            return
        }
        guard profile.productNoticeVersion == ProductNotice.currentVersion else {
            launchDestination = .productNotice(.updated)
            resetNavigation()
            return
        }
        launchDestination = .home
        restore(restoredState, profileID: profile.localProfileID)
    }

    private func continueFromProductNotice() {
        guard !isProcessingOnboarding else {
            return
        }
        switch launchDestination {
        case .productNotice(.initial):
            createGuestProfile()
        case .productNotice(.updated):
            updateProductNotice()
        default:
            return
        }
    }

    private func createGuestProfile() {
        isProcessingOnboarding = true
        feedbackMessage = nil
        let now = dateProvider.now()
        let profile = OnboardingProfile(
            localProfileID: identifierProvider.makeIdentifier(),
            profileCreatedAt: now,
            productNoticeVersion: ProductNotice.currentVersion,
            productNoticeSeenAt: now,
            onboardingCompletedAt: now
        )
        onboardingTask?.cancel()
        onboardingTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            do {
                let stored = try await profileStore.createGuestProfileIfAbsent(profile)
                guard !Task.isCancelled else {
                    return
                }
                profileID = stored.localProfileID
                isProcessingOnboarding = false
                launchDestination = .home
                resetNavigation()
            } catch {
                guard !Task.isCancelled else {
                    return
                }
                isProcessingOnboarding = false
                feedbackMessage = String(localized: "feedback.database.retry")
            }
        }
    }

    private func updateProductNotice() {
        isProcessingOnboarding = true
        feedbackMessage = nil
        let now = dateProvider.now()
        onboardingTask?.cancel()
        onboardingTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            do {
                let stored = try await profileStore.markNoticeSeen(
                    version: ProductNotice.currentVersion,
                    seenAt: now
                )
                guard !Task.isCancelled else {
                    return
                }
                profileID = stored.localProfileID
                isProcessingOnboarding = false
                launchDestination = .home
                resetNavigation()
            } catch {
                guard !Task.isCancelled else {
                    return
                }
                isProcessingOnboarding = false
                feedbackMessage = String(localized: "feedback.database.retry")
            }
        }
    }

    private func open(_ route: AppRoute) {
        guard profileID != nil || isNoticeUtility(route) else {
            return
        }
        guard launchDestination == .home || isNoticeUtility(route) else {
            return
        }
        path.append(route)
        logger.record(.routeChanged, category: .navigation)
    }

    private func setPath(_ newPath: [AppRoute]) {
        guard launchDestination == .home else {
            path = newPath.filter(isNoticeUtility)
            return
        }
        path = newPath
        logger.record(.routeChanged, category: .navigation)
    }

    private func restore(_ value: String, profileID: UUID) {
        guard let envelope = restorationCodec.decode(value, profileID: profileID) else {
            resetNavigation()
            return
        }
        selectedTab = envelope.selectedTab
        path = envelope.path
        presentedSheet = envelope.sheet
    }

    private func resetNavigation() {
        selectedTab = .home
        path = []
        presentedSheet = nil
    }

    private func isNoticeUtility(_ route: AppRoute) -> Bool {
        route == .alarm || route == .dataPrivacy || route == .helpLegal
    }

    enum Intent: Sendable {
        case continueFromWelcome
        case continueFromProductNotice
        case retryLaunch
        case open(AppRoute)
        case openDeepLink(URL)
        case setPath([AppRoute])
        case selectTab(AppTab)
        case present(AppSheet)
        case dismissSheet
        case authenticationChanged(AccountAccessState)
        case clearFeedback
    }
}
