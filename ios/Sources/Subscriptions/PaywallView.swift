import StoreKit
import SwiftUI

/// Apple App Store Guidelines 3.1.1 and 3.1.2 compliant paywall presentation.
///
/// Features:
/// - Clear brand header with glowing moon icon and dismiss action
/// - 4 core feature highlights (curated audio, personal voice, journal, 100% privacy)
/// - 3 interactive subscription tiers (Annual with 3-day trial as default, Monthly, Lifetime)
/// - Localized dynamic pricing fetched from StoreKit 2 with graceful offline reference fallbacks
/// - Dynamic primary CTA with progress indicator during active purchase
/// - Full Apple compliance: auto-renewal disclosure, restore purchases, and direct EULA / Privacy links
/// - Dynamic error banner with dismiss action
@MainActor
struct PaywallView: View {
    @Bindable var model: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedTier: SubscriptionProductTier = .annual
    @State private var productsByTier: [SubscriptionProductTier: Product] = [:]

    var body: some View {
        ZStack {
            NightBackground()

            ScrollView {
                VStack(spacing: 24) {
                    topBar
                    header
                    featuresList
                    tierSelectionSection
                    purchaseSection
                    complianceSection
                }
                .padding(AppAccessibility.contentPadding(for: dynamicTypeSize))
                .frame(maxWidth: 680)
            }
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(model.isPurchasing)
        .task {
            await loadProducts()
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                model.dismissPaywall()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .accessibilityLabel("Dismiss")
            .accessibilityIdentifier("paywall.dismiss")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.purple.opacity(0.45), Color.indigo.opacity(0.15), .clear],
                            center: .center,
                            startRadius: 4,
                            endRadius: 44
                        )
                    )
                    .frame(width: 88, height: 88)

                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.95, green: 0.9, blue: 1.0), Color.cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text("Unlock Sleep Paralysis Companion")
                .font(AppFont.latoBold(size: 26, relativeTo: .title))
                .multilineTextAlignment(.center)

            Text("Calm soundscapes, custom comfort voice recordings, and morning check-in history.")
                .font(AppTypographyRole.body)
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Features

    private var featuresList: some View {
        VStack(alignment: .leading, spacing: 14) {
            featureRow(
                icon: "🎧",
                title: "Curated Soundscapes",
                description: "Full access to the calming audio library and offline downloads."
            )
            featureRow(
                icon: "🎙️",
                title: "Personal Comfort Voice",
                description: "Record and keep loved ones' reassuring grounding messages."
            )
            featureRow(
                icon: "📖",
                title: "Sleep & Check-in Journal",
                description: "Descriptive morning check-ins and recovery insights."
            )
            featureRow(
                icon: "🔒",
                title: "100% Private",
                description: "Local-first storage; personal voice recordings never leave your device."
            )
        }
        .padding(18)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.indigo.opacity(0.3), lineWidth: 1)
        }
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(icon)
                .font(.title2)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypographyRole.control)
                    .foregroundStyle(.white)
                Text(description)
                    .font(AppTypographyRole.footnote)
                    .foregroundStyle(.white.opacity(0.68))
            }
        }
    }

    // MARK: - Tier Selection

    private var tierSelectionSection: some View {
        VStack(spacing: 12) {
            tierCard(
                tier: .annual,
                title: "Annual Premium",
                badges: ["3-Day Free Trial", "Best Value"],
                priceText: annualPriceText,
                subtitle: annualSubtitle,
                identifier: "paywall.tier.annual"
            )
            tierCard(
                tier: .monthly,
                title: "Monthly Premium",
                badges: ["3-Day Free Trial"],
                priceText: monthlyPriceText,
                subtitle: monthlySubtitle,
                identifier: "paywall.tier.monthly"
            )
            tierCard(
                tier: .lifetime,
                title: "Lifetime Access",
                badges: ["One-Time"],
                priceText: lifetimePriceText,
                subtitle: lifetimeSubtitle,
                identifier: "paywall.tier.lifetime"
            )
        }
    }

    private func tierCard(
        tier: SubscriptionProductTier,
        title: String,
        badges: [String],
        priceText: String,
        subtitle: String,
        identifier: String
    ) -> some View {
        let isSelected = selectedTier == tier
        return Button {
            AppHaptics.selectionChanged(hapticsEnabled: model.settings?.hapticsEnabled != false)
            selectedTier = tier
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(AppTypographyRole.cardTitle)
                        .foregroundStyle(.white)

                    ForEach(badges, id: \.self) { badge in
                        Text(badge)
                            .font(AppTypographyRole.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(badge == "Best Value" ? Color.yellow : Color.cyan)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                (badge == "Best Value" ? Color.yellow : Color.cyan).opacity(0.18),
                                in: Capsule()
                            )
                    }

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? Color(red: 0.72, green: 0.61, blue: 1.0) : .white.opacity(0.4))
                }

                Text(priceText)
                    .font(AppFont.interSemiBold(size: 17, relativeTo: .body))
                    .foregroundStyle(.white.opacity(0.95))

                Text(subtitle)
                    .font(AppTypographyRole.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? Color.purple.opacity(0.2) : Color.white.opacity(0.04),
                in: RoundedRectangle(cornerRadius: 18)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        isSelected ? Color(red: 0.72, green: 0.61, blue: 1.0) : Color.white.opacity(0.12),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Dynamic Price Calculations

    private var annualPriceText: String {
        if let product = productsByTier[.annual] {
            return "\(product.displayPrice)/year ≈ $5.00/month"
        }
        return "$59.99/year ≈ $5.00/month"
    }

    private var annualSubtitle: String {
        if let product = productsByTier[.annual] {
            return "3 days free, then \(product.displayPrice)/year. Cancel anytime."
        }
        return "3 days free, then $59.99/year. Cancel anytime."
    }

    private var monthlyPriceText: String {
        if let product = productsByTier[.monthly] {
            return "\(product.displayPrice)/month"
        }
        return "$8.99/month"
    }

    private var monthlySubtitle: String {
        if let product = productsByTier[.monthly] {
            return "3 days free, then \(product.displayPrice)/month. Cancel anytime."
        }
        return "3 days free, then $8.99/month. Cancel anytime."
    }

    private var lifetimePriceText: String {
        if let product = productsByTier[.lifetime] {
            return product.displayPrice
        }
        return "$149.99"
    }

    private var lifetimeSubtitle: String {
        "Pay once, keep forever. No recurring renewal."
    }

    // MARK: - Purchase Section

    private var ctaButtonTitle: String {
        switch selectedTier {
        case .annual, .monthly:
            return "Start 3-Day Free Trial"
        case .lifetime:
            return "Unlock Lifetime Access"
        }
    }

    private var purchaseSection: some View {
        VStack(spacing: 12) {
            if let errorMessage = model.purchaseErrorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(errorMessage)
                        .font(AppTypographyRole.footnote)
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        model.purchaseErrorMessage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .accessibilityLabel("Dismiss error")
                }
                .padding(12)
                .background(Color.red.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.35))
                }
                .accessibilityIdentifier("paywall.errorMessage")
            }

            Button {
                AppHaptics.primaryCTA(hapticsEnabled: model.settings?.hapticsEnabled != false)
                Task {
                    await model.purchase(tier: selectedTier)
                }
            } label: {
                HStack(spacing: 8) {
                    if model.isPurchasing {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(ctaButtonTitle)
                        .font(AppFont.interSemiBold(size: 18, relativeTo: .headline))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.55, green: 0.25, blue: 0.95), Color.indigo],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 24)
                )
            }
            .buttonStyle(.plain)
            .disabled(model.isPurchasing || model.isRestoring)
            .opacity((model.isPurchasing || model.isRestoring) ? 0.7 : 1.0)
            .accessibilityIdentifier("paywall.purchase")
        }
    }

    // MARK: - Apple Compliance Section

    private var complianceSection: some View {
        VStack(spacing: 14) {
            Text("Recurring billing. Subscriptions auto-renew unless canceled in Apple ID Settings at least 24 hours before the trial or billing period ends. Payment is charged to your Apple ID.")
                .font(AppFont.inter(size: 12, relativeTo: .caption))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            Button {
                AppHaptics.secondaryCTA(hapticsEnabled: model.settings?.hapticsEnabled != false)
                Task {
                    await model.restorePurchases()
                }
            } label: {
                HStack(spacing: 6) {
                    if model.isRestoring {
                        ProgressView()
                            .tint(.white)
                    }
                    Text("Restore Purchases")
                        .font(AppTypographyRole.footnote)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .buttonStyle(.plain)
            .disabled(model.isPurchasing || model.isRestoring)
            .accessibilityIdentifier("paywall.restore")

            HStack(spacing: 16) {
                Link("Terms of Use (EULA)", destination: LegalSupport.termsURL)
                    .accessibilityIdentifier("paywall.terms")
                Text("•")
                    .foregroundStyle(.white.opacity(0.3))
                Link("Privacy Policy", destination: LegalSupport.privacyURL)
                    .accessibilityIdentifier("paywall.privacy")
            }
            .font(AppTypographyRole.footnote)
            .tint(Color(red: 0.72, green: 0.61, blue: 1.0))
        }
        .padding(.top, 4)
    }

    // MARK: - Product Loading

    private func loadProducts() async {
        do {
            let products = try await model.subscriptionService.loadProducts()
            var map: [SubscriptionProductTier: Product] = [:]
            for product in products {
                if let tier = SubscriptionProductTier(productID: product.id) {
                    map[tier] = product
                }
            }
            productsByTier = map
        } catch {
            // Keep using reference prices when offline or loading fails
        }
    }
}
