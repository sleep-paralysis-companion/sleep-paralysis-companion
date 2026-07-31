import XCTest

final class ApplicationLaunchUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCleanInstallReachesExplicitProviderConfigurationBoundary() {
        let app = freshApplication()
        app.launch()

        XCTAssertTrue(app.buttons["splash.continue"].waitForExistence(timeout: 8))
        app.buttons["splash.continue"].tap()

        for _ in 0 ..< 3 {
            let continueButton = app.buttons["Continue"]
            let signInButton = app.buttons["Continue to sign in"]
            if signInButton.waitForExistence(timeout: 1) {
                signInButton.tap()
                break
            }
            XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
            continueButton.tap()
        }

        XCTAssertTrue(app.buttons["authentication.apple"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["authentication.google"].exists)
        XCTAssertFalse(app.buttons["authentication.apple"].isEnabled)
        XCTAssertFalse(app.buttons["authentication.google"].isEnabled)
        XCTAssertTrue(app.staticTexts["Provider configuration required"].exists)
        XCTAssertFalse(app.buttons["Start trial"].exists)
        XCTAssertFalse(app.staticTexts["Paywall"].exists)
    }

    @MainActor
    func testAccessibilitySizeKeepsPrimaryIntroductionControlsReachable() {
        let app = freshApplication(
            arguments: [
                "-UIPreferredContentSizeCategoryName",
                "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge",
                "-AppleInterfaceStyle",
                "Dark",
                "-UIAccessibilityReduceMotionEnabled",
                "YES",
            ]
        )
        app.launch()

        let splashAction = app.buttons["splash.continue"]
        XCTAssertTrue(splashAction.waitForExistence(timeout: 8))
        makeHittable(splashAction, in: app)
        splashAction.tap()

        let continueAction = app.buttons["Continue"]
        XCTAssertTrue(continueAction.waitForExistence(timeout: 5))
        makeHittable(continueAction, in: app)
    }

    @MainActor
    private func freshApplication(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["SPC_LOCAL_STORE_NAMESPACE"] = UUID().uuidString
        app.launchEnvironment["SPC_DISABLE_AUTH_CONFIGURATION"] = "1"
        app.launchArguments += arguments
        return app
    }

    @MainActor
    private func makeHittable(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0 ..< 8 where !element.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }
}
