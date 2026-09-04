import Foundation
@testable import SleepParalysisCompanion
import XCTest

final class AlarmFlowTests: XCTestCase {
    @MainActor
    func testStopAlarmRedirectsDirectlyToMorningCheckIn() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)

        model.triggerAlarmRinging()
        XCTAssertTrue(model.isAlarmRinging)

        model.stopAlarm()

        XCTAssertFalse(model.isAlarmRinging)
        XCTAssertTrue(model.isMorningCheckInPresented)
        XCTAssertEqual(model.selectedTab, .sleep)
        XCTAssertTrue(model.path.contains(.morningCheckIn))
        XCTAssertNil(model.alarmSnoozeTask)
    }

    @MainActor
    func testSnoozeAlarmSilencesWithoutTriggeringCheckIn() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)

        model.triggerAlarmRinging()
        XCTAssertTrue(model.isAlarmRinging)

        model.snoozeAlarm(minutes: 9)

        XCTAssertFalse(model.isAlarmRinging)
        XCTAssertFalse(model.isMorningCheckInPresented)
        XCTAssertNotEqual(model.path.last, .morningCheckIn)
        XCTAssertNotNil(model.alarmSnoozeTask)

        model.alarmSnoozeTask?.cancel()
    }

    func testSimplifiedScheduleUIModelValidation() {
        let namelessSleepSchedule = ScheduleUIModel(
            name: "",
            kind: .sleep,
            bedtimeHour: 23,
            bedtimeMinute: 0,
            wakeHour: 7,
            wakeMinute: 0,
            repeatWeekdaysMask: 0b0111_1111,
            bedtimeReminderLeadMinutes: 15,
            preWakeReminderLeadMinutes: 15,
            wakeAudio: .bundled(id: SystemAudioAssets.defaultAlarmAssetID, title: "Gentle rise"),
            isEnabled: true
        )
        XCTAssertTrue(namelessSleepSchedule.isValid)

        let profileID = UUID()
        let domainSchedule = namelessSleepSchedule.domainValue(
            profileID: profileID,
            existing: nil,
            sortOrder: 0
        )
        XCTAssertEqual(domainSchedule.name, "Sleep schedule")
        XCTAssertTrue(domainSchedule.isValid)

        let namelessWakeSchedule = ScheduleUIModel(
            name: "   ",
            kind: .wakeOnly,
            bedtimeHour: 0,
            bedtimeMinute: 0,
            wakeHour: 8,
            wakeMinute: 15,
            repeatWeekdaysMask: 0,
            bedtimeReminderLeadMinutes: nil,
            preWakeReminderLeadMinutes: nil,
            wakeAudio: .bundled(id: SystemAudioAssets.defaultAlarmAssetID, title: "Gentle rise"),
            isEnabled: true,
            oneTimeDate: Date.now
        )
        XCTAssertTrue(namelessWakeSchedule.isValid)

        let domainWakeSchedule = namelessWakeSchedule.domainValue(
            profileID: profileID,
            existing: nil,
            sortOrder: 1
        )
        XCTAssertEqual(domainWakeSchedule.name, "Wake up")
        XCTAssertTrue(domainWakeSchedule.isValid)

        var invalidTimeSchedule = namelessSleepSchedule
        invalidTimeSchedule.wakeHour = 25
        XCTAssertFalse(invalidTimeSchedule.isValid)

        var zeroDaysSchedule = namelessSleepSchedule
        zeroDaysSchedule.repeatWeekdaysMask = 0
        XCTAssertFalse(zeroDaysSchedule.isValid)
    }

    @MainActor
    func testSaveSchedulePersistsAndUpdatesLegacySummary() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)
        let profileID = UUID()
        let userID = UUID()
        model.setSessionForTesting(profileID: profileID, userID: userID)

        let newSchedule = ScheduleUIModel(
            name: "Weekday Rhythm",
            kind: .sleep,
            bedtimeHour: 22,
            bedtimeMinute: 45,
            wakeHour: 6,
            wakeMinute: 45,
            repeatWeekdaysMask: 0b0011_1110,
            bedtimeReminderLeadMinutes: 15,
            preWakeReminderLeadMinutes: 15,
            wakeAudio: .bundled(id: SystemAudioAssets.defaultAlarmAssetID, title: "Gentle rise"),
            isEnabled: true
        )

        let saved = model.saveScheduleUI(newSchedule)
        XCTAssertTrue(saved)
        XCTAssertEqual(model.selectedTab, .sleep)
        XCTAssertTrue(model.alarmSchedules.contains(where: { $0.id == newSchedule.id }))
        XCTAssertEqual(model.sleepSchedule.sleepHour, 22)
        XCTAssertEqual(model.sleepSchedule.sleepMinute, 45)
        XCTAssertEqual(model.sleepSchedule.wakeHour, 6)
        XCTAssertEqual(model.sleepSchedule.wakeMinute, 45)
    }
}
