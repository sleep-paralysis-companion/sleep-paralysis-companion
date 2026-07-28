import SwiftUI

struct AppTabShellView: View {
    @Bindable var model: AppModel

    var body: some View {
        TabView(
            selection: Binding(
                get: { model.selectedTab },
                set: { model.send(.selectTab($0)) }
            )
        ) {
            HomeView(
                accessPolicy: model.accessPolicy,
                open: { model.send(.open($0)) }
            )
            .tabItem {
                Label("tab.home", systemImage: "house")
            }
            .tag(AppTab.home)

            HistoryView(openPrivacy: { model.send(.open(.dataPrivacy)) })
                .tabItem {
                    Label("tab.history", systemImage: "clock")
                }
                .tag(AppTab.history)

            SettingsView(open: { model.send(.open($0)) })
                .tabItem {
                    Label("tab.settings", systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
        .accessibilityIdentifier("app.tab.shell")
    }
}
