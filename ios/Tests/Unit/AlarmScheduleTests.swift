import Foundation
@testable import SleepParalysisCompanion
import XCTest

final class AlarmScheduleTests: XCTestCase {
    private let calendar: Calendar = {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return value
    }()

    private var sunday: AlarmLocalDate {
        AlarmLocalDate(year: 2026, month: 8, day: 16)
    }

    func testFullScheduleHasIndependentWakePlans() throws {
        let id = try XCTUnwrap(UUID(uuidString: "10000000-0000-4000-8000-000000000001"))
        let schedule = AlarmSchedule(
            id: id,
            name: "Work nights",
            kind: .sleep,
            bedtimeHour: 22,
            bedtimeMinute: 30,
            wakeHour: 6,
            wakeMinute: 30,
            weekdaysMask: 0b0111_1111,
            bedtimeReminderLeadMinutes: 15,
            wakeReminderLeadMinutes: 15,
            finalWakeAlarmEnabled: true
        )

        let plans = WakeAlarmPlanner.plans(for: schedule)

        XCTAssertTrue(schedule.isValid)
        XCTAssertEqual(plans.map(\.role), [.gentleAudio, .finalWake])
        XCTAssertEqual(plans[0].hour, 6)
        XCTAssertEqual(plans[0].minute, 15)
        XCTAssertEqual(plans[1].hour, 6)
        XCTAssertEqual(plans[1].minute, 30)
        XCTAssertNotEqual(plans[0].scheduleSpecificIdentifier, plans[1].scheduleSpecificIdentifier)
    }

    func testSleepBedtimeReminderWrapsToPreviousConcreteDate() {
        let schedule = AlarmSchedule(
            name: "Midnight shift",
            kind: .sleep,
            bedtimeHour: 0,
            bedtimeMinute: 15,
            wakeHour: 7,
            wakeMinute: 0,
            weekdaysMask: 0b0000_0001,
            bedtimeReminderLeadMinutes: 30,
            wakeReminderLeadMinutes: nil,
            finalWakeAlarmEnabled: false
        )

        let occurrences = AlarmScheduleCollisionValidator.project(
            schedule: schedule,
            from: sunday,
            calendar: calendar
        )

        let reminder = occurrences.first { $0.role == .bedtimeReminder }
        XCTAssertEqual(reminder?.date, sunday.addingDays(-1, calendar: calendar))
        XCTAssertEqual(reminder?.minuteOfDay, 23 * 60 + 45)
        XCTAssertEqual(reminder?.weekday, 7)
    }

    func testWakeOnlyOneTimeProducesGentleAndFinalPlans() {
        let date = AlarmLocalDate(year: 2026, month: 8, day: 20)
        let schedule = AlarmSchedule(
            name: "Doctor appointment",
            kind: .wakeOnlyOneTime,
            bedtimeHour: nil,
            bedtimeMinute: nil,
            wakeHour: 6,
            wakeMinute: 30,
            weekdaysMask: 0,
            oneTimeDate: date,
            bedtimeReminderLeadMinutes: nil,
            wakeReminderLeadMinutes: 15,
            finalWakeAlarmEnabled: true
        )

        let plans = WakeAlarmPlanner.plans(for: schedule)

        XCTAssertTrue(schedule.isValid)
        XCTAssertEqual(plans.count, 2)
        XCTAssertEqual(plans[0].role, .gentleAudio)
        XCTAssertEqual(plans[0].date, date)
        XCTAssertEqual(plans[0].minute, 15)
        XCTAssertEqual(plans[1].role, .finalWake)
        XCTAssertEqual(plans[1].date, date)
        XCTAssertEqual(plans[1].minute, 30)
    }

    func testOneTimeGentlePlanWrapsToPreviousDate() {
        let date = AlarmLocalDate(year: 2026, month: 8, day: 20)
        let schedule = AlarmSchedule(
            name: "Early flight",
            kind: .wakeOnlyOneTime,
            bedtimeHour: nil,
            bedtimeMinute: nil,
            wakeHour: 0,
            wakeMinute: 10,
            weekdaysMask: 0,
            oneTimeDate: date,
            bedtimeReminderLeadMinutes: nil,
            wakeReminderLeadMinutes: 15,
            finalWakeAlarmEnabled: true
        )

        let gentle = WakeAlarmPlanner.plans(for: schedule).first { $0.role == .gentleAudio }

        XCTAssertEqual(gentle?.date, date.addingDays(-1, calendar: calendar))
        XCTAssertEqual(gentle?.hour, 23)
        XCTAssertEqual(gentle?.minute, 55)
    }

