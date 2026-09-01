import Foundation
@testable import SleepParalysisCompanion
import XCTest

actor InMemoryOnboardingStore: OnboardingProfilePersisting {
    private var profile: OnboardingProfile?
    private var createFailuresRemaining: Int
    private var loadShouldFail: Bool
    private(set) var createCallCount = 0
    private(set) var noticeCallCount = 0

    init(
        profile: OnboardingProfile? = nil,
        createFailuresRemaining: Int = 0,
        loadShouldFail: Bool = false
    ) {
        self.profile = profile
        self.createFailuresRemaining = createFailuresRemaining
        self.loadShouldFail = loadShouldFail
    }

    func loadProfile() async throws -> OnboardingProfile? {
        if loadShouldFail {
            throw OnboardingPersistenceError.unavailable
        }
        return profile
    }

    func createGuestProfileIfAbsent(_ value: OnboardingProfile) async throws -> OnboardingProfile {
        createCallCount += 1
        if createFailuresRemaining > 0 {
            createFailuresRemaining -= 1
            throw OnboardingPersistenceError.unavailable
        }
        if let profile {
            return profile
        }
        profile = value
        return value
    }

    func markNoticeSeen(version: String, seenAt: Date) async throws -> OnboardingProfile {
        noticeCallCount += 1
        guard var profile else {
            throw OnboardingPersistenceError.invalidStoredProfile
        }
        profile = OnboardingProfile(
            localProfileID: profile.localProfileID,
            profileCreatedAt: profile.profileCreatedAt,
            productNoticeVersion: version,
            productNoticeSeenAt: seenAt,
            onboardingCompletedAt: profile.onboardingCompletedAt
        )
        self.profile = profile
        return profile
    }

    func storedProfile() -> OnboardingProfile? {
        profile
    }

    func setLoadFailure(_ value: Bool) {
        loadShouldFail = value
    }
}

struct FixedAppDateProvider: AppDateProviding {
    let value: Date

    func now() -> Date {
        value
    }
}

struct FixedAppIdentifierProvider: AppIdentifierProviding {
    let value: UUID

    func makeIdentifier() -> UUID {
        value
    }
}

enum Phase1CFixture {
    static let now = Date(timeIntervalSince1970: 1_753_747_200)
    static let profileID = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        ?? UUID()

    static func profile(
        noticeVersion: String = ProductNotice.currentVersion,
        completed: Bool = true
    ) -> OnboardingProfile {
        OnboardingProfile(
            localProfileID: profileID,
            profileCreatedAt: now,
            productNoticeVersion: noticeVersion,
            productNoticeSeenAt: now,
            onboardingCompletedAt: completed ? now : nil
        )
    }
}

@MainActor
func waitForAppModel(
    _ predicate: @escaping @MainActor () -> Bool,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    for _ in 0 ..< 200 {
        if predicate() {
            return
        }
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
    XCTFail("Timed out waiting for app state.", file: file, line: line)
}

actor ScriptedOAuthSessionService: OAuthSessionServicing {
    nonisolated let isConfigured: Bool
    private var result: Result<AuthenticationSessionMaterial, any Error>
    private var restoreResult: SessionRestoreResult?

    init(
        isConfigured: Bool = true,
        result: Result<AuthenticationSessionMaterial, any Error> = .failure(AuthenticationError.cancelled),
        restoreResult: SessionRestoreResult? = nil
    ) {
        self.isConfigured = isConfigured
        self.result = result
        self.restoreResult = restoreResult
    }

    func restore() async throws -> SessionRestoreResult? {
        restoreResult
    }

    func signIn(provider: AuthenticationProvider) async throws -> AuthenticationSessionMaterial {
        _ = provider
        switch result {
        case let .success(material):
            return material
        case let .failure(error):
            throw error
        }
    }

    func signOut() async throws {}

    func reauthenticateForDeletion() async throws -> ReauthenticatedSession {
        throw AuthenticationError.cancelled
    }
}

actor NoOpReminderScheduler: ReminderNotificationScheduling {
    func authorizationState() async -> ReminderAuthorizationState {
        .authorized
    }

    func requestAuthorization() async throws -> Bool {
        true
    }

    func pendingIdentifiers() async -> [String] {
        []
    }

    func remove(identifiers _: [String]) async {}

    func add(_: SleepReminderPlan) async throws {}
}

func makeTestPhase1Store(namespace: String = "test-\(UUID().uuidString)") -> IntegratedPhase1Store {
    IntegratedPhase1Store(
        location: LocalStoreLocation(namespace: namespace),
        preferences: AccountBoundPreferencesStore(keychain: LockedKeychain())
    )
}

@MainActor
func makeTestAppModel(
    authService: any OAuthSessionServicing = UnavailableOAuthSessionService(),
    store: IntegratedPhase1Store? = nil,
    reminders: SleepReminderService? = nil
) -> AppModel {
    let resolvedStore = store ?? makeTestPhase1Store(namespace: "test-auth-\(UUID().uuidString)")
    let resolvedReminders = reminders ?? SleepReminderService(scheduler: NoOpReminderScheduler())
    return AppModel(
        environment: .development,
        accessPolicy: AccessPolicy(),
        store: resolvedStore,
        authentication: authService,
        reminders: resolvedReminders,
        logger: NoOpPrivacySafeLogger()
    )
}
