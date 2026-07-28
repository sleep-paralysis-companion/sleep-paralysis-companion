import SwiftUI

@MainActor
struct AppRootView: View {
    @Bindable var model: AppModel

    @Environment(\.scenePhase) private var scenePhase
    @SceneStorage("spc.navigation.v1") private var restoredNavigation = ""

    var body: some View {
        NavigationStack(
            path: Binding(
                get: { model.path },
                set: { model.send(.setPath($0)) }
            )
        ) {
            launchContent
                .navigationDestination(for: AppRoute.self, destination: destination)
        }
        .tint(AppColorRole.accent)
        .sheet(
            item: Binding(
                get: { model.presentedSheet },
                set: { _ in model.send(.dismissSheet) }
            )
        ) { _ in
            AccessUnavailableView()
        }
        .onOpenURL { url in
            model.send(.openDeepLink(url))
        }
        .task {
            model.activate(restoredState: restoredNavigation)
        }
        .onChange(of: model.restorationValue) { _, value in
            restoredNavigation = value
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                if model.launchDestination == .loading {
                    model.activate(restoredState: restoredNavigation)
                }
            case .background:
                model.deactivate()
            case .inactive:
                break
            @unknown default:
                model.deactivate()
            }
        }
    }

    @ViewBuilder
    private var launchContent: some View {
        switch model.launchDestination {
        case .loading:
            LoadingView()
        case .welcome:
            WelcomeView {
                model.send(.continueFromWelcome)
            }
        case let .productNotice(presentation):
            ProductNoticeView(
                presentation: presentation,
                isProcessing: model.isProcessingOnboarding,
                feedbackMessage: model.feedbackMessage,
                continueAction: { model.send(.continueFromProductNotice) },
                openAlarm: { model.send(.open(.alarm)) },
                openPrivacy: { model.send(.open(.dataPrivacy)) },
                openHelp: { model.send(.open(.helpLegal)) }
            )
        case .home:
            AppTabShellView(model: model)
        case .recoverableError:
            AppStateView(
                title: "state.database.title",
                message: "state.database.message",
                systemImage: "externaldrive.badge.exclamationmark",
                actionTitle: "action.retry",
                action: { model.send(.retryLaunch) }
            )
        }
    }

    @ViewBuilder
    private func destination(_ route: AppRoute) -> some View {
        switch route {
        case .alarm:
            AlarmStatusView()
        case .grounding:
            UnavailableFeatureView(
                title: "grounding.title",
                message: "grounding.unavailable"
            )
        case .preparation:
            UnavailableFeatureView(
                title: "preparation.title",
                message: "preparation.unavailable"
            )
        case .permissionEducation:
            PermissionEducationView()
        case .syncAccount:
            SyncAccountView(accountState: model.accountAccessState)
        case .dataPrivacy:
            DataPrivacyView()
        case .helpLegal:
            HelpLegalView()
        }
    }
}

private struct LoadingView: View {
    var body: some View {
        ProgressView("state.loading")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColorRole.background)
            .accessibilityIdentifier("launch.loading")
    }
}