    func testExactRecurringCollisionIsRejectedButDifferentMinuteIsAllowed() throws {
        let first = recurringWake(name: "Work", hour: 6, minute: 30)
        let second = recurringWake(name: "Backup", hour: 6, minute: 30)

        XCTAssertThrowsError(
            try AlarmScheduleCollisionValidator.validate(
                [first, second],
                from: sunday,
                calendar: calendar
            )
        ) { error in
            guard case let AlarmScheduleValidationError.collision(collision) = error else {
                return XCTFail("Expected an exact generated occurrence collision")
            }
            XCTAssertEqual(collision.first.minuteOfDay, 390)
            XCTAssertEqual(collision.second.minuteOfDay, 390)
        }

        let differentMinute = recurringWake(name: "Backup", hour: 6, minute: 31)
        XCTAssertNoThrow(
            try AlarmScheduleCollisionValidator.validate(
                [first, differentMinute],
                from: sunday,
                calendar: calendar
            )
        )
    }

    func testDisabledSchedulesAreIgnoredForCollisionValidation() {
        let first = recurringWake(name: "Enabled", hour: 6, minute: 30)
        var disabled = recurringWake(name: "Disabled", hour: 6, minute: 30)
        disabled.isEnabled = false

        XCTAssertNoThrow(
            try AlarmScheduleCollisionValidator.validate(
                [first, disabled],
                from: sunday,
                calendar: calendar
            )
        )
        XCTAssertEqual(
            AlarmScheduleCollisionValidator.project(
                schedule: disabled,
                from: sunday,
                calendar: calendar
            ),
            []
        )
    }

    func testOneTimeAndRecurringCollisionUsesConcreteDate() {
        let recurring = recurringWake(name: "Every Thursday", hour: 6, minute: 30)
        let oneTime = AlarmSchedule(
            name: "One time",
            kind: .wakeOnlyOneTime,
            bedtimeHour: nil,
            bedtimeMinute: nil,
            wakeHour: 6,
            wakeMinute: 30,
            weekdaysMask: 0,
            oneTimeDate: AlarmLocalDate(year: 2026, month: 8, day: 20),
            bedtimeReminderLeadMinutes: nil,
            wakeReminderLeadMinutes: nil,
            finalWakeAlarmEnabled: true
        )

        XCTAssertThrowsError(
            try AlarmScheduleCollisionValidator.validate(
                [recurring, oneTime],
                from: sunday,
                calendar: calendar
            )
        )
    }

    func testScheduleLimitAndAudioAvailabilityAreExplicit() {
        XCTAssertEqual(AlarmSchedule.maximumCount, 8)
        var schedules = (0 ..< AlarmSchedule.maximumCount).map {
            recurringWake(name: "Alarm \($0)", hour: 1, minute: $0)
        }
        XCTAssertNoThrow(
            try AlarmScheduleCollisionValidator.validate(
                schedules,
                from: sunday,
                calendar: calendar
            )
        )

        schedules.append(recurringWake(name: "Ninth", hour: 12, minute: 0))
        XCTAssertThrowsError(
            try AlarmScheduleCollisionValidator.validate(
                schedules,
                from: sunday,
                calendar: calendar
            )
        ) { error in
            XCTAssertEqual(
                error as? AlarmScheduleValidationError,
                .maximumSchedulesExceeded(limit: AlarmSchedule.maximumCount)
            )
        }

        let selection = AlarmAudioSelection(
            reference: .personal(clipID: UUID()),
            availability: .unavailableOnThisDevice
        )
        XCTAssertEqual(selection.availability.accessibilityDescription, "Audio unavailable on this device")
    }

    func testReminderIdentifiersAreScheduleSpecific() throws {
        var first = try AlarmSchedule(
            id: XCTUnwrap(UUID(uuidString: "10000000-0000-4000-8000-000000000011")),
            name: "First"
        )
        var second = first
        second = try AlarmSchedule(
            id: XCTUnwrap(UUID(uuidString: "10000000-0000-4000-8000-000000000012")),
            name: "Second"
        )
        first.weekdaysMask = 0b0000_0001
        second.weekdaysMask = 0b0000_0001

        let firstID = SleepReminderPlanner.plans(for: first).single()?.identifier
        let secondID = SleepReminderPlanner.plans(for: second).single()?.identifier

        XCTAssertNotEqual(firstID, secondID)
        XCTAssertTrue(firstID.map { SleepReminderPlanner.owns(identifier: $0, scheduleID: first.id) } == true)
        XCTAssertFalse(firstID.map { SleepReminderPlanner.owns(identifier: $0, scheduleID: second.id) } == true)
    }

    private func recurringWake(name: String, hour: Int, minute: Int) -> AlarmSchedule {
        AlarmSchedule(
            name: name,
            kind: .wakeOnlyRecurring,
            bedtimeHour: nil,
            bedtimeMinute: nil,
            wakeHour: hour,
            wakeMinute: minute,
            weekdaysMask: 0b0001_0000,
            bedtimeReminderLeadMinutes: nil,
            wakeReminderLeadMinutes: nil,
            finalWakeAlarmEnabled: true
        )
    }
}

private extension Collection {
    func single() -> Element? {
        count == 1 ? first : nil
    }
}
