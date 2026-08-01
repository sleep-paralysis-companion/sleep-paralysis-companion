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
    func testInterruptionAndRestorationAcrossAuthenticatedQuestionnaire() {
        let namespace = UUID().uuidString
        let userID = UUID().uuidString
        var app = authenticatedApplication(namespace: namespace, userID: userID)
        app.launch()
        XCTAssertTrue(
            app.staticTexts["How often do you experience Sleep Paralysis?"].waitForExistence(timeout: 8),
            app.debugDescription
        )
        app.buttons["Weekly"].tap()
        XCTAssertTrue(app.staticTexts["How do you feel after the episode?"].waitForExistence(timeout: 8))
        app.terminate()

        app = authenticatedApplication(namespace: namespace, userID: userID)
        app.launch()
        XCTAssertTrue(app.staticTexts["How do you feel after the episode?"].waitForExistence(timeout: 8))
    }

    @MainActor
    func testAuthenticatedQ1ThroughQ3AudioScheduleHomeGroundingAndCheckInJourney() {
        let app = authenticatedApplication()
        app.launch()

        XCTAssertTrue(
            app.staticTexts["How often do you experience Sleep Paralysis?"].waitForExistence(timeout: 8),
            app.debugDescription
        )
        app.buttons["Weekly"].tap()
        XCTAssertTrue(app.staticTexts["How do you feel after the episode?"].waitForExistence(timeout: 8))
        app.buttons["I lie awake scared for a while"].tap()
        XCTAssertTrue(app.staticTexts["Do you have someone whose voice calms you down?"].waitForExistence(timeout: 8))
        app.buttons["No â€“ I go through this alone"].tap()

        XCTAssertTrue(app.buttons["Continue to comfort audio"].waitForExistence(timeout: 8))
        app.buttons["Continue to comfort audio"].tap()
        XCTAssertTrue(app.staticTexts["Add a comfort voice"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Record"].exists)
        XCTAssertTrue(app.buttons["Import audio file"].exists)
        app.buttons["Continue to sleep schedule"].tap()

        XCTAssertTrue(app.staticTexts["Sleep schedule"].waitForExistence(timeout: 8))
        app.switches["Enable sleep reminders"].tap()
        app.buttons["Save schedule and open Home"].tap()
        XCTAssertTrue(app.buttons["home.manualEpisode"].waitForExistence(timeout: 8))

        app.buttons["home.manualEpisode"].tap()
        XCTAssertTrue(app.navigationBars["Grounding"].waitForExistence(timeout: 8))
        app.buttons["Optional check-in"].tap()
        XCTAssertTrue(app.navigationBars["Morning check-in"].waitForExistence(timeout: 8))
    }

    @MainActor
    func testVisualShowcaseJourney() {
        var app = freshApplication()
        app.launch()

        let splashAction = app.buttons["splash.continue"]
        XCTAssertTrue(splashAction.waitForExistence(timeout: 8))
        capture("01-splash", app: app)
        splashAction.tap()

        XCTAssertTrue(app.staticTexts["Wake up gently"].waitForExistence(timeout: 5))
        capture("02-introduction-schedule", app: app)
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.staticTexts["Support when you need it most"].waitForExistence(timeout: 5))
        capture("03-introduction-grounding", app: app)
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.staticTexts["A familiar voice guiding you to calmness"].waitForExistence(timeout: 5))
        capture("04-introduction-audio", app: app)
        app.buttons["Continue to sign in"].tap()

        XCTAssertTrue(app.staticTexts["Welcome to Paralux"].waitForExistence(timeout: 5))
        capture("05-authentication-configuration-boundary", app: app)
        app.terminate()

        app = authenticatedApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["How often do you experience Sleep Paralysis?"].waitForExistence(timeout: 8))
        capture("06-questionnaire-frequency", app: app)
        app.buttons["Weekly"].tap()

        XCTAssertTrue(app.staticTexts["How do you feel after the episode?"].waitForExistence(timeout: 8))
        capture("07-questionnaire-feeling", app: app)
        app.buttons["I lie awake scared for a while"].tap()

        XCTAssertTrue(app.staticTexts["Do you have someone whose voice calms you down?"].waitForExistence(timeout: 8))
        capture("08-questionnaire-comfort-context", app: app)
        let aloneChoice = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "go through this alone")
        ).firstMatch
        XCTAssertTrue(aloneChoice.exists)
        aloneChoice.tap()

        let recommendedSetupAction = app.buttons["Continue to comfort audio"]
        XCTAssertTrue(recommendedSetupAction.waitForExistence(timeout: 8))
        capture("09-recommended-setup", app: app)
        recommendedSetupAction.tap()

        XCTAssertTrue(app.staticTexts["Add a comfort voice"].waitForExistence(timeout: 8))
        capture("10-comfort-audio", app: app)
        let continueToSchedule = app.buttons["Continue to sleep schedule"]
        makeHittable(continueToSchedule, in: app)
        continueToSchedule.tap()

        XCTAssertTrue(app.staticTexts["Sleep schedule"].waitForExistence(timeout: 8))
        capture("11-sleep-schedule", app: app)
        app.switches["Enable sleep reminders"].tap()
        let saveSchedule = app.buttons["Save schedule and open Home"]
        makeHittable(saveSchedule, in: app)
        saveSchedule.tap()

        XCTAssertTrue(app.buttons["home.manualEpisode"].waitForExistence(timeout: 8))
        capture("12-home", app: app)
        app.buttons["home.manualEpisode"].tap()

        XCTAssertTrue(app.navigationBars["Grounding"].waitForExistence(timeout: 8))
        capture("13-grounding", app: app)
        app.buttons["Optional check-in"].tap()

        XCTAssertTrue(app.navigationBars["Morning check-in"].waitForExistence(timeout: 8))
        capture("14-morning-check-in", app: app)
        app.buttons["No"].tap()
        app.buttons["Save check-in"].tap()

        XCTAssertTrue(app.navigationBars["Grounding"].waitForExistence(timeout: 8))
        app.navigationBars["Grounding"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["home.manualEpisode"].waitForExistence(timeout: 8))
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 5))
        capture("15-history", app: app)

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        capture("16-settings", app: app)
    }

    @MainActor
    func testDynamicTypeVoiceOverOrderRTLContrastAndReduceMotionRemainOperable() {
        let configurations = [
            [
                "-UIPreferredContentSizeCategoryName",
                "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge",
                "-UIAccessibilityReduceMotionEnabled",
                "YES",
                "-UIAccessibilityDarkerSystemColorsEnabled",
                "YES",
            ],
            [
                "-AppleLanguages",
                "(ar)",
                "-AppleLocale",
                "ar_SA",
                "-UIPreferredContentSizeCategoryName",
                "UICTContentSizeCategoryAccessibilityExtraLarge",
            ],
        ]

        for arguments in configurations {
            let app = freshApplication(arguments: arguments)
            app.launch()
            let heading = app.staticTexts["Understand your nights.\nOwn your sleep."]
            let action = app.buttons["splash.continue"]
            XCTAssertTrue(action.waitForExistence(timeout: 8))
            XCTAssertTrue(heading.exists)
            XCTAssertLessThan(heading.frame.minY, action.frame.minY)
            makeHittable(action, in: app)
            app.terminate()
        }
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
    private func authenticatedApplication(
        namespace: String = UUID().uuidString,
        userID: String = UUID().uuidString
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["SPC_LOCAL_STORE_NAMESPACE"] = namespace
        app.launchEnvironment["SPC_UI_TEST_AUTHENTICATED_USER_ID"] = userID
        return app
    }

    @MainActor
    private func makeHittable(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0 ..< 8 where !element.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }

    @MainActor
    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
