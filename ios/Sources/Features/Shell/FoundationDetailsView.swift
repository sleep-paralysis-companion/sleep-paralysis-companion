import SwiftUI

struct FoundationDetailsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.standard) {
                Text("shell.details.title")
                    .font(AppTypographyRole.screenTitle)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("foundation.details.title")

                Text("shell.details.body")
                    .font(AppTypographyRole.body)
                    .foregroundStyle(AppColorRole.textSecondary)
            }
            .padding(AppSpacing.screen)
            .frame(maxWidth: 680, alignment: .leading)
        }
        .navigationTitle(Text("shell.details.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
