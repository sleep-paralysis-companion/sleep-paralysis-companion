import SwiftUI

struct SettingsView: View {
    let open: (AppRoute) -> Void

    var body: some View {
        List {
            Section("settings.account.section") {
                settingsButton(
                    title: "settings.sync.title",
                    icon: "arrow.triangle.2.circlepath",
                    route: .syncAccount
                )
            }
            Section("settings.system.section") {
                settingsButton(
                    title: "settings.permissions.title",
                    icon: "bell.badge",
                    route: .permissionEducation
                )
            }
            Section("settings.information.section") {
                settingsButton(
                    title: "settings.privacy.title",
                    icon: "hand.raised",
                    route: .dataPrivacy
                )
                settingsButton(
                    title: "settings.help.title",
                    icon: "questionmark.circle",
                    route: .helpLegal
                )
            }
        }
        .navigationTitle(Text("tab.settings"))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("settings.list")
    }

    private func settingsButton(
        title: LocalizedStringKey,
        icon: String,
        route: AppRoute
    ) -> some View {
        Button {
            open(route)
        } label: {
            Label(title, systemImage: icon)
                .frame(minHeight: AppSpacing.minimumControl)
        }
        .foregroundStyle(AppColorRole.textPrimary)
        .accessibilityIdentifier("settings.\(route.rawValue).button")
    }
}
