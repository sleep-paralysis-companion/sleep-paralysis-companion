import CoreMedia
import Foundation
@testable import SleepParalysisCompanion
import XCTest

final class WidgetActivationStoreTests: XCTestCase {
    func testPendingActivationSurvivesASecondStoreInstanceUntilConsumed() throws {
        let suite = uniqueSuite()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let first = ManualEpisodeActivationStore(suiteName: suite)
        let activation = try first.enqueue(
            id: XCTUnwrap(UUID(uuidString: "10000000-0000-4000-8000-000000000001")),
            requestedAt: Date(timeIntervalSince1970: 1)
        )

        let relaunched = ManualEpisodeActivationStore(suiteName: suite)
        XCTAssertEqual(try relaunched.firstPending(), activation)
        XCTAssertTrue(try relaunched.consume(id: activation.id))
        XCTAssertNil(try relaunched.firstPending())
    }

    func testDuplicateIdentifierIsQueuedAndConsumedExactlyOnce() throws {
        let suite = uniqueSuite()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let store = ManualEpisodeActivationStore(suiteName: suite)
        let id = try XCTUnwrap(UUID(uuidString: "10000000-0000-4000-8000-000000000002"))

        try store.enqueue(id: id)
        try store.enqueue(id: id)

        XCTAssertEqual(try store.firstPending()?.id, id)
        XCTAssertTrue(try store.consume(id: id))
        XCTAssertFalse(try store.consume(id: id))
        XCTAssertNil(try store.firstPending())
    }

    func testPreAuthenticationReadDoesNotConsumePendingActivation() throws {
        let suite = uniqueSuite()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let store = ManualEpisodeActivationStore(suiteName: suite)
        let activation = try store.enqueue()

        XCTAssertEqual(try store.firstPending()?.id, activation.id)
        XCTAssertEqual(try store.firstPending()?.id, activation.id)
        XCTAssertTrue(try store.consume(id: activation.id))
    }

    func testActivationPreservesRequestedPlaybackAction() throws {
        let suite = uniqueSuite()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let store = ManualEpisodeActivationStore(suiteName: suite)

        try store.enqueue(action: .pause)

        XCTAssertEqual(try store.firstPending()?.action, .pause)
    }

    func testWrongOrMissingSuiteNeverFallsBackToStandardDefaults() {
        UserDefaults.standard.removeObject(forKey: ManualEpisodeActivationStore.pendingKey)
        let store = ManualEpisodeActivationStore(suiteName: nil)

        XCTAssertThrowsError(try store.enqueue()) { error in
            XCTAssertEqual(error as? ManualEpisodeActivationError, .appGroupUnavailable)
        }
        XCTAssertNil(UserDefaults.standard.data(forKey: ManualEpisodeActivationStore.pendingKey))
    }

    private func uniqueSuite() -> String {
        "spc.tests.activation.\(UUID().uuidString)"
    }
}

final class SleepSessionFoundationTests: XCTestCase {
    func testLiveActivityContentStateDistinguishesPlaybackStates() {
        let ready = SleepSessionAttributes.ContentState(audioStatus: .ready)
        let playing = SleepSessionAttributes.ContentState(audioStatus: .playing)
        let paused = SleepSessionAttributes.ContentState(audioStatus: .paused)

        XCTAssertNotEqual(ready, playing)
        XCTAssertNotEqual(playing, paused)
        XCTAssertEqual(ready.audioStatus, .ready)
        XCTAssertEqual(playing.audioStatus, .playing)
        XCTAssertEqual(paused.audioStatus, .paused)
    }

    func testApplicationDeclaresLiveActivitiesBackgroundAudioAndBundledFonts() throws {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "NSSupportsLiveActivities") as? Bool, true)

        let backgroundModes = try XCTUnwrap(
            Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
        )
        XCTAssertTrue(backgroundModes.contains("audio"))

        let fonts = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "UIAppFonts") as? [String])
        XCTAssertTrue(fonts.contains("InterVariable.ttf"))
        XCTAssertTrue(fonts.contains("Lato-Bold.ttf"))
        XCTAssertTrue(fonts.contains("Lato-Regular.ttf"))
        XCTAssertTrue(fonts.contains("Lato-SemiBold.ttf"))
    }
}

