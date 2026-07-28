import SwiftUI

struct DataPrivacyView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppAccessibility.verticalSpacing(for: dynamicTypeSize)) {
                Text("privacy.title")
                    .font(AppTypographyRole.screenTitle)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("privacy.title")
                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.compact) {
                        Text("privacy.local.title")
                            .font(AppTypographyRole.cardTitle)
                        Text("privacy.local.body")
                            .font(AppTypographyRole.body)
                    }
                }
                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.compact) {
                        Text("privacy.controls.title")
                            .font(AppTypographyRole.cardTitle)
                        Text("privacy.controls.body")
                            .font(AppTypographyRole.body)
                        Text("privacy.controls.unavailable")
                            .font(AppTypographyRole.supporting)
                            .foregroundStyle(AppColorRole.textSecondary)
                    }
                }
                Text("privacy.permissions")
                    .font(AppTypographyRole.body)
            }
            .padding(AppAccessibility.contentPadding(for: dynamicTypeSize))
            .frame(maxWidth: 680, alignment: .leading)
        }
        .background(AppColorRole.background)
        .navigationTitle(Text("privacy.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
