import Foundation
@testable import SleepParalysisCompanion
import XCTest

final class SleepSessionNavigationTests: XCTestCase {
    @MainActor
    func testStartSleepSessionWithAutoStartAudioRespectsSleepSupportSetting() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)
        let profileID = UUID()
        let userID = UUID()
        model.setSessionForTesting(profileID: profileID, userID: userID)

        // Default quickSleep plays Quick Unwind
        model.startSleepSession(startAudio: true)
        XCTAssertTrue(model.isSleepSessionPresented)
        XCTAssertNotNil(model.sleepSessionStartedAt)
        XCTAssertEqual(model.activeTrackTitle, "Quick Unwind")
        XCTAssertFalse(model.path.contains(.audioPlayer))
        model.endSleepSession()

        // LongSleepAid setting plays Slow Unwind
        model.settings?.defaultSleepSupport = .longSleepAid
        model.startSleepSession(startAudio: true)
        XCTAssertTrue(model.isSleepSessionPresented)
        XCTAssertEqual(model.activeTrackTitle, "Slow Unwind")
        XCTAssertFalse(model.path.contains(.audioPlayer))
        model.endSleepSession()
    }

    @MainActor
    func testSaveTonightScheduleDraftFromSleepTabPresentsSleepSessionAndStartsAudio() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)
        let profileID = UUID()
        let userID = UUID()
        model.setSessionForTesting(profileID: profileID, userID: userID)

        var draft = ScheduleUIModel.newSleep
        draft.name = "Tonight Bedtime"
        let saved = model.saveTonightScheduleDraft(draft, immediate: true, autoStartUnwind: true)
        XCTAssertTrue(saved)
        XCTAssertFalse(model.isSleepSessionPresented)
        XCTAssertNotNil(model.sleepSessionStartedAt)
        XCTAssertEqual(model.activeTrackTitle, "Quick Unwind")
        XCTAssertTrue(model.path.contains(.audioPlayer))
        model.endSleepSession()
    }

    @MainActor
    func testPlayDefaultSleepAudioResumesWhenPaused() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)
        let profileID = UUID()
        let userID = UUID()
        model.setSessionForTesting(profileID: profileID, userID: userID)

        model.setPlaybackStateForTesting(.paused("quick-unwind"))
        XCTAssertEqual(model.playbackState, .paused("quick-unwind"))

        model.playDefaultSleepAudio()
        XCTAssertEqual(model.playbackState, .playing("quick-unwind"))
        XCTAssertEqual(model.activeTrackTitle, "Quick Unwind")

        model.setPlaybackStateForTesting(.paused("slow-unwind"))
        XCTAssertEqual(model.playbackState, .paused("slow-unwind"))

        model.playDefaultSleepAudio()
        XCTAssertEqual(model.playbackState, .playing("slow-unwind"))
        XCTAssertEqual(model.activeTrackTitle, "Slow Unwind")
        model.stopPlayback()
    }

    @MainActor
    func testMinimizeAndEndSleepSessionRoutesToSleepTab() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)
        let profileID = UUID()
        let userID = UUID()
        model.setSessionForTesting(profileID: profileID, userID: userID)

        model.startSleepSession()
        XCTAssertTrue(model.isSleepSessionPresented)
        model.selectedTab = .me
        XCTAssertEqual(model.selectedTab, .me)

        model.minimizeSleepSession()
        XCTAssertFalse(model.isSleepSessionPresented)
        XCTAssertEqual(model.selectedTab, .sleep)

        model.startSleepSession()
        XCTAssertTrue(model.isSleepSessionPresented)
        model.selectedTab = .activity
        XCTAssertEqual(model.selectedTab, .activity)

        model.endSleepSession()
        XCTAssertFalse(model.isSleepSessionPresented)
        XCTAssertEqual(model.selectedTab, .sleep)
    }

    @MainActor
    func testCallPartnerFromLockScreenBypassesSleepSessionView() {
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
        model.setPartnerContactForTesting(nil)

        model.startSleepSession()
        XCTAssertTrue(model.isSleepSessionPresented)

        model.playSelectedRecoveryAudio()
        XCTAssertFalse(model.isSleepSessionPresented)
        XCTAssertTrue(model.path.contains(.defaultSettings))
        XCTAssertEqual(model.feedbackMessage, "Add a partner phone number in Settings to use Call Partner.")

        guard let contact = PartnerContact(name: "Partner", phoneNumber: "+15551234567") else {
            XCTFail("PartnerContact initialization failed")
            model.endSleepSession()
            return
        }
        model.setPartnerContactForTesting(contact)
        model.path = []
        model.feedbackMessage = nil
        model.startSleepSession()
        XCTAssertTrue(model.isSleepSessionPresented)

        model.playSelectedRecoveryAudio()
        XCTAssertFalse(model.isSleepSessionPresented)
        XCTAssertFalse(model.path.contains(.defaultSettings))
        XCTAssertNil(model.feedbackMessage)
        model.endSleepSession()
    }
}
