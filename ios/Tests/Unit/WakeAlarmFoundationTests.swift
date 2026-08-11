import Foundation
@testable import SleepParalysisCompanion
import XCTest

final class WakeAlarmFoundationTests: XCTestCase {
    func testWakeAlarmPlanStartsAtSelectedLeadTime() {
        var schedule = SleepSchedule.defaultValue
        schedule.wakeHour = 6
        schedule.wakeMinute = 0
        schedule.wakeReminderLeadMinutes = 15
        schedule.weekdaysMask = 0b0111_1111

        let plan = WakeAlarmPlanner.plan(for: schedule)

        XCTAssertEqual(plan?.hour, 5)
        XCTAssertEqual(plan?.minute, 45)
        XCTAssertEqual(plan?.weekdays, [1, 2, 3, 4, 5, 6, 7])
        XCTAssertEqual(plan?.maximumPlaybackSeconds, 15 * 60)
    }

    func testWakeAlarmPlanMovesEarlyMorningWakeToPreviousWeekday() {
        var schedule = SleepSchedule.defaultValue
        schedule.wakeHour = 0
        schedule.wakeMinute = 10
        schedule.wakeReminderLeadMinutes = 15
        schedule.weekdaysMask = 0b0000_0011

        let plan = WakeAlarmPlanner.plan(for: schedule)

        XCTAssertEqual(plan?.hour, 23)
        XCTAssertEqual(plan?.minute, 55)
        XCTAssertEqual(plan?.weekdays, [7, 1])
    }

    func testWakeAlarmPlanIsAbsentWhenWakeAudioIsOff() {
        var schedule = SleepSchedule.defaultValue
        schedule.wakeReminderLeadMinutes = nil

        XCTAssertNil(WakeAlarmPlanner.plan(for: schedule))
    }

    func testLegacyScheduleDecodingLeavesWakeAudioOff() throws {
        let data = Data(
            """
            {
              "sleepHour": 22,
              "sleepMinute": 30,
              "wakeHour": 6,
              "wakeMinute": 30,
              "weekdaysMask": 127,
              "reminderLeadMinutes": 15,
              "isEnabled": true
            }
            """.utf8
        )

        let schedule = try JSONDecoder().decode(SleepSchedule.self, from: data)

        XCTAssertNil(schedule.wakeReminderLeadMinutes)
        XCTAssertTrue(schedule.isValid)
    }
}