final class RecordingAndAudioBoundaryTests: XCTestCase {
    @MainActor
    func testRecordingCancelsAtBothInactiveAndBackgroundBoundaries() {
        XCTAssertTrue(
            RecordingLifecycleBoundary.requiresCancellation(
                isRecording: true,
                sceneIsActive: false
            )
        )
        XCTAssertFalse(
            RecordingLifecycleBoundary.requiresCancellation(
                isRecording: true,
                sceneIsActive: true
            )
        )
        XCTAssertFalse(
            RecordingLifecycleBoundary.requiresCancellation(
                isRecording: false,
                sceneIsActive: false
            )
        )
        XCTAssertEqual(RecoveryAudioController.maximumRecordingDuration, 180)
    }

    func testDurationValidationAcceptsPolicyBoundaryBeforeIntegerConversion() throws {
        XCTAssertEqual(
            try PersonalAudioDurationValidator.milliseconds(
                from: CMTime(seconds: 180, preferredTimescale: 1000)
            ),
            180_000
        )
        XCTAssertEqual(
            try PersonalAudioDurationValidator.milliseconds(
                from: CMTime(seconds: 0, preferredTimescale: 1000)
            ),
            0
        )
    }

    func testDurationValidationRejectsInvalidIndefiniteNegativeAndOversizedValues() {
        let invalidValues = [
            CMTime.invalid,
            CMTime.indefinite,
            CMTime(seconds: -0.001, preferredTimescale: 1000),
            CMTime(seconds: 180.001, preferredTimescale: 1000),
        ]
        for value in invalidValues {
            XCTAssertThrowsError(try PersonalAudioDurationValidator.milliseconds(from: value))
        }
        XCTAssertThrowsError(
            try PersonalAudioDurationValidator.milliseconds(from: Double.nan)
        )
        XCTAssertThrowsError(
            try PersonalAudioDurationValidator.milliseconds(from: Double.infinity)
        )
    }

    func testAudioPolicyRejectsEleventhClipInputsByCountAndBadMetadataByPolicy() {
        XCTAssertEqual(PersonalAudioPolicy.maximumClipCount, 10)
        XCTAssertFalse(
            PersonalAudioPolicy.validates(
                source: .imported,
                storageFormat: .mp3,
                byteCount: PersonalAudioPolicy.maximumByteCount + 1,
                durationMilliseconds: 1
            )
        )
        XCTAssertFalse(
            PersonalAudioPolicy.validates(
                source: .recorded,
                storageFormat: .mp3,
                byteCount: 1,
                durationMilliseconds: 1
            )
        )
    }

    @MainActor
    func testImportedBytesAreRemovedWhenMetadataPersistenceFaults() async {
        var removed = false
        do {
            try await PersonalAudioLifecycleCoordinator.persistImported(
                persistMetadata: { throw CocoaError(.fileWriteUnknown) },
                removeCommittedBytes: { removed = true }
            )
            XCTFail("Expected persistence fault")
        } catch {
            XCTAssertTrue(removed)
        }
    }

    @MainActor
    func testDatabaseDeletionFaultRollsBackStagedBytes() async {
        var rolledBack = false
        do {
            try await PersonalAudioLifecycleCoordinator.delete(
                stageBytes: { testDeletionToken() },
                deleteMetadata: { throw CocoaError(.fileWriteUnknown) },
                restoreMetadata: {},
                commitBytes: { _ in XCTFail("Bytes must not commit") },
                rollbackBytes: { _ in rolledBack = true }
            )
            XCTFail("Expected database fault")
        } catch {
            XCTAssertTrue(rolledBack)
        }
    }

