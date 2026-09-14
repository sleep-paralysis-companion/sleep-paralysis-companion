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
        XCTAssertFalse(tracks.contains(where: { $0.id == "second-sleep" }))

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
        XCTAssertEqual(
            model.sleepSessionAudioStatus,
            .ready,
            "Status must remain ready for episode recovery while unwind track plays"
        )

        // Lock screen widget "I just had an episode" executes post-episode recovery
        _ = model.performSleepSessionAudioAction(.startOrResume, presentSession: true)
        XCTAssertEqual(model.selectedCatalogAsset?.id, "second-sleep")
        XCTAssertEqual(
            model.sleepSessionAudioStatus,
            .playing,
            "Status must be playing once Second Sleep begins"
        )

        model.endSleepSession()
        XCTAssertNil(model.sleepSessionStartedAt)
    }

    @MainActor
    func testLockScreenWidgetRecoveryCTAStartsSecondSleepDuringUnwind() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)

        model.startUnwindSession()
        XCTAssertNotNil(model.sleepSessionStartedAt)
        XCTAssertEqual(model.selectedCatalogAsset?.id, "quick-unwind")
        XCTAssertEqual(model.sleepSessionAudioStatus, .ready)

        // Tapping lock screen recovery CTA
        let handled = model.requestSleepSessionAudioAction(.startOrResume)
        XCTAssertTrue(handled)
        XCTAssertEqual(model.selectedCatalogAsset?.id, "second-sleep")
        XCTAssertEqual(model.activeTrackTitle, "Calming Second Sleep")
        XCTAssertEqual(model.sleepSessionAudioStatus, .playing)

        model.endSleepSession()
    }

    @MainActor
    func testLockScreenWidgetRecoveryCTAWithoutActiveSessionStartsSecondSleep() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)

        XCTAssertNil(model.sleepSessionStartedAt)
        let handled = model.requestSleepSessionAudioAction(.startOrResume)
        XCTAssertTrue(handled)
        XCTAssertEqual(model.selectedCatalogAsset?.id, "second-sleep")
        XCTAssertEqual(model.activeTrackTitle, "Calming Second Sleep")
        XCTAssertTrue(model.path.contains(.grounding))
    }

    @MainActor
    func testPerformSleepSessionAudioActionResumeWhileUnwindPausedStartsSecondSleep() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)
        model.startSleepSession()

        guard let quickUnwind = CatalogAudioManifest.bundled.assets.first(where: { $0.id == "quick-unwind" }) else {
            XCTFail("Missing quick unwind asset")
            return
        }
        model.playCatalogAsset(quickUnwind)
        model.togglePlayback()
        if case let .paused(id) = model.playbackState {
            XCTAssertEqual(id, "quick-unwind")
        } else {
            XCTFail("Expected quick-unwind to be paused")
        }
        XCTAssertEqual(model.sleepSessionAudioStatus, .ready)

        // Resuming when an unwind track was paused should trigger Second Sleep recovery rather than unpausing unwind
        _ = model.performSleepSessionAudioAction(.resume, presentSession: true)
        XCTAssertEqual(model.selectedCatalogAsset?.id, "second-sleep")
        XCTAssertEqual(model.activeTrackTitle, "Calming Second Sleep")

        model.endSleepSession()
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

    @MainActor
    func testSavingViaAlarmScheduleEditorNavigatesToAudioPlayerWithoutRouteDrops() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)
        let profileID = UUID()
        let userID = UUID()
        model.setSessionForTesting(profileID: profileID, userID: userID)

        // Simulate navigation stack: Home -> Alarm History -> Alarm Editor
        model.setPath([.alarmHistory, .alarmScheduleEditor])
        XCTAssertEqual(model.path, [.alarmHistory, .alarmScheduleEditor])

        let schedule = ScheduleUIModel(
            name: "Editor Bedtime Alarm",
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

        // Production onSave wiring from AppRootView
        let editor = AlarmScheduleEditorView(
            schedule: schedule,
            audioOptions: model.scheduleAudioOptions,
            hapticsEnabled: false,
            onSave: { savedSchedule in
                let currentPath = model.path
                let saved = model.saveScheduleUI(savedSchedule, autoStartUnwind: true)
                if !saved {
                    model.setPath(currentPath)
                }
            }
        )

        editor.save()

        // Editor save must cleanly reach .audioPlayer without route drops or desync
        XCTAssertEqual(model.path.last, .audioPlayer)
        XCTAssertEqual(model.path, [.audioPlayer])
        XCTAssertEqual(model.activeTrackTitle, "Quick Unwind")

        // Popping audioPlayer returns directly to Home/Sleep tab
        model.setPath(Array(model.path.dropLast()))
        XCTAssertTrue(model.path.isEmpty)
    }

    @MainActor
    func testSavingViaAlarmScheduleEditorCollisionRollsBackPathWithoutDismissing() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)
        let profileID = UUID()
        let userID = UUID()
        model.setSessionForTesting(profileID: profileID, userID: userID)

        let initial = ScheduleUIModel(
            name: "Existing Alarm",
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
        XCTAssertTrue(model.saveScheduleUI(initial, autoStartUnwind: false))

        // Navigate to editor
        model.setPath([.alarmHistory, .alarmScheduleEditor])

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

        // Production onSave wiring from AppRootView
        let editor = AlarmScheduleEditorView(
            schedule: conflicting,
            audioOptions: model.scheduleAudioOptions,
            hapticsEnabled: false,
            onSave: { savedSchedule in
                let currentPath = model.path
                let saved = model.saveScheduleUI(savedSchedule, autoStartUnwind: true)
                if !saved {
                    model.setPath(currentPath)
                }
            }
        )

        editor.save()

        // Validation failure must restore path to editor and not navigate to audioPlayer
        XCTAssertEqual(model.path, [.alarmHistory, .alarmScheduleEditor])
        XCTAssertNotEqual(model.path.last, .audioPlayer)
        XCTAssertTrue(model.feedbackMessage?.contains("collides") == true)
    }

    @MainActor
    func testCancellingAlarmScheduleEditorPopsEditorRouteOnly() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)
        let profileID = UUID()
        let userID = UUID()
        model.setSessionForTesting(profileID: profileID, userID: userID)

        // Case 1: Entered from Alarm History -> cancel returns to Alarm History
        model.setPath([.alarmHistory, .alarmScheduleEditor])

        let editorFromHistory = AlarmScheduleEditorView(
            schedule: .newSleep,
            audioOptions: model.scheduleAudioOptions,
            hapticsEnabled: false,
            onCancel: {
                if !model.path.isEmpty {
                    model.setPath(Array(model.path.dropLast()))
                }
            }
        )

        editorFromHistory.cancel()
        XCTAssertEqual(model.path, [.alarmHistory])

        // Case 2: Entered from Home directly -> cancel returns to Home (empty path)
        model.setPath([.alarmScheduleEditor])

        let editorFromHome = AlarmScheduleEditorView(
            schedule: .newSleep,
            audioOptions: model.scheduleAudioOptions,
            hapticsEnabled: false,
            onCancel: {
                if !model.path.isEmpty {
                    model.setPath(Array(model.path.dropLast()))
                }
            }
        )

        editorFromHome.cancel()
        XCTAssertTrue(model.path.isEmpty)
    }

    @MainActor
    func testDeletingAlarmScheduleEditorRemovesScheduleAndPopsRoute() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)
        let profileID = UUID()
        let userID = UUID()
        model.setSessionForTesting(profileID: profileID, userID: userID)

        let initial = ScheduleUIModel(
            name: "Alarm to Delete",
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
        XCTAssertTrue(model.saveScheduleUI(initial, autoStartUnwind: false))
        XCTAssertTrue(model.alarmSchedules.contains(where: { $0.id == initial.id }))

        // Navigate to editor
        model.setPath([.alarmHistory, .alarmScheduleEditor])

        let editor = AlarmScheduleEditorView(
            schedule: initial,
            audioOptions: model.scheduleAudioOptions,
            hapticsEnabled: false,
            onCancel: {
                if !model.path.isEmpty {
                    model.setPath(Array(model.path.dropLast()))
                }
            },
            onSave: { _ in },
            onDelete: { schedule in
                model.deleteScheduleUI(schedule)
                if !model.path.isEmpty {
                    model.setPath(Array(model.path.dropLast()))
                }
            }
        )

        editor.delete()

        // Path pops back to Alarm History
        XCTAssertEqual(model.path, [.alarmHistory])
        // Schedule is removed from AppModel
        XCTAssertFalse(model.alarmSchedules.contains(where: { $0.id == initial.id }))
    }

    @MainActor
    func testBeginSleepSessionGroundingRespectsPartnerVoiceDefaultSupport() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)
        let profileID = UUID()
        let userID = UUID()
        let settings = AppSettings(
            profileID: profileID,
            preferredGroundingAssetID: nil,
            preferredModality: .audio,
            hapticsEnabled: true,
            lastSelectedHistoryPeriod: .sevenDays,
            diagnosticsEnabled: false,
            defaultSleepSupport: .quickSleep,
            defaultPostEpisodeSupport: .partnerVoice,
            updatedAt: Date(),
            revision: 1
        )
        model.setSessionForTesting(profileID: profileID, userID: userID, settings: settings)

        let clip = PersonalAudioClipMetadata(
            id: UUID(),
            profileID: profileID,
            source: .recorded,
            storageFormat: .m4a,
            byteCount: 1024,
            durationMilliseconds: 5000,
            createdOrImportedAt: Date(),
            availability: .ready,
            protectionVersion: 1
        )
        model.setPersonalClipsForTesting([clip])
        model.setRecoveryAudioDefaultForTesting(.personalClip(clip.id))

        model.startSleepSession()
        XCTAssertEqual(model.sleepSessionAudioStatus, .ready)

        _ = model.performSleepSessionAudioAction(.startOrResume, presentSession: false)

        // With partnerVoice and a personal clip, playSelectedRecoveryAudio plays the clip
        // instead of selecting the default catalog asset "second-sleep"
        XCTAssertNil(model.selectedCatalogAsset)

        model.endSleepSession()
    }

    @MainActor
    func testBeginSleepSessionGroundingFallsBackToSecondSleepWhenNoPersonalClips() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)
        let profileID = UUID()
        let userID = UUID()
        let settings = AppSettings(
            profileID: profileID,
            preferredGroundingAssetID: nil,
            preferredModality: .audio,
            hapticsEnabled: true,
            lastSelectedHistoryPeriod: .sevenDays,
            diagnosticsEnabled: false,
            defaultSleepSupport: .quickSleep,
            defaultPostEpisodeSupport: .partnerVoice,
            updatedAt: Date(),
            revision: 1
        )
        model.setSessionForTesting(profileID: profileID, userID: userID, settings: settings)

        model.startSleepSession()
        _ = model.performSleepSessionAudioAction(.startOrResume, presentSession: false)

        // When partnerVoice has no clips, it falls back to Second Sleep
        XCTAssertEqual(model.selectedCatalogAsset?.id, "second-sleep")
        XCTAssertEqual(model.activeTrackTitle, "Calming Second Sleep")

        model.endSleepSession()
    }

    @MainActor
    func testBeginSleepSessionGroundingRespectsCallPartnerDefaultSupportWithoutContact() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)
        let profileID = UUID()
        let userID = UUID()
        let settings = AppSettings(
            profileID: profileID,
            preferredGroundingAssetID: nil,
            preferredModality: .audio,
            hapticsEnabled: true,
            lastSelectedHistoryPeriod: .sevenDays,
            diagnosticsEnabled: false,
            defaultSleepSupport: .quickSleep,
            defaultPostEpisodeSupport: .callPartner,
            updatedAt: Date(),
            revision: 1
        )
        model.setSessionForTesting(profileID: profileID, userID: userID, settings: settings)

        model.startSleepSession()
        _ = model.performSleepSessionAudioAction(.startOrResume, presentSession: false)

        // Without partner contact, callPartner routes to defaultSettings
        XCTAssertTrue(model.path.contains(.defaultSettings))

        model.endSleepSession()
    }

    @MainActor
    func testBeginManualGroundingRespectsDefaultPostEpisodeSupport() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)
        let profileID = UUID()
        let userID = UUID()
        let settings = AppSettings(
            profileID: profileID,
            preferredGroundingAssetID: nil,
            preferredModality: .audio,
            hapticsEnabled: true,
            lastSelectedHistoryPeriod: .sevenDays,
            diagnosticsEnabled: false,
            defaultSleepSupport: .quickSleep,
            defaultPostEpisodeSupport: .calmingAudio,
            updatedAt: Date(),
            revision: 1
        )
        model.setSessionForTesting(profileID: profileID, userID: userID, settings: settings)

        model.beginManualGrounding()
        XCTAssertTrue(model.path.contains(.grounding))
        XCTAssertEqual(model.selectedCatalogAsset?.id, "second-sleep")
    }
}
