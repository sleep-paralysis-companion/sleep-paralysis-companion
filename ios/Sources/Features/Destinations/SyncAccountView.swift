import SwiftUI

struct SyncAccountView: View {
    let accountState: AccountAccessState

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppAccessibility.verticalSpacing(for: dynamicTypeSize)) {
                Text("sync.title")
                    .font(AppTypographyRole.screenTitle)
                    .accessibilityAddTraits(.isHeader)
                Text("sync.value")
                    .font(AppTypographyRole.body)
                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.compact) {
                        Text("sync.future.title")
                            .font(AppTypographyRole.cardTitle)
                        Text("sync.future.providers")
                            .font(AppTypographyRole.body)
                        Text("sync.future.unavailable")
                            .font(AppTypographyRole.body)
                            .foregroundStyle(AppColorRole.textSecondary)
                    }
                }
                if accountState == .wrongAccount || accountState == .authenticationRequired {
                    AppFeedbackBanner(message: accountMessage)
                }
                Text("sync.local.safe")
                    .font(AppTypographyRole.supporting)
                    .foregroundStyle(AppColorRole.textSecondary)
            }
            .padding(AppAccessibility.contentPadding(for: dynamicTypeSize))
            .frame(maxWidth: 680, alignment: .leading)
        }
        .background(AppColorRole.background)
        .navigationTitle(Text("sync.title"))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("sync.account")
    }

    private var accountMessage: String {
        switch accountState {
        case .wrongAccount:
            String(localized: "sync.wrong.account")
        case .authenticationRequired:
            String(localized: "sync.authentication.required")
        case .guest, .signedInMatching:
            ""
        }
    }
}
