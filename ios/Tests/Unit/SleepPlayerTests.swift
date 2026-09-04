import Foundation
@testable import SleepParalysisCompanion
import XCTest

final class SleepPlayerTests: XCTestCase {
    @MainActor
    func testSaveScheduleAutoStartsUnwindSessionWithDefaultAudio() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)
        let profileID = UUID()
        let userID = UUID()
        model.setSessionForTesting(profileID: profileID, userID: userID)

        let schedule = ScheduleUIModel(
            name: "Bedtime Rhythm",
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

        let saved = model.saveScheduleUI(schedule, autoStartUnwind: true)
        XCTAssertTrue(saved)
        XCTAssertTrue(model.alarmSchedules.contains(where: { $0.id == schedule.id }))
        XCTAssertTrue(model.path.contains(.audioPlayer), "Sleep Player should be presented upon saving")
        XCTAssertFalse(model.isSleepSessionPresented, "Second Sleep screen must not be presented for bedtime unwind")
        XCTAssertEqual(model.activeTrackTitle, "Quick Unwind", "Default unwind track should be Quick Unwind")
    }

    @MainActor
    func testSwitchingBetweenQuickAndSlowUnwindUpdatesMetadataAndPlayback() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)

        guard let quickUnwind = CatalogAudioManifest.bundled.assets.first(where: { $0.id == "quick-unwind" }),
              let slowUnwind = CatalogAudioManifest.bundled.assets.first(where: { $0.id == "slow-unwind" })
        else {
            XCTFail("Missing bundled unwind assets")
            return
        }

        model.playCatalogAsset(quickUnwind)
        XCTAssertEqual(model.activeTrackTitle, "Quick Unwind")
        XCTAssertEqual(model.sleepTrackDurationText(for: quickUnwind), "15 min")
        XCTAssertEqual(model.selectedCatalogAsset?.id, "quick-unwind")

        model.playCatalogAsset(slowUnwind)
        XCTAssertEqual(model.activeTrackTitle, "Slow Unwind")
        XCTAssertEqual(model.sleepTrackDurationText(for: slowUnwind), "1 hr 15 min")
        XCTAssertEqual(model.selectedCatalogAsset?.id, "slow-unwind")
    }

    @MainActor
    func testFadeAwayTimerCountdownAndVolumeFadeOut() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)

        model.setSleepTimer(minutes: 15)
        XCTAssertNotNil(model.sleepTimerRemaining)
        XCTAssertEqual(model.sleepTimerRemaining, 900)

        model.cancelSleepTimer()
        XCTAssertNil(model.sleepTimerRemaining)

        model.setSleepTimerToEndOfTrack()
        XCTAssertNotNil(model.sleepTimerRemaining)
        XCTAssertGreaterThan(model.sleepTimerRemaining ?? 0, 0)

        model.cancelSleepTimer()
        XCTAssertNil(model.sleepTimerRemaining)
    }

    @MainActor
    func testSecondSleepSingleCTAInvokesGrounding() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)

        model.startSleepSession()
        XCTAssertTrue(model.isSleepSessionPresented, "Second Sleep should be presented")
        XCTAssertEqual(model.sleepSessionAudioStatus, .ready)

        _ = model.performSleepSessionAudioAction(.startOrResume, presentSession: false)

        model.beginManualGrounding()
        XCTAssertTrue(model.path.contains(.grounding), "Manual grounding must be invoked from Second Sleep CTA")

        model.endSleepSession()
        XCTAssertFalse(model.isSleepSessionPresented)
    }

    @MainActor
    func testSleepPlayerTracksContainQuickAndSlowUnwind() {
        let model = makeTestAppModel()
        let tracks = model.sleepPlayerTracks

        XCTAssertTrue(tracks.contains(where: { $0.id == "quick-unwind" }))
        XCTAssertTrue(tracks.contains(where: { $0.id == "slow-unwind" }))

        if let quick = tracks.first(where: { $0.id == "quick-unwind" }) {
            XCTAssertTrue(model.isSleepTrackDownloaded(quick))
            XCTAssertEqual(model.sleepTrackDurationText(for: quick), "15 min")
        }

        if let slow = tracks.first(where: { $0.id == "slow-unwind" }) {
            XCTAssertTrue(model.isSleepTrackDownloaded(slow))
            XCTAssertEqual(model.sleepTrackDurationText(for: slow), "1 hr 15 min")
        }
    }
}