    @MainActor
    func testFileCommitFaultRestoresMetadataAndBytes() async {
        var metadataRestored = false
        var bytesRestored = false
        do {
            try await PersonalAudioLifecycleCoordinator.delete(
                stageBytes: { testDeletionToken() },
                deleteMetadata: {},
                restoreMetadata: { metadataRestored = true },
                commitBytes: { _ in throw CocoaError(.fileWriteUnknown) },
                rollbackBytes: { _ in bytesRestored = true }
            )
            XCTFail("Expected file fault")
        } catch {
            XCTAssertTrue(metadataRestored)
            XCTAssertTrue(bytesRestored)
        }
    }

    private func testDeletionToken() -> PersonalAudioDeletionToken {
        PersonalAudioDeletionToken(
            originalURL: URL(fileURLWithPath: "/original"),
            quarantinedURL: URL(fileURLWithPath: "/quarantined")
        )
    }
}

final class ReminderRepairTests: XCTestCase {
    func testZeroLeadPreservesAllSevenWeekdays() {
        var schedule = SleepSchedule.defaultValue
        schedule.sleepHour = 0
        schedule.sleepMinute = 0
        schedule.reminderLeadMinutes = 0
        schedule.weekdaysMask = 0b0111_1111

        let plans = SleepReminderPlanner.plans(for: schedule)
        XCTAssertEqual(plans.map(\.weekday), Array(1 ... 7))
        XCTAssertEqual(plans.map(\.hour), Array(repeating: 0, count: 7))
        XCTAssertEqual(plans.map(\.minute), Array(repeating: 0, count: 7))
    }

    func testPreviousDayRolloverWrapsSundayToSaturday() {
        var schedule = SleepSchedule.defaultValue
        schedule.sleepHour = 0
        schedule.sleepMinute = 15
        schedule.reminderLeadMinutes = 30
        schedule.weekdaysMask = 0b0111_1111

        let plans = SleepReminderPlanner.plans(for: schedule)
        XCTAssertEqual(plans.map(\.weekday), [7, 1, 2, 3, 4, 5, 6])
        XCTAssertTrue(plans.allSatisfy { $0.hour == 23 && $0.minute == 45 })
        XCTAssertEqual(Set(plans.map(\.identifier)).count, 7)
    }

    func testWallClockPlansRemainStableAcrossDSTTimeZones() {
        var schedule = SleepSchedule.defaultValue
        schedule.sleepHour = 0
        schedule.sleepMinute = 30
        schedule.reminderLeadMinutes = 60
        let expected = SleepReminderPlanner.plans(for: schedule)

        for identifier in ["America/Los_Angeles", "Europe/London", "Asia/Kolkata"] {
            XCTAssertNotNil(TimeZone(identifier: identifier))
            XCTAssertEqual(SleepReminderPlanner.plans(for: schedule), expected)
        }
    }

    func testDisabledScheduleProducesReplacementWithNoRequests() {
        var schedule = SleepSchedule.defaultValue
        schedule.isEnabled = false
        XCTAssertEqual(SleepReminderPlanner.plans(for: schedule), [])
    }

    func testReplacementRemovesOnlyOwnedRequestsBeforeAddingCurrentPlans() async throws {
        let scheduler = RecordingReminderScheduler(
            pending: ["paralux.sleep.reminder.1", "another.application"]
        )
        let service = SleepReminderService(scheduler: scheduler)
        var schedule = SleepSchedule.defaultValue
        schedule.weekdaysMask = 0b0000_0010

        _ = try await service.updateWithoutPrompt(schedule)

        let removed = await scheduler.removed
        let added = await scheduler.added
        XCTAssertEqual(removed, ["paralux.sleep.reminder.1"])
        XCTAssertEqual(added, SleepReminderPlanner.plans(for: schedule))
        XCTAssertEqual(added.first?.identifier, "sleepcompanion.sleep.reminder.2")
    }

