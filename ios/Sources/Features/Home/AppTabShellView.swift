import SwiftUI

struct AppTabShellView: View {
    @Bindable var model: AppModel

    var body: some View {
        ZStack {
            switch model.selectedTab {
            case .sleep:
                ZStack {
                    HomeView(model: model, showsSleepSessionAction: true)
                    if model.isMorningCheckInPresented {
                        MorningCheckInFlowView(model: model)
                    }
                }
            case .journal:
                ComingSoonView(
                    title: "Journal",
                    message: "Your private journal is coming soon.",
                    systemImage: "book.closed"
                )
            case .home:
                HomeView(model: model)
            case .activity:
                ComingSoonView(
                    title: "Activity",
                    message: "Activity tracking is coming soon.",
                    systemImage: "chart.line.uptrend.xyaxis"
                )
            case .me:
                SettingsView(model: model)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AppTabBar(selection: Binding(
                get: { model.selectedTab },
                set: { model.selectTab($0) }
            ))
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .accessibilityIdentifier("app.tab.shell")
        .fullScreenCover(
            isPresented: Binding(
                get: { model.isSleepSessionPresented },
                set: { presented in
                    if !presented {
                        model.minimizeSleepSession()
                    }
                }
            )
        ) {
            SleepSessionView(model: model)
        }
    }
}

private struct AppTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 22, weight: .medium))
                        Text(tab.title)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .foregroundStyle(
                        selection == tab
                            ? HomeScreenPalette.accent
                            : HomeScreenPalette.textSecondary.opacity(0.72)
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background {
                        if selection == tab {
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .fill(HomeScreenPalette.cardBorder.opacity(0.75))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(5)
        .frame(maxWidth: 380, minHeight: 72)
        .background(HomeScreenPalette.cardSecondary)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(HomeScreenPalette.cardBorder, lineWidth: 1.2)
        }
    }
}

private extension AppTab {
    var title: String {
        switch self {
        case .sleep: "Sleep"
        case .journal: "Journal"
        case .home: "Home"
        case .activity: "Activity"
        case .me: "Me"
        }
    }

    var systemImage: String {
        switch self {
        case .sleep: "moon.stars.fill"
        case .journal: "book.closed"
        case .home: "house.fill"
        case .activity: "chart.line.uptrend.xyaxis"
        case .me: "person.crop.circle"
        }
    }
}
