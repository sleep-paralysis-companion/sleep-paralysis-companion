import Foundation
@testable import SleepParalysisCompanion
import XCTest

final class MorningCheckInMatrixTests: XCTestCase {
    // MARK: - 1. Guest Save Test

    @MainActor
    func testGuestCheckInSaveSucceedsWithoutSupabaseUserID() async throws {
        let (model, profileID) = try await makeSeededAppModel()

        // Configure model as a guest user: profileID is set, userID is nil
        model.setSessionForTesting(profileID: profileID, userID: nil)
        XCTAssertNotNil(model.profileID)
        XCTAssertNil(model.userID)

        var form = MorningCheckInForm()
        form.occurrence = .yes
        form.presentState = .fineNow
        form.spcOutcome = .calmer
        form.postEpisodeSupport = .calmingAudio

        XCTAssertTrue(form.canSubmit)

        let saved = await model.submitCheckIn(form)
        XCTAssertTrue(saved)
        XCTAssertNil(model.feedbackMessage)
        XCTAssertEqual(model.checkIns.count, 1)

        let submitted = try XCTUnwrap(model.checkIns.first)
        XCTAssertEqual(submitted.profileID, profileID)
        XCTAssertEqual(submitted.occurrence, .yes)
        XCTAssertEqual(submitted.presentState, .fineNow)
        XCTAssertEqual(submitted.spcOutcome, .calmer)
        XCTAssertEqual(submitted.postEpisodeSupport, .calmingAudio)
        XCTAssertNil(submitted.sleepHelpOutcome)
        XCTAssertEqual(submitted.revision, 1)

        // Verify guest delete succeeds
        model.deleteCheckIn(submitted)
        await waitForAppModel { model.checkIns.isEmpty }
        XCTAssertEqual(model.checkIns.count, 0)
        XCTAssertNil(model.feedbackMessage)
    }

    // MARK: - 2. Authenticated Save Test

    @MainActor
    func testAuthenticatedCheckInSaveSucceeds() async throws {
        let (model, profileID) = try await makeSeededAppModel()
        let authenticatedUserID = UUID()

        model.setSessionForTesting(profileID: profileID, userID: authenticatedUserID)
        XCTAssertNotNil(model.profileID)
        XCTAssertEqual(model.userID, authenticatedUserID)

        var form = MorningCheckInForm()
        form.occurrence = .no
        form.sleepHelpOutcome = .audioHelped

        XCTAssertTrue(form.canSubmit)

        let saved = await model.submitCheckIn(form)
        XCTAssertTrue(saved)
        XCTAssertNil(model.feedbackMessage)
        XCTAssertEqual(model.checkIns.count, 1)

        let submitted = try XCTUnwrap(model.checkIns.first)
        XCTAssertEqual(submitted.occurrence, .no)
        XCTAssertEqual(submitted.sleepHelpOutcome, .audioHelped)
        XCTAssertNil(submitted.presentState)
        XCTAssertNil(submitted.spcOutcome)
        XCTAssertNil(submitted.postEpisodeSupport)
    }

    // MARK: - 3. NO Episode Path Test (2 Questions)

    @MainActor
    func testNoEpisodePathStepSequenceAndTitles() {
        // Step 1: Episode
        let step1 = MorningCheckInStep.episode
        XCTAssertEqual(step1.progressIndex, 0)
        XCTAssertEqual(step1.progressTitle(for: .no), "QUESTION 1 OF 2")
        XCTAssertEqual(step1.progressTitle(for: nil), "QUESTION 1 OF 4")

        // Step 2: Sleep Help (final question in NO branch)
        let step2 = MorningCheckInStep.sleepHelp
        XCTAssertEqual(step2.progressIndex, 1)
        XCTAssertEqual(step2.progressTitle(for: .no), "QUESTION 2 OF 2")
        XCTAssertEqual(step2.questionTitle, "Did SPC help you fall asleep?")

        // Affirmation
        let affirmationStep = MorningCheckInStep.affirmation(.no)
        XCTAssertNil(affirmationStep.progressTitle(for: .no))
    }

    @MainActor
    func testNoEpisodeSubmissionPreservesOnlyAllowedFields() async throws {
        let (model, profileID) = try await makeSeededAppModel()
        model.setSessionForTesting(profileID: profileID, userID: nil)

        var form = MorningCheckInForm()
        form.occurrence = .no
        form.sleepHelpOutcome = .didNotUseIt
        // Accidental presentState shouldn't leak to submission
        form.presentState = .fineNow

        let saved = await model.submitCheckIn(form)
        XCTAssertTrue(saved)

        let checkIn = try XCTUnwrap(model.checkIns.first)
        XCTAssertEqual(checkIn.occurrence, .no)
        XCTAssertEqual(checkIn.sleepHelpOutcome, .didNotUseIt)
        XCTAssertNil(checkIn.presentState)
        XCTAssertNil(checkIn.spcOutcome)
        XCTAssertNil(checkIn.postEpisodeSupport)
    }

    // MARK: - 4. YES Episode Path Test (4 Questions)