    func testDisabledReplacementRemovesOwnedRequestsAndAddsNothing() async throws {
        let scheduler = RecordingReminderScheduler(
            pending: ["paralux.sleep.reminder.4"]
        )
        let service = SleepReminderService(scheduler: scheduler)
        var schedule = SleepSchedule.defaultValue
        schedule.isEnabled = false

        _ = try await service.updateWithoutPrompt(schedule)

        let removed = await scheduler.removed
        let added = await scheduler.added
        XCTAssertEqual(removed, ["paralux.sleep.reminder.4"])
        XCTAssertEqual(added, [])
    }
}

private actor RecordingReminderScheduler: ReminderNotificationScheduling {
    private let pending: [String]
    private(set) var removed: [String] = []
    private(set) var added: [SleepReminderPlan] = []

    init(pending: [String]) {
        self.pending = pending
    }

    func authorizationState() async -> ReminderAuthorizationState {
        .authorized
    }

    func requestAuthorization() async throws -> Bool {
        true
    }

    func pendingIdentifiers() async -> [String] {
        pending
    }

    func remove(identifiers: [String]) async {
        removed.append(contentsOf: identifiers)
    }

    func add(_ plan: SleepReminderPlan) async throws {
        added.append(plan)
    }
}

final class ExportLifecycleRepairTests: XCTestCase {
    func testCompletionOrCancellationRemovalDeletesPreparedArchive() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("spc-export-remove-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("prepared.zip")
        try Data("protected".utf8).write(to: url)
        let service = LocalExportService(
            clock: FixedClock(value: Phase1BFixture.now),
            identifier: FixedIdentifierGenerator(value: Phase1BFixture.key),
            protection: RecordingProtection()
        )

        try service.remove(url)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertNoThrow(try service.remove(url))
    }

    func testStartupRecoveryIsBoundedAndRemovesOnlyStaleZIPs() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("spc-export-recovery-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let stale = directory.appendingPathComponent("stale.zip")
        let fresh = directory.appendingPathComponent("fresh.zip")
        let audio = directory.appendingPathComponent("audio.m4a")
        for url in [stale, fresh, audio] {
            try Data("x".utf8).write(to: url)
        }
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 0)],
            ofItemAtPath: stale.path
        )
        let now = Date(timeIntervalSince1970: 172_800)
        try FileManager.default.setAttributes(
            [.modificationDate: now],
            ofItemAtPath: fresh.path
        )
        let service = LocalExportService(
            clock: FixedClock(value: now),
            identifier: FixedIdentifierGenerator(value: Phase1BFixture.key),
            protection: RecordingProtection()
        )

        try service.cleanupExpired(in: directory, now: now, maximumEntries: 64)

        XCTAssertFalse(FileManager.default.fileExists(atPath: stale.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fresh.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: audio.path))
    }
}

final class AuthenticatedJourneyDomainCoverageTests: XCTestCase {
    func testQ1ThroughQ3CanDeriveEveryPersona() {
        let cases: [(CalmingPersonContext, DerivedPersona)] = [
            (.besideMe, .frequentIntensePersonBesideUser),
            (.notAlwaysPresent, .frequentIntensePersonNotAlwaysPresent),
            (.alone, .frequentIntenseNoCalmingPerson),
        ]
        for (context, expected) in cases {
            XCTAssertEqual(
                PersonaRouting.derive(
                    episodeFrequency: .weekly,
                    postEpisodeFeeling: .awakeScared,
                    calmingPersonContext: context
                ),
                expected
            )
        }
        XCTAssertEqual(
            PersonaRouting.derive(
                episodeFrequency: .monthly,
                postEpisodeFeeling: .tooFrightenedToCloseEyes,
                calmingPersonContext: .alone
            ),
            .generalDefault
        )
        XCTAssertEqual(Set(DerivedPersona.allCases).count, 4)
    }

