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

    func testWakeAlarmDueDetectionForRecurringSchedule() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        // Create a recurring alarm for Tuesday (weekday 3 in Gregorian calendar) at 07:30
        let schedule = AlarmSchedule(
            id: UUID(),
            name: "Morning Wake",
            kind: .wakeOnlyRecurring,
            wakeHour: 7,
            wakeMinute: 30,
            weekdaysMask: 1 << 2, // Tuesday (bit 2)
            finalWakeAlarmEnabled: true,
            isEnabled: true
        )

        // Date on Tuesday at 07:30:00
        var components = DateComponents()
        components.calendar = calendar
        components.year = 2026
        components.month = 9
        components.day = 8 // Tuesday
        components.hour = 7
        components.minute = 30
        components.second = 0
        let matchingDate = try XCTUnwrap(calendar.date(from: components))

        XCTAssertTrue(WakeAlarmPlanner.isWakeAlarmDue(for: schedule, at: matchingDate, calendar: calendar))

        // Non-matching minute: 07:31
        components.minute = 31
        let nonMatchingMinute = try XCTUnwrap(calendar.date(from: components))
        XCTAssertFalse(WakeAlarmPlanner.isWakeAlarmDue(for: schedule, at: nonMatchingMinute, calendar: calendar))

        // Non-matching weekday: Wednesday Sept 9 at 07:30
        components.day = 9
        components.minute = 30
        let nonMatchingDay = try XCTUnwrap(calendar.date(from: components))
        XCTAssertFalse(WakeAlarmPlanner.isWakeAlarmDue(for: schedule, at: nonMatchingDay, calendar: calendar))

        // Disabled schedule
        var disabledSchedule = schedule
        disabledSchedule.isEnabled = false
        XCTAssertFalse(WakeAlarmPlanner.isWakeAlarmDue(for: disabledSchedule, at: matchingDate, calendar: calendar))
    }

    func testWakeAlarmDueDetectionForOneTimeSchedule() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let targetDate = AlarmLocalDate(year: 2026, month: 9, day: 15)
        let schedule = AlarmSchedule(
            id: UUID(),
            name: "Dentist Wake",
            kind: .wakeOnlyOneTime,
            wakeHour: 8,
            wakeMinute: 0,
            weekdaysMask: 0,
            oneTimeDate: targetDate,
            finalWakeAlarmEnabled: true,
            isEnabled: true
        )

        var components = DateComponents()
        components.calendar = calendar
        components.year = 2026
        components.month = 9
        components.day = 15
        components.hour = 8
        components.minute = 0
        components.second = 15
        let matchingDate = try XCTUnwrap(calendar.date(from: components))

        XCTAssertTrue(WakeAlarmPlanner.isWakeAlarmDue(for: schedule, at: matchingDate, calendar: calendar))

        // Wrong day
        components.day = 16
        let wrongDay = try XCTUnwrap(calendar.date(from: components))
        XCTAssertFalse(WakeAlarmPlanner.isWakeAlarmDue(for: schedule, at: wrongDay, calendar: calendar))
    }

    func testOccurrenceMinuteKeyDeduplication() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let id = UUID()
        var components = DateComponents()
        components.calendar = calendar
        components.year = 2026
        components.month = 9
        components.day = 8
        components.hour = 7
        components.minute = 30
        components.second = 5
        let date1 = try XCTUnwrap(calendar.date(from: components))

        components.second = 45
        let date2 = try XCTUnwrap(calendar.date(from: components))

        components.minute = 31
        let date3 = try XCTUnwrap(calendar.date(from: components))

        let key1 = WakeAlarmPlanner.occurrenceMinuteKey(for: id, at: date1, calendar: calendar)
        let key2 = WakeAlarmPlanner.occurrenceMinuteKey(for: id, at: date2, calendar: calendar)
        let key3 = WakeAlarmPlanner.occurrenceMinuteKey(for: id, at: date3, calendar: calendar)

        XCTAssertEqual(key1, key2)
        XCTAssertNotEqual(key1, key3)
        XCTAssertTrue(key1.contains("2026-9-8-7-30"))
    }

    func testNextWakeDateCalculation() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        // Recurring alarm: Tuesday at 07:30
        let recurring = AlarmSchedule(
            id: UUID(),
            name: "Tuesday Alarm",
            kind: .wakeOnlyRecurring,
            wakeHour: 7,
            wakeMinute: 30,
            weekdaysMask: 1 << 2, // Tuesday
            finalWakeAlarmEnabled: true,
            isEnabled: true
        )

        // Tuesday Sept 8, 2026 at 06:00
        var comp = DateComponents()
        comp.calendar = calendar
        comp.timeZone = calendar.timeZone
        comp.year = 2026
        comp.month = 9
        comp.day = 8
        comp.hour = 6
        comp.minute = 0
        comp.second = 0
        let beforeWake = try XCTUnwrap(calendar.date(from: comp))

        let nextFromBefore = WakeAlarmPlanner.nextWakeDate(for: recurring, after: beforeWake, calendar: calendar)
        XCTAssertNotNil(nextFromBefore)
        comp.hour = 7
        comp.minute = 30
        let expectedToday = try XCTUnwrap(calendar.date(from: comp))
        XCTAssertEqual(nextFromBefore, expectedToday)

        // Tuesday Sept 8, 2026 at 08:00 (past wake time -> next Tuesday Sept 15)
        comp.hour = 8
        comp.minute = 0
        let afterWake = try XCTUnwrap(calendar.date(from: comp))

        let nextFromAfter = WakeAlarmPlanner.nextWakeDate(for: recurring, after: afterWake, calendar: calendar)
        XCTAssertNotNil(nextFromAfter)
        comp.day = 15
        comp.hour = 7
        comp.minute = 30
        let expectedNextWeek = try XCTUnwrap(calendar.date(from: comp))
        XCTAssertEqual(nextFromAfter, expectedNextWeek)

        // One-time alarm: Sept 20, 2026 at 09:00
        let oneTime = AlarmSchedule(
            id: UUID(),
            name: "One-Off",
            kind: .wakeOnlyOneTime,
            wakeHour: 9,
            wakeMinute: 0,
            weekdaysMask: 0,
            oneTimeDate: AlarmLocalDate(year: 2026, month: 9, day: 20),
            finalWakeAlarmEnabled: true,
            isEnabled: true
        )

        let nextOneTime = WakeAlarmPlanner.nextWakeDate(for: oneTime, after: beforeWake, calendar: calendar)
        XCTAssertNotNil(nextOneTime)
        comp.day = 20
        comp.hour = 9
        comp.minute = 0
        let expectedOneTime = try XCTUnwrap(calendar.date(from: comp))
        XCTAssertEqual(nextOneTime, expectedOneTime)

        // Disabled schedule should return nil
        var disabled = recurring
        disabled.isEnabled = false
        XCTAssertNil(WakeAlarmPlanner.nextWakeDate(for: disabled, after: beforeWake, calendar: calendar))
    }

    func testWakeAlarmPlansCarryScheduleSnoozeMinutes() {
        let recurring = AlarmSchedule(
            id: UUID(),
            name: "Recurring Snooze 15",
            kind: .sleep,
            bedtimeHour: 22,
            bedtimeMinute: 30,
            wakeHour: 6,
            wakeMinute: 30,
            weekdaysMask: 0b0111_1111,
            wakeReminderLeadMinutes: 15,
            finalWakeAlarmEnabled: true,
            snoozeMinutes: 15,
            isEnabled: true
        )

        let recurringPlans = WakeAlarmPlanner.plans(for: recurring)
        XCTAssertEqual(recurringPlans.count, 2)
        XCTAssertTrue(recurringPlans.allSatisfy { $0.snoozeMinutes == 15 })

        let oneTime = AlarmSchedule(
            id: UUID(),
            name: "One-Time Snooze 5",
            kind: .wakeOnlyOneTime,
            wakeHour: 7,
            wakeMinute: 0,
            weekdaysMask: 0,
            oneTimeDate: AlarmLocalDate(year: 2026, month: 9, day: 20),
            wakeReminderLeadMinutes: 10,
            finalWakeAlarmEnabled: true,
            snoozeMinutes: 5,
            isEnabled: true
        )

        let oneTimePlans = WakeAlarmPlanner.plans(for: oneTime)
        XCTAssertEqual(oneTimePlans.count, 2)
        XCTAssertTrue(oneTimePlans.allSatisfy { $0.snoozeMinutes == 5 })

        let nilSnooze = AlarmSchedule(
            id: UUID(),
            name: "Nil Snooze",
            kind: .sleep,
            bedtimeHour: 23,
            bedtimeMinute: 0,
            wakeHour: 7,
            wakeMinute: 0,
            weekdaysMask: 0b0001_0000,
            wakeReminderLeadMinutes: 15,
            finalWakeAlarmEnabled: true,
            snoozeMinutes: nil,
            isEnabled: true
        )

        let nilPlans = WakeAlarmPlanner.plans(for: nilSnooze)
        XCTAssertEqual(nilPlans.count, 2)
        XCTAssertTrue(nilPlans.allSatisfy { $0.snoozeMinutes == nil })
    }

    func testLegacySleepSchedulePlanHasNilSnoozeMinutes() {
        let schedule = SleepSchedule.defaultValue
        let plan = WakeAlarmPlanner.plan(for: schedule)
        XCTAssertNotNil(plan)
        XCTAssertNil(plan?.snoozeMinutes)
    }

    func testWakeOnlyRecurringScheduleCarriesSnoozeMinutes() {
        let wakeOnly = AlarmSchedule(
            id: UUID(),
            name: "Wake Only Recurring Snooze 10",
            kind: .wakeOnlyRecurring,
            wakeHour: 8,
            wakeMinute: 0,
            weekdaysMask: 0b0011_1110,
            wakeReminderLeadMinutes: 5,
            finalWakeAlarmEnabled: true,
            snoozeMinutes: 10,
            isEnabled: true
        )
        let plans = WakeAlarmPlanner.plans(for: wakeOnly)
        XCTAssertEqual(plans.count, 2)
        XCTAssertTrue(plans.allSatisfy { $0.snoozeMinutes == 10 })
    }

    func testOneTimeScheduleWithNilSnoozeProducesNilSnoozeMinutes() {
        let oneTime = AlarmSchedule(
            id: UUID(),
            name: "One Time Nil Snooze",
            kind: .wakeOnlyOneTime,
            wakeHour: 6,
            wakeMinute: 45,
            weekdaysMask: 0,
            oneTimeDate: AlarmLocalDate(year: 2026, month: 9, day: 21),
            wakeReminderLeadMinutes: nil,
            finalWakeAlarmEnabled: true,
            snoozeMinutes: nil,
            isEnabled: true
        )
        let plans = WakeAlarmPlanner.plans(for: oneTime)
        XCTAssertEqual(plans.count, 1)
        XCTAssertNil(plans.first?.snoozeMinutes)
    }

    func testWakeAlarmPlanEqualityRespectsSnoozeMinutes() {
        let plan5 = WakeAlarmPlan(
            hour: 7,
            minute: 0,
            weekdays: [2, 3, 4, 5, 6],
            maximumPlaybackSeconds: 900,
            snoozeMinutes: 5
        )
        let plan10 = WakeAlarmPlan(
            hour: 7,
            minute: 0,
            weekdays: [2, 3, 4, 5, 6],
            maximumPlaybackSeconds: 900,
            snoozeMinutes: 10
        )
        let planNil = WakeAlarmPlan(
            hour: 7,
            minute: 0,
            weekdays: [2, 3, 4, 5, 6],
            maximumPlaybackSeconds: 900,
            snoozeMinutes: nil
        )

        XCTAssertNotEqual(plan5, plan10)
        XCTAssertNotEqual(plan5, planNil)
        XCTAssertNotEqual(plan10, planNil)
        XCTAssertEqual(
            plan5,
            WakeAlarmPlan(
                hour: 7,
                minute: 0,
                weekdays: [2, 3, 4, 5, 6],
                maximumPlaybackSeconds: 900,
                snoozeMinutes: 5
            )
        )
    }

    func testSleepScheduleGentleAudioOnlyCarriesSnoozeMinutes() {
        let schedule = AlarmSchedule(
            id: UUID(),
            name: "Gentle Audio Only",
            kind: .sleep,
            bedtimeHour: 23,
            bedtimeMinute: 0,
            wakeHour: 7,
            wakeMinute: 0,
            weekdaysMask: 0b0011_1110,
            wakeReminderLeadMinutes: 15,
            finalWakeAlarmEnabled: false,
            snoozeMinutes: 15,
            isEnabled: true
        )
        let plans = WakeAlarmPlanner.plans(for: schedule)
        XCTAssertEqual(plans.count, 1)
        XCTAssertEqual(plans.first?.role, .gentleAudio)
        XCTAssertEqual(plans.first?.snoozeMinutes, 15)
    }

    func testSleepScheduleFinalWakeOnlyCarriesSnoozeMinutes() {
        let schedule = AlarmSchedule(
            id: UUID(),
            name: "Final Wake Only",
            kind: .sleep,
            bedtimeHour: 23,
            bedtimeMinute: 0,
            wakeHour: 7,
            wakeMinute: 0,
            weekdaysMask: 0b0011_1110,
            wakeReminderLeadMinutes: nil,
            finalWakeAlarmEnabled: true,
            snoozeMinutes: 5,
            isEnabled: true
        )
        let plans = WakeAlarmPlanner.plans(for: schedule)
        XCTAssertEqual(plans.count, 1)
        XCTAssertEqual(plans.first?.role, .finalWake)
        XCTAssertEqual(plans.first?.snoozeMinutes, 5)
    }
}
