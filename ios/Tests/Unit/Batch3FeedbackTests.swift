import Foundation
@testable import SleepParalysisCompanion
import XCTest

final class Batch3FeedbackTests: XCTestCase {
    @MainActor
    func testAlarmCardCTARoutesToAlarmScheduleEditorWhenEmpty() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)
        let profileID = UUID()
        let userID = UUID()
        model.setSessionForTesting(profileID: profileID, userID: userID)

        XCTAssertTrue(model.alarmSchedules.isEmpty)
        model.openAlarmScheduleSummary()

        XCTAssertTrue(
            model.path.contains(.alarmScheduleEditor),
            "When no alarm schedules exist, CTA must open alarmScheduleEditor"
        )
        XCTAssertNil(model.selectedAlarmScheduleID)
    }

    @MainActor
    func testAlarmCardCTARoutesToAlarmScheduleEditorWhenSchedulesExist() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)
        let profileID = UUID()
        let userID = UUID()
        model.setSessionForTesting(profileID: profileID, userID: userID)

        let schedule = ScheduleUIModel(
            name: "Morning Wake",
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

        let saved = model.saveScheduleUI(schedule, autoStartUnwind: false)
        XCTAssertTrue(saved)
        XCTAssertFalse(model.alarmSchedules.isEmpty)

        model.setPath([])
        model.openAlarmScheduleSummary()

        XCTAssertTrue(
            model.path.contains(.alarmScheduleEditor),
            "When alarm schedules exist, CTA must open alarmScheduleEditor directly"
        )
        XCTAssertEqual(model.selectedAlarmScheduleID, model.tonightScheduleID)
    }

    func testNotificationSoundSelectionPersistenceAndFallback() {
        AlarmSoundSelectionStore.selectNotification(
            assetID: "notification",
            fileName: "SPCNotification.caf"
        )
        XCTAssertEqual(AlarmSoundSelectionStore.selectedNotificationAssetID(), "notification")
        XCTAssertEqual(AlarmSoundSelectionStore.selectedNotificationSoundFileName(), "SPCNotification.caf")
        let bundledSound = SystemAudioAssets.notificationSound()
        XCTAssertNotNil(bundledSound)

        AlarmSoundSelectionStore.selectNotification(
            assetID: "system-default",
            fileName: "default"
        )
        XCTAssertEqual(AlarmSoundSelectionStore.selectedNotificationAssetID(), "system-default")
        XCTAssertEqual(AlarmSoundSelectionStore.selectedNotificationSoundFileName(), "default")
        let defaultSound = SystemAudioAssets.notificationSound()
        XCTAssertNotNil(defaultSound)

        AlarmSoundSelectionStore.selectNotification(
            assetID: "nonexistent",
            fileName: "nonexistent.caf"
        )
        // Missing/unusable custom file must fall back gracefully to a playable sound
        let fallbackSound = SystemAudioAssets.notificationSound()
        XCTAssertNotNil(fallbackSound)

        // Restore default notification setting
        AlarmSoundSelectionStore.selectNotification(
            assetID: SystemAudioAssets.defaultNotificationAssetID,
            fileName: SystemAudioAssets.defaultNotificationFileName
        )
    }

    func testEnsureDefaultSoundsInstalledDoesNotThrow() {
        SystemAudioAssets.ensureDefaultSoundsInstalled()
    }

    @MainActor
    func testSleepPlayerTracksContainStrictlyUnwindTracks() {
        let model = makeTestAppModel()
        let tracks = model.sleepPlayerTracks

        XCTAssertEqual(tracks.count, 2, "Sleep player tracks must strictly contain the 2 unwind tracks")

        let trackIDs = Set(tracks.map(\.id))
        let expectedIDs = Set(["quick-unwind", "slow-unwind"])
        XCTAssertEqual(trackIDs, expectedIDs)

        XCTAssertFalse(
            tracks.contains(where: { $0.id == "second-sleep" }),
            "Second Sleep recovery audio must not appear in sleep player tracks"
        )
        XCTAssertFalse(
            tracks.contains(where: { $0.id == "felt-dawn" }),
            "Felt Dawn morning alarm sound must not be in calming tracks"
        )
        XCTAssertFalse(
            tracks.contains(where: { $0.category == .morningAlarm }),
            "Morning alarm category must not appear in calming tracks"
        )
        XCTAssertFalse(
            tracks.contains(where: { $0.category == .notification }),
            "Notification category must not appear in calming tracks"
        )

        if let quickUnwind = tracks.first(where: { $0.id == "quick-unwind" }) {
            XCTAssertEqual(model.sleepTrackDurationText(for: quickUnwind), "15 min")
        }
        if let slowUnwind = tracks.first(where: { $0.id == "slow-unwind" }) {
            XCTAssertEqual(model.sleepTrackDurationText(for: slowUnwind), "1 hr 15 min")
        }
    }
}
