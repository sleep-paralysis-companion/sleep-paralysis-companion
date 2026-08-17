import XCTest

final class CatalogAudioLibraryUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLoadingStateIsExplicit() {
        let app = application(scenario: "loading")
        app.launch()

        XCTAssertTrue(app.staticTexts["Loading curated audio"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.otherElements["catalogAudio.loading"].exists)
    }

    @MainActor
    func testEmptyAndErrorStatesAreRecoverable() {
        let empty = application(scenario: "empty")
        empty.launch()
        XCTAssertTrue(empty.staticTexts["No approved curated audio yet"].waitForExistence(timeout: 8))
        XCTAssertTrue(empty.otherElements["catalogAudio.empty"].exists)

        let error = application(scenario: "error")
        error.launch()
        XCTAssertTrue(error.staticTexts["Audio library unavailable"].waitForExistence(timeout: 8))
        XCTAssertTrue(error.buttons["Try again"].exists)
        XCTAssertTrue(error.otherElements["catalogAudio.error"].exists)
    }

    @MainActor
    func testStreamingPreviewCanBePlayedAndPaused() {
        let app = application(scenario: "streaming-preview")
        app.launch()

        let play = app.buttons["catalogAudio.play.quick_unwind"]
        XCTAssertTrue(play.waitForExistence(timeout: 8))
        makeHittable(play, in: app)
        play.tap()
        XCTAssertTrue(app.staticTexts["Playing preview"].waitForExistence(timeout: 3))

        let pause = app.buttons["catalogAudio.pause.quick_unwind"]
        XCTAssertTrue(pause.exists)
        makeHittable(pause, in: app)
        pause.tap()
        XCTAssertTrue(app.staticTexts["Preview paused"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testDownloadProgressIsVisible() {
        let app = application(scenario: "download-progress")
        app.launch()

        let download = app.buttons["catalogAudio.download.quick_unwind"]
        XCTAssertTrue(download.waitForExistence(timeout: 8))
        makeHittable(download, in: app)
        download.tap()
        XCTAssertTrue(app.otherElements["catalogAudio.progress.quick_unwind"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Downloading'"))
            .firstMatch.exists)
    }

    @MainActor
    func testDownloadedAndOfflineStatesAreExplicit() {
        let downloaded = application(scenario: "downloaded")
        downloaded.launch()
        XCTAssertTrue(downloaded.staticTexts["Available offline"].waitForExistence(timeout: 8))
        XCTAssertTrue(downloaded.buttons["catalogAudio.remove.quick_unwind"].exists)

        let offline = application(scenario: "offline")
        offline.launch()
        XCTAssertTrue(offline.staticTexts["Unavailable offline"].waitForExistence(timeout: 8))
        XCTAssertTrue(offline.buttons["catalogAudio.download.quick_unwind"].exists)
    }

    @MainActor
    func testSelectedAlarmIsVisibleOnlyAsLocalSelection() {
        let app = application(scenario: "selected-alarm")
        app.launch()

        let selection = app.buttons["catalogAudio.selectAlarm.morning_alarm"]
        XCTAssertTrue(selection.waitForExistence(timeout: 8))
        XCTAssertEqual(selection.label, "Selected for alarm")
        XCTAssertTrue(app.staticTexts["Available offline"].exists)
    }

    @MainActor
    func testFailedDownloadOffersRecovery() {
        let app = application(scenario: "failed-download")
        app.launch()

        XCTAssertTrue(app.staticTexts["Download failed"].waitForExistence(timeout: 8))
        let retry = app.buttons["catalogAudio.download.quick_unwind"]
        XCTAssertTrue(retry.exists)
        makeHittable(retry, in: app)
        retry.tap()
        XCTAssertTrue(app.staticTexts["Download failed"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testStorageRemovalReturnsToStreamableState() {
        let app = application(scenario: "storage-removal")
        app.launch()

        let remove = app.buttons["catalogAudio.remove.quick_unwind"]
        XCTAssertTrue(remove.waitForExistence(timeout: 8))
        makeHittable(remove, in: app)
        remove.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Removed Quick Unwind'"))
            .firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Stream preview available"].exists)
    }

    @MainActor
    private func application(scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["SPC_UI_TEST_OPEN_AUDIO_LIBRARY"] = "1"
        app.launchEnvironment["SPC_UI_TEST_CATALOG_SCENARIO"] = scenario
        app.launchEnvironment["SPC_DISABLE_AUTH_CONFIGURATION"] = "1"
        app.launchEnvironment["SPC_LOCAL_STORE_NAMESPACE"] = UUID().uuidString
        return app
    }

    @MainActor
    private func makeHittable(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0 ..< 10 where !element.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, app.debugDescription)
    }
}
