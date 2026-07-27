import SwiftUI

@MainActor
struct AppRootView: View {
    @Bindable var model: AppModel

    var body: some View {
        NavigationStack(
            path: Binding(
                get: { model.path },
                set: { model.send(.setPath($0)) }
            )
        ) {
            FoundationShellView(
                environment: model.environment,
                isReady: model.isReady,
                showDetails: { model.send(.showFoundationDetails) }
            )
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .foundationDetails:
                    FoundationDetailsView()
                }
            }
        }
    }
}
