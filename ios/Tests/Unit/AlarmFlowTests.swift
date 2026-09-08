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

    @MainActor
    func testAlarmAudioAssetResolutionFallback() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)

        // Resolving when audio selection is missing or unavailable falls back to default alarm audio
        let uiModel = ScheduleUIModel(
            name: "Custom Sound Alarm",
            kind: .sleep,
            bedtimeHour: 23,
            bedtimeMinute: 0,
            wakeHour: 7,
            wakeMinute: 0,
            repeatWeekdaysMask: 0b0111_1111,
            bedtimeReminderLeadMinutes: nil,
            wakeAudio: .unavailable,
            isEnabled: true
        )

        let resolvedURL = model.resolveAlarmPlaybackURL(target: uiModel, domain: nil)
        XCTAssertNotNil(resolvedURL)
        XCTAssertTrue(resolvedURL?.lastPathComponent.contains("SPCWakeUpGentleLoop") ?? false)

        // SystemAudioAssets resolution fallback
        let nonExistent = SystemAudioAssets.resolveAlarmAudioURL(requestedFileName: "nonexistent_audio_file.caf")
        XCTAssertNotNil(nonExistent?.url)
        XCTAssertTrue(nonExistent?.usedFallback == true)
        XCTAssertTrue(nonExistent?.url.lastPathComponent.contains("SPCWakeUpGentleLoop") ?? false)
    }

    @MainActor
    func testForegroundWallClockAlarmTriggerCalculationAndDeduplication() throws {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let profileID = UUID()
        let userID = UUID()
        model.setSessionForTesting(profileID: profileID, userID: userID)

        // Tuesday (weekday 3 in Gregorian) at 06:45
        let schedule = ScheduleUIModel(
            name: "Early Riser",
            kind: .sleep,
            bedtimeHour: 22,
            bedtimeMinute: 0,
            wakeHour: 6,
            wakeMinute: 45,
            repeatWeekdaysMask: 0b0111_1111, // Every day
            bedtimeReminderLeadMinutes: nil,
            wakeAudio: .bundled(id: SystemAudioAssets.defaultAlarmAssetID, title: "Gentle rise"),
            isEnabled: true
        )
        _ = model.saveScheduleUI(schedule)

        // Non-matching time: Tuesday at 06:44
        var comp = DateComponents()
        comp.calendar = calendar
        comp.year = 2026
        comp.month = 9
        comp.day = 8 // Tuesday
        comp.hour = 6
        comp.minute = 44
        comp.second = 30
        let nonMatchingTime = try XCTUnwrap(calendar.date(from: comp))

        model.checkForegroundAlarmTriggers(at: nonMatchingTime, calendar: calendar)
        XCTAssertFalse(model.isAlarmRinging)

        // Matching time: Tuesday at 06:45:00
        comp.minute = 45
        comp.second = 0
        let matchingTime = try XCTUnwrap(calendar.date(from: comp))

        model.checkForegroundAlarmTriggers(at: matchingTime, calendar: calendar)
        XCTAssertTrue(model.isAlarmRinging)

        // Simulate dismissing the ringing screen without advancing time
        model.snoozeAlarm(minutes: 9)
        XCTAssertFalse(model.isAlarmRinging)

        // Foreground observer ticks again during the same minute: 06:45:15
        comp.second = 15
        let sameMinuteTime = try XCTUnwrap(calendar.date(from: comp))
        model.checkForegroundAlarmTriggers(at: sameMinuteTime, calendar: calendar)

        // Must NOT re-trigger ringing for the same occurrence minute!
        XCTAssertFalse(model.isAlarmRinging)

        model.stopAlarm()
    }

    @MainActor
    func testSnoozeCalculationAndMultipleSnoozeCancellationOnStop() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)

        model.triggerAlarmRinging()
        XCTAssertTrue(model.isAlarmRinging)

        // First Snooze
        model.snoozeAlarm(minutes: 9)
        XCTAssertFalse(model.isAlarmRinging)
        guard let firstSnoozeTask = model.alarmSnoozeTask else {
            XCTFail("Expected active snooze task")
            return
        }
        XCTAssertFalse(firstSnoozeTask.isCancelled)

        // Trigger alarm again (simulating snooze expiration) and snooze a second time
        model.triggerAlarmRinging()
        XCTAssertTrue(model.isAlarmRinging)

        model.snoozeAlarm(minutes: 9)
        XCTAssertFalse(model.isAlarmRinging)
        guard let secondSnoozeTask = model.alarmSnoozeTask else {
            XCTFail("Expected active second snooze task")
            return
        }
        XCTAssertTrue(firstSnoozeTask.isCancelled, "First snooze task must be cancelled when re-snoozed")
        XCTAssertFalse(secondSnoozeTask.isCancelled)

        // Explicit Stop must cancel all snooze tasks, silence audio, and route to morning check-in
        model.stopAlarm()
        XCTAssertFalse(model.isAlarmRinging)
        XCTAssertNil(model.alarmSnoozeTask)
        XCTAssertTrue(secondSnoozeTask.isCancelled)
        XCTAssertEqual(model.selectedTab, .sleep)
        XCTAssertTrue(model.isMorningCheckInPresented)
        XCTAssertTrue(model.path.contains(.morningCheckIn))
    }

    @MainActor
    func testStopAlarmEndsActiveSleepSession() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)

        model.startSleepSession()
        XCTAssertTrue(model.isSleepSessionPresented)

        model.triggerAlarmRinging()
        XCTAssertTrue(model.isAlarmRinging)

        model.stopAlarm()
        XCTAssertFalse(model.isAlarmRinging)
        XCTAssertFalse(model.isSleepSessionPresented)
        XCTAssertEqual(model.selectedTab, .sleep)
        XCTAssertTrue(model.isMorningCheckInPresented)
        XCTAssertTrue(model.path.contains(.morningCheckIn))
    }

    @MainActor
    func testTriggerAlarmRingingClearsModalOverlaysAndPreservesSleepSession() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)

        model.startSleepSession()
        XCTAssertTrue(model.isSleepSessionPresented)
        XCTAssertNotNil(model.sleepSessionStartedAt)

        model.presentedSheet = .audioImport
        XCTAssertNotNil(model.presentedSheet)

        model.triggerAlarmRinging()

        XCTAssertFalse(
            model.isSleepSessionPresented,
            "Sleep session presentation must be dismissed so AlarmRingingView fullScreenCover is not obstructed"
        )
        XCTAssertNil(
            model.presentedSheet,
            "Presented modal sheet must be dismissed before presenting AlarmRingingView"
        )
        XCTAssertNil(
            model.exportURL,
            "Structured export URL must be cleared before presenting AlarmRingingView"
        )
        XCTAssertNil(
            model.audioExportURL,
            "Audio export URL must be cleared before presenting AlarmRingingView"
        )
        XCTAssertTrue(model.isAlarmRinging)
        XCTAssertNotNil(
            model.sleepSessionStartedAt,
            "Sleep session start timestamp must be preserved while alarm is ringing"
        )

        model.stopAlarm()

        XCTAssertFalse(model.isAlarmRinging)
        XCTAssertFalse(model.isSleepSessionPresented)
        XCTAssertNil(
            model.sleepSessionStartedAt,
            "Stopping alarm must terminate the active sleep session"
        )
        XCTAssertEqual(model.selectedTab, .sleep)
        XCTAssertTrue(model.isMorningCheckInPresented)
        XCTAssertTrue(model.path.contains(.morningCheckIn))
    }

    @MainActor
    func testSnoozeWakeUpBypassesMinuteDeduplication() throws {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let profileID = UUID()
        let userID = UUID()
        model.setSessionForTesting(profileID: profileID, userID: userID)

        let schedule = ScheduleUIModel(
            name: "Morning Wake",
            kind: .sleep,
            bedtimeHour: 23,
            bedtimeMinute: 0,
            wakeHour: 7,
            wakeMinute: 0,
            repeatWeekdaysMask: 1 << 2, // Tuesday
            wakeAudio: .bundled(id: SystemAudioAssets.defaultAlarmAssetID, title: "Gentle rise"),
            isEnabled: true
        )
        _ = model.saveScheduleUI(schedule)

        var comp = DateComponents()
        comp.calendar = calendar
        comp.year = 2026
        comp.month = 9
        comp.day = 8
        comp.hour = 7
        comp.minute = 0
        comp.second = 0
        let triggerTime = try XCTUnwrap(calendar.date(from: comp))

        // Initial trigger
        model.triggerAlarmRinging(schedule: schedule, at: triggerTime, calendar: calendar)
        XCTAssertTrue(model.isAlarmRinging)

        // Snooze
        model.snoozeAlarm(minutes: 9)
        XCTAssertFalse(model.isAlarmRinging)

        // Normal trigger at same minute is deduplicated
        model.triggerAlarmRinging(schedule: schedule, at: triggerTime, calendar: calendar, isSnooze: false)
        XCTAssertFalse(model.isAlarmRinging)

        // Snooze expiration wakeup (isSnooze: true) is NOT deduplicated and rings
        model.triggerAlarmRinging(schedule: schedule, at: triggerTime, calendar: calendar, isSnooze: true)
        XCTAssertTrue(model.isAlarmRinging)

        model.stopAlarm()
    }

    @MainActor
    func testStopAlarmEndsMinimizedSleepSession() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)

        model.startSleepSession()
        XCTAssertTrue(model.isSleepSessionPresented)
        model.minimizeSleepSession()
        XCTAssertFalse(model.isSleepSessionPresented)
        XCTAssertNotNil(model.sleepSessionStartedAt)

        model.triggerAlarmRinging()
        XCTAssertTrue(model.isAlarmRinging)

        model.stopAlarm()
        XCTAssertFalse(model.isAlarmRinging)
        XCTAssertNil(model.sleepSessionStartedAt)
        XCTAssertFalse(model.isSleepSessionPresented)
        XCTAssertEqual(model.selectedTab, .sleep)
        XCTAssertTrue(model.isMorningCheckInPresented)
        XCTAssertTrue(model.path.contains(.morningCheckIn))
    }

    @MainActor
    func testAlarmKitDeepLinkDeduplicationAfterForegroundSnooze() throws {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let profileID = UUID()
        let userID = UUID()
        model.setSessionForTesting(profileID: profileID, userID: userID)

        let schedule = ScheduleUIModel(
            name: "Morning Rise",
            kind: .sleep,
            bedtimeHour: 22,
            bedtimeMinute: 0,
            wakeHour: 7,
            wakeMinute: 0,
            repeatWeekdaysMask: 0b0111_1111, // Every day
            bedtimeReminderLeadMinutes: nil,
            wakeAudio: .bundled(id: SystemAudioAssets.defaultAlarmAssetID, title: "Gentle rise"),
            isEnabled: true
        )
        _ = model.saveScheduleUI(schedule)

        // Tuesday at 07:00:05
        var comp = DateComponents()
        comp.calendar = calendar
        comp.year = 2026
        comp.month = 9
        comp.day = 8
        comp.hour = 7
        comp.minute = 0
        comp.second = 5
        let triggerTime = try XCTUnwrap(calendar.date(from: comp))

        model.checkForegroundAlarmTriggers(at: triggerTime, calendar: calendar)
        XCTAssertTrue(model.isAlarmRinging)

        // User snoozes
        model.snoozeAlarm(minutes: 9)
        XCTAssertFalse(model.isAlarmRinging)

        // AlarmKit event arrives at 07:00:15 (same minute)
        // Simulating the minute key already registered for the schedule
        let occurrenceKey = WakeAlarmPlanner.occurrenceMinuteKey(for: schedule.id, at: triggerTime, calendar: calendar)
        XCTAssertTrue(model.firedAlarmMinuteKeys.contains(occurrenceKey))

        // Triggering with the same schedule at the same minute should deduplicate
        model.triggerAlarmRinging(schedule: schedule, at: triggerTime, calendar: calendar)
        XCTAssertFalse(model.isAlarmRinging, "Alarm must not ring twice in the same minute occurrence")

        model.stopAlarm()
    }

    @MainActor
    func testNextUpcomingWakeScheduleProperty() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)

        let profileID = UUID()
        let userID = UUID()
        model.setSessionForTesting(profileID: profileID, userID: userID)

        XCTAssertNil(model.nextUpcomingWakeSchedule)

        let schedule = ScheduleUIModel(
            name: "Upcoming",
            kind: .sleep,
            bedtimeHour: 23,
            bedtimeMinute: 0,
            wakeHour: 6,
            wakeMinute: 30,
            repeatWeekdaysMask: 0b0111_1111, // Every day
            wakeAudio: .bundled(id: SystemAudioAssets.defaultAlarmAssetID, title: "Gentle rise"),
            isEnabled: true
        )
        _ = model.saveScheduleUI(schedule)

        XCTAssertNotNil(model.nextUpcomingWakeSchedule)
        XCTAssertEqual(model.nextUpcomingWakeSchedule?.schedule.wakeHour, 6)
        XCTAssertEqual(model.nextUpcomingWakeSchedule?.schedule.wakeMinute, 30)
    }
}
