import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        List {
            Section("Your setup") {
                row("Comfort audio", icon: "waveform", route: .audioLibrary)
                row("Sleep schedule", icon: "moon.stars", route: .sleepSchedule)
                row("Questionnaire answers", icon: "list.bullet.clipboard", route: .editQuestionnaire)
            }
            Section("Preferences") {
                row("Accessibility", icon: "accessibility", route: .accessibility)
            }
            Section("Privacy and support") {
                row("Data and privacy", icon: "hand.raised", route: .dataPrivacy)
                row("Help and legal", icon: "questionmark.circle", route: .helpLegal)
                row("Account", icon: "person.crop.circle", route: .account)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ title: String, icon: String, route: AppRoute) -> some View {
        Button {
            model.open(route)
        } label: {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
        }
        .foregroundStyle(.primary)
    }
}
