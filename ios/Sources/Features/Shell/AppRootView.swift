import SwiftUI

@MainActor
struct AppRootView: View {
    @Bindable var model: AppModel
    private let activationStore = ManualEpisodeActivationStore.live()

    @Environment(\.scenePhase) private var scenePhase
    @SceneStorage("spc.navigation.v2") private var restoredNavigation = ""

    var body: some View {
        NavigationStack(
            path: Binding(
                get: { model.path },
                set: { model.setPath($0) }
            )
        ) {
            launchContent
                .enableNativeBackGesture()
                .navigationDestination(for: AppRoute.self, destination: destination)
        }
        .font(AppTypographyRole.body)
        .tint(AppColorRole.accent)
        .onOpenURL(perform: model.openDeepLink)
        .fullScreenCover(
            isPresented: Binding(
                get: { model.isAlarmRinging || model.isMorningCheckInPresented },
                set: { presented in
                    if !presented {
                        if model.isAlarmRinging {
                            model.snoozeAlarm(minutes: 9)
                        } else if model.isMorningCheckInPresented {
                            model.completeMorningCheckIn()
                        }
                    }
                }
            )
        ) {
            MorningAlarmFlowContainerView(model: model)
        }
        .task {
            model.activate(restoredState: restoredNavigation)
            attemptManualEpisodeHandoff()
        }
        .onChange(of: model.restorationValue) { _, value in
            restoredNavigation = value
        }
        .onChange(of: scenePhase) { _, phase in
            model.handleScenePhase(phase)
            if phase == .active {
                attemptManualEpisodeHandoff()
            }
        }
        .onChange(of: model.launchDestination) { _, _ in
            attemptManualEpisodeHandoff()
        }
        .safeAreaInset(edge: .top) {
            if let feedback = model.feedbackMessage,
               model.launchDestination != .authentication
            {
                HStack {
                    AppFeedbackBanner(message: feedback)
                    Button {
                        model.clearFeedback()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .accessibilityLabel("Dismiss message")
                }
                .padding(.horizontal)
            }
        }
    }

    private func attemptManualEpisodeHandoff() {
        guard let activation = try? activationStore.firstPending(),
              model.requestSleepSessionAudioAction(activation.action ?? .startOrResume)
        else { return }
        _ = try? activationStore.consume(id: activation.id)
    }

    @ViewBuilder
    private var launchContent: some View {
        switch model.launchDestination {
        case .loading:
            ZStack {
                NightBackground()
                ProgressView("Preparing your private setup")
                    .tint(.white)
                    .foregroundStyle(.white)
            }
        case .splash:
            SplashView(continueAction: model.continueFromSplash)
        case let .introduction(page):
            FeatureIntroductionView(page: page) {
                model.advanceIntroduction(from: page)
            } skipAction: {
                model.skipIntroduction()
            }
        case .authentication:
            FigmaAuthenticationView(
                state: model.authenticationState,
                feedback: model.feedbackMessage,
                isConfigured: model.isAuthenticationConfigured,
                signIn: model.signIn
            )
        case let .question(question):
            QuestionnaireView(
                question: question,
                draft: model.questionnaireDraft,
                selectFrequency: { model.answer(frequency: $0) },
                selectFeeling: { model.answer(feeling: $0) },
                selectContext: { model.answer(context: $0) }
            )
        case .recommendedSetup:
            if let persona = model.persona {
                RecommendedSetupView(
                    persona: persona,
                    continueAction: model.continueFromRecommendedSetup
                )
            } else {
                ContentUnavailableView("Setup unavailable", systemImage: "exclamationmark.triangle")
            }
        case .personalAudio:
            PersonalAudioSetupView(model: model, isOnboarding: true)
        case .sleepSchedule:
            SleepScheduleView(model: model, isOnboarding: true)
        case .home:
            AppTabShellView(model: model)
        case .recoverableError:
            AppStateView(
                title: "Local data needs attention",
                message: "Your protected local data could not be opened. Retry without replacing it.",
                systemImage: "externaldrive.badge.exclamationmark",
                actionTitle: "Try again",
                action: { model.activate(restoredState: restoredNavigation) }
            )
        }
    }

    private func destination(_ route: AppRoute) -> some View {
        AppRouteDestinationView(model: model, route: route)
            .enableNativeBackGesture()
    }
}

@MainActor
private struct AppRouteDestinationView: View {
    @Bindable var model: AppModel
    let route: AppRoute

    var body: some View {
        switch route {
        case .grounding:
            GroundingView(model: model)
        case .audioLibrary:
            PersonalAudioSetupView(model: model)
        case .audioPlayer:
            AudioPlayerView(model: model)
        case .curatedAudioLibrary:
            CatalogAudioLibraryView(appModel: model, service: model.catalogAudioService) {
                model.open(.audioLibrary)
            }
        case .sleepSchedule:
            SleepScheduleView(model: model)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .tint(.white)
        case .alarmHistory:
            AlarmHistoryView(
                schedules: model.scheduleUIModels,
                hapticsEnabled: model.settings?.hapticsEnabled != false,
                onBack: dismissScheduleRoute,
                onAdd: {
                    model.beginNewSchedule()
                    model.open(.alarmScheduleEditor)
                },
                onEdit: { schedule in
                    model.editSchedule(schedule)
                    model.open(.alarmScheduleEditor)
                },
                onToggle: { schedule, enabled in
                    model.toggleScheduleUI(schedule, enabled: enabled)
                },
                onDelete: { schedule in
                    model.deleteScheduleUI(schedule)
                }
            )
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
        case .alarmScheduleEditor:
            AlarmScheduleEditorView(
                schedule: model.selectedScheduleUIModel,
                audioOptions: model.scheduleAudioOptions,
                hapticsEnabled: model.settings?.hapticsEnabled != false,
                onCancel: dismissScheduleRoute,
                onSave: { schedule in
                    let currentPath = model.path
                    let saved = model.saveScheduleUI(schedule, autoStartUnwind: true)
                    if !saved {
                        model.setPath(currentPath)
                        AppHaptics.warning(hapticsEnabled: model.settings?.hapticsEnabled != false)
                    }
                },
                onDelete: { schedule in
                    model.deleteScheduleUI(schedule)
                    dismissScheduleRoute()
                }
            )
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
        case .morningCheckIn:
            MorningCheckInView(model: model)
        case .checkInDetail:
            CheckInDetailView(model: model)
        case .editQuestionnaire:
            EditQuestionnaireView(model: model)
        case .accessibility:
            AccessibilitySettingsView()
        case .dataPrivacy:
            DataPrivacyView(model: model)
        case .helpLegal:
            HelpLegalView()
        case .account:
            AccountView(model: model)
        case .editProfile:
            EditProfileView(model: model)
        case .defaultSettings:
            DefaultSupportSettingsView(model: model)
        }
    }

    private func dismissScheduleRoute() {
        guard !model.path.isEmpty else { return }
        model.setPath(Array(model.path.dropLast()))
    }
}

private struct MorningAlarmFlowContainerView: View {
    @Bindable var model: AppModel

    var body: some View {
        ZStack {
            if model.isAlarmRinging {
                AlarmRingingView(model: model)
                    .transition(.opacity)
            } else {
                MorningCheckInFlowView(model: model)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: model.isAlarmRinging)
        .interactiveDismissDisabled(true)
    }
}
