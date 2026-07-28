import SwiftUI

struct WelcomeView: View {
    let continueAction: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AccessibilityFocusState private var headingFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppAccessibility.verticalSpacing(for: dynamicTypeSize)) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(AppColorRole.accent)
                    .accessibilityHidden(true)
                Text("welcome.title")
                    .font(AppTypographyRole.hero)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($headingFocused)
                    .accessibilityIdentifier("welcome.title")
                Text("welcome.body")
                    .font(AppTypographyRole.body)
                    .foregroundStyle(AppColorRole.textSecondary)
                AppCard {
                    Label("welcome.local.label", systemImage: "iphone")
                        .font(AppTypographyRole.cardTitle)
                    Text("welcome.local.detail")
                        .font(AppTypographyRole.body)
                        .foregroundStyle(AppColorRole.textSecondary)
                }
                Spacer(minLength: AppSpacing.standard)
                Button(action: continueAction) {
                    Text("welcome.continue")
                }
                .buttonStyle(AppPrimaryButtonStyle())
                .accessibilityHint(Text("welcome.continue.hint"))
                .accessibilityIdentifier("welcome.continue")
            }
            .padding(AppAccessibility.contentPadding(for: dynamicTypeSize))
            .frame(maxWidth: 680, minHeight: 600, alignment: .leading)
        }
        .background(AppColorRole.background)
        .navigationBarBackButtonHidden()
        .task {
            headingFocused = true
        }
    }
}
