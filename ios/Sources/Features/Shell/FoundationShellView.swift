import SwiftUI

struct FoundationShellView: View {
    let environment: AppEnvironment
    let isReady: Bool
    let showDetails: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppAccessibility.verticalSpacing(for: dynamicTypeSize)) {
                Text("shell.title")
                    .font(AppTypographyRole.screenTitle)
                    .accessibilityAddTraits(.isHeader)

                Text("shell.summary")
                    .font(AppTypographyRole.body)
                    .foregroundStyle(AppColorRole.textSecondary)

                statusCard

                Button(action: showDetails) {
                    Text("shell.details.button")
                        .font(AppTypographyRole.control)
                        .frame(maxWidth: .infinity, minHeight: AppSpacing.minimumControl)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("foundation.details.button")
            }
            .padding(AppSpacing.screen)
            .frame(maxWidth: 680, alignment: .leading)
        }
        .background(AppColorRole.background)
        .navigationTitle(Text("shell.title"))
        .navigationBarTitleDisplayMode(.inline)
        .animation(
            .easeInOut(duration: AppMotion.standardDuration(reduceMotion: reduceMotion)),
            value: isReady
        )
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.compact) {
            Text("shell.status.label")
                .font(AppTypographyRole.sectionTitle)
                .accessibilityAddTraits(.isHeader)

            Text(statusText)
                .font(AppTypographyRole.body)

            LabeledContent {
                Text(environment.rawValue.capitalized)
            } label: {
                Text("shell.environment.label")
            }
            .font(AppTypographyRole.supporting)
        }
        .padding(AppSpacing.standard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColorRole.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppShape.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: AppShape.cardRadius)
                .stroke(AppColorRole.separator(contrast), lineWidth: contrast == .increased ? 2 : 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("foundation.status.card")
    }

    private var statusText: String {
        isReady
            ? String(localized: "shell.status.value")
            : String(localized: "shell.status.preparing")
    }
}
