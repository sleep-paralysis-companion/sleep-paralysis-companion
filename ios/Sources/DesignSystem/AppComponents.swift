import SwiftUI

struct AppPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypographyRole.control)
            .multilineTextAlignment(.center)
            .foregroundStyle(Color.white)
            .padding(.horizontal, AppSpacing.standard)
            .frame(maxWidth: .infinity, minHeight: AppSpacing.minimumControl)
            .background(isEnabled ? AppColorRole.accent : Color.secondary)
            .clipShape(RoundedRectangle(cornerRadius: AppShape.controlRadius))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct AppSecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorSchemeContrast) private var contrast

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypographyRole.control)
            .multilineTextAlignment(.center)
            .foregroundStyle(AppColorRole.accent)
            .padding(.horizontal, AppSpacing.standard)
            .frame(maxWidth: .infinity, minHeight: AppSpacing.minimumControl)
            .background(AppColorRole.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppShape.controlRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AppShape.controlRadius)
                    .stroke(
                        AppColorRole.separator(contrast),
                        lineWidth: contrast == .increased ? 2 : 1
                    )
            }
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct AppCard<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(AppSpacing.standard)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(reduceTransparency ? AppColorRole.surface : AppColorRole.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppShape.cardRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AppShape.cardRadius)
                    .stroke(
                        AppColorRole.separator(contrast),
                        lineWidth: contrast == .increased ? 2 : 1
                    )
            }
    }
}

struct AppFeedbackBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.compact) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(AppColorRole.error)
                .accessibilityHidden(true)
            Text(message)
                .font(AppTypographyRole.body)
                .foregroundStyle(AppColorRole.textPrimary)
        }
        .padding(AppSpacing.standard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColorRole.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppShape.controlRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("feedback.accessibility.label"))
        .accessibilityValue(message)
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityIdentifier("feedback.banner")
    }
}

struct AppStateView: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let systemImage: String
    let actionTitle: LocalizedStringKey?
    let action: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AccessibilityFocusState private var titleFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppAccessibility.verticalSpacing(for: dynamicTypeSize)) {
                Image(systemName: systemImage)
                    .font(.largeTitle)
                    .foregroundStyle(AppColorRole.accent)
                    .accessibilityHidden(true)
                Text(title)
                    .font(AppTypographyRole.screenTitle)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($titleFocused)
                Text(message)
                    .font(AppTypographyRole.body)
                    .foregroundStyle(AppColorRole.textSecondary)
                if let actionTitle, let action {
                    Button(action: action) {
                        Text(actionTitle)
                    }
                    .buttonStyle(AppPrimaryButtonStyle())
                }
            }
            .padding(AppAccessibility.contentPadding(for: dynamicTypeSize))
            .frame(maxWidth: 680, alignment: .leading)
        }
        .background(AppColorRole.background)
        .task {
            titleFocused = true
        }
    }
}

struct AppFeatureCard: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let systemImage: String
    let actionTitle: LocalizedStringKey
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.compact) {
                Label {
                    Text(title)
                        .font(AppTypographyRole.cardTitle)
                } icon: {
                    Image(systemName: systemImage)
                        .foregroundStyle(AppColorRole.accent)
                }
                Text(detail)
                    .font(AppTypographyRole.body)
                    .foregroundStyle(AppColorRole.textSecondary)
                Button(action: action) {
                    Text(actionTitle)
                }
                .buttonStyle(AppSecondaryButtonStyle())
                .accessibilityIdentifier(accessibilityIdentifier)
            }
        }
        .accessibilityElement(children: .contain)
    }
}
