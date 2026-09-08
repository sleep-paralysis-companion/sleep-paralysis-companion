import Foundation
@testable import SleepParalysisCompanion
import XCTest

final class SleepTabTonightScheduleTests: XCTestCase {
    @MainActor
    func testTonightScheduleUIModelDefaultsWhenNoSchedules() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)
        let profileID = UUID()
        let userID = UUID()
        model.setSessionForTesting(profileID: profileID, userID: userID)

        XCTAssertTrue(model.alarmSchedules.isEmpty)
        let tonight = model.tonightScheduleUIModel
        XCTAssertEqual(tonight.kind, .sleep)
        XCTAssertEqual(tonight.wakeHour, model.sleepSchedule.wakeHour)
        XCTAssertEqual(tonight.wakeMinute, model.sleepSchedule.wakeMinute)
        XCTAssertTrue(tonight.isValid)
    }

    @MainActor
    func testStableDraftIDWhenEmpty() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)
        let profileID = UUID()
        let userID = UUID()
        model.setSessionForTesting(profileID: profileID, userID: userID)

        let first = model.tonightScheduleUIModel
        let second = model.tonightScheduleUIModel
        XCTAssertEqual(first.id, second.id, "Draft ID must remain stable across reads when empty to prevent collisions")
    }

    @MainActor
    func testTonightScheduleUIModelResolvesActiveSchedule() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)
        let profileID = UUID()
        let userID = UUID()
        model.setSessionForTesting(profileID: profileID, userID: userID)

        let schedule = ScheduleUIModel(
            name: "Tonight Primary",
            kind: .sleep,
            bedtimeHour: 23,
            bedtimeMinute: 15,
            wakeHour: 7,
            wakeMinute: 45,
            repeatWeekdaysMask: 0b0111_1111,
            bedtimeReminderLeadMinutes: 15,
            preWakeReminderLeadMinutes: 15,
            wakeAudio: .bundled(id: SystemAudioAssets.defaultAlarmAssetID, title: "Gentle rise"),
            isEnabled: true
        )

        let saved = model.saveScheduleUI(schedule, autoStartUnwind: false)
        XCTAssertTrue(saved)
        XCTAssertFalse(model.alarmSchedules.isEmpty)

        let tonight = model.tonightScheduleUIModel
        XCTAssertEqual(tonight.name, "Tonight Primary")
        XCTAssertEqual(tonight.bedtimeHour, 23)
        XCTAssertEqual(tonight.bedtimeMinute, 15)
        XCTAssertEqual(tonight.wakeHour, 7)
        XCTAssertEqual(tonight.wakeMinute, 45)
    }

    @MainActor
    func testTonightScheduleNotHijackedBySelectedAlarmScheduleID() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)
        let profileID = UUID()
        let userID = UUID()
        model.setSessionForTesting(profileID: profileID, userID: userID)

        // Schedule 1: Everyday (active tonight)
        let primarySchedule = ScheduleUIModel(
            name: "Primary Everyday",
            kind: .sleep,
            bedtimeHour: 22,
            bedtimeMinute: 30,
            wakeHour: 6,
            wakeMinute: 30,
            repeatWeekdaysMask: 0b0111_1111,
            bedtimeReminderLeadMinutes: 15,
            preWakeReminderLeadMinutes: 15,
            wakeAudio: .bundled(id: SystemAudioAssets.defaultAlarmAssetID, title: "Gentle rise"),
            isEnabled: true
        )
        XCTAssertTrue(model.saveScheduleUI(primarySchedule, autoStartUnwind: false))

        // Schedule 2: Different schedule (e.g. disabled or selected in history)
        let otherSchedule = ScheduleUIModel(
            name: "Other Schedule",
            kind: .sleep,
            bedtimeHour: 23,
            bedtimeMinute: 0,
            wakeHour: 8,
            wakeMinute: 0,
            repeatWeekdaysMask: 0b0100_0000,
            bedtimeReminderLeadMinutes: 15,
            preWakeReminderLeadMinutes: 15,
            wakeAudio: .bundled(id: SystemAudioAssets.defaultAlarmAssetID, title: "Gentle rise"),
            isEnabled: false
        )
        XCTAssertTrue(model.saveScheduleUI(otherSchedule, autoStartUnwind: false))

        // User taps other schedule in Alarm History
        model.editSchedule(otherSchedule)
        XCTAssertEqual(model.selectedScheduleUIModel?.id, otherSchedule.id)

        // Tonight schedule on Sleep tab must still target tonight's primary schedule
        let tonight = model.tonightScheduleUIModel
        XCTAssertEqual(tonight.name, "Primary Everyday")
        XCTAssertEqual(tonight.wakeHour, 6)
        XCTAssertEqual(tonight.wakeMinute, 30)
    }

    @MainActor
    func testSaveTonightScheduleDraftUpdatesInMemoryAndLegacySummary() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)
        let profileID = UUID()
        let userID = UUID()
        model.setSessionForTesting(profileID: profileID, userID: userID)

        var draft = model.tonightScheduleUIModel
        draft.wakeHour = 8
        draft.wakeMinute = 15

        model.saveTonightScheduleDraft(draft, immediate: true)

        XCTAssertEqual(model.tonightScheduleUIModel.wakeHour, 8)
        XCTAssertEqual(model.tonightScheduleUIModel.wakeMinute, 15)
        XCTAssertEqual(model.sleepSchedule.wakeHour, 8)
        XCTAssertEqual(model.sleepSchedule.wakeMinute, 15)
        XCTAssertNil(model.feedbackMessage)
    }

    @MainActor
    func testWakeOnlyScheduleUpdatesLegacySummary() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)
        let profileID = UUID()
        let userID = UUID()
        model.setSessionForTesting(profileID: profileID, userID: userID)

        var draft = model.tonightScheduleUIModel
        draft.kind = .wakeOnly
        draft.wakeHour = 9
        draft.wakeMinute = 30
        draft.oneTimeDate = Calendar.current.date(byAdding: .day, value: 1, to: .now)

        model.saveTonightScheduleDraft(draft, immediate: true)

        XCTAssertEqual(model.tonightScheduleUIModel.kind, .wakeOnly)
        XCTAssertEqual(model.tonightScheduleUIModel.wakeHour, 9)
        XCTAssertEqual(model.tonightScheduleUIModel.wakeMinute, 30)
        XCTAssertEqual(model.sleepSchedule.wakeHour, 9)
        XCTAssertEqual(model.sleepSchedule.wakeMinute, 30)
    }

    @MainActor
    func testToggleTonightSchedule() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)
        let profileID = UUID()
        let userID = UUID()
        model.setSessionForTesting(profileID: profileID, userID: userID)

        model.toggleTonightSchedule(enabled: false)
        XCTAssertFalse(model.tonightScheduleUIModel.isEnabled)
        XCTAssertNil(model.feedbackMessage)

        model.toggleTonightSchedule(enabled: true)
        XCTAssertTrue(model.tonightScheduleUIModel.isEnabled)
        XCTAssertNil(model.feedbackMessage)
    }

    @MainActor
    func testDisablingTonightSchedulePreservesIdentity() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)
        let profileID = UUID()
        let userID = UUID()
        model.setSessionForTesting(profileID: profileID, userID: userID)

        var draft = model.tonightScheduleUIModel
        draft.name = "Custom Tonight"
        model.saveTonightScheduleDraft(draft, immediate: true)

        let initialID = model.tonightScheduleUIModel.id

        // Turn primary alarm toggle OFF
        model.toggleTonightSchedule(enabled: false)

        // Must still be the same schedule in the OFF state, not jump to another
        XCTAssertEqual(model.tonightScheduleUIModel.id, initialID)
        XCTAssertEqual(model.tonightScheduleUIModel.name, "Custom Tonight")
        XCTAssertFalse(model.tonightScheduleUIModel.isEnabled)
    }

    @MainActor
    func testAppHapticsExecution() {
        AppHaptics.preparePageSnap()
        AppHaptics.pageSnap(hapticsEnabled: false)
        AppHaptics.pageSnap(hapticsEnabled: true)
        AppHaptics.stepAdjustment(direction: .increase, hapticsEnabled: true)
        AppHaptics.stepAdjustment(direction: .decrease, hapticsEnabled: true)
        AppHaptics.toggleChanged(isOn: true, hapticsEnabled: true)
        AppHaptics.toggleChanged(isOn: false, hapticsEnabled: false)
        AppHaptics.selectionChanged(hapticsEnabled: true)
    }

    func testDynamicWakeOnlyNextOccurrenceLaterToday() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 8
        components.hour = 14
        components.minute = 30
        components.second = 0
        let now = try XCTUnwrap(calendar.date(from: components))

        // Wake time 16:30 is 2 hours ahead -> later today -> today
        let targetToday = ScheduleUIModel.nextWakeOnlyDate(
            wakeHour: 16,
            wakeMinute: 30,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(calendar.component(.day, from: targetToday), 8)
        XCTAssertEqual(calendar.component(.month, from: targetToday), 9)
        XCTAssertEqual(calendar.component(.year, from: targetToday), 2026)

        // Wake time 14:31 is 1 minute ahead -> later today -> today
        let targetMinuteAhead = ScheduleUIModel.nextWakeOnlyDate(
            wakeHour: 14,
            wakeMinute: 31,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(calendar.component(.day, from: targetMinuteAhead), 8)
    }

    func testDynamicWakeOnlyNextOccurrenceEarlierToday() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 8
        components.hour = 14
        components.minute = 30
        components.second = 0
        let now = try XCTUnwrap(calendar.date(from: components))

        // Wake time 12:30 is 2 hours behind -> already passed -> tomorrow (Sept 9)
        let targetTomorrow = ScheduleUIModel.nextWakeOnlyDate(
            wakeHour: 12,
            wakeMinute: 30,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(calendar.component(.day, from: targetTomorrow), 9)
        XCTAssertEqual(calendar.component(.month, from: targetTomorrow), 9)
        XCTAssertEqual(calendar.component(.year, from: targetTomorrow), 2026)

        // Wake time 14:30 exact minute -> already passed / now -> tomorrow (Sept 9)
        let targetExact = ScheduleUIModel.nextWakeOnlyDate(
            wakeHour: 14,
            wakeMinute: 30,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(calendar.component(.day, from: targetExact), 9)

        // Wake time 14:29 1 minute behind -> tomorrow (Sept 9)
        let targetMinuteBehind = ScheduleUIModel.nextWakeOnlyDate(
            wakeHour: 14,
            wakeMinute: 29,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(calendar.component(.day, from: targetMinuteBehind), 9)
    }

    func testUpdateWakeOnlyNextOccurrenceOnScheduleUIModel() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 8
        components.hour = 10
        components.minute = 0
        let now = try XCTUnwrap(calendar.date(from: components))

        var draft = ScheduleUIModel(
            name: "Wake Test",
            kind: .wakeOnly,
            bedtimeHour: 0,
            bedtimeMinute: 0,
            wakeHour: 12,
            wakeMinute: 0,
            repeatWeekdaysMask: 0,
            bedtimeReminderLeadMinutes: nil,
            wakeAudio: .bundled(id: SystemAudioAssets.defaultAlarmAssetID, title: "Gentle rise"),
            isEnabled: true
        )
        draft.updateWakeOnlyNextOccurrence(now: now, calendar: calendar)
        let firstTarget = try XCTUnwrap(draft.oneTimeDate)
        XCTAssertEqual(calendar.component(.day, from: firstTarget), 8)

        // Change wakeHour to 8 (earlier than 10)
        draft.wakeHour = 8
        draft.updateWakeOnlyNextOccurrence(now: now, calendar: calendar)
        let secondTarget = try XCTUnwrap(draft.oneTimeDate)
        XCTAssertEqual(calendar.component(.day, from: secondTarget), 9)
    }

    @MainActor
    func testOpenAlarmScheduleSummaryNavigatesDirectlyToEditorForTonightSchedule() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)
        let profileID = UUID()
        let userID = UUID()
        model.setSessionForTesting(profileID: profileID, userID: userID)

        // Case 1: No schedules exist
        model.openAlarmScheduleSummary()
        XCTAssertEqual(model.path.last, .alarmScheduleEditor)
        XCTAssertNil(model.selectedAlarmScheduleID)

        // Case 2: Schedule exists
        let schedule = ScheduleUIModel(
            name: "Active Alarm",
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
        XCTAssertTrue(model.saveScheduleUI(schedule, autoStartUnwind: false))
        model.setPath([])

        model.openAlarmScheduleSummary()
        XCTAssertEqual(model.path.last, .alarmScheduleEditor)
        XCTAssertEqual(model.selectedAlarmScheduleID, model.tonightScheduleID)
    }

    func testDynamicWakeOnlyNextOccurrenceMidnightBoundaryAndYearRollover() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt

        // Case A: 23:59 on Dec 31, 2026 for wake time 00:05 -> targets tomorrow (Jan 1, 2027)
        var components = DateComponents()
        components.year = 2026
        components.month = 12
        components.day = 31
        components.hour = 23
        components.minute = 59
        components.second = 30
        let newYearsEve = try XCTUnwrap(calendar.date(from: components))

        let targetNextDay = ScheduleUIModel.nextWakeOnlyDate(
            wakeHour: 0,
            wakeMinute: 5,
            now: newYearsEve,
            calendar: calendar
        )
        XCTAssertEqual(calendar.component(.year, from: targetNextDay), 2027)
        XCTAssertEqual(calendar.component(.month, from: targetNextDay), 1)
        XCTAssertEqual(calendar.component(.day, from: targetNextDay), 1)

        // Case B: 00:01 on Jan 1, 2027 for wake time 00:05 -> later today (Jan 1, 2027)
        components.year = 2027
        components.month = 1
        components.day = 1
        components.hour = 0
        components.minute = 1
        let justAfterMidnight = try XCTUnwrap(calendar.date(from: components))

        let targetLaterToday = ScheduleUIModel.nextWakeOnlyDate(
            wakeHour: 0,
            wakeMinute: 5,
            now: justAfterMidnight,
            calendar: calendar
        )
        XCTAssertEqual(calendar.component(.year, from: targetLaterToday), 2027)
        XCTAssertEqual(calendar.component(.month, from: targetLaterToday), 1)
        XCTAssertEqual(calendar.component(.day, from: targetLaterToday), 1)

        // Case C: Same minute (23:59 for 23:59) -> already started/passed -> next day
        let targetExactMinute = ScheduleUIModel.nextWakeOnlyDate(
            wakeHour: 23,
            wakeMinute: 59,
            now: newYearsEve,
            calendar: calendar
        )
        XCTAssertEqual(calendar.component(.year, from: targetExactMinute), 2027)
        XCTAssertEqual(calendar.component(.day, from: targetExactMinute), 1)
    }

    @MainActor
    func testClearIntermediateScheduleRoutesPreventsNavigationBackStackLeak() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)
        let profileID = UUID()
        let userID = UUID()
        model.setSessionForTesting(profileID: profileID, userID: userID)

        // User navigated: Home -> Alarm History -> Alarm Editor
        model.setPath([.alarmHistory, .alarmScheduleEditor])
        XCTAssertEqual(model.path, [.alarmHistory, .alarmScheduleEditor])

        // Calling clearIntermediateScheduleRoutes removes intermediate schedule routes
        model.clearIntermediateScheduleRoutes()
        XCTAssertTrue(model.path.isEmpty)

        // When autoStartUnwind navigates to .audioPlayer
        model.open(.audioPlayer)
        XCTAssertEqual(model.path, [.audioPlayer])

        // When audioPlayer is popped, user returns directly to Home (path is empty)
        model.setPath(Array(model.path.dropLast()))
        XCTAssertTrue(model.path.isEmpty)
    }

    @MainActor
    func testSaveTonightScheduleDraftReturnsFalseOnCollision() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)
        let profileID = UUID()
        let userID = UUID()
        model.setSessionForTesting(profileID: profileID, userID: userID)

        let first = ScheduleUIModel(
            name: "First Alarm",
            kind: .sleep,
            bedtimeHour: 22,
            bedtimeMinute: 0,
            wakeHour: 6,
            wakeMinute: 30,
            repeatWeekdaysMask: 0b0111_1111,
            bedtimeReminderLeadMinutes: 15,
            preWakeReminderLeadMinutes: 15,
            wakeAudio: .bundled(id: SystemAudioAssets.defaultAlarmAssetID, title: "Gentle rise"),
            isEnabled: true
        )
        XCTAssertTrue(model.saveScheduleUI(first, autoStartUnwind: false))

        // Create conflicting schedule with identical wake and repeat
        let conflicting = ScheduleUIModel(
            name: "Conflicting Alarm",
            kind: .sleep,
            bedtimeHour: 23,
            bedtimeMinute: 0,
            wakeHour: 6,
            wakeMinute: 30,
            repeatWeekdaysMask: 0b0111_1111,
            bedtimeReminderLeadMinutes: 15,
            preWakeReminderLeadMinutes: 15,
            wakeAudio: .bundled(id: SystemAudioAssets.defaultAlarmAssetID, title: "Gentle rise"),
            isEnabled: true
        )

        let saved = model.saveTonightScheduleDraft(conflicting, immediate: true)
        XCTAssertFalse(saved, "saveTonightScheduleDraft must return false on validation collision")
        XCTAssertNotNil(model.feedbackMessage)
        XCTAssertTrue(model.feedbackMessage?.contains("collides") == true)
    }

    @MainActor
    func testSleepTabLocalDraftRemainsLocalUntilExplicitlySaved() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)
        let profileID = UUID()
        let userID = UUID()
        model.setSessionForTesting(profileID: profileID, userID: userID)

        let initial = ScheduleUIModel(
            name: "Original Alarm",
            kind: .sleep,
            bedtimeHour: 22,
            bedtimeMinute: 0,
            wakeHour: 6,
            wakeMinute: 0,
            repeatWeekdaysMask: 0b0111_1111,
            bedtimeReminderLeadMinutes: 15,
            preWakeReminderLeadMinutes: 15,
            wakeAudio: .bundled(id: SystemAudioAssets.defaultAlarmAssetID, title: "Gentle rise"),
            isEnabled: true
        )
        XCTAssertTrue(model.saveScheduleUI(initial, autoStartUnwind: false))

        // Simulate local draft mutation in SleepTabView
        var localDraft = model.tonightScheduleUIModel
        localDraft.wakeHour = 8
        localDraft.wakeMinute = 45

        // AppModel tonightScheduleUIModel must remain at 6:00 (no auto-save occurred)
        XCTAssertEqual(model.tonightScheduleUIModel.wakeHour, 6)
        XCTAssertEqual(model.tonightScheduleUIModel.wakeMinute, 0)

        // Explicitly saving commits the change
        let saved = model.saveTonightScheduleDraft(localDraft, immediate: true)
        XCTAssertTrue(saved)
        XCTAssertEqual(model.tonightScheduleUIModel.wakeHour, 8)
        XCTAssertEqual(model.tonightScheduleUIModel.wakeMinute, 45)
    }
}
