import SwiftUI

struct AppTabShellView: View {
    @Bindable var model: AppModel

    var body: some View {
        TabView(
            selection: Binding(
                get: { model.selectedTab },
                set: { model.selectTab($0) }
            )
        ) {
            HomeView(model: model)
            .tabItem {
                Label("tab.home", systemImage: "house")
            }
            .tag(AppTab.home)

            HistoryView(model: model)
                .tabItem {
                    Label("tab.history", systemImage: "clock")
                }
                .tag(AppTab.history)

            SettingsView(model: model)
                .tabItem {
                    Label("tab.settings", systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
        .accessibilityIdentifier("app.tab.shell")
    }
}
