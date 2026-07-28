import SwiftUI

struct ProductNoticeView: View {
    let presentation: ProductNoticePresentation
    let isProcessing: Bool
    let feedbackMessage: String?
    let continueAction: () -> Void
    let openAlarm: () -> Void
    let openPrivacy: () -> Void
    let openHelp: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AccessibilityFocusState private var headingFocused: Bool
    @AccessibilityFocusState private var feedbackFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppAccessibility.verticalSpacing(for: dynamicTypeSize)) {
                Text(title)
                    .font(AppTypographyRole.screenTitle)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($headingFocused)
                    .accessibilityIdentifier("notice.title")
                Text(introduction)
                    .font(AppTypographyRole.body)
                    .foregroundStyle(AppColorRole.textSecondary)

                claimCard
                privacyCard

                if let feedbackMessage {
                    AppFeedbackBanner(message: feedbackMessage)
                        .accessibilityFocused($feedbackFocused)
                }

                utilityLinks

                Button(action: continueAction) {
                    if isProcessing {
                        ProgressView()
                            .tint(.white)
                            .accessibilityLabel(Text("notice.saving"))
                    } else {
                        Text("notice.continue")
                    }
                }
                .buttonStyle(AppPrimaryButtonStyle())
                .disabled(isProcessing)
                .accessibilityIdentifier("notice.continue")
            }
            .padding(AppAccessibility.contentPadding(for: dynamicTypeSize))
            .frame(maxWidth: 680, alignment: .leading)
        }
        .background(AppColorRole.background)
        .navigationBarBackButtonHidden()
        .task {
            headingFocused = true
        }
        .onChange(of: feedbackMessage) { _, message in
            feedbackFocused = message != nil
        }
    }

    private var claimCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.compact) {
                Text("notice.boundary.title")
                    .font(AppTypographyRole.cardTitle)
                    .accessibilityAddTraits(.isHeader)
                Text("notice.claim.001")
                    .font(AppTypographyRole.body)
                    .accessibilityIdentifier("notice.claim.001")
                Text("notice.claim.002")
                    .font(AppTypographyRole.body)
                    .accessibilityIdentifier("notice.claim.002")
            }
        }
        .accessibilityIdentifier("notice.boundary.card")
    }

    private var privacyCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.compact) {
                Text("notice.privacy.title")
                    .font(AppTypographyRole.cardTitle)
                    .accessibilityAddTraits(.isHeader)
                Text("notice.privacy.body")
                    .font(AppTypographyRole.body)
                Text("notice.permissions.body")
                    .font(AppTypographyRole.body)
                    .foregroundStyle(AppColorRole.textSecondary)
            }
        }
        .accessibilityIdentifier("notice.privacy.card")
    }

    private var utilityLinks: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppSpacing.compact) {
                utilityButton("notice.utility.alarm", action: openAlarm)
                    .accessibilityIdentifier("notice.alarm.button")
                utilityButton("notice.utility.privacy", action: openPrivacy)
                    .accessibilityIdentifier("notice.privacy.button")
                utilityButton("notice.utility.help", action: openHelp)
                    .accessibilityIdentifier("notice.help.button")
            }
            VStack(spacing: AppSpacing.compact) {
                utilityButton("notice.utility.alarm", action: openAlarm)
                    .accessibilityIdentifier("notice.alarm.button")
                utilityButton("notice.utility.privacy", action: openPrivacy)
                    .accessibilityIdentifier("notice.privacy.button")
                utilityButton("notice.utility.help", action: openHelp)
                    .accessibilityIdentifier("notice.help.button")
            }
        }
    }

    private func utilityButton(
        _ title: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
        }
        .buttonStyle(AppSecondaryButtonStyle())
    }

    private var title: LocalizedStringKey {
        presentation == .initial ? "notice.title.initial" : "notice.title.updated"
    }

    private var introduction: LocalizedStringKey {
        presentation == .initial ? "notice.intro.initial" : "notice.intro.updated"
    }
}
