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
}
