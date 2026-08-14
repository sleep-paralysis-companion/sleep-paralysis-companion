import Foundation
import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class AppModel {
    private(set) var launchDestination = LaunchDestination.loading
    var path: [AppRoute] = []
    var selectedTab = AppTab.home
    var isMorningCheckInPresented = false
    private(set) var presentedSheet: AppSheet?
    var feedbackMessage: String?
    private(set) var authenticationState = AuthenticationPresentationState.ready
    private(set) var accountAccessState = AccountAccessState.signedOut
    private(set) var profileID: UUID?
    private(set) var userID: UUID?
    private(set) var questionnaireDraft: QuestionnaireDraft?
    private(set) var persona: PersonaAnswerAggregate?
    private(set) var personalClips: [PersonalAudioClipMetadata] = []
    private(set) var recoveryAudioDefault: LocalRecoveryAudioDefault?
    private(set) var sleepSchedule = SleepSchedule.defaultValue
    var reminderAuthorization = ReminderAuthorizationState.notDetermined
    private(set) var wakeAlarmOutcome = WakeAlarmSchedulingOutcome.notRequested
    private(set) var checkIns: [SubmittedCheckIn] = []
    private(set) var playbackState = GroundingPlaybackState.idle
    private(set) var isRecording = false
    private(set) var exportURL: URL?
    private(set) var audioExportURL: URL?
    private(set) var selectedCheckInID: UUID?
    var profile: LocalProfile?
    var settings: AppSettings?

    let environment: AppEnvironment
    let accessPolicy: AccessPolicy
    let providedAudio = ProvidedRecoveryAudio.approvedCatalog

    let store: IntegratedPhase1Store
    let authentication: any OAuthSessionServicing
    private let audioFiles: PersonalAudioFileStore
    private let audioController: RecoveryAudioController
    let reminders: SleepReminderService
    private let wakeAlarms: WakeAlarmService
    private let logger: any PrivacySafeLogging
    let restorationCodec: RouteRestorationCodec
    private let deepLinkResolver: DeepLinkResolver

    @ObservationIgnored private var session: AuthenticationSessionMaterial?
    @ObservationIgnored private var activationTask: Task<Void, Never>?
    @ObservationIgnored private var recordingLimitTask: Task<Void, Never>?
    @ObservationIgnored private var pendingRecordingClipID: UUID?

    init(
        environment: AppEnvironment,
        accessPolicy: AccessPolicy,
        store: IntegratedPhase1Store,
        authentication: any OAuthSessionServicing,
        audioFiles: PersonalAudioFileStore = PersonalAudioFileStore(),
        audioController: RecoveryAudioController = RecoveryAudioController(),
        reminders: SleepReminderService = SleepReminderService(),
        wakeAlarms: WakeAlarmService = WakeAlarmService(),
        logger: any PrivacySafeLogging,
        restorationCodec: RouteRestorationCodec = RouteRestorationCodec(),
        deepLinkResolver: DeepLinkResolver = DeepLinkResolver()
    ) {
        self.environment = environment
        self.accessPolicy = accessPolicy
        self.store = store
        self.authentication = authentication
        self.audioFiles = audioFiles
        self.audioController = audioController
        self.reminders = reminders
        self.wakeAlarms = wakeAlarms
        self.logger = logger
        self.restorationCodec = restorationCodec
        self.deepLinkResolver = deepLinkResolver
        self.audioController.recordingEndedUnexpectedly = { [weak self] in
            self?.cancelRecording(reason: "Recording stopped before it could be saved. No partial recording was kept.")
        }
    }

    func activate(restoredState: String = "") {
        activationTask?.cancel()
        launchDestination = .loading
        activationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await store.cleanupStructuredExports(
                in: structuredExportDirectory,
                maximumEntries: 64
            )
            reminderAuthorization = await reminders.authorizationState()
            do {
                guard let restored = try await authentication.restore() else {
                    launchDestination = .splash
                    authenticationState = authentication.isConfigured ? .ready : .configurationRequired
                    accountAccessState = .signedOut
                    return
                }
                try await resume(session: restored, restoredState: restoredState)
            } catch AuthenticationError.expired {
                session = nil
                authenticationState = .sessionExpired
                accountAccessState = .expired
                launchDestination = .authentication
            } catch {
                feedbackMessage = "Your protected local data could not be opened. Nothing was replaced."
                launchDestination = .recoverableError
            }
        }
    }

    func continueFromSplash() {
        guard launchDestination == .splash else { return }
        launchDestination = .introduction(0)
    }

    func advanceIntroduction(from page: Int) {
        if page + 1 < FeatureIntroductionPage.allCases.count {
            launchDestination = .introduction(page + 1)
        } else {
            launchDestination = .authentication
        }
    }

    func skipIntroduction() {
        guard case .introduction = launchDestination else { return }
        launchDestination = .authentication
    }

    func signIn(provider: AuthenticationProvider) {
        guard authentication.isConfigured else {
            authenticationState = .configurationRequired
            return
        }
        authenticationState = .processing(provider)
        feedbackMessage = nil
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let value = try await authentication.signIn(provider: provider)
                try await resume(session: value, restoredState: "")
                authenticationState = .ready
            } catch AuthenticationError.cancelled {
                authenticationState = .cancelled
            } catch AuthenticationError.wrongAccount {
                accountAccessState = .wrongAccount
                authenticationState = .failed
                feedbackMessage = "This account does not match the protected profile on this device."
            } catch {
                authenticationState = .failed
                feedbackMessage = "Sign-in did not finish. Check the provider configuration and try again."
            }
        }
    }

    func answer(
        frequency: EpisodeFrequency? = nil,
        feeling: PostEpisodeFeeling? = nil,
        context: CalmingPersonContext? = nil
    ) {
        guard let profileID, let userID else { return }
        let now = Date()
        let current = questionnaireDraft ?? QuestionnaireDraft(
            id: UUID(),
            profileID: profileID,
            accountUserID: userID,
            episodeFrequency: nil,
            postEpisodeFeeling: nil,
            calmingPersonContext: nil,
            createdAt: now,
            updatedAt: now
        )
        let updated = QuestionnaireDraft(
            id: current.id,
            profileID: profileID,
            accountUserID: userID,
            episodeFrequency: frequency ?? current.episodeFrequency,
            postEpisodeFeeling: feeling ?? current.postEpisodeFeeling,
            calmingPersonContext: context ?? current.calmingPersonContext,
            createdAt: current.createdAt,
            updatedAt: now
        )
        questionnaireDraft = updated
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await store.saveDraft(updated)
                if let next = updated.firstUnansweredQuestion {
                    launchDestination = .question(next)
                } else {
                    persona = try await store.completeQuestionnaire(
                        profileID: profileID,
                        userID: userID
                    )
                    questionnaireDraft = nil
                    launchDestination = .recommendedSetup
                }
            } catch {
                feedbackMessage =
                    "Your answer could not be saved. Try again; no persona was created from partial answers."
            }
        }
    }

    func continueFromRecommendedSetup() {
        guard persona != nil else { return }
        launchDestination = .personalAudio
    }

    func continueFromAudioSetup() {
        launchDestination = .sleepSchedule
    }

    func saveSleepSchedule(_ schedule: SleepSchedule, requestPermission: Bool) {
        guard let profileID, let userID, schedule.isValid else {
            feedbackMessage = "Choose a valid sleep and wake time."
            return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let wakePreference = try await store.saveSchedule(
                    schedule,
                    profileID: profileID,
                    userID: userID
                )
                sleepSchedule = schedule
                reminderAuthorization = requestPermission
                    ? try await reminders.requestPermissionAndSchedule(schedule)
                    : try await reminders.updateWithoutPrompt(schedule)
                let wakeResult = await wakeAlarms.reconcile(
                    schedule: schedule,
                    preference: wakePreference
                )
                wakeAlarmOutcome = wakeResult.1
                try await store.saveWakeAlarmPreference(
                    wakeResult.0,
                    profileID: profileID,
                    userID: userID
                )
                launchDestination = .home
                resetNavigation()
            } catch {
                feedbackMessage =
                    "The schedule could not be saved. You can continue using Sleep Paralysis Companion " +
                    "without reminders."
            }
        }
    }

    func importAudio(from url: URL) {
        guard let profileID, let userID else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let clipID = UUID()
            do {
                let metadata = try await audioFiles.importClip(
                    from: url,
                    profileID: profileID,
                    clipID: clipID
                )
                try await PersonalAudioLifecycleCoordinator.persistImported(
                    persistMetadata: {
                        try await self.store.saveClip(metadata, userID: userID)
                    },
                    removeCommittedBytes: {
                        try await self.audioFiles.delete(metadata)
                    }
                )
                personalClips.append(metadata)
            } catch {
                feedbackMessage = "That audio file could not be imported. No partial copy was kept."
            }
        }
    }

    func startRecording() {
        guard let profileID else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let permission = audioController.microphonePermission()
            let allowed: Bool = if permission == .granted {
                true
            } else if permission == .undetermined {
                await audioController.requestMicrophonePermission()
            } else {
                false
            }
            guard allowed else {
                audioController.deactivateRecordingSession()
                feedbackMessage = "Microphone access is off. You can import audio or continue without recording."
                return
            }
            let clipID = UUID()
            do {
                let url = try await audioFiles.recordingURL(profileID: profileID, clipID: clipID)
                try audioController.startRecording(to: url)
                pendingRecordingClipID = clipID
                isRecording = true
                beginRecordingLimit()
            } catch {
                audioController.deactivateRecordingSession()
                await audioFiles.discardRecording(profileID: profileID, clipID: clipID)
                feedbackMessage = "Recording could not start. Check microphone access and try again."
            }
        }
    }

    func stopAndSaveRecording() {
        guard let profileID, let userID, let clipID = pendingRecordingClipID else { return }
        let duration = audioController.stopRecording()
        recordingLimitTask?.cancel()
        recordingLimitTask = nil
        isRecording = false
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let metadata = try await audioFiles.metadataForRecording(
                    profileID: profileID,
                    clipID: clipID,
                    duration: duration
                )
                try await store.saveClip(metadata, userID: userID)
                personalClips.append(metadata)
                pendingRecordingClipID = nil
            } catch {
                await audioFiles.discardRecording(profileID: profileID, clipID: clipID)
                pendingRecordingClipID = nil
                feedbackMessage = "The recording could not be saved."
            }
        }
    }

    func cancelRecording() {
        cancelRecording(reason: nil)
    }

    func handleScenePhase(_ phase: ScenePhase) {
        guard RecordingLifecycleBoundary.requiresCancellation(
            isRecording: isRecording,
            sceneIsActive: phase == .active
        ) else { return }
        cancelRecording(
            reason: "Recording stopped when Sleep Paralysis Companion left the foreground. " +
                "No partial recording was kept."
        )
    }

    private func cancelRecording(reason: String?) {
        recordingLimitTask?.cancel()
        recordingLimitTask = nil
        audioController.cancelRecording()
        if let profileID, let clipID = pendingRecordingClipID {
            Task { await audioFiles.discardRecording(profileID: profileID, clipID: clipID) }
        }
        pendingRecordingClipID = nil
        isRecording = false
        if let reason {
            feedbackMessage = reason
        }
    }

    private func beginRecordingLimit() {
        recordingLimitTask?.cancel()
        recordingLimitTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(RecoveryAudioController.maximumRecordingDuration))
            guard !Task.isCancelled else { return }
            self?.cancelRecording(reason: "The 3-minute recording limit was reached. No partial recording was kept.")
        }
    }

    func selectPersonalClip(_ clip: PersonalAudioClipMetadata) {
        setAudioDefault(.personalClip(clip.id))
    }

    func selectProvidedAudio(_ item: ProvidedRecoveryAudio) {
        guard item.isBundled else {
            feedbackMessage = "Production Sleep Paralysis Companion audio assets are not bundled in this checkout."
            return
        }
        setAudioDefault(.catalogItem(item.id))
    }

    func deleteClip(_ clip: PersonalAudioClipMetadata) {
        guard let profileID, let userID else { return }
        audioController.stopPlayback()
        playbackState = .idle
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await PersonalAudioLifecycleCoordinator.delete(
                    stageBytes: { try await self.audioFiles.stageDeletion(clip) },
                    deleteMetadata: {
                        try await self.store.deleteClip(
                            id: clip.id,
                            profileID: profileID,
                            userID: userID
                        )
                    },
                    restoreMetadata: {
                        try await self.store.saveClip(clip, userID: userID)
                    },
                    commitBytes: { try await self.audioFiles.commitDeletion($0) },
                    rollbackBytes: { try await self.audioFiles.rollbackDeletion($0) }
                )
                personalClips.removeAll { $0.id == clip.id }
                if recoveryAudioDefault == .personalClip(clip.id) {
                    recoveryAudioDefault = nil
                }
            } catch {
                feedbackMessage = "The clip could not be deleted completely."
            }
        }
    }

    func prepareAudioExport(_ clip: PersonalAudioClipMetadata) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                audioExportURL = try await audioFiles.protectedExportURL(for: clip)
            } catch {
                feedbackMessage = "The protected temporary audio export could not be created."
            }
        }
    }

    func cleanupAudioExport() {
        guard let audioExportURL else { return }
        Task { await audioFiles.removeTemporaryExport(audioExportURL) }
        self.audioExportURL = nil
    }

    func play(_ clip: PersonalAudioClipMetadata) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let url = try await audioFiles.existingURL(for: clip)
                try audioController.play(url: url, identifier: clip.id.uuidString)
                playbackState = audioController.playbackState
            } catch {
                audioController.showVisualFallback()
                playbackState = .visualFallback
            }
        }
    }

    func togglePlayback() {
        audioController.togglePause()
        playbackState = audioController.playbackState
    }

    func stopPlayback() {
        audioController.stopPlayback()
        playbackState = .idle
    }

    func beginManualGrounding() {
        guard launchDestination == .home else { return }
        open(.grounding)
        guard case let .personalClip(id) = recoveryAudioDefault,
              let clip = personalClips.first(where: { $0.id == id })
        else {
            audioController.showVisualFallback()
            playbackState = .visualFallback
            return
        }
        play(clip)
    }

    @discardableResult
    func requestManualGrounding() -> Bool {
        guard launchDestination == .home else { return false }
        beginManualGrounding()
        return true
    }

    @discardableResult
    func submitCheckIn(_ form: MorningCheckInForm, editing: SubmittedCheckIn? = nil) async -> Bool {
        guard let profileID, let userID, let occurrence = form.occurrence, form.canSubmit else {
            return false
        }
        let now = Date()
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let value = SubmittedCheckIn(
            id: editing?.id ?? UUID(),
            profileID: profileID,
            reportedForLocalDate: editing?.reportedForLocalDate ?? formatter.string(from: now),
            reportedTimezoneID: TimeZone.current.identifier,
            occurrence: occurrence,
            perceivedIntensity: nil,
            presentState: occurrence == .yes ? form.presentState : nil,
            spcOutcome: occurrence == .yes ? form.spcOutcome : nil,
            postEpisodeSupport: occurrence == .yes ? form.postEpisodeSupport : nil,
            sleepHelpOutcome: occurrence == .no ? form.sleepHelpOutcome : nil,
            note: nil,
            createdAt: editing?.createdAt ?? now,
            updatedAt: now,
            revision: (editing?.revision ?? 0) + 1,
            deletedAt: nil
        )
        do {
            try await store.saveCheckIn(value, userID: userID)
            checkIns.removeAll { $0.id == value.id }
            checkIns.insert(value, at: 0)
            if path.last == .morningCheckIn {
                path.removeLast()
            }
            return true
        } catch {
            feedbackMessage = "The check-in could not be saved. Your answers remain on screen."
            return false
        }
    }

    func selectCheckIn(_ value: SubmittedCheckIn) {
        selectedCheckInID = value.id
        open(.checkInDetail)
    }

    func deleteCheckIn(_ value: SubmittedCheckIn) {
        guard let userID else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await store.deleteCheckIn(value, userID: userID)
                checkIns.removeAll { $0.id == value.id }
                path.removeAll { $0 == .checkInDetail }
            } catch {
                feedbackMessage = "The history entry could not be deleted."
            }
        }
    }

    func updateQuestionnaire(
        frequency: EpisodeFrequency,
        feeling: PostEpisodeFeeling,
        context: CalmingPersonContext
    ) {
        guard let existing = persona else { return }
        let now = Date()
        let revised = PersonaAnswerAggregate(
            id: existing.id,
            profileID: existing.profileID,
            accountUserID: existing.accountUserID,
            episodeFrequency: frequency,
            postEpisodeFeeling: feeling,
            calmingPersonContext: context,
            derivedPersona: PersonaRouting.derive(
                episodeFrequency: frequency,
                postEpisodeFeeling: feeling,
                calmingPersonContext: context
            ),
            routingRuleVersion: PersonaRouting.initialRuleVersion,
            calculatedAt: now,
            createdAt: existing.createdAt,
            updatedAt: now,
            revision: existing.revision + 1
        )
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await store.replacePersona(revised)
                persona = revised
                path.removeAll { $0 == .editQuestionnaire }
            } catch {
                feedbackMessage = "The answers were not changed."
            }
        }
    }

    func createStructuredExport() {
        guard let profileID, let userID else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                cleanupStructuredExport()
                let versionValue = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
                let version = versionValue as? String ?? "unknown"
                exportURL = try await store.export(
                    profileID: profileID,
                    userID: userID,
                    appVersion: version,
                    directory: structuredExportDirectory
                ).archiveURL
            } catch {
                feedbackMessage = "The structured export could not be created."
            }
        }
    }

    func cleanupStructuredExport() {
        guard let exportURL else { return }
        self.exportURL = nil
        Task { try? await store.removeStructuredExport(at: exportURL) }
    }

    func signOut() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await authentication.signOut()
            } catch {
                feedbackMessage = "The remote session may still be active. Try signing out again."
                return
            }
            await cleanupAllStructuredExports()
            clearSessionState()
            launchDestination = .authentication
        }
    }

    func deleteAllLocalData() {
        guard let userID, let profileID else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await reminders.removeAllAppCreatedAlarms()
                try await audioFiles.deleteAll(profileID: profileID)
                await cleanupAllStructuredExports()
                try await store.deleteAllLocalData(userID: userID)
                try? await authentication.signOut()
                clearSessionState()
                launchDestination = .splash
            } catch {
                feedbackMessage = "Local deletion did not complete. No completion was reported."
            }
        }
    }

    func deleteRemoteAccount() {
        guard let profileID, let userID else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await authentication.deleteRemoteAccount()
                try await reminders.removeAllAppCreatedAlarms()
                try await audioFiles.deleteAll(profileID: profileID)
                await cleanupAllStructuredExports()
                try await store.deleteAllLocalData(userID: userID)
                clearSessionState()
                launchDestination = .splash
            } catch {
                feedbackMessage = "Account deletion did not complete. Local data was kept."
            }
        }
    }

    func open(_ route: AppRoute) {
        guard launchDestination == .home else { return }
        if route == .morningCheckIn {
            isMorningCheckInPresented = true
            selectedTab = .sleep
            path = []
            return
        }
        path.append(route)
        if route == .grounding {
            logger.record(.routeChanged, category: .navigation)
        }
    }

    func openDeepLink(_ url: URL) {
        guard let route = deepLinkResolver.route(for: url) else { return }
        if launchDestination == .home {
            if route == .grounding {
                beginManualGrounding()
            } else {
                open(route)
            }
        }
    }

    func setPath(_ value: [AppRoute]) {
        path = value
    }

    func selectTab(_ value: AppTab) {
        selectedTab = value
        path = []
        if value != .sleep {
            isMorningCheckInPresented = false
        }
    }

    func dismissSheet() {
        presentedSheet = nil
    }

    func clearFeedback() {
        feedbackMessage = nil
    }

    private func resume(
        session: AuthenticationSessionMaterial,
        restoredState: String
    ) async throws {
        let snapshot = try await store.resume(session: session)
        self.session = session
        userID = session.userID
        profileID = snapshot.profile.id
        accountAccessState = .signedInMatching
        questionnaireDraft = snapshot.questionnaireDraft
        persona = snapshot.persona
        personalClips = snapshot.clips
        recoveryAudioDefault = snapshot.audioDefault
        sleepSchedule = snapshot.schedule
        wakeAlarmOutcome = snapshot.schedule.wakeAlarmIsRequested ? .audioAssetUnavailable : .notRequested
        checkIns = snapshot.checkIns.sorted { $0.reportedForLocalDate > $1.reportedForLocalDate }
        profile = snapshot.profile
        settings = snapshot.settings
        feedbackMessage = nil

        if let next = snapshot.questionnaireDraft?.firstUnansweredQuestion {
            launchDestination = .question(next)
        } else if snapshot.persona == nil {
            launchDestination = .question(.episodeFrequency)
        } else if snapshot.profile.onboardingCompletedAt == nil {
            launchDestination = .recommendedSetup
        } else {
            launchDestination = .home
            restore(restoredState, profileID: snapshot.profile.id)
        }
    }

    private func setAudioDefault(_ value: LocalRecoveryAudioDefault) {
        guard let profileID, let userID else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await store.setAudioDefault(
                    value,
                    profileID: profileID,
                    userID: userID
                )
                recoveryAudioDefault = value
            } catch {
                feedbackMessage = "That audio choice is not available."
            }
        }
    }

    private func restore(_ value: String, profileID: UUID) {
        guard let envelope = restorationCodec.decode(value, profileID: profileID) else {
            resetNavigation()
            return
        }
        selectedTab = envelope.selectedTab
        path = envelope.path
        presentedSheet = envelope.sheet
        if path.last == .morningCheckIn {
            path.removeLast()
            isMorningCheckInPresented = true
            selectedTab = .sleep
        }
    }

    private func resetNavigation() {
        selectedTab = .home
        path = []
        presentedSheet = nil
        isMorningCheckInPresented = false
    }

    private func clearSessionState() {
        cancelRecording(reason: nil)
        session = nil
        userID = nil
        profileID = nil
        profile = nil
        settings = nil
        questionnaireDraft = nil
        persona = nil
        personalClips = []
        recoveryAudioDefault = nil
        checkIns = []
        audioExportURL = nil
        exportURL = nil
        audioController.stopPlayback()
        playbackState = .idle
        accountAccessState = .signedOut
        resetNavigation()
    }

    private var structuredExportDirectory: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ParaluxStructuredExports", isDirectory: true)
    }

    private func cleanupAllStructuredExports() async {
        cleanupStructuredExport()
        try? FileManager.default.removeItem(at: structuredExportDirectory)
    }
}
