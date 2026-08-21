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
        XCTAssertTrue(app.otherElements["morningCheckIn.flow"].waitForExistence(timeout: 8))
    }

    @MainActor
    func testVisualShowcaseJourney() {
        let namespace = UUID().uuidString
        let userID = UUID().uuidString
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

        app = authenticatedApplication(namespace: namespace, userID: userID)
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

        XCTAssertTrue(app.buttons["comfortVoice.record"].waitForExistence(timeout: 8))
        capture("09-comfort-audio", app: app)
        let skipAction = app.buttons["comfortVoice.skip"]
        makeHittable(skipAction, in: app)
        skipAction.tap()

        let recommendedSetupAction = app.buttons["Continue to comfort audio"]
        XCTAssertTrue(recommendedSetupAction.waitForExistence(timeout: 8))
        capture("10-recommended-setup", app: app)
        recommendedSetupAction.tap()

        XCTAssertTrue(app.staticTexts["What time do you want to sleep?"].waitForExistence(timeout: 8))
        capture("11-sleep-schedule", app: app)
        let saveSchedule = app.buttons["schedule.save"]
        makeHittable(saveSchedule, in: app)
        saveSchedule.tap()
        acceptNotificationPermissionIfNeeded()

        XCTAssertTrue(app.buttons["home.manualEpisode"].waitForExistence(timeout: 12))
        capture("12-home", app: app)
        app.buttons["home.sleepSchedule"].tap()
        XCTAssertTrue(app.otherElements["schedule.alarmHistory"].waitForExistence(timeout: 8))
        capture("12a-alarm-history", app: app)
        app.buttons["schedule.history.back"].tap()
        XCTAssertTrue(app.buttons["home.manualEpisode"].waitForExistence(timeout: 8))
        app.buttons["home.manualEpisode"].tap()

        XCTAssertTrue(app.navigationBars["Grounding"].waitForExistence(timeout: 8))
        capture("13-grounding", app: app)
        app.buttons["Optional check-in"].tap()

        XCTAssertTrue(app.otherElements["morningCheckIn.flow"].waitForExistence(timeout: 8))
        capture("14-morning-check-in", app: app)
        app.buttons["No, I did not have an episode"].tap()
        let noSleepHelp = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Didn't use it")
        ).firstMatch
        XCTAssertTrue(noSleepHelp.waitForExistence(timeout: 8))
        noSleepHelp.tap()
        let returnHome = app.buttons["Return To Home"]
        XCTAssertTrue(returnHome.waitForExistence(timeout: 8))
        returnHome.tap()

        XCTAssertTrue(app.buttons["home.manualEpisode"].waitForExistence(timeout: 8))
        app.buttons["Sleep"].tap()
        XCTAssertTrue(app.buttons["sleepSession.start"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["home.manualEpisode"].exists)
        XCTAssertTrue(app.buttons["home.sleepSchedule"].exists)
        XCTAssertTrue(app.buttons["home.editSchedule"].exists)
        capture("15-sleep-tab", app: app)
        app.buttons["sleepSession.start"].tap()

        let activeSleepSession = app.otherElements["sleepSession.active"]
        XCTAssertTrue(activeSleepSession.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["sleepSession.episode"].exists)
        XCTAssertTrue(app.buttons["sleepSession.minimize"].exists)
        XCTAssertTrue(app.buttons["sleepSession.end"].waitForExistence(timeout: 3))
        capture("15a-sleep-session", app: app)
        activeSleepSession.swipeDown()
        XCTAssertTrue(app.buttons["sleepSession.start"].waitForExistence(timeout: 8))
        app.buttons["sleepSession.start"].tap()
        XCTAssertTrue(activeSleepSession.waitForExistence(timeout: 8))
        app.buttons["sleepSession.minimize"].tap()
        XCTAssertTrue(app.buttons["sleepSession.start"].waitForExistence(timeout: 8))
        app.buttons["sleepSession.start"].tap()
        XCTAssertTrue(activeSleepSession.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["sleepSession.end"].waitForExistence(timeout: 3))
        app.buttons["sleepSession.end"].tap()
        XCTAssertTrue(app.buttons["sleepSession.start"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["home.manualEpisode"].exists)

        app.buttons["Activity"].tap()
        XCTAssertTrue(app.staticTexts["Activity is coming soon"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Activity tracking is coming soon."].exists)
        capture("16-activity-tab", app: app)

        app.buttons["Home"].tap()
        XCTAssertTrue(app.buttons["home.manualEpisode"].waitForExistence(timeout: 8))
        capture("17-home-tab", app: app)

        app.buttons["Journal"].tap()
        XCTAssertTrue(app.staticTexts["Journal is coming soon"].waitForExistence(timeout: 8))
        capture("18-journal-coming-soon", app: app)

        app.buttons["Me"].tap()
        XCTAssertTrue(app.buttons["Manage subscription"].waitForExistence(timeout: 8))
        capture("19-me-settings", app: app)
        app.terminate()

        captureRoute(
            "edit-questionnaire",
            name: "20-edit-questionnaire",
            namespace: namespace,
            userID: userID,
            expected: { $0.navigationBars["Questionnaire answers"] }
        )
        captureRoute(
            "edit-profile",
            name: "21-edit-profile",
            namespace: namespace,
            userID: userID,
            expected: { $0.staticTexts["Edit Profile"] }
        )
        captureRoute(
            "accessibility",
            name: "22-accessibility",
            namespace: namespace,
            userID: userID,
            expected: { $0.navigationBars["Accessibility"] }
        )
        captureRoute(
            "data-privacy",
            name: "23-data-and-privacy",
            namespace: namespace,
            userID: userID,
            expected: { $0.navigationBars["Data and privacy"] }
        )
        captureRoute(
            "help-legal",
            name: "24-help-and-legal",
            namespace: namespace,
            userID: userID,
            expected: { $0.navigationBars["Help and legal"] }
        )
        captureRoute(
            "account",
            name: "25-account",
            namespace: namespace,
            userID: userID,
            expected: { $0.navigationBars["Account"] }
        )
        captureRoute(
            "default-settings",
            name: "26-default-settings",
            namespace: namespace,
            userID: userID,
            expected: { $0.staticTexts["Default settings"] }
        )
        captureRoute(
            "sleep-schedule",
            name: "27-sleep-schedule-settings",
            namespace: namespace,
            userID: userID,
            expected: { $0.staticTexts["What time do you want to sleep?"] }
        )
        captureRoute(
            "audio-library",
            name: "28-personal-audio-library",
            namespace: namespace,
            userID: userID,
            expected: { $0.staticTexts["Record a loved\none’s voice"] }
        )
        captureRoute(
            "check-in-detail",
            name: "29-check-in-detail",
            namespace: namespace,
            userID: userID,
            expected: { $0.navigationBars["History detail"] }
        )

        captureCatalogRoute(
            scenario: "streaming-preview",
            name: "30-curated-audio-streaming",
            namespace: namespace,
            userID: userID
        ) { catalog in
            let play = catalog.buttons.matching(NSPredicate(format: "label == 'Play preview'"))
                .firstMatch
            XCTAssertTrue(waitForExistenceByScrolling(play, in: catalog), catalog.debugDescription)
            makeHittable(play, in: catalog)
            play.tap()
            XCTAssertTrue(catalog.staticTexts["Playing preview"].waitForExistence(timeout: 3))
            capture("31-curated-audio-playing", app: catalog)
            let pause = catalog.buttons.matching(NSPredicate(format: "label == 'Pause preview'"))
                .firstMatch
            XCTAssertTrue(pause.waitForExistence(timeout: 3))
            pause.tap()
            XCTAssertTrue(catalog.staticTexts["Preview paused"].waitForExistence(timeout: 3))
            capture("32-curated-audio-paused", app: catalog)
        }

        captureCatalogRoute(
            scenario: "downloaded",
            name: "33-curated-audio-offline",
            namespace: namespace,
            userID: userID
        ) { catalog in
            let alarm = catalog.buttons.matching(NSPredicate(format: "label == 'Set as alarm'"))
                .firstMatch
            XCTAssertTrue(waitForExistenceByScrolling(alarm, in: catalog), catalog.debugDescription)
            makeHittable(alarm, in: catalog)
            alarm.tap()
            XCTAssertTrue(catalog.staticTexts["Morning Alarm"].exists)
            capture("34-curated-audio-alarm-selection", app: catalog)
        }

        captureCatalogRoute(
            scenario: "download-progress",
            name: "35-curated-audio-download",
            namespace: namespace,
            userID: userID
        ) { catalog in
            let download = catalog.buttons.matching(NSPredicate(format: "label == 'Download for offline'"))
                .firstMatch
            XCTAssertTrue(waitForExistenceByScrolling(download, in: catalog), catalog.debugDescription)
            makeHittable(download, in: catalog)
            download.tap()
            let progress = catalog.staticTexts.matching(
                NSPredicate(format: "label CONTAINS 'Downloading'")
            ).firstMatch
            XCTAssertTrue(progress.waitForExistence(timeout: 3))
            capture("36-curated-audio-download-progress", app: catalog)
        }
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
        userID: String = UUID().uuidString,
        showcaseRoute: String? = nil,
        catalogScenario: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["SPC_LOCAL_STORE_NAMESPACE"] = namespace
        app.launchEnvironment["SPC_UI_TEST_AUTHENTICATED_USER_ID"] = userID
        if let showcaseRoute {
            app.launchEnvironment["SPC_UI_TEST_SHOWCASE_ROUTE"] = showcaseRoute
        }
        if let catalogScenario {
            app.launchEnvironment["SPC_UI_TEST_CATALOG_SCENARIO"] = catalogScenario
        }
        return app
    }

    @MainActor
    private func captureRoute(
        _ route: String,
        name: String,
        namespace: String,
        userID: String,
        expected: (XCUIApplication) -> XCUIElement
    ) {
        let app = authenticatedApplication(
            namespace: namespace,
            userID: userID,
            showcaseRoute: route
        )
        app.launch()
        XCTAssertTrue(expected(app).waitForExistence(timeout: 8), app.debugDescription)
        capture(name, app: app)
        app.terminate()
    }

    @MainActor
    private func captureCatalogRoute(
        scenario: String,
        name: String,
        namespace: String,
        userID: String,
        interaction: (XCUIApplication) -> Void
    ) {
        let app = authenticatedApplication(
            namespace: namespace,
            userID: userID,
            catalogScenario: scenario
        )
        app.launchEnvironment["SPC_UI_TEST_OPEN_AUDIO_LIBRARY"] = "1"
        app.launch()
        XCTAssertTrue(app.staticTexts["Curated audio"].waitForExistence(timeout: 8), app.debugDescription)
        capture(name, app: app)
        interaction(app)
        app.terminate()
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
