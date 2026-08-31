import Foundation
@testable import SleepParalysisCompanion
import XCTest

final class NavigationStateTests: XCTestCase {
    func testEverySupportedDeepLinkResolvesToAnExplicitLocalRoute() throws {
        let resolver = DeepLinkResolver()
        let routes: [(String, AppRoute)] = [
            ("spc://grounding", .grounding),
            ("spc://episode", .grounding),
            ("spc://audio", .audioLibrary),
            ("spc://player", .audioPlayer),
            ("spc://audio-player", .audioPlayer),
            ("spc://catalog", .curatedAudioLibrary),
            ("spc://schedule", .alarmHistory),
            ("spc://checkin", .morningCheckIn),
            ("spc://privacy", .dataPrivacy),
            ("spc://help", .helpLegal),
            ("spc://account", .account),
        ]

        for (value, expected) in routes {
            XCTAssertEqual(try resolver.route(for: XCTUnwrap(URL(string: value))), expected)
        }
    }

    func testUnknownOrNonAppDeepLinksAreRejected() throws {
        let resolver = DeepLinkResolver()
        XCTAssertNil(try resolver.route(for: XCTUnwrap(URL(string: "spc://unknown"))))
        XCTAssertNil(try resolver.route(for: XCTUnwrap(URL(string: "https://example.invalid"))))
    }

    func testRestorationRoundTripRequiresMatchingProfileAndCurrentVersion() throws {
        let profileID = UUID()
        let envelope = RouteRestorationEnvelope(
            profileID: profileID,
            selectedTab: .me,
            path: [.dataPrivacy, .helpLegal],
            sheet: .structuredExport
        )
        let codec = RouteRestorationCodec()
        let encoded = try XCTUnwrap(codec.encode(envelope))

        XCTAssertEqual(codec.decode(encoded, profileID: profileID), envelope)
        XCTAssertNil(codec.decode(encoded, profileID: UUID()))
        XCTAssertNil(codec.decode("not-base64", profileID: profileID))
    }

    func testSleepScheduleRejectsInvalidClockAndReminderValues() {
        XCTAssertTrue(SleepSchedule.defaultValue.isValid)

        var invalidHour = SleepSchedule.defaultValue
        invalidHour.sleepHour = 24
        XCTAssertFalse(invalidHour.isValid)

        var invalidMinute = SleepSchedule.defaultValue
        invalidMinute.wakeMinute = 60
        XCTAssertFalse(invalidMinute.isValid)

        var invalidReminder = SleepSchedule.defaultValue
        invalidReminder.reminderLeadMinutes = 7
        XCTAssertFalse(invalidReminder.isValid)
    }

    func testMorningCheckInCanSubmitAfterTheEpisodeAnswerWhenLaterQuestionsAreSkipped() {
        XCTAssertFalse(MorningCheckInForm().canSubmit)
        XCTAssertTrue(MorningCheckInForm(occurrence: .no).canSubmit)
        XCTAssertTrue(MorningCheckInForm(occurrence: .no, sleepHelpOutcome: .audioHelped).canSubmit)
        XCTAssertTrue(MorningCheckInForm(occurrence: .yes).canSubmit)
        XCTAssertTrue(
            MorningCheckInForm(
                occurrence: .yes,
                presentState: .fineNow,
                spcOutcome: .calmer,
                postEpisodeSupport: .calmingAudio
            ).canSubmit
        )
    }

    @MainActor
    func testOAuthCallbackDeepLinkProducesNoNavigationOrFeedback() async throws {
        let resolver = DeepLinkResolver()
        let callbackURL = try XCTUnwrap(URL(string: "spc://auth/callback?code=abc&state=xyz"))

        // Resolver must reject unrouted OAuth callback URL
        XCTAssertNil(resolver.route(for: callbackURL))

        // 1. Signed-out state: openDeepLink produces no navigation change, no feedback banner
        let signedOutModel = makeTestAppModel()
        signedOutModel.activate()
        await waitForAppModel {
            signedOutModel.launchDestination == .splash
        }
        signedOutModel.continueFromSplash()
        signedOutModel.skipIntroduction()
        XCTAssertEqual(signedOutModel.launchDestination, .authentication)
        XCTAssertEqual(signedOutModel.selectedTab, .home)
        XCTAssertEqual(signedOutModel.path, [])
        XCTAssertNil(signedOutModel.feedbackMessage)

        signedOutModel.openDeepLink(callbackURL)

        XCTAssertEqual(signedOutModel.launchDestination, .authentication)
        XCTAssertEqual(signedOutModel.selectedTab, .home)
        XCTAssertEqual(signedOutModel.path, [])
        XCTAssertNil(signedOutModel.feedbackMessage)

        // 2. Signed-in state: openDeepLink produces no navigation change, no feedback banner
        let user = UUID()
        let session = AuthenticationSessionMaterial(
            userID: user,
            provider: .apple,
            accessToken: "test-token",
            refreshToken: "test-refresh",
            expiresAt: Date().addingTimeInterval(3600)
        )
        let store = makeTestPhase1Store(namespace: "test-oauth-cb-\(UUID().uuidString)")
        let snapshot = try await store.resume(session: session)
        _ = try await store.completeQuestionnaire(profileID: snapshot.profile.id, userID: user)
        _ = try await store.saveSchedule(SleepSchedule.defaultValue, profileID: snapshot.profile.id, userID: user)

        let authService = ScriptedOAuthSessionService(result: .success(session))
        let signedInModel = makeTestAppModel(authService: authService, store: store)
        signedInModel.signIn(provider: .apple)

        await waitForAppModel {
            signedInModel.launchDestination == .home
        }
        XCTAssertEqual(signedInModel.launchDestination, .home)

        signedInModel.selectTab(.me)
        signedInModel.open(.helpLegal)
        XCTAssertEqual(signedInModel.selectedTab, .me)
        XCTAssertEqual(signedInModel.path, [.helpLegal])
        XCTAssertNil(signedInModel.feedbackMessage)

        signedInModel.openDeepLink(callbackURL)

        XCTAssertEqual(signedInModel.launchDestination, .home)
        XCTAssertEqual(signedInModel.selectedTab, .me)
        XCTAssertEqual(signedInModel.path, [.helpLegal])
        XCTAssertNil(signedInModel.feedbackMessage)
    }
}
