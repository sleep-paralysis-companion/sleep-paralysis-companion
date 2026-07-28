import SwiftUI

struct HelpLegalView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppAccessibility.verticalSpacing(for: dynamicTypeSize)) {
                Text("help.title")
                    .font(AppTypographyRole.screenTitle)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("help.title")
                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.compact) {
                        Text("help.boundary.title")
                            .font(AppTypographyRole.cardTitle)
                        Text("notice.claim.001")
                            .font(AppTypographyRole.body)
                        Text("notice.claim.002")
                            .font(AppTypographyRole.body)
                    }
                }
                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.compact) {
                        Text("help.local.title")
                            .font(AppTypographyRole.cardTitle)
                        Text("help.local.body")
                            .font(AppTypographyRole.body)
                        Text("help.publication.pending")
                            .font(AppTypographyRole.supporting)
                            .foregroundStyle(AppColorRole.textSecondary)
                    }
                }
            }
            .padding(AppAccessibility.contentPadding(for: dynamicTypeSize))
            .frame(maxWidth: 680, alignment: .leading)
        }
        .background(AppColorRole.background)
        .navigationTitle(Text("help.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
