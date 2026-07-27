import XCTest

final class ApplicationLaunchUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testApplicationLaunchAndBasicNavigation() {
        let app = XCUIApplication()
        app.launch()

        let detailsButton = app.buttons["foundation.details.button"]
        XCTAssertTrue(detailsButton.waitForExistence(timeout: 5))
        XCTAssertTrue(detailsButton.isHittable)

        detailsButton.tap()

        let detailsTitle = app.staticTexts["foundation.details.title"]
        XCTAssertTrue(detailsTitle.waitForExistence(timeout: 5))
        XCTAssertEqual(detailsTitle.label, "Foundation ready")
    }

    @MainActor
    func testShellAtAccessibilityTextSizeDarkContrastAndReducedMotion() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge",
            "-AppleInterfaceStyle",
            "Dark",
            "-UIAccessibilityDarkerSystemColorsEnabled",
            "YES",
            "-UIAccessibilityReduceMotionEnabled",
            "YES",
        ]
        app.launch()

        let statusCard = app.otherElements["foundation.status.card"]
        let detailsButton = app.buttons["foundation.details.button"]

        XCTAssertTrue(statusCard.waitForExistence(timeout: 5))
        XCTAssertTrue(detailsButton.waitForExistence(timeout: 5))
        XCTAssertTrue(detailsButton.isHittable)
        XCTAssertEqual(detailsButton.label, "View foundation details")
    }
}
