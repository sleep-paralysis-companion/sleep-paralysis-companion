import SwiftUI

struct HistoryView: View {
    let openPrivacy: () -> Void

    var body: some View {
        AppStateView(
            title: "history.title",
            message: "history.unavailable",
            systemImage: "clock",
            actionTitle: "history.data.action",
            action: openPrivacy
        )
        .navigationTitle(Text("tab.history"))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("history.placeholder")
    }
}
