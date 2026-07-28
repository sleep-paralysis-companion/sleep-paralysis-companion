import Foundation
@testable import SleepParalysisCompanion
import XCTest

final class NavigationStateTests: XCTestCase {
    @MainActor
    func testCleanInstallRoutesWelcomeThenNoticeThenHome() async {
        let store = InMemoryOnboardingStore()
        let model = makeModel(store: store)

        model.activate()
        await waitForAppModel { model.launchDestination == .welcome }
        model.send(.continueFromWelcome)
        XCTAssertEqual(model.launchDestination, .productNotice(.initial))

        model.send(.continueFromProductNotice)
        await waitForAppModel { model.launchDestination == .home }

        let stored = await store.storedProfile()
        let createCallCount = await store.createCallCount
        XCTAssertEqual(stored, Phase1CFixture.profile())
        XCTAssertEqual(model.profileID, Phase1CFixture.profileID)
        XCTAssertEqual(createCallCount, 1)
    }

    @MainActor
    func testEveryPersistedOnboardingRestorationPointRoutesDeterministically() async {
        let emptyModel = makeModel(store: InMemoryOnboardingStore())
        emptyModel.activate()
        await waitForAppModel { emptyModel.launchDestination == .welcome }

        let partialModel = makeModel(
            store: InMemoryOnboardingStore(profile: Phase1CFixture.profile(completed: false))
        )
        partialModel.activate()
        await waitForAppModel {
            partialModel.launchDestination == .productNotice(.initial)
        }

        let currentModel = makeModel(
            store: InMemoryOnboardingStore(profile: Phase1CFixture.profile())
        )
        currentModel.activate()
        await waitForAppModel { currentModel.launchDestination == .home }

        let updatedModel = makeModel(
            store: InMemoryOnboardingStore(
                profile: Phase1CFixture.profile(noticeVersion: "superseded")
            )
        )
        updatedModel.activate()
        await waitForAppModel {
            updatedModel.launchDestination == .productNotice(.updated)
        }
    }

    @MainActor
    func testDuplicateContinueTapsCreateOneGuestProfile() async {
        let store = InMemoryOnboardingStore()
        let model = makeModel(store: store)
        model.activate()
        await waitForAppModel { model.launchDestination == .welcome }
        model.send(.continueFromWelcome)

        model.send(.continueFromProductNotice)
        model.send(.continueFromProductNotice)
        model.send(.continueFromProductNotice)

        await waitForAppModel { model.launchDestination == .home }
        let createCallCount = await store.createCallCount
        XCTAssertEqual(createCallCount, 1)
    }

    @MainActor
    func testDatabaseFailureRemainsOnNoticeAndRetriesSafely() async {
        let store = InMemoryOnboardingStore(createFailuresRemaining: 1)
        let model = makeModel(store: store)
        model.activate()
        await waitForAppModel { model.launchDestination == .welcome }
        model.send(.continueFromWelcome)
        model.send(.continueFromProductNotice)

        await waitForAppModel {
            model.feedbackMessage != nil && !model.isProcessingOnboarding
        }
        XCTAssertEqual(model.launchDestination, .productNotice(.initial))
        let failedProfile = await store.storedProfile()
        XCTAssertNil(failedProfile)

        model.send(.continueFromProductNotice)
        await waitForAppModel { model.launchDestination == .home }
        let createCallCount = await store.createCallCount
        let storedProfile = await store.storedProfile()
        XCTAssertEqual(createCallCount, 2)
        XCTAssertNotNil(storedProfile)
    }

    @MainActor
    func testSupersededNoticeCanReachAlarmAndPrivacyBeforeAcknowledgement() async {
        let store = InMemoryOnboardingStore(
            profile: Phase1CFixture.profile(noticeVersion: "old")
        )
        let model = makeModel(store: store)
        model.activate()
        await waitForAppModel {
            model.launchDestination == .productNotice(.updated)
        }

        model.send(.open(.alarm))
        model.send(.open(.dataPrivacy))
        XCTAssertEqual(model.path, [.alarm, .dataPrivacy])

        model.send(.continueFromProductNotice)
        await waitForAppModel { model.launchDestination == .home }
        let noticeCallCount = await store.noticeCallCount
        XCTAssertEqual(noticeCallCount, 1)
        XCTAssertTrue(model.path.isEmpty)
    }