    @MainActor
    func testYesEpisodePathStepSequenceAndTitles() {
        // Step 1: Episode
        let step1 = MorningCheckInStep.episode
        XCTAssertEqual(step1.progressIndex, 0)
        XCTAssertEqual(step1.progressTitle(for: .yes), "QUESTION 1 OF 4")

        // Step 2: Feeling
        let step2 = MorningCheckInStep.feeling
        XCTAssertEqual(step2.progressIndex, 1)
        XCTAssertEqual(step2.progressTitle(for: .yes), "QUESTION 2 OF 4")
        XCTAssertEqual(step2.questionTitle, "How are you feeling now?")

        // Step 3: SPC Outcome
        let step3 = MorningCheckInStep.spcOutcome
        XCTAssertEqual(step3.progressIndex, 2)
        XCTAssertEqual(step3.progressTitle(for: .yes), "QUESTION 3 OF 4")
        XCTAssertEqual(step3.questionTitle, "How did you feel after using\nguided sleep meditation?")

        // Step 4: Post Episode Support
        let step4 = MorningCheckInStep.postEpisodeSupport
        XCTAssertEqual(step4.progressIndex, 3)
        XCTAssertEqual(step4.progressTitle(for: .yes), "QUESTION 4 OF 4")
        XCTAssertEqual(step4.questionTitle, "What did you use after the\nepisode?")

        // Affirmation
        let affirmationStep = MorningCheckInStep.affirmation(.yes)
        XCTAssertNil(affirmationStep.progressTitle(for: .yes))
    }

    @MainActor
    func testYesEpisodeSubmissionPreservesOnlyAllowedFields() async throws {
        let (model, profileID) = try await makeSeededAppModel()
        model.setSessionForTesting(profileID: profileID, userID: nil)

        var form = MorningCheckInForm()
        form.occurrence = .yes
        form.presentState = .stillShaken
        form.spcOutcome = .noDifference
        form.postEpisodeSupport = .partnerCall
        // Accidental sleepHelpOutcome shouldn't leak to submission
        form.sleepHelpOutcome = .audioHelped

        let saved = await model.submitCheckIn(form)
        XCTAssertTrue(saved)

        let checkIn = try XCTUnwrap(model.checkIns.first)
        XCTAssertEqual(checkIn.occurrence, .yes)
        XCTAssertEqual(checkIn.presentState, .stillShaken)
        XCTAssertEqual(checkIn.spcOutcome, .noDifference)
        XCTAssertEqual(checkIn.postEpisodeSupport, .partnerCall)
        XCTAssertNil(checkIn.sleepHelpOutcome)
    }

    // MARK: - 5. Skip Test

    @MainActor
    func testSkipFlowDoesNotSetFeedbackErrorAndTransitionsCleanly() async throws {
        let (model, profileID) = try await makeSeededAppModel()
        model.setSessionForTesting(profileID: profileID, userID: nil)

        // Submitting partial form where user answered YES to episode but skipped subsequent questions
        var form = MorningCheckInForm()
        form.occurrence = .yes
        // presentState, spcOutcome, postEpisodeSupport all skipped (nil)
        XCTAssertTrue(form.canSubmit)

        let saved = await model.submitCheckIn(form)
        XCTAssertTrue(saved)
        XCTAssertNil(model.feedbackMessage)

        let checkIn = try XCTUnwrap(model.checkIns.first)
        XCTAssertEqual(checkIn.occurrence, .yes)
        XCTAssertNil(checkIn.presentState)
        XCTAssertNil(checkIn.spcOutcome)
        XCTAssertNil(checkIn.postEpisodeSupport)
        XCTAssertNil(checkIn.sleepHelpOutcome)

        // Verify clearFeedback removes any residual message
        model.feedbackMessage = "Temporary error"
        model.clearFeedback()
        XCTAssertNil(model.feedbackMessage)

        // Verify completeMorningCheckIn dismisses cleanly
        model.isMorningCheckInPresented = true
        model.completeMorningCheckIn()
        XCTAssertFalse(model.isMorningCheckInPresented)
    }

    // MARK: - 6. Moon Count Test

    @MainActor
    func testComputedMoonStageCount() {
        // NO branch: 2 moons
        XCTAssertEqual(MorningCheckInHeader.totalSteps(for: .sleepHelp, occurrence: .no), 2)
        XCTAssertEqual(MorningCheckInHeader.totalSteps(for: .sleepHelp, occurrence: nil), 2)
        XCTAssertEqual(MorningCheckInHeader.totalSteps(for: .episode, occurrence: .no), 2)

        // YES branch: 4 moons
        XCTAssertEqual(MorningCheckInHeader.totalSteps(for: .episode, occurrence: nil), 4)
        XCTAssertEqual(MorningCheckInHeader.totalSteps(for: .episode, occurrence: .yes), 4)
        XCTAssertEqual(MorningCheckInHeader.totalSteps(for: .feeling, occurrence: .yes), 4)
        XCTAssertEqual(MorningCheckInHeader.totalSteps(for: .spcOutcome, occurrence: .yes), 4)
        XCTAssertEqual(MorningCheckInHeader.totalSteps(for: .postEpisodeSupport, occurrence: .yes), 4)

        // Instance property evaluation
        let headerNo = MorningCheckInHeader(step: .sleepHelp, occurrence: .no)
        XCTAssertEqual(headerNo.totalSteps, 2)

        let headerYes = MorningCheckInHeader(step: .postEpisodeSupport, occurrence: .yes)
        XCTAssertEqual(headerYes.totalSteps, 4)

        let headerInitial = MorningCheckInHeader(step: .episode, occurrence: nil)
        XCTAssertEqual(headerInitial.totalSteps, 4)
    }

    // MARK: - Test Helpers

    @MainActor
    private func makeSeededAppModel() async throws -> (AppModel, UUID) {
        let namespace = "test-checkin-\(UUID().uuidString)"
        let location = LocalStoreLocation(namespace: namespace)
        let dbURL = try location.databaseURL()
        let database = try LocalDatabase(path: dbURL.path)

        let profile = Phase1BFixture.profile()
        try await database.createProfile(profile, settings: Phase1BFixture.settings())

        let store = makeTestPhase1Store(namespace: namespace)
        let model = makeTestAppModel(store: store)
        return (model, profile.id)
    }
}
