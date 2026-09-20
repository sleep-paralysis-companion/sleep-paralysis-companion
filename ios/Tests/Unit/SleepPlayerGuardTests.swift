import Foundation
@testable import SleepParalysisCompanion
import XCTest

final class SleepPlayerGuardTests: XCTestCase {
    @MainActor
    func testSleepPlayerGuardsAgainstSecondSleepLeakageAndPreventsResumingGroundingAudio() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)

        // 1. Simulate episode recovery: "I just had an episode" selects and plays "second-sleep"
        model.playCalmingSecondSleepAudio()
        XCTAssertEqual(model.selectedCatalogAsset?.id, "second-sleep")
        XCTAssertEqual(model.playbackState, .playing("second-sleep"))

        // 2. Prepare / transition to Sleep Player (AudioPlayerView)
        let playerView = AudioPlayerView(model: model)
        playerView.ensureUnwindTrackSelected()

        // 3. Selection must be reset to a valid unwind track, and second-sleep stopped
        XCTAssertNotEqual(model.selectedCatalogAsset?.id, "second-sleep")
        XCTAssertEqual(model.selectedCatalogAsset?.id, "quick-unwind")
        XCTAssertEqual(model.playbackState, .idle)

        // 4. Toggling playback must NOT resume "second-sleep"
        model.togglePlayback()
        XCTAssertEqual(model.selectedCatalogAsset?.id, "quick-unwind")
        XCTAssertEqual(model.playbackState, .playing("quick-unwind"))
        XCTAssertNotEqual(model.playbackState, .playing("second-sleep"))

        // 5. When second-sleep was paused, entering Sleep Player resets to unwind track
        model.playCalmingSecondSleepAudio()
        model.togglePlayback()
        XCTAssertEqual(model.selectedCatalogAsset?.id, "second-sleep")
        XCTAssertEqual(model.playbackState, .paused("second-sleep"))

        playerView.ensureUnwindTrackSelected()
        XCTAssertEqual(model.selectedCatalogAsset?.id, "quick-unwind")
        XCTAssertEqual(model.playbackState, .idle)

        model.togglePlayback()
        XCTAssertEqual(model.selectedCatalogAsset?.id, "quick-unwind")
        XCTAssertEqual(model.playbackState, .playing("quick-unwind"))
        XCTAssertNotEqual(model.playbackState, .playing("second-sleep"))

        // 6. Central playback button safety in AudioPlayerView
        model.playCalmingSecondSleepAudio()
        XCTAssertEqual(model.selectedCatalogAsset?.id, "second-sleep")

        playerView.handleMainPlaybackToggle()
        XCTAssertEqual(model.selectedCatalogAsset?.id, "quick-unwind")
        XCTAssertEqual(model.playbackState, .playing("quick-unwind"))
        XCTAssertNotEqual(model.playbackState, .playing("second-sleep"))

        // 7. Verify preferred track selection respects longSleepAid setting
        let profileID = UUID()
        let userID = UUID()
        let settings = AppSettings(
            profileID: profileID,
            preferredGroundingAssetID: nil,
            preferredModality: .audio,
            hapticsEnabled: true,
            lastSelectedHistoryPeriod: .sevenDays,
            diagnosticsEnabled: false,
            defaultSleepSupport: .longSleepAid,
            defaultPostEpisodeSupport: .calmingAudio,
            updatedAt: Date(),
            revision: 1
        )
        model.setSessionForTesting(profileID: profileID, userID: userID, settings: settings)
        model.playCalmingSecondSleepAudio()
        XCTAssertEqual(model.selectedCatalogAsset?.id, "second-sleep")

        playerView.ensureUnwindTrackSelected()
        XCTAssertEqual(model.selectedCatalogAsset?.id, "slow-unwind")
        XCTAssertEqual(model.playbackState, .idle)

        playerView.handleMainPlaybackToggle()
        XCTAssertEqual(model.selectedCatalogAsset?.id, "slow-unwind")
        XCTAssertEqual(model.playbackState, .playing("slow-unwind"))
    }
}
