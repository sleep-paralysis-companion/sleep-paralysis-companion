import XCTest

final class ApplicationLaunchUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testCleanInstallGuestReachesUsefulHomeWithoutBlockers() {
        let app = freshApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["welcome.title"].waitForExistence(timeout: 8))
        makeHittable(app.buttons["welcome.continue"], in: app)
        XCTAssertFalse(app.buttons["Sign in"].exists)
        XCTAssertFalse(app.buttons["Start trial"].exists)
        XCTAssertFalse(app.staticTexts["Paywall"].exists)

        app.buttons["welcome.continue"].tap()

        XCTAssertTrue(app.staticTexts["notice.title"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts[
                "Sleep Paralysis Companion is a nonmedical wellness tool. It does not diagnose, detect, "
                    + "monitor, predict, prevent, or treat sleep paralysis, and it is not an emergency service."
            ].exists
        )
        XCTAssertTrue(
            app.staticTexts[
                "The app responds only when you choose an action or enter information."
            ].exists
        )
        makeHittable(app.buttons["notice.alarm.button"], in: app)
        makeHittable(app.buttons["notice.privacy.button"], in: app)
        makeHittable(app.buttons["notice.continue"], in: app)

        app.buttons["notice.continue"].tap()

        XCTAssertTrue(app.staticTexts["home.title"].waitForExistence(timeout: 8))
        makeHittable(app.buttons["home.alarm.button"], in: app)
        XCTAssertFalse(app.buttons["Sign in"].exists)
        XCTAssertFalse(app.buttons["Start trial"].exists)
        XCTAssertEqual(app.alerts.count, 0)
        keepScreenshot(app, name: "clean-install-home-light")
    }

    @MainActor
    func testInterruptionAtEveryVisibleOnboardingPointRestoresValidState() {
        let namespace = UUID().uuidString
        let app = application(namespace: namespace)
        app.launch()
        XCTAssertTrue(app.staticTexts["welcome.title"].waitForExistence(timeout: 8))
        app.terminate()

        app.launch()
        XCTAssertTrue(app.staticTexts["welcome.title"].waitForExistence(timeout: 8))
        app.buttons["welcome.continue"].tap()
        XCTAssertTrue(app.staticTexts["notice.title"].waitForExistence(timeout: 5))
        app.terminate()

        app.launch()
        XCTAssertTrue(app.staticTexts["welcome.title"].waitForExistence(timeout: 8))
        completeOnboarding(app)
        app.terminate()

        app.launch()
        XCTAssertTrue(app.staticTexts["home.title"].waitForExistence(timeout: 8))
        makeHittable(app.buttons["home.alarm.button"], in: app)
    }

    @MainActor
    func testTypedRouteRestoresAfterRelaunch() {
        let app = freshApplication()
        app.launch()
        completeOnboarding(app)

        app.tabBars.buttons["Settings"].tap()
        let privacyButton = app.buttons["settings.dataPrivacy.button"]
        XCTAssertTrue(privacyButton.waitForExistence(timeout: 5))
        privacyButton.tap()
        XCTAssertTrue(app.staticTexts["privacy.title"].waitForExistence(timeout: 5))
        app.terminate()

        app.launch()
        XCTAssertTrue(app.staticTexts["privacy.title"].waitForExistence(timeout: 8))
    }

    @MainActor
    func testAllAccessibilityDynamicTypeCategoriesKeepCriticalControlsOperable() {
        let categories = [
            "UICTContentSizeCategoryAccessibilityMedium",
            "UICTContentSizeCategoryAccessibilityLarge",
            "UICTContentSizeCategoryAccessibilityExtraLarge",
            "UICTContentSizeCategoryAccessibilityExtraExtraLarge",
            "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge",
        ]

        for category in categories {
            let app = freshApplication(
                arguments: [
                    "-UIPreferredContentSizeCategoryName",
                    category,
                ]
            )
            app.launch()
            XCTAssertTrue(app.buttons["welcome.continue"].waitForExistence(timeout: 8))
            makeHittable(app.buttons["welcome.continue"], in: app, context: category)
            app.buttons["welcome.continue"].tap()
            XCTAssertTrue(app.buttons["notice.continue"].waitForExistence(timeout: 5))
            makeHittable(app.buttons["notice.continue"], in: app, context: category)
            app.buttons["notice.continue"].tap()
            XCTAssertTrue(app.buttons["home.alarm.button"].waitForExistence(timeout: 8))
            makeHittable(app.buttons["home.alarm.button"], in: app, context: category)
            app.terminate()
        }
    }

    @MainActor
    func testDarkIncreasedContrastReducedMotionAndVoiceOverOrder() {
        let app = freshApplication(
            arguments: [
                "-UIPreferredContentSizeCategoryName",
                "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge",
                "-AppleInterfaceStyle",
                "Dark",
                "-UIAccessibilityDarkerSystemColorsEnabled",
                "YES",
                "-UIAccessibilityReduceMotionEnabled",
                "YES",
                "-UIAccessibilityReduceTransparencyEnabled",
                "YES",
            ]
        )
        app.launch()

        let heading = app.staticTexts["welcome.title"]
        let action = app.buttons["welcome.continue"]
        XCTAssertTrue(heading.waitForExistence(timeout: 8))
        XCTAssertLessThan(heading.frame.minY, action.frame.minY)
        XCTAssertEqual(action.label, "Continue")
        makeHittable(action, in: app)
        app.buttons["welcome.continue"].tap()

        let noticeHeading = app.staticTexts["notice.title"]
        let noticeAction = app.buttons["notice.continue"]
        XCTAssertTrue(noticeHeading.waitForExistence(timeout: 5))
        XCTAssertLessThan(noticeHeading.frame.minY, noticeAction.frame.minY)
        makeHittable(noticeAction, in: app)
        keepScreenshot(app, name: "notice-dark-contrast-accessibility")
    }

    @MainActor
    func testRightToLeftNarrowLayoutKeepsActionsReachable() {
        let app = freshApplication(
            arguments: [
                "-AppleLanguages",
                "(ar)",
                "-AppleLocale",
                "ar_SA",
                "-UIPreferredContentSizeCategoryName",
                "UICTContentSizeCategoryAccessibilityExtraLarge",
            ]
        )
        app.launch()

        XCTAssertTrue(app.buttons["welcome.continue"].waitForExistence(timeout: 8))
        makeHittable(app.buttons["welcome.continue"], in: app)
        app.buttons["welcome.continue"].tap()
        XCTAssertTrue(app.buttons["notice.continue"].waitForExistence(timeout: 5))
        makeHittable(app.buttons["notice.alarm.button"], in: app)
        makeHittable(app.buttons["notice.privacy.button"], in: app)
        makeHittable(app.buttons["notice.help.button"], in: app)
        makeHittable(app.buttons["notice.continue"], in: app)
        keepScreenshot(app, name: "notice-rtl-narrow")
    }

    @MainActor
    private func freshApplication(arguments: [String] = []) -> XCUIApplication {
        application(namespace: UUID().uuidString, arguments: arguments)
    }

    @MainActor
    private func application(
        namespace: String,
        arguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["SPC_LOCAL_STORE_NAMESPACE"] = namespace
        app.launchArguments += arguments
        return app
    }

    @MainActor
    private func completeOnboarding(_ app: XCUIApplication) {
        if app.staticTexts["welcome.title"].exists {
            makeHittable(app.buttons["welcome.continue"], in: app)
            app.buttons["welcome.continue"].tap()
        }
        XCTAssertTrue(app.buttons["notice.continue"].waitForExistence(timeout: 5))
        makeHittable(app.buttons["notice.continue"], in: app)
        app.buttons["notice.continue"].tap()
        XCTAssertTrue(app.staticTexts["home.title"].waitForExistence(timeout: 8))
    }

    @MainActor
    private func makeHittable(
        _ element: XCUIElement,
        in app: XCUIApplication,
        context: String = ""
    ) {
        for _ in 0 ..< 8 where !element.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, context)
    }

    @MainActor
    private func keepScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
