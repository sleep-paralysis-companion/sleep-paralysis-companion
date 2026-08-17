import SwiftUI

struct ComingSoonView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        NightScreen {
            VStack(spacing: AppSpacing.spacious) {
                Image(systemName: systemImage)
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(HomeScreenPalette.accent)

                Text("\(title) is coming soon")
                    .font(AppTypographyRole.hero)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(message)
                    .font(AppTypographyRole.body)
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 80)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("comingSoon.\(title.lowercased())")
    }
}