    @MainActor
    func testValidRestorationRestoresTabRouteAndSheet() async {
        let envelope = RouteRestorationEnvelope(
            profileID: Phase1CFixture.profileID,
            selectedTab: .settings,
            path: [.dataPrivacy],
            sheet: .accessUnavailable
        )
        let value = RouteRestorationCodec().encode(envelope) ?? ""
        let model = makeModel(
            store: InMemoryOnboardingStore(profile: Phase1CFixture.profile())
        )

        model.activate(restoredState: value)
        await waitForAppModel { model.launchDestination == .home }

        XCTAssertEqual(model.selectedTab, .settings)
        XCTAssertEqual(model.path, [.dataPrivacy])
        XCTAssertEqual(model.presentedSheet, .accessUnavailable)
    }

    @MainActor
    func testMalformedStaleAndFutureRestorationFallsBackToHomeRoot() async {
        let wrongProfile = UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
            ?? UUID()
        let stale = RouteRestorationCodec().encode(
            RouteRestorationEnvelope(
                profileID: wrongProfile,
                selectedTab: .history,
                path: [.helpLegal],
                sheet: nil
            )
        ) ?? ""
        let futureJSON = """
        {"version":99,"profileID":"\(Phase1CFixture.profileID.uuidString)",
        "selectedTab":"settings","path":["future"],"sheet":null}
        """
        let values = [
            "not-base64",
            stale,
            Data(futureJSON.utf8).base64EncodedString(),
        ]

        for value in values {
            let model = makeModel(
                store: InMemoryOnboardingStore(profile: Phase1CFixture.profile())
            )
            model.activate(restoredState: value)
            await waitForAppModel { model.launchDestination == .home }
            XCTAssertEqual(model.selectedTab, .home)
            XCTAssertTrue(model.path.isEmpty)
            XCTAssertNil(model.presentedSheet)
        }
    }

    @MainActor
    func testDeepLinksRejectUnknownSchemesAndResolveKnownLocalDestinations() async throws {
        let model = makeModel(
            store: InMemoryOnboardingStore(profile: Phase1CFixture.profile())
        )
        model.activate()
        await waitForAppModel { model.launchDestination == .home }

        let alarmURL = try XCTUnwrap(URL(string: "spc://alarm"))
        model.send(.openDeepLink(alarmURL))
        XCTAssertEqual(model.path, [.alarm])

        let unknownURL = try XCTUnwrap(URL(string: "https://example.invalid/privacy"))
        model.send(.openDeepLink(unknownURL))
        XCTAssertTrue(model.path.isEmpty)
    }

    @MainActor
    func testWrongAccountAndAuthenticationRequiredDoNotRemoveLocalProfile() async {
        let store = InMemoryOnboardingStore(profile: Phase1CFixture.profile())
        let model = makeModel(store: store)
        model.activate()
        await waitForAppModel { model.launchDestination == .home }

        model.send(.authenticationChanged(.wrongAccount))
        let wrongAccountProfile = await store.storedProfile()
        XCTAssertEqual(model.accountAccessState, .wrongAccount)
        XCTAssertEqual(model.profileID, Phase1CFixture.profileID)
        XCTAssertNotNil(wrongAccountProfile)

        model.send(.authenticationChanged(.authenticationRequired))
        let authenticationRequiredProfile = await store.storedProfile()
        XCTAssertEqual(model.accountAccessState, .authenticationRequired)
        XCTAssertEqual(model.launchDestination, .home)
        XCTAssertNotNil(authenticationRequiredProfile)
    }

    @MainActor
    private func makeModel(store: InMemoryOnboardingStore) -> AppModel {
        AppModel(
            environment: .development,
            accessPolicy: AccessPolicy(),
            profileStore: store,
            dateProvider: FixedAppDateProvider(value: Phase1CFixture.now),
            identifierProvider: FixedAppIdentifierProvider(value: Phase1CFixture.profileID),
            logger: Phase1CRecordingLogger()
        )
    }
}

private struct Phase1CRecordingLogger: PrivacySafeLogging {
    func record(_ event: AppLogEvent, category: AppLogCategory) {
        _ = event
        _ = category
    }
}
