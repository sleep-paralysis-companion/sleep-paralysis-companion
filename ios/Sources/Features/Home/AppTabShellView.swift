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
            ZStack {
                HomeView(model: model)
                if model.isMorningCheckInPresented {
                    MorningCheckInFlowView(model: model)
                }
            }
            .tabItem {
                Label("Sleep", systemImage: "moon.stars.fill")
            }
            .tag(AppTab.sleep)

            HistoryView(model: model)
                .tabItem {
                    Label("Journal", systemImage: "book.closed")
                }
                .tag(AppTab.journal)

            HomeView(model: model)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(AppTab.home)

            CheckInReportView(model: model)
                .tabItem {
                    Label("Report", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(AppTab.report)

            SettingsView(model: model)
                .tabItem {
                    Label("Me", systemImage: "person.crop.circle")
                }
                .tag(AppTab.me)
        }
        .toolbarBackground(Color(red: 0.02, green: 0.006, blue: 0.11), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .accessibilityIdentifier("app.tab.shell")
    }
}

private struct CheckInReportView: View {
    @Bindable var model: AppModel

    var body: some View {
        NightScreen {
            VStack(alignment: .leading, spacing: AppSpacing.spacious) {
                Text("Report")
                    .font(AppTypographyRole.hero)
                Text("Your private check-in history stays descriptive.")
                    .foregroundStyle(.white.opacity(0.72))
                NightCard {
                    Text("Check-ins logged")
                        .font(.headline)
                    Text("\(model.checkIns.count)")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.66, green: 0.49, blue: 1))
                    Text("This is not a clinical score, prediction, or diagnosis.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.62))
                }
            }
        }
        .navigationTitle("Report")
        .navigationBarTitleDisplayMode(.inline)
    }
}
