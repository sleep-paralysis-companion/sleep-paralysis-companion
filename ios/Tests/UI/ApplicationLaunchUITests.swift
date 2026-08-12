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

        let buildProfileButton = app.buttons["Build my sleep profile"]
        XCTAssertTrue(buildProfileButton.waitForExistence(timeout: 5))
        buildProfileButton.tap()

        XCTAssertTrue(buildProfileButton.waitForExistence(timeout: 5))
        buildProfileButton.tap()

        XCTAssertTrue(buildProfileButton.waitForExistence(timeout: 5))
        buildProfileButton.tap()

        XCTAssertTrue(app.buttons["authentication.createAccount"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["authentication.apple"].exists)
        XCTAssertTrue(app.buttons["authentication.google"].exists)
        XCTAssertTrue(app.textFields["authentication.fullName"].exists)
        app.buttons["authentication.goToLogin"].tap()
        XCTAssertTrue(app.staticTexts["Welcome Back"].waitForExistence(timeout: 3))
        app.buttons["authentication.goToCreateAccount"].tap()
        XCTAssertTrue(app.staticTexts["Create your account"].waitForExistence(timeout: 3))
        app.buttons["authentication.google"].tap()
        XCTAssertTrue(
            app.staticTexts[
                "Provider sign-in will be available once configuration is complete."
            ].waitForExistence(timeout: 3)
        )
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

        let buildProfileAction = app.buttons["Build my sleep profile"]
        XCTAssertTrue(buildProfileAction.waitForExistence(timeout: 5))
        makeHittable(buildProfileAction, in: app)
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
    func testQuestionnaireStructureAndRecommendedSetupActionRemainReachable() {
        let app = authenticatedApplication()
        app.launch()

        let q1Rows = [
            app.buttons["Almost Nightly"],
            app.buttons["Weekly"],
            app.buttons["Monthly – a few times a month"],
            app.buttons["Rarely – a few times a year"],
        ]
        for row in q1Rows {
            XCTAssertTrue(row.waitForExistence(timeout: 8))
        }
        for (upper, lower) in zip(q1Rows, q1Rows.dropFirst()) {
            XCTAssertLessThan(upper.frame.maxY, lower.frame.minY)
        }

        q1Rows[1].tap()
        app.buttons["I lie awake scared for a while"].tap()
        app.buttons["No – I go through this alone"].tap()

        let resultHeading = app.staticTexts["Your sleep profile is ready"]
        let resultAction = app.buttons["Continue to comfort audio"]
        XCTAssertTrue(resultHeading.waitForExistence(timeout: 8))
        XCTAssertTrue(resultAction.exists)
        XCTAssertLessThan(resultHeading.frame.minY, resultAction.frame.minY)
        makeHittable(resultAction, in: app)
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
        let aloneChoice = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "go through this alone")
        ).firstMatch
        XCTAssertTrue(aloneChoice.waitForExistence(timeout: 8))
        aloneChoice.tap()

        XCTAssertTrue(app.buttons["Continue to comfort audio"].waitForExistence(timeout: 8))
        app.buttons["Continue to comfort audio"].tap()
        let recordAction = app.buttons["comfortVoice.record"]
        let uploadAction = app.buttons["comfortVoice.upload"]
        let skipAction = app.buttons["comfortVoice.skip"]
        XCTAssertTrue(recordAction.waitForExistence(timeout: 8))
        XCTAssertTrue(uploadAction.exists)
        XCTAssertTrue(skipAction.exists)
        skipAction.tap()

        XCTAssertTrue(app.staticTexts["What time do you want to sleep?"].waitForExistence(timeout: 8))
        let saveSchedule = app.buttons["schedule.save"]
        makeHittable(saveSchedule, in: app)
        saveSchedule.tap()
        acceptNotificationPermissionIfNeeded()
        XCTAssertTrue(app.buttons["home.manualEpisode"].waitForExistence(timeout: 12))

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

        XCTAssertTrue(app.staticTexts["Wake up gently!"].waitForExistence(timeout: 5))
        capture("02-introduction-schedule", app: app)
        app.buttons["Build my sleep profile"].tap()

        XCTAssertTrue(app.staticTexts["Support when you\nneed it most."].waitForExistence(timeout: 5))
        capture("03-introduction-grounding", app: app)
        app.buttons["Build my sleep profile"].tap()

        XCTAssertTrue(app.staticTexts["A familiar voice\nguiding to calmness"].waitForExistence(timeout: 5))
        capture("04-introduction-audio", app: app)
        app.buttons["Build my sleep profile"].tap()

        XCTAssertTrue(app.staticTexts["Create your account"].waitForExistence(timeout: 5))
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
        let partnerNotAlwaysPresentChoice = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "not always with me")
        ).firstMatch
        XCTAssertTrue(partnerNotAlwaysPresentChoice.exists)
        partnerNotAlwaysPresentChoice.tap()

        let recommendedSetupAction = app.buttons["Continue to comfort audio"]
        XCTAssertTrue(recommendedSetupAction.waitForExistence(timeout: 8))
        capture("09-recommended-setup", app: app)
        recommendedSetupAction.tap()

        XCTAssertTrue(app.buttons["comfortVoice.record"].waitForExistence(timeout: 8))
        capture("10-comfort-audio", app: app)
        let skipAction = app.buttons["comfortVoice.skip"]
        makeHittable(skipAction, in: app)
        skipAction.tap()

        XCTAssertTrue(app.staticTexts["What time do you want to sleep?"].waitForExistence(timeout: 8))
        capture("11-sleep-schedule", app: app)
        let saveSchedule = app.buttons["schedule.save"]
        makeHittable(saveSchedule, in: app)
        saveSchedule.tap()
        acceptNotificationPermissionIfNeeded()

        XCTAssertTrue(app.buttons["home.manualEpisode"].waitForExistence(timeout: 12))
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
        XCTAssertTrue(app.staticTexts["No episode reported"].waitForExistence(timeout: 8))
        capture("15-history", app: app)

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["Questionnaire answers"].waitForExistence(timeout: 8))
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
            let heading = app.staticTexts["Understand your nights. Own your sleep."]
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
    private func acceptNotificationPermissionIfNeeded() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allowButton = springboard.buttons["Allow"]
        if allowButton.waitForExistence(timeout: 3) {
            allowButton.tap()
        }
    }

    @MainActor
    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
