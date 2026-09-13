import Foundation
@testable import SleepParalysisCompanion
import XCTest

final class AlarmHistoryTests: XCTestCase {
    @MainActor
    func testSetTonightScheduleOverridesWeekdayDefault() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)
        let profileID = UUID()
        let userID = UUID()
        model.setSessionForTesting(profileID: profileID, userID: userID)

        let defaultSchedule = ScheduleUIModel(
            name: "Everyday Schedule",
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
        XCTAssertTrue(model.saveScheduleUI(defaultSchedule, autoStartUnwind: false))

        let customSchedule = ScheduleUIModel(
            name: "Special Night",
            kind: .sleep,
            bedtimeHour: 23,
            bedtimeMinute: 45,
            wakeHour: 8,
            wakeMinute: 0,
            repeatWeekdaysMask: 0b0100_0000,
            bedtimeReminderLeadMinutes: 15,
            preWakeReminderLeadMinutes: 15,
            wakeAudio: .bundled(id: SystemAudioAssets.defaultAlarmAssetID, title: "Gentle rise"),
            isEnabled: false
        )
        XCTAssertTrue(model.saveScheduleUI(customSchedule, autoStartUnwind: false))

        // Set the custom disabled schedule for tonight
        model.setTonightSchedule(customSchedule)

        // Verifications
        XCTAssertEqual(model.tonightScheduleID, customSchedule.id)
        XCTAssertEqual(model.feedbackMessage, "\"\(customSchedule.name)\" set for tonight")

        let updatedInModel = model.alarmSchedules.first(where: { $0.id == customSchedule.id })
        XCTAssertNotNil(updatedInModel)
        XCTAssertTrue(updatedInModel?.isEnabled == true, "Selecting for tonight must enable the schedule")

        // tonightSchedule and tonightScheduleUIModel must resolve to the explicitly chosen schedule
        XCTAssertEqual(model.tonightSchedule?.id, customSchedule.id)
        XCTAssertEqual(model.tonightScheduleUIModel.id, customSchedule.id)
        XCTAssertEqual(model.tonightScheduleUIModel.name, "Special Night")
    }

    @MainActor
    func testDeleteScheduleUIRemovesScheduleAndClearsTonightID() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)
        let profileID = UUID()
        let userID = UUID()
        model.setSessionForTesting(profileID: profileID, userID: userID)

        let schedule = ScheduleUIModel(
            name: "To Be Deleted",
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

        model.setTonightSchedule(schedule)
        XCTAssertEqual(model.tonightScheduleID, schedule.id)

        // Delete schedule as invoked by the history view card delete action
        model.deleteScheduleUI(schedule)

        XCTAssertFalse(model.alarmSchedules.contains(where: { $0.id == schedule.id }))
        XCTAssertNil(model.tonightScheduleID, "Deleting tonight's schedule must clear tonightScheduleID")
    }

    @MainActor
    func testAlarmHistoryViewPassesOnSelectTonightAndOnDelete() {
        let schedule1 = ScheduleUIModel(
            name: "Schedule 1",
            kind: .sleep,
            bedtimeHour: 22,
            bedtimeMinute: 0,
            wakeHour: 6,
            wakeMinute: 0,
            repeatWeekdaysMask: 0b0111_1111,
            isEnabled: true
        )
        let schedule2 = ScheduleUIModel(
            name: "Schedule 2",
            kind: .sleep,
            bedtimeHour: 23,
            bedtimeMinute: 0,
            wakeHour: 7,
            wakeMinute: 0,
            repeatWeekdaysMask: 0b0100_0000,
            isEnabled: false
        )

        var selectedTonight: ScheduleUIModel?
        var deletedSchedule: ScheduleUIModel?

        let view = AlarmHistoryView(
            schedules: [schedule1, schedule2],
            tonightScheduleID: schedule1.id,
            hapticsEnabled: false,
            onDelete: { deletedSchedule = $0 },
            onSelectTonight: { selectedTonight = $0 }
        )

        XCTAssertNotNil(view)
        XCTAssertEqual(view.schedules.count, 2)
        XCTAssertEqual(view.tonightScheduleID, schedule1.id)

        view.onDelete(schedule1)
        XCTAssertEqual(deletedSchedule?.id, schedule1.id)

        view.onSelectTonight?(schedule2)
        XCTAssertEqual(selectedTonight?.id, schedule2.id)
    }

    @MainActor
    func testSetTonightScheduleRejectsCollidingDisabledSchedule() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)
        let profileID = UUID()
        let userID = UUID()
        model.setSessionForTesting(profileID: profileID, userID: userID)

        let schedule1 = ScheduleUIModel(
            name: "Morning Wake",
            kind: .wakeOnly,
            wakeHour: 7,
            wakeMinute: 0,
            repeatWeekdaysMask: 0b0111_1111,
            isEnabled: true
        )
        XCTAssertTrue(model.saveScheduleUI(schedule1, autoStartUnwind: false))
        XCTAssertEqual(model.tonightScheduleID, schedule1.id)

        // Colliding schedule with the exact same wake time and weekdays
        let collidingSchedule = ScheduleUIModel(
            name: "Duplicate Wake",
            kind: .wakeOnly,
            wakeHour: 7,
            wakeMinute: 0,
            repeatWeekdaysMask: 0b0111_1111,
            isEnabled: false
        )
        XCTAssertTrue(model.saveScheduleUI(collidingSchedule, autoStartUnwind: false))

        // Attempt to set the colliding disabled schedule for tonight
        model.setTonightSchedule(collidingSchedule)

        // Because enabling collidingSchedule causes a collision with schedule1,
        // it must fail validation and not set tonightScheduleID to collidingSchedule
        XCTAssertNotEqual(model.tonightScheduleID, collidingSchedule.id)
        XCTAssertNotEqual(model.feedbackMessage, "\"\(collidingSchedule.name)\" set for tonight")
    }
}
