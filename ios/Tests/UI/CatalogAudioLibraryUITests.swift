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
    }

    @MainActor
    func testEmptyAndErrorStatesAreRecoverable() {
        let empty = application(scenario: "empty")
        empty.launch()
        XCTAssertTrue(empty.staticTexts["No approved curated audio yet"].waitForExistence(timeout: 8))

        let error = application(scenario: "error")
        error.launch()
        XCTAssertTrue(error.staticTexts["Audio library unavailable"].waitForExistence(timeout: 8))
        XCTAssertTrue(error.buttons["Try again"].exists)
    }

    @MainActor
    func testStreamingPreviewCanBePlayedAndPaused() {
        let app = application(scenario: "streaming-preview")
        app.launch()

        let play = app.buttons["catalogAudio.play.quick_unwind"]
        XCTAssertTrue(waitForExistenceByScrolling(play, in: app), app.debugDescription)
        makeHittable(play, in: app)
        play.tap()
        XCTAssertTrue(app.staticTexts["Playing preview"].waitForExistence(timeout: 3))

        let pause = app.buttons["catalogAudio.pause.quick_unwind"]
        XCTAssertTrue(waitForExistenceByScrolling(pause, in: app), app.debugDescription)
        makeHittable(pause, in: app)
        pause.tap()
        XCTAssertTrue(app.staticTexts["Preview paused"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testDownloadProgressIsVisible() {
        let app = application(scenario: "download-progress")
        app.launch()

        let download = app.buttons["catalogAudio.download.quick_unwind"]
        XCTAssertTrue(waitForExistenceByScrolling(download, in: app), app.debugDescription)
        makeHittable(download, in: app)
        download.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Downloading'"))
            .firstMatch.waitForExistence(timeout: 3))
    }

    @MainActor
    func testDownloadedAndOfflineStatesAreExplicit() {
        let downloaded = application(scenario: "downloaded")
        downloaded.launch()
        let remove = downloaded.buttons["catalogAudio.remove.quick_unwind"]
        XCTAssertTrue(waitForExistenceByScrolling(remove, in: downloaded), downloaded.debugDescription)
        XCTAssertTrue(downloaded.staticTexts["Available offline"].exists)
        XCTAssertTrue(remove.exists)

        let offline = application(scenario: "offline")
        offline.launch()
        let download = offline.buttons["catalogAudio.download.quick_unwind"]
        XCTAssertTrue(waitForExistenceByScrolling(download, in: offline), offline.debugDescription)
        XCTAssertTrue(offline.staticTexts["Unavailable offline"].exists)
        XCTAssertTrue(download.exists)
    }

    @MainActor
    func testSelectedAlarmIsVisibleOnlyAsLocalSelection() {
        let app = application(scenario: "selected-alarm")
        app.launch()

        let selection = app.buttons["catalogAudio.selectAlarm.morning_alarm"]
        XCTAssertTrue(waitForExistenceByScrolling(selection, in: app), app.debugDescription)
        makeHittable(selection, in: app)
        XCTAssertEqual(selection.label, "Selected for alarm")
        XCTAssertTrue(app.staticTexts["Available offline"].exists)
    }

    @MainActor
    func testFailedDownloadOffersRecovery() {
        let app = application(scenario: "failed-download")
        app.launch()

        let retry = app.buttons["catalogAudio.download.quick_unwind"]
        XCTAssertTrue(waitForExistenceByScrolling(retry, in: app), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Download failed"].exists)
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
        XCTAssertTrue(waitForExistenceByScrolling(remove, in: app), app.debugDescription)
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
        app.launchEnvironment["SPC_UI_TEST_AUTHENTICATED_USER_ID"] = "ui-test-user"
        app.launchEnvironment["SPC_DISABLE_AUTH_CONFIGURATION"] = "1"
        app.launchEnvironment["SPC_LOCAL_STORE_NAMESPACE"] = UUID().uuidString
        return app
    }

    @MainActor
    private func swipeUp(in app: XCUIApplication) {
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            scrollView.swipeUp()
        } else {
            app.swipeUp()
        }
    }

    @MainActor
    private func makeHittable(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0 ..< 8 where !element.isHittable {
            swipeUp(in: app)
        }
        XCTAssertTrue(element.isHittable)
    }

    @MainActor
    private func waitForExistenceByScrolling(
        _ element: XCUIElement,
        in app: XCUIApplication,
        timeout: TimeInterval = 8
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.waitForExistence(timeout: 1) {
                return true
            }
            swipeUp(in: app)
        }
        return element.exists
    }
}
