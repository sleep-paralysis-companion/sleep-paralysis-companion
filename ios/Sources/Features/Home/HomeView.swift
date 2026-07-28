import SwiftUI

struct HomeView: View {
    let accessPolicy: AccessPolicy
    let open: (AppRoute) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppAccessibility.verticalSpacing(for: dynamicTypeSize)) {
                Text("home.title")
                    .font(AppTypographyRole.screenTitle)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("home.title")
                Text("home.summary")
                    .font(AppTypographyRole.body)
                    .foregroundStyle(AppColorRole.textSecondary)

                AppFeatureCard(
                    title: "alarm.title",
                    detail: "alarm.home.detail",
                    systemImage: "alarm",
                    actionTitle: "alarm.view.status",
                    accessibilityIdentifier: "home.alarm.button",
                    action: { open(.alarm) }
                )

                AppFeatureCard(
                    title: "grounding.title",
                    detail: capabilityDetail(.grounding),
                    systemImage: "circle.grid.cross",
                    actionTitle: "feature.view.status",
                    accessibilityIdentifier: "home.grounding.button",
                    action: { open(.grounding) }
                )

                AppFeatureCard(
                    title: "preparation.title",
                    detail: capabilityDetail(.preparation),
                    systemImage: "checklist",
                    actionTitle: "feature.view.status",
                    accessibilityIdentifier: "home.preparation.button",
                    action: { open(.preparation) }
                )
            }
            .padding(AppAccessibility.contentPadding(for: dynamicTypeSize))
            .frame(maxWidth: 680, alignment: .leading)
        }
        .background(AppColorRole.background)
        .navigationTitle(Text("tab.home"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func capabilityDetail(_ capability: ProductCapability) -> LocalizedStringKey {
        let presentation = AccessPolicyPresenter(policy: accessPolicy).capability(
            capability,
            platform: PlatformCapabilities(supported: []),
            release: ReleaseGates(enabled: []),
            premium: .unknown,
            external: ExternalAvailability(available: [])
        )
        return presentation.decision == .unavailable
            ? "feature.unavailable.detail"
            : "feature.access.future"
    }
}
