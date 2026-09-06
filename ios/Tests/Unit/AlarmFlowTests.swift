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

    func testWakeUpWindowDropdownDefaultsAndPersistence() {
        var schedule = ScheduleUIModel.newSleep
        XCTAssertEqual(schedule.gentleWakeLeadMinutes, 15)
        XCTAssertEqual(schedule.preWakeReminderLeadMinutes, 15)

        let options = [5, 10, 15, 30]
        for lead in options {
            schedule.gentleWakeLeadMinutes = lead
            XCTAssertEqual(schedule.gentleWakeLeadMinutes, lead)
            XCTAssertEqual(schedule.preWakeReminderLeadMinutes, lead)

            let domain = schedule.domainValue(
                profileID: UUID(),
                existing: nil,
                sortOrder: 0
            )
            XCTAssertEqual(domain.wakeReminderLeadMinutes, lead)
        }

        let customDomain = AlarmSchedule(
            id: UUID(),
            name: "Morning Wake",
            kind: .sleep,
            bedtimeHour: 23,
            bedtimeMinute: 0,
            wakeHour: 7,
            wakeMinute: 0,
            weekdaysMask: 0b0111_1111,
            bedtimeReminderLeadMinutes: 15,
            wakeReminderLeadMinutes: 10,
            finalWakeAlarmEnabled: true
        )
        let uiModel = ScheduleUIModel(customDomain)
        XCTAssertEqual(uiModel.gentleWakeLeadMinutes, 10)
    }

    @MainActor
    func testSoundOptionsDeduplication() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)

        let options = model.scheduleAudioOptions
        var seenIDs = Set<String>()
        var seenTitles = Set<String>()
        for option in options {
            XCTAssertFalse(seenIDs.contains(option.id), "Duplicate option id: \(option.id)")
            XCTAssertFalse(seenTitles.contains(option.title.lowercased()), "Duplicate option title: \(option.title)")
            seenIDs.insert(option.id)
            seenTitles.insert(option.title.lowercased())
        }

        let gentleRiseCount = options.filter {
            $0.title.lowercased() == "gentle rise"
                || $0.id.contains("SPCWakeUpGentleLoop")
                || $0.id.contains("felt-dawn")
        }.count
        XCTAssertEqual(gentleRiseCount, 1)
    }

    @MainActor
    func testSnoozeNineMinutesTaskScheduling() {
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
        model.alarmSnoozeTask = nil
    }

    @MainActor
    func testStrictManualStopRequirement() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)

        model.triggerAlarmRinging()
        XCTAssertTrue(model.isAlarmRinging)
        XCTAssertFalse(model.isMorningCheckInPresented)

        // Stays on ringing screen without auto-dismiss
        XCTAssertTrue(model.isAlarmRinging)
        XCTAssertFalse(model.isMorningCheckInPresented)

        // Only explicit stop tap advances to morning check-in
        model.stopAlarm()

        XCTAssertFalse(model.isAlarmRinging)
        XCTAssertTrue(model.isMorningCheckInPresented)
        XCTAssertEqual(model.selectedTab, .sleep)
        XCTAssertTrue(model.path.contains(.morningCheckIn))
    }
}
