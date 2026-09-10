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
    var selectedTab = AppTab.sleep
    var isMorningCheckInPresented = false
    var presentedSheet: AppSheet?
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
    var isSleepSessionPresented = false
    private(set) var isRecording = false
    private(set) var catalogAudioService: any CatalogAudioLibraryServicing
    @ObservationIgnored let catalogAudioPlayer = CatalogAudioPlayer()
    var selectedCatalogAsset: CatalogAudioAsset?
    private(set) var exportURL: URL?
    private(set) var audioExportURL: URL?
    private(set) var selectedCheckInID: UUID?
    private(set) var sleepTimerRemaining: TimeInterval?
    @ObservationIgnored private var sleepTimerTask: Task<Void, Never>?
    var isAlarmRinging: Bool = false
    private(set) var ringingAlarmSchedule: ScheduleUIModel?
    @ObservationIgnored var alarmSnoozeTask: Task<Void, Never>?
    @ObservationIgnored var foregroundAlarmMonitorTask: Task<Void, Never>?
    @ObservationIgnored var firedAlarmMinuteKeys: Set<String> = []
    @ObservationIgnored private var tonightScheduleSaveTask: Task<Void, Never>?
    @ObservationIgnored private var fallbackTonightScheduleID = UUID()
    private(set) var tonightScheduleID: UUID?
    var profile: LocalProfile?
    var settings: AppSettings?

    var scheduleUIModels: [ScheduleUIModel] {
        alarmSchedules
            .sorted { ($0.sortOrder, $0.createdAt) < ($1.sortOrder, $1.createdAt) }
            .map { ScheduleUIModel($0) }
    }

    var selectedScheduleUIModel: ScheduleUIModel? {
        guard let selectedAlarmScheduleID,
              let schedule = alarmSchedules.first(where: { $0.id == selectedAlarmScheduleID })
        else { return nil }
        return ScheduleUIModel(schedule)
    }

    var tonightSchedule: AlarmSchedule? {
        guard !alarmSchedules.isEmpty else { return nil }

        let now = Date()
        let calendar = Calendar.current
        let todayLocalDate = AlarmLocalDate(date: now, calendar: calendar)
        let tomorrowLocalDate = todayLocalDate.addingDays(1, calendar: calendar)
        let todayWeekday = todayLocalDate.date(in: calendar).map { calendar.component(.weekday, from: $0) }
            ?? calendar.component(.weekday, from: now)
        let tomorrowWeekday = (todayWeekday % 7) + 1
        let currentMinuteOfDay = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)

        let matchingEnabled = alarmSchedules.filter { schedule in
            guard schedule.isEnabled else { return false }
            switch schedule.kind {
            case .sleep:
                let matchesTonightBedtime = (schedule.weekdaysMask & (1 << (todayWeekday - 1))) != 0
                let yesterdayWeekday = ((todayWeekday + 5) % 7) + 1
                let matchesLastNightBedtime = currentMinuteOfDay < (schedule.wakeHour * 60 + schedule.wakeMinute)
                    && (schedule.weekdaysMask & (1 << (yesterdayWeekday - 1))) != 0
                return matchesTonightBedtime || matchesLastNightBedtime
            case .wakeOnlyRecurring:
                let matchesTomorrowWake = (schedule.weekdaysMask & (1 << (tomorrowWeekday - 1))) != 0
                let matchesTodayWake = currentMinuteOfDay < (schedule.wakeHour * 60 + schedule.wakeMinute)
                    && (schedule.weekdaysMask & (1 << (todayWeekday - 1))) != 0
                return matchesTomorrowWake || matchesTodayWake
            case .wakeOnlyOneTime:
                let matchesTodayOneTime = currentMinuteOfDay < (schedule.wakeHour * 60 + schedule.wakeMinute)
                    && schedule.oneTimeDate == todayLocalDate
                return schedule.oneTimeDate == tomorrowLocalDate || matchesTodayOneTime
            }
        }

        if let primary = matchingEnabled.first(where: { $0.kind == .sleep }) {
            tonightScheduleID = primary.id
            return primary
        }
        if let primary = matchingEnabled.first {
            tonightScheduleID = primary.id
            return primary
        }

        if let tonightScheduleID,
           let existingTonight = alarmSchedules.first(where: { $0.id == tonightScheduleID })
        {
            return existingTonight
        }

        if let enabledSleep = alarmSchedules.first(where: { $0.isEnabled && $0.kind == .sleep }) {
            tonightScheduleID = enabledSleep.id
            return enabledSleep
        }
        if let enabled = alarmSchedules.first(where: { $0.isEnabled }) {
            tonightScheduleID = enabled.id
            return enabled
        }
        if let sleep = alarmSchedules.first(where: { $0.kind == .sleep }) {
            tonightScheduleID = sleep.id
            return sleep
        }

        let fallback = alarmSchedules.first
        tonightScheduleID = fallback?.id
        return fallback
    }

    var tonightScheduleUIModel: ScheduleUIModel {
        if let schedule = tonightSchedule {
            return ScheduleUIModel(schedule)
        }
        return ScheduleUIModel(
            id: fallbackTonightScheduleID,
            name: "Sleep schedule",
            kind: .sleep,
            bedtimeHour: sleepSchedule.sleepHour,
            bedtimeMinute: sleepSchedule.sleepMinute,
            wakeHour: sleepSchedule.wakeHour,
            wakeMinute: sleepSchedule.wakeMinute,
            repeatWeekdaysMask: sleepSchedule.weekdaysMask == 0 ? 0b0111_1111 : sleepSchedule.weekdaysMask,
            bedtimeReminderLeadMinutes: sleepSchedule.reminderLeadMinutes == 0 ? 15 : sleepSchedule.reminderLeadMinutes,
            preWakeReminderLeadMinutes: sleepSchedule.wakeReminderLeadMinutes ?? 15,
            wakeAudio: .bundled(id: SystemAudioAssets.defaultAlarmAssetID, title: "Gentle rise"),
            isEnabled: sleepSchedule.isEnabled
        )
    }

    var scheduleAudioOptions: [ScheduleUIAudioSelection] {
        var result: [ScheduleUIAudioSelection] = [
            .bundled(id: SystemAudioAssets.defaultAlarmAssetID, title: "Gentle rise"),
        ]
        if let selectedID = AlarmSoundSelectionStore.selectedAlarmAssetID(),
           selectedID != SystemAudioAssets.defaultAlarmAssetID,
           selectedID != SystemAudioAssets.defaultAlarmFileName
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
        return deduplicatedAudioSelections(result)
    }

    private func deduplicatedAudioSelections(_ options: [ScheduleUIAudioSelection]) -> [ScheduleUIAudioSelection] {
        var seenIDs = Set<String>()
        var seenTitles = Set<String>()
        var deduplicated: [ScheduleUIAudioSelection] = []

        for option in options {
            let normalizedID = canonicalAudioID(for: option)
            let normalizedTitle = option.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            if !seenIDs.contains(normalizedID), !seenTitles.contains(normalizedTitle) {
                seenIDs.insert(normalizedID)
                seenTitles.insert(normalizedTitle)
                deduplicated.append(option)
            }
        }
        return deduplicated
    }

    private func canonicalAudioID(for option: ScheduleUIAudioSelection) -> String {
        switch option {
        case let .bundled(id, _):
            if id == SystemAudioAssets.defaultAlarmAssetID || id == SystemAudioAssets.defaultAlarmFileName {
                return "bundled:\(SystemAudioAssets.defaultAlarmAssetID)"
            }
            return option.id
        default:
            return option.id
        }
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
        self.catalogAudioPlayer.playbackStateDidChange = { [weak self] state in
            guard let self else { return }
            switch state {
            case let .playing(id), let .streaming(id):
                self.playbackState = .playing(id)
            case let .paused(id), let .interrupted(id):
                self.playbackState = .paused(id)
            case .failed:
                self.playbackState = .visualFallback
            case .idle, .offlineFallback:
                if case .playing = self.playbackState {
                    self.playbackState = .idle
                } else if case .paused = self.playbackState {
                    self.playbackState = .idle
                }
            }
            self.updateSleepSessionLiveActivityForPlayback()
        }
        SleepSessionAudioIntentBridge.shared.install { [weak self] action in
            self?.performSleepSessionAudioAction(action, presentSession: false) ?? false
        }
        SystemAudioAssets.ensureDefaultSoundsInstalled()
        startForegroundAlarmMonitoring()
    }

    deinit {
        foregroundAlarmMonitorTask?.cancel()
        alarmSnoozeTask?.cancel()
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
            } catch is AuthenticationError {
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
            case "sleep", "home":
                selectedTab = .sleep
            case "journal":
                selectedTab = .journal
            case "activity":
                selectedTab = .activity
            case "me":
                selectedTab = .me
            case "grounding":
                selectedTab = .sleep
                path = [.grounding]
            case "audio-library":
                selectedTab = .sleep
                path = [.audioLibrary]
            case "audio-player", "player":
                selectedTab = .sleep
                path = [.audioPlayer]
            case "curated-audio-library":
                selectedTab = .me
                path = [.curatedAudioLibrary]
            case "sleep-schedule":
                selectedTab = .sleep
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

        func setLaunchDestinationForTesting(_ destination: LaunchDestination) {
            launchDestination = destination
        }

        func setSessionForTesting(profileID: UUID?, userID: UUID?, settings: AppSettings? = nil) {
            self.profileID = profileID
            self.userID = userID
            if let profileID {
                self.settings = settings ?? AppSettings(
                    profileID: profileID,
                    preferredGroundingAssetID: nil,
                    preferredModality: .audio,
                    hapticsEnabled: true,
                    lastSelectedHistoryPeriod: .sevenDays,
                    diagnosticsEnabled: false,
                    defaultSleepSupport: .quickSleep,
                    defaultPostEpisodeSupport: .calmingAudio,
                    updatedAt: Date(),
                    revision: 1
                )
            } else {
                self.settings = settings
            }
        }

        func setPlaybackStateForTesting(_ state: GroundingPlaybackState) {
            playbackState = state
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
            } catch AuthenticationError.networkUnavailable {
                authenticationState = .failed
                feedbackMessage = "Network connection is unavailable. Check your connection and try again."
            } catch AuthenticationError.serverRejected {
                authenticationState = .failed
                feedbackMessage = "Sign-in was rejected by the server. Try again later."
            } catch AuthenticationError.externalProviderUnavailable {
                authenticationState = .failed
                feedbackMessage = "Sign-in did not finish. Check the provider configuration and try again."
            } catch AuthenticationError.wrongAccount {
                // Thrown by store.resume(session:) / LocalDatabase.activateAuthenticatedProfile when
                // the signed-in account does not match the protected local profile already linked on this device.
                accountAccessState = .wrongAccount
                authenticationState = .failed
                feedbackMessage = "This account does not match the protected profile on this device."
            } catch {
                authenticationState = .failed
                feedbackMessage = "Sign-in could not be completed. Try again later."
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
                selectedTab = .home
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

    func openAlarmScheduleSummary() {
        if !alarmSchedules.isEmpty {
            selectedAlarmScheduleID = tonightScheduleID ?? tonightSchedule?.id ?? alarmSchedules.first?.id
            open(.alarmScheduleEditor)
        } else {
            beginNewSchedule()
            open(.alarmScheduleEditor)
        }
    }

    private func scheduleValidationFeedback(proposed: [AlarmSchedule]) -> String? {
        do {
            try AlarmScheduleValidator.validate(proposed)
            return nil
        } catch AlarmScheduleValidationError.maximumSchedulesExceeded(limit: _) {
            return "You can create up to \(AlarmSchedule.maximumCount) schedules."
        } catch AlarmScheduleValidationError.collision(_) {
            return "This alarm collides with another enabled schedule. Choose a different time or reminder."
        } catch {
            return "Choose valid times, repeat days, and reminder settings."
        }
    }

    @discardableResult
    func saveScheduleUI(_ value: ScheduleUIModel, autoStartUnwind: Bool = false) -> Bool {
        guard let profileID, let userID else { return false }
        let existing = alarmSchedules.first(where: { $0.id == value.id })
        let schedule = value.domainValue(
            profileID: profileID,
            existing: existing,
            sortOrder: existing?.sortOrder ?? alarmSchedules.count
        )
        var proposed = alarmSchedules.filter { $0.id != schedule.id }
        proposed.append(schedule)
        if let message = scheduleValidationFeedback(proposed: proposed) {
            feedbackMessage = message
            return false
        }

        let previous = alarmSchedules
        alarmSchedules = proposed.sorted { ($0.sortOrder, $0.createdAt) < ($1.sortOrder, $1.createdAt) }
        selectedAlarmScheduleID = schedule.id
        selectedTab = .sleep
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
                if storedSchedule.isEnabled {
                    applyWakeAlarmOutcomeFeedback(
                        outcome: wakeAlarmOutcome,
                        isUnavailable: storedSchedule.wakeAudioIsUnavailableOnThisDevice
                    )
                }
            } catch {
                alarmSchedules = previous
                updateLegacyScheduleSummary()
                feedbackMessage = "The schedule could not be saved. Nothing was replaced."
            }
        }
        if autoStartUnwind {
            clearIntermediateScheduleRoutes()
            startUnwindSession()
        }
        return true
    }

    private func applyWakeAlarmOutcomeFeedback(
        outcome: WakeAlarmSchedulingOutcome,
        isUnavailable: Bool
    ) {
        feedbackMessage = if outcome == .denied {
            "Alarm authorization is not granted. Enable permissions in Settings so alarms can ring."
        } else if outcome == .fallbackScheduled || isUnavailable {
            "The selected audio is unavailable on this device. Your alarm was scheduled with the default wake sound."
        } else if outcome == .failed {
            "The system could not schedule this alarm. Please verify permissions and settings."
        } else {
            feedbackMessage
        }
    }

    func toggleScheduleUI(_ value: ScheduleUIModel, enabled: Bool) {
        var draft = value
        draft.isEnabled = enabled
        _ = saveScheduleUI(draft)
    }

    @discardableResult
    func saveTonightScheduleDraft(
        _ draft: ScheduleUIModel,
        immediate: Bool = false,
        autoStartUnwind: Bool = false
    ) -> Bool {
        guard let profileID, let userID else { return false }
        let existing = alarmSchedules.first(where: { $0.id == draft.id })
        let schedule = draft.domainValue(
            profileID: profileID,
            existing: existing,
            sortOrder: existing?.sortOrder ?? 0
        )
        var proposed = alarmSchedules.filter { $0.id != schedule.id }
        proposed.append(schedule)
        if let message = scheduleValidationFeedback(proposed: proposed) {
            feedbackMessage = message
            return false
        }

        tonightScheduleID = schedule.id
        alarmSchedules = proposed.sorted { ($0.sortOrder, $0.createdAt) < ($1.sortOrder, $1.createdAt) }
        updateLegacyScheduleSummary()

        tonightScheduleSaveTask?.cancel()
        tonightScheduleSaveTask = Task { @MainActor [weak self] in
            if !immediate {
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            guard let self, !Task.isCancelled else { return }
            defer { self.tonightScheduleSaveTask = nil }
            await self.persistTonightSchedule(schedule, profileID: profileID, userID: userID)
        }
        if autoStartUnwind {
            clearIntermediateScheduleRoutes()
            startUnwindSession()
        }
        return true
    }

    private func persistTonightSchedule(
        _ schedule: AlarmSchedule,
        profileID: UUID,
        userID: UUID
    ) async {
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
            if storedSchedule.isEnabled {
                applyWakeAlarmOutcomeFeedback(
                    outcome: wakeAlarmOutcome,
                    isUnavailable: storedSchedule.wakeAudioIsUnavailableOnThisDevice
                )
            }
        } catch {
            feedbackMessage = "The schedule could not be saved. Nothing was replaced."
        }
    }

    func toggleTonightSchedule(enabled: Bool) {
        var draft = tonightScheduleUIModel
        draft.isEnabled = enabled
        saveTonightScheduleDraft(draft, immediate: true)
    }

    func flushTonightScheduleSave() {
        guard let task = tonightScheduleSaveTask, !task.isCancelled else { return }
        saveTonightScheduleDraft(tonightScheduleUIModel, immediate: true)
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
        if tonightScheduleID == value.id {
            tonightScheduleID = nil
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
        } else if outcomes.contains(.fallbackScheduled) {
            wakeAlarmOutcome = .fallbackScheduled
        } else if outcomes.contains(.scheduled) {
            wakeAlarmOutcome = .scheduled
        } else {
            wakeAlarmOutcome = .notRequested
        }
    }

    private func updateLegacyScheduleSummary() {
        guard let schedule = tonightSchedule
            ?? alarmSchedules.first(where: { $0.isEnabled && $0.kind == .sleep })
            ?? alarmSchedules.first(where: { $0.isEnabled })
            ?? alarmSchedules.first(where: { $0.kind == .sleep })
            ?? alarmSchedules.first
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
        if phase == .active {
            startForegroundAlarmMonitoring()
            checkForegroundAlarmTriggers()
        } else if phase == .background {
            if sleepSessionStartedAt == nil {
                stopForegroundAlarmMonitoring()
            }
        }
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
        selectedCatalogAsset = nil
        catalogAudioPlayer.stop()
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

    func selectCatalogAsset(_ asset: CatalogAudioAsset) {
        selectedCatalogAsset = asset
    }

    func playCatalogAsset(_ asset: CatalogAudioAsset) {
        selectedCatalogAsset = asset
        audioController.stopPlayback()

        #if DEBUG
            if ProcessInfo.processInfo.environment["SPC_UI_TEST_CATALOG_SCENARIO"] != nil
                || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
                || NSClassFromString("XCTestCase") != nil
            {
                playbackState = .playing(asset.id)
                updateSleepSessionLiveActivityForPlayback()
                return
            }
        #endif

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let url = try await catalogAudioService.playbackURL(for: asset, networkAvailable: true)
                let isStreaming = !url.isFileURL
                catalogAudioPlayer.play(url: url, assetID: asset.id, streaming: isStreaming)
                if case .failed = catalogAudioPlayer.state {
                    playbackState = .visualFallback
                } else {
                    playbackState = .playing(asset.id)
                }
                updateSleepSessionLiveActivityForPlayback()
            } catch {
                playbackState = .visualFallback
                updateSleepSessionLiveActivityForPlayback()
            }
        }
    }

    func togglePlayback() {
        if let selectedCatalogAsset {
            switch playbackState {
            case .playing:
                catalogAudioPlayer.pause()
                playbackState = .paused(selectedCatalogAsset.id)
            case .paused:
                catalogAudioPlayer.resume()
                playbackState = .playing(selectedCatalogAsset.id)
            default:
                switch catalogAudioPlayer.state {
                case .playing, .streaming:
                    catalogAudioPlayer.pause()
                    playbackState = .paused(selectedCatalogAsset.id)
                case .paused:
                    catalogAudioPlayer.resume()
                    playbackState = .playing(selectedCatalogAsset.id)
                default:
                    playCatalogAsset(selectedCatalogAsset)
                }
            }
            updateSleepSessionLiveActivityForPlayback()
            return
        }

        audioController.togglePause()
        playbackState = audioController.playbackState
        updateSleepSessionLiveActivityForPlayback()
    }

    var activeTrackTitle: String {
        if let selectedCatalogAsset {
            if selectedCatalogAsset.id == "second-sleep" {
                return "Calming Second Sleep"
            }
            return selectedCatalogAsset.title
        }
        if case let .playing(id) = playbackState {
            if id == "quick-unwind" {
                return "Quick Unwind"
            }
            if id == "slow-unwind" {
                return "Slow Unwind"
            }
            if id == "second-sleep" {
                return "Calming Second Sleep"
            }
        }
        if case let .paused(id) = playbackState {
            if id == "quick-unwind" {
                return "Quick Unwind"
            }
            if id == "slow-unwind" {
                return "Slow Unwind"
            }
            if id == "second-sleep" {
                return "Calming Second Sleep"
            }
        }
        if case let .personalClip(id) = recoveryAudioDefault,
           personalClips.contains(where: { $0.id == id })
        {
            return "Personal Voice Guide"
        }
        if case let .catalogItem(id) = recoveryAudioDefault,
           let item = providedAudio.first(where: { $0.id == id })
        {
            return item.title
        }
        if !personalClips.isEmpty {
            return "Personal Voice Guide"
        }
        return "Quick Unwind"
    }

    var activeTrackSubtitle: String {
        if let selectedCatalogAsset {
            if selectedCatalogAsset.id == "second-sleep" {
                return "Gentle guided recovery session"
            }
            return selectedCatalogAsset.shortDescription
        }
        if case let .playing(id) = playbackState {
            if id == "quick-unwind" {
                return "Settling into restful calmness"
            }
            if id == "slow-unwind" {
                return "Slower transition into sleep"
            }
            if id == "second-sleep" {
                return "Gentle guided recovery session"
            }
        }
        if case let .paused(id) = playbackState {
            if id == "quick-unwind" {
                return "Settling into restful calmness"
            }
            if id == "slow-unwind" {
                return "Slower transition into sleep"
            }
            if id == "second-sleep" {
                return "Gentle guided recovery session"
            }
        }
        if case let .personalClip(id) = recoveryAudioDefault,
           personalClips.contains(where: { $0.id == id })
        {
            return "Private recording on this device"
        }
        if case let .catalogItem(id) = recoveryAudioDefault,
           let item = providedAudio.first(where: { $0.id == id })
        {
            return item.detail
        }
        if !personalClips.isEmpty {
            return "Private recording on this device"
        }
        return "Calming Grounding Meditation"
    }

    var playbackCurrentTime: TimeInterval {
        if selectedCatalogAsset != nil {
            return catalogAudioPlayer.currentTime
        }
        return audioController.currentTime
    }

    var playbackDuration: TimeInterval {
        if let selectedCatalogAsset {
            let playerDur = catalogAudioPlayer.duration
            if playerDur > 0 {
                return playerDur
            }
            return Double(selectedCatalogAsset.durationMilliseconds) / 1000.0
        }
        return audioController.duration
    }

    func seekPlayback(to time: TimeInterval) {
        if selectedCatalogAsset != nil {
            catalogAudioPlayer.seek(to: time)
        } else {
            audioController.seek(to: time)
        }
    }

    func skipPlayback(by seconds: TimeInterval) {
        if selectedCatalogAsset != nil {
            catalogAudioPlayer.skip(by: seconds)
        } else {
            audioController.skip(by: seconds)
        }
    }

    func toggleHeroPlayback() {
        switch playbackState {
        case .playing:
            togglePlayback()
        case .paused:
            togglePlayback()
        default:
            if let selectedCatalogAsset {
                playCatalogAsset(selectedCatalogAsset)
            } else {
                playSelectedRecoveryAudio()
            }
        }
    }

    func setSleepTimer(seconds: TimeInterval) {
        sleepTimerTask?.cancel()
        guard seconds > 0 else {
            sleepTimerRemaining = nil
            catalogAudioPlayer.setVolume(1.0)
            return
        }
        var secondsRemaining = seconds
        sleepTimerRemaining = secondsRemaining
        catalogAudioPlayer.setVolume(1.0)

        sleepTimerTask = Task { @MainActor [weak self] in
            while secondsRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                secondsRemaining -= 1
                self?.sleepTimerRemaining = secondsRemaining

                if secondsRemaining <= 5, let self {
                    let fraction = Float(max(0, secondsRemaining)) / 5.0
                    self.catalogAudioPlayer.setVolume(fraction)
                }
            }
            self?.sleepTimerRemaining = nil
            self?.catalogAudioPlayer.setVolume(0.0)
            self?.stopPlayback()
            self?.catalogAudioPlayer.setVolume(1.0)
        }
    }

    func setSleepTimer(minutes: Int) {
        setSleepTimer(seconds: TimeInterval(minutes * 60))
    }

    func setSleepTimerToEndOfTrack() {
        let duration = playbackDuration > 0 ? playbackDuration : 900
        let remaining = max(1, duration - playbackCurrentTime)
        setSleepTimer(seconds: remaining)
    }

    func cancelSleepTimer() {
        sleepTimerTask?.cancel()
        sleepTimerTask = nil
        sleepTimerRemaining = nil
        catalogAudioPlayer.setVolume(1.0)
    }

    func stopPlayback() {
        cancelSleepTimer()
        audioController.stopPlayback()
        catalogAudioPlayer.stop()
        catalogAudioPlayer.setVolume(1.0)
        playbackState = .idle
        updateSleepSessionLiveActivityForPlayback()
    }

    var sleepPlayerTracks: [CatalogAudioAsset] {
        CatalogAudioManifest.bundled.assets.filter {
            $0.category == .quickUnwind || $0.category == .secondSleep || $0.category == .slowUnwind
        }
    }

    func sleepTrackDurationText(for asset: CatalogAudioAsset) -> String {
        switch asset.category {
        case .quickUnwind:
            return "15 min"
        case .secondSleep:
            return "6 min"
        case .slowUnwind:
            return "1 hr 15 min"
        default:
            let totalSeconds = max(0, asset.durationMilliseconds / 1000)
            let mins = totalSeconds / 60
            let secs = totalSeconds % 60
            return String(format: "%d:%02d", mins, secs)
        }
    }

    func isSleepTrackDownloaded(_ asset: CatalogAudioAsset) -> Bool {
        if asset.delivery == .bundled {
            return true
        }
        if let resourceName = asset.bundledResourceName,
           SystemAudioAssets.bundledURL(for: resourceName) != nil
        {
            return true
        }
        return false
    }

    func downloadSleepTrack(_ asset: CatalogAudioAsset) async {
        guard asset.delivery == .downloadable else { return }
        do {
            _ = try await catalogAudioService.download(asset, progress: { _ in })
        } catch {
            feedbackMessage = "Could not download track for offline listening."
        }
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
        startForegroundAlarmMonitoring()

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
        isSleepSessionPresented = true
        UIApplication.shared.isIdleTimerDisabled = true
    }

    func endSleepSession() {
        sleepSessionStartedAt = nil
        isSleepSessionPresented = false
        UserDefaults.standard.removeObject(forKey: Self.sleepSessionStartedAtKey)
        UIApplication.shared.isIdleTimerDisabled = false
        stopForegroundAlarmMonitoring()
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
            beginSleepSessionGrounding()
        case .pause:
            if case .playing = playbackState {
                togglePlayback()
            }
        case .resume:
            if case .paused = playbackState {
                togglePlayback()
            } else {
                beginSleepSessionGrounding()
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

    var nextUpcomingWakeSchedule: (schedule: AlarmSchedule, date: Date)? {
        var closest: (schedule: AlarmSchedule, date: Date)?
        for schedule in alarmSchedules where schedule.isEnabled {
            if let date = WakeAlarmPlanner.nextWakeDate(for: schedule, after: Date()) {
                if let currentClosest = closest {
                    if date < currentClosest.date {
                        closest = (schedule, date)
                    }
                } else {
                    closest = (schedule, date)
                }
            }
        }
        return closest
    }

    func triggerAlarmRinging(
        schedule: ScheduleUIModel? = nil,
        at date: Date = Date(),
        calendar: Calendar = .current,
        isSnooze: Bool = false
    ) {
        guard !isAlarmRinging else { return }
        let dueSchedule = alarmSchedules.first {
            $0.isEnabled && WakeAlarmPlanner.isWakeAlarmDue(for: $0, at: date, calendar: calendar)
        }
        let targetSchedule = schedule
            ?? dueSchedule.map { ScheduleUIModel($0) }
            ?? scheduleUIModels.first { $0.isEnabled }

        if let targetSchedule, !isSnooze {
            let key = WakeAlarmPlanner.occurrenceMinuteKey(for: targetSchedule.id, at: date, calendar: calendar)
            guard !firedAlarmMinuteKeys.contains(key) else { return }
            firedAlarmMinuteKeys.insert(key)
            if firedAlarmMinuteKeys.count > 200 {
                let year = calendar.component(.year, from: date)
                let month = calendar.component(.month, from: date)
                let day = calendar.component(.day, from: date)
                let todayPrefix = "\(year)-\(month)-\(day)"
                firedAlarmMinuteKeys = firedAlarmMinuteKeys.filter { $0.contains(todayPrefix) }
            }
        }

        isSleepSessionPresented = false
        presentedSheet = nil
        cleanupStructuredExport()
        cleanupAudioExport()

        ringingAlarmSchedule = targetSchedule
        isAlarmRinging = true

        let domainSchedule = targetSchedule.flatMap { ts in alarmSchedules.first(where: { $0.id == ts.id }) }
        let audioURL = resolveAlarmPlaybackURL(target: targetSchedule, domain: domainSchedule)

        if let audioURL {
            do {
                try audioController.playAlarm(url: audioURL, identifier: "alarm-ringing")
                playbackState = audioController.playbackState
            } catch {
                let defaultURL = SystemAudioAssets.alarmAudioURL(for: SystemAudioAssets.defaultAlarmFileName)
                    ?? SystemAudioAssets.bundledURL(for: SystemAudioAssets.defaultAlarmFileName)
                if let defaultURL, defaultURL != audioURL {
                    do {
                        try audioController.playAlarm(url: defaultURL, identifier: "alarm-ringing")
                        playbackState = audioController.playbackState
                        return
                    } catch {
                        // Fallback also failed
                    }
                }
                audioController.showVisualFallback()
                playbackState = .visualFallback
            }
        } else {
            audioController.showVisualFallback()
            playbackState = .visualFallback
        }
    }

    private func resolveDomainAlarmAudioURL(_ domainAudio: AlarmAudioSelection) -> URL? {
        switch domainAudio.reference {
        case let .bundled(resourceName):
            let fileName = domainAudio.localFileName ?? resourceName
            return SystemAudioAssets.alarmAudioURL(for: fileName)
        case .catalog:
            if let fileName = domainAudio.localFileName {
                return SystemAudioAssets.alarmAudioURL(for: fileName)
            }
            return nil
        case let .personal(clipID):
            let fileName = domainAudio.localFileName ?? PersonalAlarmAudioContract.fileName(for: clipID)
            return SystemAudioAssets.localURL(for: fileName)
        }
    }

    private func resolveUIAlarmAudioURL(_ uiAudio: ScheduleUIAudioSelection) -> URL? {
        switch uiAudio {
        case let .bundled(id, _):
            let isDefault = id == SystemAudioAssets.defaultAlarmAssetID
                || id == SystemAudioAssets.defaultAlarmFileName
            let fileName = isDefault
                ? SystemAudioAssets.defaultAlarmFileName
                : (id.hasSuffix(".caf") ? id : "\(id).caf")
            return SystemAudioAssets.alarmAudioURL(for: fileName)
        case let .catalog(id, _, isAvailable):
            guard isAvailable else { return nil }
            let fileName = AlarmSoundSelectionStore.selectedAlarmAssetID() == id
                ? AlarmSoundSelectionStore.selectedAlarmSoundFileName()
                : nil
            if let fileName, let url = SystemAudioAssets.alarmAudioURL(for: fileName) {
                return url
            }
            if let asset = CatalogAudioManifest.bundled.assets.first(where: { $0.id == id }),
               let soundName = asset.systemSoundFileName
            {
                return SystemAudioAssets.alarmAudioURL(for: soundName)
            }
            return nil
        case let .personal(clipID, _, isAvailable):
            guard isAvailable else { return nil }
            let fileName = PersonalAlarmAudioContract.fileName(for: clipID)
            return SystemAudioAssets.localURL(for: fileName)
        case .unavailable:
            return nil
        }
    }

    func resolveAlarmPlaybackURL(
        target: ScheduleUIModel?,
        domain: AlarmSchedule?
    ) -> URL? {
        if let domainAudio = domain?.wakeAudio,
           let url = resolveDomainAlarmAudioURL(domainAudio)
        {
            return url
        }

        if let uiAudio = target?.wakeAudio,
           let url = resolveUIAlarmAudioURL(uiAudio)
        {
            return url
        }

        return SystemAudioAssets.alarmAudioURL(for: SystemAudioAssets.defaultAlarmFileName)
            ?? SystemAudioAssets.bundledURL(for: SystemAudioAssets.defaultAlarmFileName)
    }

    func snoozeAlarm(minutes: Int? = nil) {
        audioController.stopPlayback()
        playbackState = .idle
        isAlarmRinging = false

        let duration = minutes ?? ringingAlarmSchedule?.snoozeMinutes ?? 9
        alarmSnoozeTask?.cancel()
        alarmSnoozeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(duration * 60))
            guard !Task.isCancelled, let self else { return }
            self.triggerAlarmRinging(schedule: self.ringingAlarmSchedule, isSnooze: true)
        }
    }

    func stopAlarm() {
        alarmSnoozeTask?.cancel()
        alarmSnoozeTask = nil
        audioController.stopPlayback()
        playbackState = .idle
        isAlarmRinging = false
        ringingAlarmSchedule = nil
        if isSleepSessionPresented || sleepSessionStartedAt != nil {
            endSleepSession()
        }

        // Stopping alarm immediately presents the morning questionnaire
        selectedTab = .sleep
        isMorningCheckInPresented = true
        open(.morningCheckIn)
    }

    func startForegroundAlarmMonitoring() {
        guard foregroundAlarmMonitorTask == nil else { return }
        foregroundAlarmMonitorTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.checkForegroundAlarmTriggers()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func stopForegroundAlarmMonitoring() {
        foregroundAlarmMonitorTask?.cancel()
        foregroundAlarmMonitorTask = nil
    }

    func checkForegroundAlarmTriggers(at date: Date = Date(), calendar: Calendar = .current) {
        guard !isAlarmRinging else { return }
        for schedule in alarmSchedules where schedule.isEnabled {
            if WakeAlarmPlanner.isWakeAlarmDue(for: schedule, at: date, calendar: calendar) {
                let key = WakeAlarmPlanner.occurrenceMinuteKey(for: schedule.id, at: date, calendar: calendar)
                guard !firedAlarmMinuteKeys.contains(key) else { continue }
                triggerAlarmRinging(schedule: ScheduleUIModel(schedule), at: date, calendar: calendar)
                break
            }
        }
    }

    func startUnwindSession() {
        guard launchDestination == .home else { return }
        let defaultSleep = settings?.defaultSleepSupport ?? .quickSleep
        let trackID = defaultSleep == .longSleepAid ? "slow-unwind" : "quick-unwind"

        isSleepSessionPresented = false
        let startedAt = sleepSessionStartedAt ?? Date()
        sleepSessionStartedAt = startedAt
        UserDefaults.standard.set(startedAt, forKey: Self.sleepSessionStartedAtKey)
        startForegroundAlarmMonitoring()

        Task { @MainActor [weak self] in
            guard let self else { return }
            try? sleepSessionLiveActivities.start(startedAt: startedAt)
        }

        let isUnwindActive = switch playbackState {
        case let .playing(id), let .paused(id):
            id == "quick-unwind" || id == "slow-unwind"
        default:
            false
        }

        if !isUnwindActive {
            if let asset = CatalogAudioManifest.bundled.assets.first(where: { $0.id == trackID }) {
                playCatalogAsset(asset)
            }
        }
        if !path.contains(.audioPlayer) {
            open(.audioPlayer)
        }
    }

    func playCalmingSecondSleepAudio() {
        if let secondSleep = CatalogAudioManifest.bundled.assets.first(where: { $0.id == "second-sleep" }) {
            playCatalogAsset(secondSleep)
            return
        }
        if let selectedCatalogAsset, selectedCatalogAsset.id == "second-sleep" {
            playCatalogAsset(selectedCatalogAsset)
            return
        }
        if let quickUnwind = CatalogAudioManifest.bundled.assets.first(where: { $0.id == "quick-unwind" }) {
            playCatalogAsset(quickUnwind)
            return
        }
        audioController.showVisualFallback()
        playbackState = .visualFallback
        updateSleepSessionLiveActivityForPlayback()
    }

    func playSelectedRecoveryAudio() {
        let postSupport = settings?.defaultPostEpisodeSupport ?? .calmingAudio
        switch postSupport {
        case .partnerVoice:
            if case let .personalClip(id) = recoveryAudioDefault,
               let clip = personalClips.first(where: { $0.id == id })
            {
                play(clip)
                return
            } else if let firstClip = personalClips.first {
                play(firstClip)
                return
            }
            playCalmingSecondSleepAudio()

        case .calmingAudio, .quickSleep, .longSleepAid:
            playCalmingSecondSleepAudio()

        case .callPartner:
            if let contact = partnerContact,
               let phoneURL = contact.phoneURL
            {
                UIApplication.shared.open(phoneURL)
            } else {
                open(.defaultSettings)
            }
        }
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
        guard let profileID, let occurrence = form.occurrence, form.canSubmit else {
            return false
        }
        let effectiveUserID = userID ?? profileID
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
            try await store.saveCheckIn(value, userID: effectiveUserID)
            checkIns.removeAll { $0.id == value.id }
            checkIns.insert(value, at: 0)
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
        guard let profileID else { return }
        let effectiveUserID = userID ?? profileID
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await store.deleteCheckIn(value, userID: effectiveUserID)
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
        }
        path.append(route)
        if route == .grounding {
            logger.record(.routeChanged, category: .navigation)
        }
    }

    func openDeepLink(_ url: URL) {
        if url.scheme?.lowercased() == "spc" {
            let host = url.host?.lowercased()
            if host == "sleep-session" {
                presentActiveSleepSession()
                return
            }
            if host == "alarm-ringing" || host == "ring" {
                triggerAlarmRinging()
                return
            }
            if host == "alarm-stop" {
                stopAlarm()
                return
            }
            if host == "alarm-snooze" {
                snoozeAlarm()
                return
            }
            if host == "checkin" {
                selectedTab = .sleep
                isMorningCheckInPresented = true
                open(.morningCheckIn)
                return
            }
        }
        // ASWebAuthenticationSession consumes OAuth callbacks (e.g. spc://auth/callback);
        // unrouted URLs are ignored safely (verified in
        // NavigationStateTests.testOAuthCallbackDeepLinkProducesNoNavigationOrFeedback).
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

    func clearIntermediateScheduleRoutes() {
        let scheduleRoutes: Set<AppRoute> = [.alarmScheduleEditor, .alarmHistory, .sleepSchedule]
        setPath(path.filter { !scheduleRoutes.contains($0) })
    }

    func selectTab(_ value: AppTab) {
        selectedTab = value
        path = []
        if value != .sleep {
            isMorningCheckInPresented = false
        }
    }

    func presentSheet(_ sheet: AppSheet) {
        presentedSheet = sheet
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
        selectedTab = .sleep
        path = []
        presentedSheet = nil
        isMorningCheckInPresented = false
    }

    static let sleepSessionStartedAtKey = "spc.sleepSession.startedAt.v1"

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
