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
            ("spc://schedule", .sleepSchedule),
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
}
