import SwiftUI

struct AlarmStatusView: View {
    var body: some View {
        AppStateView(
            title: "alarm.title",
            message: "alarm.status.message",
            systemImage: "alarm",
            actionTitle: nil,
            action: nil
        )
        .navigationTitle(Text("alarm.title"))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("alarm.status")
    }
}

struct PermissionEducationView: View {
    var body: some View {
        AppStateView(
            title: "permission.title",
            message: "permission.message",
            systemImage: "bell.badge",
            actionTitle: nil,
            action: nil
        )
        .navigationTitle(Text("permission.title"))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("permission.education")
    }
}
