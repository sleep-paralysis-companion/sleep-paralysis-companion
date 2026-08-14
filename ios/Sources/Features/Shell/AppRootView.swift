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
                .navigationDestination(for: AppRoute.self, destination: destination)
        }
        .tint(AppColorRole.accent)
        .onOpenURL(perform: model.openDeepLink)
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
              model.requestManualGrounding()
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

    @ViewBuilder
    private func destination(_ route: AppRoute) -> some View {
        switch route {
        case .grounding:
            GroundingView(model: model)
        case .audioLibrary:
            PersonalAudioSetupView(model: model)
        case .sleepSchedule:
            SleepScheduleView(model: model)
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
}
