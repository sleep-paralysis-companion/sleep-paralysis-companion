import Foundation
@testable import SleepParalysisCompanion
import XCTest

@MainActor
final class AppHapticsTests: XCTestCase {
    func testAllHapticMethodsExecuteSafelyWhenEnabled() {
        AppHaptics.preparePageSnap()
        AppHaptics.pageSnap(hapticsEnabled: true)
        AppHaptics.primaryCTA(hapticsEnabled: true)
        AppHaptics.secondaryCTA(hapticsEnabled: true)
        AppHaptics.playbackToggle(hapticsEnabled: true)
        AppHaptics.success(hapticsEnabled: true)
        AppHaptics.warning(hapticsEnabled: true)
        AppHaptics.stepAdjustment(direction: .increase, hapticsEnabled: true)
        AppHaptics.stepAdjustment(direction: .decrease, hapticsEnabled: true)
        AppHaptics.toggleChanged(isOn: true, hapticsEnabled: true)
        AppHaptics.toggleChanged(isOn: false, hapticsEnabled: true)
        AppHaptics.selectionChanged(hapticsEnabled: true)
    }

    func testAllHapticMethodsExecuteSafelyWhenDisabled() {
        AppHaptics.pageSnap(hapticsEnabled: false)
        AppHaptics.primaryCTA(hapticsEnabled: false)
        AppHaptics.secondaryCTA(hapticsEnabled: false)
        AppHaptics.playbackToggle(hapticsEnabled: false)
        AppHaptics.success(hapticsEnabled: false)
        AppHaptics.warning(hapticsEnabled: false)
        AppHaptics.stepAdjustment(direction: .increase, hapticsEnabled: false)
        AppHaptics.stepAdjustment(direction: .decrease, hapticsEnabled: false)
        AppHaptics.toggleChanged(isOn: true, hapticsEnabled: false)
        AppHaptics.toggleChanged(isOn: false, hapticsEnabled: false)
        AppHaptics.selectionChanged(hapticsEnabled: false)
    }

    func testHapticPreferenceUpdateInAppModel() async {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)
        let profileID = UUID()
        let userID = UUID()
        model.setSessionForTesting(profileID: profileID, userID: userID)

        // Verify initial state
        XCTAssertNotNil(model.settings)
        XCTAssertTrue(model.settings?.hapticsEnabled != false)

        // Toggle haptics off - verify synchronous in-memory update
        model.setHapticsEnabled(false)
        XCTAssertEqual(model.settings?.hapticsEnabled, false, "In-memory settings must update synchronously")
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(model.settings?.hapticsEnabled, false)

        // Toggle haptics back on - verify synchronous in-memory update
        model.setHapticsEnabled(true)
        XCTAssertEqual(model.settings?.hapticsEnabled, true, "In-memory settings must update synchronously")
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(model.settings?.hapticsEnabled, true)
    }

    func testSavePartnerCallSettingsPersistsHapticsPreference() async throws {
        let namespace = "test-haptics-\(UUID().uuidString)"
        let location = LocalStoreLocation(namespace: namespace)
        let dbURL = try location.databaseURL()
        let database = try LocalDatabase(path: dbURL.path)

        var profile = Phase1BFixture.profile()
        profile.ownership = .accountLinked
        profile.accountUserID = Phase1BFixture.userID
        profile.accountLinkState = .linked
        try await database.createProfile(profile, settings: Phase1BFixture.settings())

        let store = makeTestPhase1Store(namespace: namespace)
        let model = makeTestAppModel(store: store)
        model.setLaunchDestinationForTesting(.home)
        model.setSessionForTesting(profileID: profile.id, userID: Phase1BFixture.userID)

        let success = model.savePartnerCallSettings(
            sleep: .quickSleep,
            postEpisode: .calmingAudio,
            partnerName: "Alex",
            partnerPhoneNumber: "555-123-4567",
            hapticsEnabled: false
        )
        XCTAssertTrue(success)
        XCTAssertEqual(model.settings?.hapticsEnabled, false)
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(model.settings?.hapticsEnabled, false)
        XCTAssertEqual(model.partnerContact?.name, "Alex")
    }

    func testSavePartnerCallSettingsFailsOnInvalidPhoneNumber() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)
        let profileID = UUID()
        let userID = UUID()
        model.setSessionForTesting(profileID: profileID, userID: userID)

        let success = model.savePartnerCallSettings(
            sleep: .quickSleep,
            postEpisode: .calmingAudio,
            partnerName: "Alex",
            partnerPhoneNumber: "123", // too short, requires 7-15 digits
            hapticsEnabled: false
        )
        XCTAssertFalse(success, "Invalid phone number must fail validation")
        XCTAssertEqual(model.feedbackMessage, "Enter a valid phone number with 7 to 15 digits.")
    }
}
