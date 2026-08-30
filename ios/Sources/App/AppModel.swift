import Foundation
import Observation
import SwiftUI
import UIKit

// AppModel is the single observable integration boundary for the active app shell.
// swiftlint:disable file_length

@MainActor
@Observable
// swiftlint:disable:next type_body_length
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
    private(set) var alarmSchedules: [AlarmSchedule] = []
    private(set) var selectedAlarmScheduleID: UUID?
    private(set) var accountDeletionState = AccountDeletionState.idle
    var reminderAuthorization = ReminderAuthorizationState.notDetermined
    private(set) var wakeAlarmOutcome = WakeAlarmSchedulingOutcome.notRequested
    private(set) var checkIns: [SubmittedCheckIn] = []
    private(set) var partnerContact: PartnerContact?
    private(set) var playbackState = GroundingPlaybackState.idle
    private(set) var sleepSessionStartedAt: Date?
    private(set) var isSleepSessionPresented = false
    private(set) var isRecording = false
    private(set) var catalogAudioService: any CatalogAudioLibraryServicing
    private(set) var exportURL: URL?
    private(set) var audioExportURL: URL?
    private(set) var selectedCheckInID: UUID?
    var profile: LocalProfile?
    var settings: AppSettings?

    var scheduleUIModels: [ScheduleUIModel] {
        alarmSchedules
            .sorted { ($0.sortOrder, $0.createdAt) < ($1.sortOrder, $1.createdAt) }
            .map(ScheduleUIModel.init)
    }

    var selectedScheduleUIModel: ScheduleUIModel? {
        guard let selectedAlarmScheduleID,
              let schedule = alarmSchedules.first(where: { $0.id == selectedAlarmScheduleID })
        else { return nil }
        return ScheduleUIModel(schedule)
    }

    var scheduleAudioOptions: [ScheduleUIAudioSelection] {
        var result: [ScheduleUIAudioSelection] = [
            .bundled(id: SystemAudioAssets.defaultAlarmAssetID, title: "Gentle rise"),
        ]
        if let selectedID = AlarmSoundSelectionStore.selectedAlarmAssetID(),
           selectedID != SystemAudioAssets.defaultAlarmAssetID
        {
            result.append(.catalog(id: selectedID, title: "Downloaded sound", isAvailable: true))
        }
        result.append(contentsOf: personalClips.enumerated().map { index, clip in
            .personal(
                id: clip.id,
                title: "Personal recording \(index + 1)",
                isAvailable: clip.availability == .ready
            )
        })
        return result
    }

    func updatePartnerContact(_ contact: PartnerContact?) {
        partnerContact = contact
    }

    let environment: AppEnvironment
    let accessPolicy: AccessPolicy
    let providedAudio = ProvidedRecoveryAudio.approvedCatalog

    let store: IntegratedPhase1Store
    let authentication: any OAuthSessionServicing
    private let accountDeletionGateway: (any AccountDeletionGateway)?
    private let accountDeletionIdentifier: any IdentifierGenerating
    private let accountDeletionClock: any Phase1BClock
    private let audioFiles: PersonalAudioFileStore
    private let personalAlarmAudioPreparer: PersonalAlarmAudioPreparer
    private let audioController: RecoveryAudioController
    private let sleepSessionLiveActivities: SleepSessionLiveActivityController
    private let catalogAudioConfiguration: CatalogAudioRemoteConfiguration?
    let reminders: SleepReminderService
    private let wakeAlarms: WakeAlarmService
    private let logger: any PrivacySafeLogging
    let restorationCodec: RouteRestorationCodec
    private let deepLinkResolver: DeepLinkResolver

    @ObservationIgnored private var session: AuthenticationSessionMaterial?
    @ObservationIgnored private var accountDeletionCoordinator: AccountDeletionCoordinator?
    @ObservationIgnored private var pendingAccountDeletionSession: ReauthenticatedSession?
    @ObservationIgnored private var activationTask: Task<Void, Never>?
    @ObservationIgnored private var recordingLimitTask: Task<Void, Never>?
    @ObservationIgnored private var pendingRecordingClipID: UUID?
    @ObservationIgnored private var alarmSchedulingStates: [UUID: AlarmScheduleSchedulingState] = [:]

    init(
        environment: AppEnvironment,
        accessPolicy: AccessPolicy,
        store: IntegratedPhase1Store,
        authentication: any OAuthSessionServicing,
        accountDeletionGateway: (any AccountDeletionGateway)? = nil,
        accountDeletionIdentifier: any IdentifierGenerating = SystemIdentifierGenerator(),
        accountDeletionClock: any Phase1BClock = SystemPhase1BClock(),
        audioFiles: PersonalAudioFileStore = PersonalAudioFileStore(),
        audioController: RecoveryAudioController = RecoveryAudioController(),
        sleepSessionLiveActivities: SleepSessionLiveActivityController = SleepSessionLiveActivityController(),
        reminders: SleepReminderService = SleepReminderService(),
        wakeAlarms: WakeAlarmService = WakeAlarmService(),
        catalogAudioConfiguration: CatalogAudioRemoteConfiguration? = nil,
        logger: any PrivacySafeLogging,
        restorationCodec: RouteRestorationCodec = RouteRestorationCodec(),
        deepLinkResolver: DeepLinkResolver = DeepLinkResolver()
    ) {
        self.environment = environment
        self.accessPolicy = accessPolicy
        self.store = store
        self.authentication = authentication
        self.accountDeletionGateway = accountDeletionGateway
        self.accountDeletionIdentifier = accountDeletionIdentifier
        self.accountDeletionClock = accountDeletionClock
        self.audioFiles = audioFiles
        self.personalAlarmAudioPreparer = PersonalAlarmAudioPreparer(fileStore: audioFiles)
        self.audioController = audioController
        self.sleepSessionLiveActivities = sleepSessionLiveActivities
        self.catalogAudioConfiguration = catalogAudioConfiguration
        self.catalogAudioService = UnavailableCatalogAudioService()
        self.reminders = reminders
        self.wakeAlarms = wakeAlarms
        self.logger = logger
        self.restorationCodec = restorationCodec
        self.deepLinkResolver = deepLinkResolver
        self.audioController.recordingEndedUnexpectedly = { [weak self] in
            self?.cancelRecording(reason: "Recording stopped before it could be saved. No partial recording was kept.")
        }
        self.audioController.playbackStateDidChange = { [weak self] state in
            self?.playbackState = state
            self?.updateSleepSessionLiveActivityForPlayback()
        }
        SleepSessionAudioIntentBridge.shared.install { [weak self] action in
            self?.performSleepSessionAudioAction(action, presentSession: false) ?? false
        }
    }

    func activate(restoredState: String = "") {
        activationTask?.cancel()

        #if DEBUG
            if ProcessInfo.processInfo.environment["SPC_UI_TEST_OPEN_AUDIO_LIBRARY"] == "1" {
                launchDestination = .home
                selectedTab = .me
                path = [.curatedAudioLibrary]
                return
            }
        #endif

        launchDestination = .loading
        activationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await store.cleanupStructuredExports(
                in: structuredExportDirectory,
                maximumEntries: 64
            )
            await configureCatalogAudioServiceIfAvailable()
            reminderAuthorization = await reminders.authorizationState()
            do {
                guard let restoreResult = try await authentication.restore() else {
                    launchDestination = .splash
                    authenticationState = authentication.isConfigured ? .ready : .configurationRequired
                    accountAccessState = .signedOut
                    return
                }
                try await resume(session: restoreResult.session, restoredState: restoredState)
                #if DEBUG
                    applyUITestShowcaseRouteIfRequested()
                #endif
            } catch AuthenticationError.expired {
                session = nil
                authenticationState = .sessionExpired
                accountAccessState = .expired
                launchDestination = .authentication
            } catch let error as AuthenticationError {
                session = nil
                authenticationState = .failed
                accountAccessState = .signedOut
                feedbackMessage = "Authentication failed. Please sign in again."
                launchDestination = .authentication
            } catch {
                feedbackMessage = "Your protected local data could not be opened. Nothing was replaced."
                launchDestination = .recoverableError
            }
        }
    }

    #if DEBUG
        // swiftlint:disable:next cyclomatic_complexity
        private func applyUITestShowcaseRouteIfRequested() {
            guard let requestedRoute = ProcessInfo.processInfo.environment["SPC_UI_TEST_SHOWCASE_ROUTE"],
                  launchDestination == .home
            else { return }

            isMorningCheckInPresented = false
            path = []

            switch requestedRoute {
            case "sleep":
                selectedTab = .sleep
            case "journal":
                selectedTab = .journal
            case "home":
                selectedTab = .home
            case "activity":
                selectedTab = .activity
            case "me":
                selectedTab = .me
            case "grounding":
                selectedTab = .home
                path = [.grounding]
            case "audio-library":
                selectedTab = .home
                path = [.audioLibrary]
            case "curated-audio-library":
                selectedTab = .me
                path = [.curatedAudioLibrary]
            case "sleep-schedule":
                selectedTab = .home
                path = [.sleepSchedule]
            case "morning-check-in":
                selectedTab = .sleep
                isMorningCheckInPresented = true
            case "check-in-detail":
                selectedTab = .journal
                selectedCheckInID = checkIns.first?.id
                path = [.checkInDetail]
            case "edit-questionnaire":
                selectedTab = .me
                path = [.editQuestionnaire]
            case "accessibility":
                selectedTab = .me
                path = [.accessibility]
            case "data-privacy":
                selectedTab = .me
                path = [.dataPrivacy]
            case "help-legal":
                selectedTab = .me
                path = [.helpLegal]
            case "account":
                selectedTab = .me
                path = [.account]
            case "edit-profile":
                selectedTab = .me
                path = [.editProfile]
            case "default-settings":
                selectedTab = .me
                path = [.defaultSettings]
            default:
                break
            }
        }
    #endif

    private func configureCatalogAudioServiceIfAvailable() async {
        guard let catalogAudioConfiguration else { return }
        do {
            catalogAudioService = try await store.makeCatalogAudioService(
                configuration: catalogAudioConfiguration
            )
        } catch {
            catalogAudioService = UnavailableCatalogAudioService()
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
        accountDeletionState = .idle
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
                    launchDestination = .personalAudio
                }
            } catch {
                feedbackMessage =
                    "Your answer could not be saved. Try again; no persona was created from partial answers."
            }
        }
    }

    func continueFromRecommendedSetup() {
        guard persona != nil else { return }
        launchDestination = .sleepSchedule
    }

    func continueFromAudioSetup() {
        guard persona != nil else { return }
        launchDestination = .recommendedSetup
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
                let namedSchedule = AlarmSchedule(
                    legacy: schedule,
                    id: wakePreference.id,
                    profileID: profileID,
                    createdAt: wakePreference.createdAt,
                    updatedAt: wakePreference.updatedAt
                )
                alarmSchedules = [namedSchedule]
                launchDestination = .home
                resetNavigation()
                do {
                    try await refreshScheduleDeviceArtifacts(requestPermission: requestPermission)
                } catch {
                    wakeAlarmOutcome = .failed
                    feedbackMessage =
                        "Your schedule was saved, but reminders are unavailable on this device."
                }
            } catch {
                feedbackMessage =
                    "The schedule could not be saved. You can continue using Sleep Paralysis Companion " +
                    "without reminders."
            }
        }
    }

    func beginNewSchedule() {
        guard alarmSchedules.count < AlarmSchedule.maximumCount else {
            feedbackMessage = "You can create up to \(AlarmSchedule.maximumCount) schedules."
            return
        }
        selectedAlarmScheduleID = nil
    }

    func editSchedule(_ schedule: ScheduleUIModel) {
        selectedAlarmScheduleID = schedule.id
    }

    @discardableResult
    func saveScheduleUI(_ value: ScheduleUIModel) -> Bool {
        guard let profileID, let userID else { return false }
        let existing = alarmSchedules.first(where: { $0.id == value.id })
        let schedule = value.domainValue(
            profileID: profileID,
            existing: existing,
            sortOrder: existing?.sortOrder ?? alarmSchedules.count
        )
        var proposed = alarmSchedules.filter { $0.id != schedule.id }
        proposed.append(schedule)
        do {
            try AlarmScheduleValidator.validate(proposed)
        } catch AlarmScheduleValidationError.maximumSchedulesExceeded(limit: _) {
            feedbackMessage = "You can create up to \(AlarmSchedule.maximumCount) schedules."
            return false
        } catch AlarmScheduleValidationError.collision(_) {
            feedbackMessage = "This alarm collides with another enabled schedule. Choose a different time or reminder."
            return false
        } catch {
            feedbackMessage = "Choose valid times, repeat days, and reminder settings."
            return false
        }

        let previous = alarmSchedules
        alarmSchedules = proposed.sorted { ($0.sortOrder, $0.createdAt) < ($1.sortOrder, $1.createdAt) }
        selectedAlarmScheduleID = schedule.id
        updateLegacyScheduleSummary()
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                var storedSchedule = schedule
                if case let .personal(clipID)? = storedSchedule.wakeAudio?.reference {
                    if let clip = personalClips.first(where: { $0.id == clipID }) {
                        let prepared = try await personalAlarmAudioPreparer.prepare(clip: clip)
                        storedSchedule.wakeAudio?.localFileName = prepared.fileName
                        storedSchedule.wakeAudio?.availability = .available
                    } else {
                        storedSchedule.wakeAudio?.localFileName = nil
                        storedSchedule.wakeAudio?.availability = .unavailableOnThisDevice
                    }
                    if let index = alarmSchedules.firstIndex(where: { $0.id == storedSchedule.id }) {
                        alarmSchedules[index] = storedSchedule
                    }
                }
                let persisted = try await store.saveAlarmSchedule(
                    storedSchedule,
                    profileID: profileID,
                    userID: userID
                )
                if let index = alarmSchedules.firstIndex(where: { $0.id == persisted.id }) {
                    alarmSchedules[index] = persisted
                }
                try await refreshScheduleDeviceArtifacts(requestPermission: false)
                if storedSchedule.wakeAudioIsUnavailableOnThisDevice, storedSchedule.isEnabled {
                    feedbackMessage =
                        "Audio unavailable on this device. " +
                        "Choose another sound before this alarm can be scheduled."
                }
            } catch {
                alarmSchedules = previous
                updateLegacyScheduleSummary()
                feedbackMessage = "The schedule could not be saved. Nothing was replaced."
            }
        }
        return true
    }

    func toggleScheduleUI(_ value: ScheduleUIModel, enabled: Bool) {
        var draft = value
        draft.isEnabled = enabled
        _ = saveScheduleUI(draft)
    }

    func deleteScheduleUI(_ value: ScheduleUIModel) {
        guard let profileID, let userID,
              alarmSchedules.contains(where: { $0.id == value.id })
        else { return }
        let previous = alarmSchedules
        let deletedSchedule = alarmSchedules.first { $0.id == value.id }
        alarmSchedules.removeAll { $0.id == value.id }
        if selectedAlarmScheduleID == value.id {
            selectedAlarmScheduleID = nil
        }
        updateLegacyScheduleSummary()
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                if let deletedSchedule {
                    let currentState = alarmSchedulingStates[deletedSchedule.id]
                        ?? AlarmScheduleSchedulingState(scheduleID: deletedSchedule.id)
                    alarmSchedulingStates[deletedSchedule.id] = await wakeAlarms.cancel(
                        schedule: deletedSchedule,
                        state: currentState
                    )
                }
                try await store.deleteAlarmSchedule(id: value.id, profileID: profileID, userID: userID)
                try await refreshScheduleDeviceArtifacts(requestPermission: false)
                alarmSchedulingStates[value.id] = nil
            } catch {
                alarmSchedules = previous
                updateLegacyScheduleSummary()
                try? await refreshScheduleDeviceArtifacts(requestPermission: false)
                feedbackMessage = "The schedule could not be deleted."
            }
        }
    }

    private func refreshScheduleReminders(requestPermission: Bool) async throws {
        reminderAuthorization = requestPermission
            ? try await reminders.requestPermissionAndSchedule(alarmSchedules)
            : try await reminders.updateWithoutPrompt(alarmSchedules)
    }

    private func refreshScheduleDeviceArtifacts(requestPermission: Bool) async throws {
        try await refreshScheduleReminders(requestPermission: requestPermission)
        var outcomes: [WakeAlarmSchedulingOutcome] = []
        for schedule in alarmSchedules {
            let current = alarmSchedulingStates[schedule.id]
                ?? AlarmScheduleSchedulingState(scheduleID: schedule.id)
            let reconciled = await wakeAlarms.reconcile(schedule: schedule, state: current)
            alarmSchedulingStates[schedule.id] = reconciled.0
            outcomes.append(reconciled.1)
        }
        if outcomes.contains(.failed) || outcomes.contains(.audioAssetUnavailable) {
            wakeAlarmOutcome = .failed
        } else if outcomes.contains(.denied) {
            wakeAlarmOutcome = .denied
        } else if outcomes.contains(.scheduled) {
            wakeAlarmOutcome = .scheduled
        } else {
            wakeAlarmOutcome = .notRequested
        }
    }

    private func updateLegacyScheduleSummary() {
        guard let schedule = alarmSchedules.first(where: { $0.kind == .sleep && $0.isEnabled })
            ?? alarmSchedules.first(where: { $0.kind == .sleep })
        else { return }
        sleepSchedule = SleepSchedule(schedule)
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
                try await personalAlarmAudioPreparer.removePreparedClip(clipID: clip.id)
                personalClips.removeAll { $0.id == clip.id }
                for index in alarmSchedules.indices {
                    guard case let .personal(clipID)? = alarmSchedules[index].wakeAudio?.reference,
                          clipID == clip.id
                    else { continue }
                    var affected = alarmSchedules[index]
                    affected.wakeAudio?.localFileName = nil
                    affected.wakeAudio?.availability = .unavailableOnThisDevice
                    affected.updatedAt = Date()
                    affected.revision += 1
                    let saved = try await store.saveAlarmSchedule(
                        affected,
                        profileID: profileID,
                        userID: userID
                    )
                    alarmSchedules[index] = saved
                }
                try await refreshScheduleDeviceArtifacts(requestPermission: false)
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
                updateSleepSessionLiveActivityForPlayback()
            } catch {
                audioController.showVisualFallback()
                playbackState = .visualFallback
                updateSleepSessionLiveActivityForPlayback()
            }
        }
    }

    func togglePlayback() {
        audioController.togglePause()
        playbackState = audioController.playbackState
        updateSleepSessionLiveActivityForPlayback()
    }

    func stopPlayback() {
        audioController.stopPlayback()
        playbackState = .idle
        updateSleepSessionLiveActivityForPlayback()
    }

    func beginManualGrounding() {
        guard launchDestination == .home else { return }
        open(.grounding)
        playSelectedRecoveryAudio()
    }

    func startSleepSession() {
        guard launchDestination == .home else { return }
        let startedAt = sleepSessionStartedAt ?? Date()
        sleepSessionStartedAt = startedAt
        isSleepSessionPresented = true
        UserDefaults.standard.set(startedAt, forKey: Self.sleepSessionStartedAtKey)
        UIApplication.shared.isIdleTimerDisabled = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try sleepSessionLiveActivities.start(startedAt: startedAt)
            } catch {
                feedbackMessage = "Sleep mode started, but its Lock Screen companion is unavailable."
            }
        }
    }

    func minimizeSleepSession() {
        guard sleepSessionStartedAt != nil else { return }
        isSleepSessionPresented = false
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func presentActiveSleepSession() {
        guard launchDestination == .home, sleepSessionStartedAt != nil else { return }
        selectedTab = .sleep
        path = []
        isSleepSessionPresented = true
        UIApplication.shared.isIdleTimerDisabled = true
    }

    func endSleepSession() {
        sleepSessionStartedAt = nil
        isSleepSessionPresented = false
        UserDefaults.standard.removeObject(forKey: Self.sleepSessionStartedAtKey)
        UIApplication.shared.isIdleTimerDisabled = false
        stopPlayback()

        Task { @MainActor [weak self] in
            await self?.sleepSessionLiveActivities.end()
        }
    }

    func beginSleepSessionGrounding() {
        guard launchDestination == .home, sleepSessionStartedAt != nil else { return }
        playSelectedRecoveryAudio()
    }

    @discardableResult
    func performSleepSessionAudioAction(
        _ action: SleepSessionAudioAction,
        presentSession: Bool
    ) -> Bool {
        guard launchDestination == .home, sleepSessionStartedAt != nil else { return false }
        if presentSession {
            presentActiveSleepSession()
        }
        switch action {
        case .startOrResume:
            if case .paused = playbackState {
                togglePlayback()
            } else if case .playing = playbackState {
                break
            } else {
                beginSleepSessionGrounding()
            }
        case .pause:
            if case .playing = playbackState {
                togglePlayback()
            }
        case .resume:
            if case .paused = playbackState {
                togglePlayback()
            }
        }
        return true
    }

    var sleepSessionAudioStatus: SleepSessionAudioStatus {
        switch playbackState {
        case .playing: .playing
        case .paused: .paused
        default: .ready
        }
    }

    private func playSelectedRecoveryAudio() {
        guard case let .personalClip(id) = recoveryAudioDefault,
              let clip = personalClips.first(where: { $0.id == id })
        else {
            audioController.showVisualFallback()
            playbackState = .visualFallback
            updateSleepSessionLiveActivityForPlayback()
            return
        }
        play(clip)
    }

    private func updateSleepSessionLiveActivityForPlayback() {
        guard sleepSessionStartedAt != nil else { return }
        let status = sleepSessionAudioStatus
        Task { @MainActor [weak self] in
            await self?.sleepSessionLiveActivities.update(audioStatus: status)
        }
    }

    @discardableResult
    func requestManualGrounding() -> Bool {
        guard launchDestination == .home else { return false }
        if sleepSessionStartedAt != nil {
            isSleepSessionPresented = true
            beginSleepSessionGrounding()
        } else {
            beginManualGrounding()
        }
        return true
    }

    @discardableResult
    func requestSleepSessionAudioAction(_ action: SleepSessionAudioAction) -> Bool {
        if sleepSessionStartedAt != nil {
            return performSleepSessionAudioAction(action, presentSession: true)
        }
        guard action == .startOrResume else { return false }
        return requestManualGrounding()
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

    // swiftlint:disable:next cyclomatic_complexity
    func deleteRemoteAccount() {
        guard let profileID, let userID else { return }
        guard let accountDeletionGateway else {
            feedbackMessage = "Account deletion is unavailable until the secure service is configured."
            return
        }

        let coordinator: AccountDeletionCoordinator
        if let existing = accountDeletionCoordinator {
            coordinator = existing
        } else {
            let localDeletion = AppAccountLocalDataRemover(
                store: store,
                reminders: reminders,
                audioFiles: audioFiles,
                profileID: profileID,
                userID: userID
            )
            coordinator = AccountDeletionCoordinator(
                remote: accountDeletionGateway,
                localDeletion: localDeletion,
                sessionSignOut: authentication,
                identifier: accountDeletionIdentifier,
                clock: accountDeletionClock
            )
            accountDeletionCoordinator = coordinator
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let reauthenticated: ReauthenticatedSession
                switch await coordinator.state {
                case .failedRecoverable, .reauthenticationRequired:
                    if let pendingAccountDeletionSession {
                        reauthenticated = pendingAccountDeletionSession
                    } else {
                        let fresh = try await authentication.reauthenticateForDeletion()
                        pendingAccountDeletionSession = fresh
                        reauthenticated = fresh
                    }
                default:
                    let fresh = try await authentication.reauthenticateForDeletion()
                    pendingAccountDeletionSession = fresh
                    reauthenticated = fresh
                }
                try await coordinator.deleteAccount(
                    session: reauthenticated.session,
                    reauthentication: reauthenticated.proof,
                    removeLocalData: true
                )
                accountDeletionState = .completed
                clearSessionState()
                launchDestination = .splash
                feedbackMessage = AccountDeletionFeedback.completed
            } catch let error as AuthenticationError {
                accountDeletionState = await coordinator.state
                feedbackMessage = deletionFeedback(for: error)
            } catch let error as DeletionError {
                if case .remoteDeletionRejected = error {
                    accountDeletionCoordinator = nil
                    pendingAccountDeletionSession = nil
                }
                accountDeletionState = await coordinator.state
                feedbackMessage = deletionFeedback(for: error)
            } catch {
                accountDeletionState = await coordinator.state
                feedbackMessage = AccountDeletionFeedback.recoverable
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
        if url.scheme?.lowercased() == "spc", url.host?.lowercased() == "sleep-session" {
            presentActiveSleepSession()
            return
        }
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
        alarmSchedules = snapshot.schedules.sorted {
            ($0.sortOrder, $0.createdAt) < ($1.sortOrder, $1.createdAt)
        }
        updateLegacyScheduleSummary()
        do {
            try await refreshScheduleDeviceArtifacts(requestPermission: false)
        } catch {
            wakeAlarmOutcome = .failed
        }
        checkIns = snapshot.checkIns.sorted { $0.reportedForLocalDate > $1.reportedForLocalDate }
        partnerContact = snapshot.partnerContact
        profile = snapshot.profile
        settings = snapshot.settings
        feedbackMessage = nil

        if let next = snapshot.questionnaireDraft?.firstUnansweredQuestion {
            launchDestination = .question(next)
        } else if snapshot.persona == nil {
            launchDestination = .question(.episodeFrequency)
        } else if snapshot.profile.onboardingCompletedAt == nil {
            launchDestination = .personalAudio
        } else {
            launchDestination = .home
            restore(restoredState, profileID: snapshot.profile.id)
            restoreSleepSessionIfNeeded()
        }
    }

    private func restoreSleepSessionIfNeeded() {
        let persisted = UserDefaults.standard.object(forKey: Self.sleepSessionStartedAtKey) as? Date
        guard let startedAt = sleepSessionLiveActivities.activeStartedAt ?? persisted else { return }
        sleepSessionStartedAt = startedAt
        isSleepSessionPresented = true
        UIApplication.shared.isIdleTimerDisabled = true
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

    private static let sleepSessionStartedAtKey = "spc.sleepSession.startedAt.v1"

    private func clearSessionState() {
        if sleepSessionStartedAt != nil {
            endSleepSession()
        }
        cancelRecording(reason: nil)
        session = nil
        accountDeletionCoordinator = nil
        pendingAccountDeletionSession = nil
        userID = nil
        profileID = nil
        profile = nil
        settings = nil
        questionnaireDraft = nil
        persona = nil
        personalClips = []
        recoveryAudioDefault = nil
        alarmSchedules = []
        selectedAlarmScheduleID = nil
        alarmSchedulingStates = [:]
        checkIns = []
        partnerContact = nil
        audioExportURL = nil
        exportURL = nil
        audioController.stopPlayback()
        playbackState = .idle
        accountAccessState = .signedOut
        resetNavigation()
    }

    private func deletionFeedback(for error: Error) -> String {
        if let error = error as? AuthenticationError {
            switch error {
            case .wrongAccount:
                return "The provider account did not match this protected account. Local data was kept."
            case .cancelled:
                return "Provider reauthentication was cancelled. Local data was kept."
            default:
                break
            }
        }
        if let error = error as? DeletionError {
            switch error {
            case .wrongAccount:
                return "The provider account did not match this protected account. Local data was kept."
            case .recentReauthenticationRequired:
                return "A fresh Apple or Google sign-in is required before deletion. Local data was kept."
            case .localCleanupFailed:
                return "The account was deleted remotely, but local cleanup did not finish. " +
                    "Retry to complete local cleanup."
            case .remoteDeletionFailedRecoverable:
                return "Account deletion could not finish. Local data was kept. Retry to resume the same request."
            case .remoteDeletionRejected:
                return "The server rejected this deletion request. Local data was kept. Reauthenticate and try again."
            }
        }
        return "Account deletion did not complete. Local data was kept. You can retry the same request."
    }

    private var structuredExportDirectory: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("SleepParalysisCompanionStructuredExports", isDirectory: true)
    }

    private func cleanupAllStructuredExports() async {
        cleanupStructuredExport()
        try? FileManager.default.removeItem(at: structuredExportDirectory)
    }
}

private actor AppAccountLocalDataRemover: LocalAccountDataRemoving {
    private let store: IntegratedPhase1Store
    private let reminders: SleepReminderService
    private let audioFiles: PersonalAudioFileStore
    private let profileID: UUID
    private let userID: UUID

    init(
        store: IntegratedPhase1Store,
        reminders: SleepReminderService,
        audioFiles: PersonalAudioFileStore,
        profileID: UUID,
        userID: UUID
    ) {
        self.store = store
        self.reminders = reminders
        self.audioFiles = audioFiles
        self.profileID = profileID
        self.userID = userID
    }

    func deleteAllLocalData() async throws {
        do {
            try await reminders.removeAllAppCreatedAlarms()
            try await audioFiles.deleteAll(profileID: profileID)
            let structuredExports = FileManager.default.temporaryDirectory
                .appendingPathComponent("SleepParalysisCompanionStructuredExports", isDirectory: true)
            if FileManager.default.fileExists(atPath: structuredExports.path) {
                try FileManager.default.removeItem(at: structuredExports)
            }
            try await store.deleteAllLocalData(userID: userID)
        } catch {
            throw DeletionError.localCleanupFailed
        }
    }
}