    func testCheckInHistoryAndDeletionFormsRetainExplicitValidation() {
        XCTAssertFalse(MorningCheckInForm().canSubmit)
        XCTAssertTrue(MorningCheckInForm(occurrence: .no).canSubmit)
        XCTAssertTrue(MorningCheckInForm(occurrence: .yes).canSubmit)
        XCTAssertTrue(MorningCheckInForm(occurrence: .no, sleepHelpOutcome: .didNotUseIt).canSubmit)
        XCTAssertTrue(
            MorningCheckInForm(
                occurrence: .yes,
                presentState: .stillShaken,
                spcOutcome: .noDifference,
                postEpisodeSupport: .partnerCall
            ).canSubmit
        )
    }
}

final class AlarmAndLockScreenCompanionFlowTests: XCTestCase {
    @MainActor
    func testTriggerAlarmRingingSetsStateAndStopNavigatesToCheckIn() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)

        XCTAssertFalse(model.isAlarmRinging)
        model.triggerAlarmRinging()
        XCTAssertTrue(model.isAlarmRinging)

        model.stopAlarm()
        XCTAssertFalse(model.isAlarmRinging)
        XCTAssertEqual(model.selectedTab, .sleep)
        XCTAssertTrue(model.isMorningCheckInPresented)
        XCTAssertTrue(model.path.contains(.morningCheckIn))
    }

    @MainActor
    func testSnoozeAlarmDismissesRingingState() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)

        model.triggerAlarmRinging()
        XCTAssertTrue(model.isAlarmRinging)

        model.snoozeAlarm(minutes: 5)
        XCTAssertFalse(model.isAlarmRinging)
    }

    @MainActor
    func testAlarmDeepLinksRouteCorrectly() throws {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)

        let ringingURL = try XCTUnwrap(URL(string: "spc://alarm-ringing"))
        model.openDeepLink(ringingURL)
        XCTAssertTrue(model.isAlarmRinging)

        let stopURL = try XCTUnwrap(URL(string: "spc://alarm-stop"))
        model.openDeepLink(stopURL)
        XCTAssertFalse(model.isAlarmRinging)
        XCTAssertEqual(model.selectedTab, .sleep)
        XCTAssertTrue(model.isMorningCheckInPresented)

        let checkinURL = try XCTUnwrap(URL(string: "spc://checkin"))
        model.openDeepLink(checkinURL)
        XCTAssertTrue(model.isMorningCheckInPresented)
    }

    @MainActor
    func testStartUnwindSessionNavigatesToSleepPlayerWithoutSecondSleep() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)

        model.startUnwindSession()
        XCTAssertFalse(model.isSleepSessionPresented)
        XCTAssertTrue(model.path.contains(.audioPlayer))
    }

    func testScheduleUIModelDefaultSnoozeMinutes() {
        let schedule = ScheduleUIModel.newSleep
        XCTAssertEqual(schedule.snoozeMinutes, 9)
    }

    @MainActor
    func testAppModelDynamicCatalogAssetTitleAndPlayback() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)

        guard let quickUnwind = CatalogAudioManifest.bundled.assets.first(where: { $0.id == "quick-unwind" }),
              let slowUnwind = CatalogAudioManifest.bundled.assets.first(where: { $0.id == "slow-unwind" })
        else {
            XCTFail("Missing bundled unwind assets in manifest")
            return
        }

        model.selectCatalogAsset(quickUnwind)
        XCTAssertEqual(model.activeTrackTitle, "Quick Unwind")
        XCTAssertEqual(model.activeTrackSubtitle, quickUnwind.shortDescription)
        XCTAssertEqual(model.selectedCatalogAsset?.id, "quick-unwind")

        model.selectCatalogAsset(slowUnwind)
        XCTAssertEqual(model.activeTrackTitle, "Slow Unwind")
        XCTAssertEqual(model.activeTrackSubtitle, slowUnwind.shortDescription)
        XCTAssertEqual(model.selectedCatalogAsset?.id, "slow-unwind")
    }
}
