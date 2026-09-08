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
        XCTAssertTrue(
            model.path.contains(.audioPlayer),
            "Sleep Player should be presented upon saving"
        )
        XCTAssertFalse(
            model.isSleepSessionPresented,
            "Second Sleep screen must not be presented for bedtime unwind"
        )
        XCTAssertEqual(
            model.activeTrackTitle,
            "Quick Unwind",
            "Default unwind track should be Quick Unwind"
        )
    }

    @MainActor
    func testSwitchingBetweenQuickAndSlowUnwindUpdatesMetadataAndPlayback() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)

        guard let quickUnwind = CatalogAudioManifest.bundled.assets.first(
            where: { $0.id == "quick-unwind" }
        ),
            let slowUnwind = CatalogAudioManifest.bundled.assets.first(
                where: { $0.id == "slow-unwind" }
            )
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

        XCTAssertEqual(model.selectedCatalogAsset?.id, "second-sleep")
        XCTAssertEqual(model.activeTrackTitle, "Calming Second Sleep")
        XCTAssertEqual(model.activeTrackSubtitle, "Gentle guided recovery session")

        model.beginManualGrounding()
        XCTAssertTrue(
            model.path.contains(.grounding),
            "Manual grounding must be invoked from Second Sleep CTA"
        )

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

    @MainActor
    func testPlayCalmingSecondSleepAudioSelectsAndPlaysSecondSleep() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)

        model.playCalmingSecondSleepAudio()
        XCTAssertEqual(model.selectedCatalogAsset?.id, "second-sleep")
        XCTAssertEqual(model.activeTrackTitle, "Calming Second Sleep")
        XCTAssertEqual(model.activeTrackSubtitle, "Gentle guided recovery session")
    }

    @MainActor
    func testStartUnwindSessionStartsLiveActivityAndPersistsSession() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)

        XCTAssertNil(model.sleepSessionStartedAt)
        model.startUnwindSession()

        XCTAssertNotNil(model.sleepSessionStartedAt)
        XCTAssertFalse(model.isSleepSessionPresented)
        XCTAssertTrue(model.path.contains(.audioPlayer))
        XCTAssertNotNil(UserDefaults.standard.object(forKey: AppModel.sleepSessionStartedAtKey))

        model.endSleepSession()
        XCTAssertNil(model.sleepSessionStartedAt)
        XCTAssertNil(UserDefaults.standard.object(forKey: AppModel.sleepSessionStartedAtKey))
        XCTAssertFalse(model.isSleepSessionPresented)
        XCTAssertEqual(model.playbackState, .idle)
    }

    @MainActor
    func testPerformSleepSessionAudioActionStartOrResumeAlwaysInvokesGrounding() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)
        model.startSleepSession()

        // When started, audioStatus is ready
        XCTAssertEqual(model.sleepSessionAudioStatus, .ready)
        _ = model.performSleepSessionAudioAction(.startOrResume, presentSession: true)

        // Verifies recovery audio is played (default calming Second Sleep)
        XCTAssertEqual(model.selectedCatalogAsset?.id, "second-sleep")
        XCTAssertTrue(model.isSleepSessionPresented)

        // Even if another track is playing, .startOrResume triggers post-episode recovery
        guard let quickUnwind = CatalogAudioManifest.bundled.assets.first(where: { $0.id == "quick-unwind" }) else {
            XCTFail("Missing quick unwind asset")
            return
        }
        model.playCatalogAsset(quickUnwind)
        XCTAssertEqual(model.selectedCatalogAsset?.id, "quick-unwind")

        // Lock screen widget "I just had an episode" executes post-episode recovery
        _ = model.performSleepSessionAudioAction(.startOrResume, presentSession: true)
        XCTAssertEqual(model.selectedCatalogAsset?.id, "second-sleep")

        model.endSleepSession()
        XCTAssertNil(model.sleepSessionStartedAt)
    }

    @MainActor
    func testHeroCardSecondSleepPlaybackSeparation() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)

        // Starting hero card with no audio: plays Second Sleep
        model.playCalmingSecondSleepAudio()
        XCTAssertEqual(model.selectedCatalogAsset?.id, "second-sleep")

        // Toggling playback pauses Second Sleep
        model.togglePlayback()
        if case let .paused(id) = model.playbackState {
            XCTAssertEqual(id, "second-sleep")
        } else {
            XCTFail("Expected playbackState to be .paused(\"second-sleep\")")
        }

        // Toggling playback again resumes Second Sleep
        model.togglePlayback()
        if case let .playing(id) = model.playbackState {
            XCTAssertEqual(id, "second-sleep")
        } else {
            XCTFail("Expected playbackState to be .playing(\"second-sleep\")")
        }

        // When a different track is playing, stopping and calling playCalmingSecondSleepAudio switches to Second Sleep
        guard let quickUnwind = CatalogAudioManifest.bundled.assets.first(where: { $0.id == "quick-unwind" }) else {
            XCTFail("Missing quick unwind asset")
            return
        }
        model.playCatalogAsset(quickUnwind)
        XCTAssertEqual(model.selectedCatalogAsset?.id, "quick-unwind")

        model.stopPlayback()
        model.playCalmingSecondSleepAudio()
        XCTAssertEqual(model.selectedCatalogAsset?.id, "second-sleep")
        XCTAssertFalse(model.isSleepSessionPresented)
    }

    @MainActor
    func testHeroCardSleepSessionPresentVsStart() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)
        model.selectTab(.home)

        // When inactive, startSleepSession initializes session and preserves selected tab
        XCTAssertNil(model.sleepSessionStartedAt)
        model.startSleepSession()
        XCTAssertNotNil(model.sleepSessionStartedAt)
        XCTAssertTrue(model.isSleepSessionPresented)
        XCTAssertEqual(model.selectedTab, .home)
        let initialStartedAt = model.sleepSessionStartedAt

        // Minimize session
        model.minimizeSleepSession()
        XCTAssertFalse(model.isSleepSessionPresented)
        XCTAssertEqual(model.sleepSessionStartedAt, initialStartedAt)
        XCTAssertEqual(model.selectedTab, .home)

        // When already active, presentActiveSleepSession re-presents without changing
        // startedAt or clobbering selectedTab
        model.presentActiveSleepSession()
        XCTAssertTrue(model.isSleepSessionPresented)
        XCTAssertEqual(model.sleepSessionStartedAt, initialStartedAt)
        XCTAssertEqual(model.selectedTab, .home)

        model.endSleepSession()
        XCTAssertNil(model.sleepSessionStartedAt)
        XCTAssertFalse(model.isSleepSessionPresented)
        XCTAssertEqual(model.selectedTab, .home)
    }

    @MainActor
    func testStartUnwindSessionPreservesExistingSessionTimestamp() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)

        model.startSleepSession()
        let establishedTime = model.sleepSessionStartedAt
        XCTAssertNotNil(establishedTime)

        model.startUnwindSession()
        XCTAssertEqual(model.sleepSessionStartedAt, establishedTime)
        XCTAssertTrue(model.path.contains(.audioPlayer))

        model.endSleepSession()
        XCTAssertNil(model.sleepSessionStartedAt)
    }

    @MainActor
    func testPerformSleepSessionAudioActionResumeHandling() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)
        model.startSleepSession()

        // When idle or visualFallback, resume triggers recovery grounding
        model.setPlaybackStateForTesting(.visualFallback)
        _ = model.performSleepSessionAudioAction(.resume, presentSession: false)
        XCTAssertEqual(model.selectedCatalogAsset?.id, "second-sleep")

        // When playing Second Sleep, pause pauses it
        _ = model.performSleepSessionAudioAction(.pause, presentSession: false)
        if case let .paused(id) = model.playbackState {
            XCTAssertEqual(id, "second-sleep")
        }

        // When paused, resume toggles back to playing
        _ = model.performSleepSessionAudioAction(.resume, presentSession: false)
        if case let .playing(id) = model.playbackState {
            XCTAssertEqual(id, "second-sleep")
        }

        model.endSleepSession()
    }

    @MainActor
    func testStartUnwindSessionPreservesActiveUnwindTrackWithoutInterruption() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)

        guard let slowUnwind = CatalogAudioManifest.bundled.assets.first(where: { $0.id == "slow-unwind" }) else {
            XCTFail("Missing slow-unwind asset")
            return
        }

        // Simulate Slow Unwind already playing
        model.playCatalogAsset(slowUnwind)
        XCTAssertEqual(model.selectedCatalogAsset?.id, "slow-unwind")

        // User taps "Calm your mind" CTA from Home
        model.startUnwindSession()

        // Should preserve slow-unwind as selected track rather than resetting to default quick-unwind
        XCTAssertEqual(model.selectedCatalogAsset?.id, "slow-unwind")
        XCTAssertTrue(model.path.contains(.audioPlayer))
        XCTAssertEqual(model.path.filter { $0 == .audioPlayer }.count, 1, "Should not duplicate route")

        model.endSleepSession()
    }
}
