import SwiftUI

struct UnavailableFeatureView: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        AppStateView(
            title: title,
            message: message,
            systemImage: "hammer",
            actionTitle: nil,
            action: nil
        )
        .navigationTitle(Text(title))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("feature.unavailable")
    }
}

struct AccessUnavailableView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            AppStateView(
                title: "access.unavailable.title",
                message: "access.unavailable.message",
                systemImage: "lock.open",
                actionTitle: "action.close",
                action: { dismiss() }
            )
            .navigationTitle(Text("access.unavailable.title"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
