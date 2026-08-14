// swiftlint:disable file_length

import SwiftUI

private enum OnboardingStyle {
    static let horizontalPadding: CGFloat = 26
    static let buttonWidth: CGFloat = 350
    static let secondaryText = Color(red: 0.62, green: 0.58, blue: 0.75)
    static let rowFill = Color(red: 0.11, green: 0.06, blue: 0.29).opacity(0.92)
    static let rowStroke = Color(red: 0.35, green: 0.25, blue: 0.72).opacity(0.65)
}

private struct OnboardingScreen<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.04, blue: 0.16), Color(red: 0.01, green: 0.01, blue: 0.07)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            OnboardingStars()
                .ignoresSafeArea()
            ScrollView {
                content
                    .padding(
                        .horizontal,
                        dynamicTypeSize.isAccessibilitySize ? AppSpacing.standard : OnboardingStyle.horizontalPadding
                    )
                    .padding(.vertical, AppSpacing.standard)
                    .frame(maxWidth: 510)
                    .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
    }
}

private struct OnboardingStars: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0 ..< 18, id: \.self) { index in
                    Circle()
                        .fill(index.isMultiple(of: 4) ? Color.purple.opacity(0.7) : Color.white.opacity(0.42))
                        .frame(width: index.isMultiple(of: 5) ? 3 : 2)
                        .position(
                            x: CGFloat((index * 67 + 29) % 97) / 97 * proxy.size.width,
                            y: CGFloat((index * 41 + 13) % 89) / 89 * proxy.size.height
                        )
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct OnboardingArtwork: View {
    let size: CGFloat
    let symbol: String?

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.purple.opacity(0.18))
                .frame(width: size * 1.55, height: size * 1.55)
                .blur(radius: 12)
            Circle()
                .fill(Color(red: 0.08, green: 0.05, blue: 0.19))
                .frame(width: size, height: size)
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(Color(red: 0.23, green: 0.15, blue: 0.52))
                        .frame(width: size * 0.52)
                }
            if let symbol {
                Image(systemName: symbol)
                    .font(.title.weight(.semibold))
                    .foregroundStyle(Color(red: 0.82, green: 0.79, blue: 1))
            }
        }
        .frame(height: size * 1.55)
        .accessibilityHidden(true)
    }
}

private struct OnboardingProgress: View {
    let current: Int
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0 ..< count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Color(red: 0.45, green: 0.26, blue: 1) : Color.white.opacity(0.28))
                    .frame(width: index == current ? 22 : 6, height: 6)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(current + 1) of \(count)")
    }
}

private struct OnboardingPrimaryAction: View {
    let title: String
    let identifier: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.compact) {
                Text(title)
                Image(systemName: "arrow.right")
                    .fontWeight(.semibold)
            }
        }
        .font(.headline)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: AppSpacing.minimumControl)
        .background(
            LinearGradient(
                colors: [Color(red: 0.35, green: 0.24, blue: 0.78), Color(red: 0.20, green: 0.49, blue: 0.84)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .frame(maxWidth: OnboardingStyle.buttonWidth)
        .accessibilityIdentifierIfPresent(identifier)
    }
}

private extension View {
    @ViewBuilder
    func accessibilityIdentifierIfPresent(_ identifier: String?) -> some View {
        if let identifier {
            accessibilityIdentifier(identifier)
        } else {
            self
        }
    }
}

struct SplashView: View {
    let continueAction: () -> Void

    var body: some View {
        OnboardingScreen {
            VStack(spacing: 0) {
                Spacer(minLength: 88)
                OnboardingArtwork(size: 104, symbol: nil)
                Text("Understand your\nnights. Own your\nsleep.")
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Understand your nights. Own your sleep.")
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, 28)
                Text("A few quick questions help us build your personal sleep paralysis setup.")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(OnboardingStyle.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)
                Spacer(minLength: 60)
                OnboardingPrimaryAction(
                    title: "See what's inside",
                    identifier: "splash.continue",
                    action: continueAction
                )
            }
            .frame(minHeight: 720)
        }
    }
}

struct FeatureIntroductionView: View {
    let page: Int
    let continueAction: () -> Void
    let skipAction: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    fileprivate struct Content {
        let title: String
        let detail: String
        let icon: String
        let cardTitle: String
    }

    private var content: Content {
        switch FeatureIntroductionPage(rawValue: page) ?? .gentleWake {
        case .gentleWake:
            Content(
                title: "Wake up gently!",
                detail: "Wake during your lightest sleep phase and start mornings feeling refreshed.",
                icon: "alarm",
                cardTitle: "Smart Alarm"
            )
        case .postEpisodeSupport:
            Content(
                title: "Support when you\nneed it most.",
                detail: "Receive calming guidance, grounding exercises, and recovery support after each episode.",
                icon: "bubble.left",
                cardTitle: "Post Episode Support"
            )
        case .familiarVoice:
            Content(
                title: "A familiar voice\nguiding to calmness",
                detail: "Record your own voice or a loved one's message to help guide you through difficult moments.",
                icon: "mic",
                cardTitle: "Calming Voice"
            )
        }
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityLayout
            } else {
                FeatureIntroductionReferenceLayout(
                    page: page,
                    content: content,
                    continueAction: continueAction,
                    skipAction: skipAction
                )
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var accessibilityLayout: some View {
        OnboardingScreen {
            VStack(spacing: 0) {
                Spacer(minLength: 70)
                Text(content.title)
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                FeatureIntroductionArtwork(page: page)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 42)
                FeatureIntroductionCard(content: content)
                    .padding(.top, 42)
                if page != FeatureIntroductionPage.postEpisodeSupport.rawValue {
                    OnboardingProgress(current: page, count: FeatureIntroductionPage.allCases.count)
                        .padding(.top, 36)
                }
                Spacer(minLength: 42)
                FeatureIntroductionCommunity()
                FeatureIntroductionPrimaryAction(action: continueAction)
                    .padding(.top, 30)
                Button("Skip", action: skipAction)
                    .font(.headline)
                    .foregroundStyle(OnboardingStyle.secondaryText)
                    .padding(.top, 22)
                    .accessibilityIdentifier("feature.skip")
            }
            .frame(minHeight: 720)
        }
    }
}

private struct FeatureIntroductionReferenceLayout: View {
    let page: Int
    let content: FeatureIntroductionView.Content
    let continueAction: () -> Void
    let skipAction: () -> Void

    private let referenceSize = CGSize(width: 430, height: 932)

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / referenceSize.width, proxy.size.height / referenceSize.height)

            ZStack {
                FeatureIntroductionBackdrop()
                canvas
                    .frame(width: referenceSize.width, height: referenceSize.height)
                    .scaleEffect(scale)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
            .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
    }

    private var canvas: some View {
        ZStack {
            Text(content.title)
                .font(.system(size: 28, weight: .bold))
                .tracking(-0.45)
                .lineSpacing(2)
                .multilineTextAlignment(.leading)
                .frame(width: 358, height: page == 0 ? 42 : 86, alignment: .topLeading)
                .position(x: 215, y: page == 0 ? 180 : 190)
                .accessibilityAddTraits(.isHeader)

            FeatureIntroductionArtwork(page: page)
                .frame(width: 220, height: 190)
                .position(x: 215, y: artworkCenterY)
                .accessibilityHidden(true)

            FeatureIntroductionCard(content: content)
                .frame(width: 350, height: 124)
                .position(x: 215, y: 586)

            if page != FeatureIntroductionPage.postEpisodeSupport.rawValue {
                OnboardingProgress(current: page, count: FeatureIntroductionPage.allCases.count)
                    .position(x: 215, y: 683)
            }

            FeatureIntroductionCommunity()
                .position(x: 215, y: 731)

            FeatureIntroductionPrimaryAction(action: continueAction)
                .frame(width: 350, height: 62)
                .position(x: 215, y: 807)

            Button("Skip", action: skipAction)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color(red: 0.59, green: 0.56, blue: 0.72))
                .position(x: 215, y: 862)
                .accessibilityIdentifier("feature.skip")
        }
    }

    private var artworkCenterY: CGFloat {
        switch FeatureIntroductionPage(rawValue: page) ?? .gentleWake {
        case .gentleWake: 377
        case .postEpisodeSupport: 351
        case .familiarVoice: 352
        }
    }
}

private struct FeatureIntroductionBackdrop: View {
    // Decorative star data is most readable as fixed x/y/size/color tuples.
    // swiftlint:disable:next large_tuple
    private let stars: [(CGFloat, CGFloat, CGFloat, Color)] = [
        (26, 103, 2.1, .purple.opacity(0.67)), (151, 20, 2.6, .white.opacity(0.36)),
        (227, 0, 2.1, .purple.opacity(0.78)), (406, 19, 2.2, .purple.opacity(0.65)),
        (89, 64, 2.0, .purple.opacity(0.72)), (319, 75, 1.5, .blue.opacity(0.48)),
        (33, 225, 1.6, .blue.opacity(0.48)), (86, 154, 2.2, .purple.opacity(0.68)),
        (247, 190, 2.8, .white.opacity(0.32)), (321, 154, 1.2, .purple.opacity(0.38)),
        (391, 123, 1.5, .blue.opacity(0.52)), (44, 360, 2.4, .white.opacity(0.34)),
        (87, 412, 2.5, .white.opacity(0.31)), (122, 260, 2.5, .white.opacity(0.35)),
        (216, 248, 2.5, .white.opacity(0.35)), (302, 271, 1.6, .blue.opacity(0.48)),
        (377, 468, 1.7, .purple.opacity(0.75)), (117, 520, 2.6, .white.opacity(0.33)),
        (180, 627, 2.5, .white.opacity(0.32)), (332, 669, 1.1, .blue.opacity(0.38)),
        (128, 696, 2.0, .purple.opacity(0.75)), (391, 756, 1.1, .purple.opacity(0.35)),
        (34, 879, 1.1, .blue.opacity(0.38)), (188, 876, 2.7, .white.opacity(0.32)),
        (378, 897, 1.1, .purple.opacity(0.35)),
    ]

    var body: some View {
        GeometryReader { proxy in
            let xScale = proxy.size.width / 430
            let yScale = proxy.size.height / 932

            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.035, green: 0.02, blue: 0.12),
                        Color(red: 0.025, green: 0.015, blue: 0.10),
                        Color(red: 0.045, green: 0.02, blue: 0.20),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [Color(red: 0.19, green: 0.17, blue: 0.46).opacity(0.44), .clear],
                    center: UnitPoint(x: 0.80, y: 0.24),
                    startRadius: 4,
                    endRadius: 260
                )
                FeatureIntroductionConstellation()
                    .stroke(Color(red: 0.13, green: 0.22, blue: 0.50).opacity(0.62), lineWidth: 1)
                ForEach(Array(stars.enumerated()), id: \.offset) { _, star in
                    Circle()
                        .fill(star.3)
                        .frame(width: star.2 * 2, height: star.2 * 2)
                        .position(x: star.0 * xScale, y: star.1 * yScale)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private struct FeatureIntroductionConstellation: Shape {
    func path(in rect: CGRect) -> Path {
        let xScale = rect.width / 430
        let yScale = rect.height / 932
        var path = Path()
        path.move(to: CGPoint(x: 50 * xScale, y: 280 * yScale))
        path.addLine(to: CGPoint(x: 228 * xScale, y: 248 * yScale))
        path.move(to: CGPoint(x: 392 * xScale, y: 226 * yScale))
        path.addLine(to: CGPoint(x: 391 * xScale, y: 310 * yScale))
        path.addLine(to: CGPoint(x: 303 * xScale, y: 351 * yScale))
        path.move(to: CGPoint(x: 303 * xScale, y: 351 * yScale))
        path.addLine(to: CGPoint(x: 317 * xScale, y: 417 * yScale))
        return path
    }
}

private struct FeatureIntroductionArtwork: View {
    let page: Int

    var body: some View {
        switch FeatureIntroductionPage(rawValue: page) ?? .gentleWake {
        case .gentleWake:
            alarmArtwork
        case .postEpisodeSupport:
            supportArtwork
        case .familiarVoice:
            voiceArtwork
        }
    }

    private var alarmArtwork: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.31, green: 0.18, blue: 0.92).opacity(0.34))
                .frame(width: 168, height: 168)
                .blur(radius: 22)
            Circle()
                .fill(Color(red: 0.28, green: 0.20, blue: 0.80))
                .frame(width: 130, height: 130)
            Circle()
                .fill(Color(red: 0.84, green: 0.83, blue: 0.97))
                .frame(width: 90, height: 90)
            Path { path in
                path.move(to: CGPoint(x: 88, y: 91))
                path.addLine(to: CGPoint(x: 66, y: 72))
                path.move(to: CGPoint(x: 88, y: 91))
                path.addLine(to: CGPoint(x: 102, y: 78))
            }
            .stroke(Color(red: 0.25, green: 0.17, blue: 0.77), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
            Circle()
                .fill(Color(red: 0.25, green: 0.17, blue: 0.77))
                .frame(width: 7, height: 7)
                .offset(y: 3)
            Capsule()
                .fill(Color(red: 0.28, green: 0.20, blue: 0.80))
                .frame(width: 27, height: 14)
                .rotationEffect(.degrees(-27))
                .offset(x: -48, y: 62)
            Capsule()
                .fill(Color(red: 0.28, green: 0.20, blue: 0.80))
                .frame(width: 27, height: 14)
                .rotationEffect(.degrees(27))
                .offset(x: 48, y: 62)
        }
        .frame(width: 176, height: 176)
    }

    private var supportArtwork: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 15)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.28, green: 0.11, blue: 0.70), Color(red: 0.10, green: 0.27, blue: 0.67)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.18)))
                .frame(width: 80, height: 48)
                .offset(x: 122, y: 17)
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.31, green: 0.16, blue: 0.80), Color(red: 0.12, green: 0.33, blue: 0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.22)))
                .frame(width: 170, height: 110)
                .offset(x: 17, y: 46)
            VStack(alignment: .leading, spacing: 4) {
                Text("You're safe.")
                    .font(.system(size: 16, weight: .bold))
                Text("Take a moment to\nreorient.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.81))
                    .lineSpacing(1)
                HStack(spacing: 7) {
                    ForEach(0 ..< 3, id: \.self) { _ in
                        Circle().fill(Color(red: 0.57, green: 0.47, blue: 0.96)).frame(width: 6, height: 6)
                    }
                }
                .padding(.top, 5)
            }
            .foregroundStyle(.white)
            .offset(x: 38, y: 69)
        }
        .frame(width: 220, height: 190)
    }

    private var voiceArtwork: some View {
        ZStack {
            Circle()
                .stroke(Color(red: 0.37, green: 0.25, blue: 0.75).opacity(0.26), lineWidth: 1)
                .frame(width: 132, height: 132)
            Circle()
                .stroke(Color(red: 0.47, green: 0.33, blue: 0.92).opacity(0.33), lineWidth: 1)
                .frame(width: 102, height: 102)
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.64, green: 0.45, blue: 1), Color(red: 0.28, green: 0.06, blue: 0.64)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 72, height: 110)
                .offset(y: 7)
                .shadow(color: Color.purple.opacity(0.52), radius: 20)
            VStack(spacing: 9) {
                Capsule().fill(Color.white.opacity(0.20)).frame(width: 43, height: 2)
                Capsule().fill(Color.white.opacity(0.20)).frame(width: 43, height: 2)
                Capsule().fill(Color.white.opacity(0.20)).frame(width: 43, height: 2)
                Capsule().fill(Color.white.opacity(0.20)).frame(width: 43, height: 2)
            }
            .offset(y: 7)
            Capsule()
                .fill(Color(red: 0.49, green: 0.29, blue: 0.92))
                .frame(width: 3, height: 24)
                .offset(y: 78)
            Capsule()
                .fill(Color.white.opacity(0.32))
                .frame(width: 46, height: 4)
                .blur(radius: 3)
                .offset(y: 104)
        }
        .frame(width: 190, height: 190)
    }
}

private struct FeatureIntroductionCard: View {
    let content: FeatureIntroductionView.Content

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: content.icon)
                .font(.system(size: 23, weight: .regular))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.39, green: 0.22, blue: 0.98), Color(red: 0.12, green: 0.37, blue: 0.87)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: Color(red: 0.39, green: 0.22, blue: 0.98).opacity(0.50), radius: 15)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text(content.cardTitle)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                Text(content.detail)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color(red: 0.68, green: 0.62, blue: 0.88))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(red: 0.065, green: 0.035, blue: 0.18).opacity(0.91))
        .clipShape(RoundedRectangle(cornerRadius: 27))
        .overlay { RoundedRectangle(cornerRadius: 27).stroke(Color(red: 0.34, green: 0.22, blue: 0.63).opacity(0.72)) }
    }
}

private struct FeatureIntroductionCommunity: View {
    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: -7) {
                avatar("A", color: Color(red: 0.33, green: 0.10, blue: 0.65))
                avatar("M", color: Color(red: 0.08, green: 0.29, blue: 0.74))
                avatar("J", color: Color(red: 0.00, green: 0.32, blue: 0.48))
            }
        }
        .frame(width: 246, height: 30, alignment: .leading)
    }

    private func avatar(_ initial: String, color: Color) -> some View {
        Text(initial)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 27, height: 27)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.12)))
    }
}

private struct FeatureIntroductionPrimaryAction: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 22) {
                Text("Build my sleep profile")
                Image(systemName: "arrow.right")
                    .font(.system(size: 24, weight: .regular))
            }
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.36, green: 0.24, blue: 0.78), Color(red: 0.21, green: 0.49, blue: 0.84)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct AuthenticationView: View {
    let state: AuthenticationPresentationState
    let feedback: String?
    let isConfigured: Bool
    let signIn: (AuthenticationProvider) -> Void

    var body: some View {
        OnboardingScreen {
            VStack(spacing: AppSpacing.standard) {
                Spacer(minLength: 56)
                OnboardingArtwork(size: 94, symbol: nil)
                Text(state == .sessionExpired ? "Sign in again" : "Welcome to Sleep Paralysis Companion")
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(authenticationDetail)
                    .font(.callout)
                    .foregroundStyle(OnboardingStyle.secondaryText)
                    .multilineTextAlignment(.center)
                if let feedback {
                    AppFeedbackBanner(message: feedback)
                }
                if !isConfigured {
                    NightCard {
                        Label("Provider configuration required", systemImage: "wrench.and.screwdriver")
                            .font(.headline)
                        Text(
                            "Add the project publishable key and Apple and Google provider credentials " +
                                "before sign-in can run."
                        )
                        .foregroundStyle(.white.opacity(0.72))
                    }
                }
                Button { signIn(.apple) } label: { Label("Sign in with Apple", systemImage: "apple.logo") }
                    .buttonStyle(AppPrimaryButtonStyle())
                    .disabled(!isConfigured || isProcessing)
                    .accessibilityIdentifier("authentication.apple")
                Button { signIn(.google) } label: { Label("Sign in with Google", systemImage: "g.circle.fill") }
                    .buttonStyle(AppSecondaryButtonStyle())
                    .disabled(!isConfigured || isProcessing)
                    .accessibilityIdentifier("authentication.google")
                if isProcessing {
                    ProgressView("Opening provider")
                }
            }
            .frame(minHeight: 720)
        }
    }

    private var authenticationDetail: String {
        state == .sessionExpired
            ? "Your protected local data remains on this device."
            : "Sign in to keep your questionnaire and wellness history account-bound."
    }

    private var isProcessing: Bool {
        if case .processing = state {
            return true
        }
        return false
    }
}

struct QuestionnaireView: View {
    let question: QuestionnaireQuestion
    let draft: QuestionnaireDraft?
    let selectFrequency: (EpisodeFrequency) -> Void
    let selectFeeling: (PostEpisodeFeeling) -> Void
    let selectContext: (CalmingPersonContext) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                OnboardingScreen {
                    VStack(alignment: .leading, spacing: 0) {
                        QuestionnaireTopProgress(current: questionNumber - 1)
                            .padding(.top, 34)
                        Text("Question \(questionNumber) of 3")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(OnboardingStyle.secondaryText)
                            .padding(.top, 26)
                        Text(title)
                            .font(.title2.weight(.bold))
                            .accessibilityAddTraits(.isHeader)
                            .padding(.top, 30)
                        VStack(spacing: AppSpacing.standard) {
                            optionRows
                        }
                        .padding(.top, 28)
                        Spacer(minLength: 42)
                        OnboardingProgress(current: questionNumber - 1, count: 3)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(minHeight: 720, alignment: .top)
                }
            } else {
                QuestionnaireReferenceLayout(
                    question: question,
                    draft: draft,
                    selectFrequency: selectFrequency,
                    selectFeeling: selectFeeling,
                    selectContext: selectContext
                )
            }
        }
        .accessibilityIdentifier("questionnaire.\(question.rawValue)")
    }

    @ViewBuilder
    private var optionRows: some View {
        switch question {
        case .episodeFrequency:
            option("Almost Nightly", selected: draft?.episodeFrequency == .almostNightly) {
                selectFrequency(.almostNightly)
            }
            option("Weekly", selected: draft?.episodeFrequency == .weekly) { selectFrequency(.weekly) }
            option("Monthly – a few times a month", selected: draft?.episodeFrequency == .monthly) {
                selectFrequency(.monthly)
            }
            option("Rarely – a few times a year", selected: draft?.episodeFrequency == .rarely) {
                selectFrequency(.rarely)
            }
        case .postEpisodeFeeling:
            option("I shake it off and go back to sleep", selected: draft?.postEpisodeFeeling == .shakeItOff) {
                selectFeeling(.shakeItOff)
            }
            option("I lie awake scared for a while", selected: draft?.postEpisodeFeeling == .awakeScared) {
                selectFeeling(.awakeScared)
            }
            option(
                "I'm too frightened to close my eyes again",
                selected: draft?.postEpisodeFeeling == .tooFrightenedToCloseEyes
            ) {
                selectFeeling(.tooFrightenedToCloseEyes)
            }
        case .calmingPersonContext:
            option("Yes - They sleep beside me", selected: draft?.calmingPersonContext == .besideMe) {
                selectContext(.besideMe)
            }
            option(
                "Yes - But they are not always with me",
                selected: draft?.calmingPersonContext == .notAlwaysPresent
            ) {
                selectContext(.notAlwaysPresent)
            }
            option("No – I go through this alone", selected: draft?.calmingPersonContext == .alone) {
                selectContext(.alone)
            }
        }
    }

    private var questionNumber: Int {
        question == .episodeFrequency ? 1 : question == .postEpisodeFeeling ? 2 : 3
    }

    private var title: String {
        switch question {
        case .episodeFrequency: "How often do you experience Sleep Paralysis?"
        case .postEpisodeFeeling: "How do you feel after the episode?"
        case .calmingPersonContext: "Do you have someone whose voice calms you down?"
        }
    }

    private func option(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.18, green: 0.11, blue: 0.45))
                    .frame(width: 44, height: 44)
                    .overlay {
                        if selected {
                            Image(systemName: "checkmark").fontWeight(.bold)
                        }
                    }
                    .accessibilityHidden(true)
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(selected ? .white : OnboardingStyle.secondaryText)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(
                        selected
                            ? Color(red: 0.65, green: 0.56, blue: 1)
                            : Color(red: 0.47, green: 0.39, blue: 0.91)
                    )
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 66)
            .background(OnboardingStyle.rowFill)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay { RoundedRectangle(cornerRadius: 18).stroke(OnboardingStyle.rowStroke) }
        }
        .buttonStyle(.plain)
        .accessibilityValue(selected ? "Selected" : "Not selected")
    }
}

private struct QuestionnaireReferenceLayout: View {
    let question: QuestionnaireQuestion
    let draft: QuestionnaireDraft?
    let selectFrequency: (EpisodeFrequency) -> Void
    let selectFeeling: (PostEpisodeFeeling) -> Void
    let selectContext: (CalmingPersonContext) -> Void

    private let referenceSize = CGSize(width: 430, height: 932)

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / referenceSize.width, proxy.size.height / referenceSize.height)

            ZStack {
                FeatureIntroductionBackdrop()
                canvas
                    .frame(width: referenceSize.width, height: referenceSize.height)
                    .scaleEffect(scale)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
            .ignoresSafeArea()
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
    }

    private var canvas: some View {
        ZStack {
            QuestionnaireTopProgress(current: questionNumber - 1)
                .position(x: 215, y: 94)

            Text("Question \(questionNumber) of 3")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(OnboardingStyle.secondaryText)
                .frame(width: 360, alignment: .leading)
                .position(x: 215, y: 149)

            Text(title)
                .font(.system(size: 26, weight: .bold))
                .tracking(-0.45)
                .lineSpacing(3)
                .multilineTextAlignment(.leading)
                .frame(width: 360, height: 70, alignment: .topLeading)
                .position(x: 215, y: 232)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 24) {
                ForEach(options) { option in
                    QuestionnaireReferenceOption(option: option)
                }
            }
            .frame(width: 378)
            .position(x: 215, y: options.count == 4 ? 448 : 403)

            QuestionnaireBottomProgress(current: questionNumber - 1)
                .position(x: 215, y: 820)
        }
    }

    private var questionNumber: Int {
        question == .episodeFrequency ? 1 : question == .postEpisodeFeeling ? 2 : 3
    }

    private var title: String {
        switch question {
        case .episodeFrequency: "How often do you experience Sleep Paralysis?"
        case .postEpisodeFeeling: "How do you feel after the episode?"
        case .calmingPersonContext: "Do you have someone whose voice calms you down?"
        }
    }

    private var options: [QuestionnaireReferenceOption.Content] {
        switch question {
        case .episodeFrequency:
            [
                .init("Almost Nightly", emoji: "\u{1F315}", selected: draft?.episodeFrequency == .almostNightly) {
                    selectFrequency(.almostNightly)
                },
                .init("Weekly", emoji: "\u{1F316}", selected: draft?.episodeFrequency == .weekly) {
                    selectFrequency(.weekly)
                },
                .init(
                    "Monthly \u{2013} a few times a month",
                    emoji: "\u{1F317}",
                    selected: draft?.episodeFrequency == .monthly
                ) {
                    selectFrequency(.monthly)
                },
                .init(
                    "Rarely \u{2013} a few times a year",
                    emoji: "\u{1F319}",
                    selected: draft?.episodeFrequency == .rarely
                ) {
                    selectFrequency(.rarely)
                },
            ]
        case .postEpisodeFeeling:
            [
                .init(
                    "I shake it off and go back to sleep",
                    emoji: "\u{1F634}",
                    selected: draft?.postEpisodeFeeling == .shakeItOff
                ) {
                    selectFeeling(.shakeItOff)
                },
                .init(
                    "I lie awake scared for a while",
                    emoji: "\u{1F61F}",
                    selected: draft?.postEpisodeFeeling == .awakeScared
                ) {
                    selectFeeling(.awakeScared)
                },
                .init(
                    "I'm too frightened to close my eyes again",
                    emoji: "\u{1F631}",
                    selected: draft?.postEpisodeFeeling == .tooFrightenedToCloseEyes
                ) {
                    selectFeeling(.tooFrightenedToCloseEyes)
                },
            ]
        case .calmingPersonContext:
            [
                .init(
                    "Yes \u{2013} They sleep beside me",
                    emoji: "\u{1F49E}",
                    selected: draft?.calmingPersonContext == .besideMe
                ) {
                    selectContext(.besideMe)
                },
                .init(
                    "Yes \u{2013} But they are not always with me",
                    emoji: "\u{1F4AC}",
                    selected: draft?.calmingPersonContext == .notAlwaysPresent
                ) {
                    selectContext(.notAlwaysPresent)
                },
                .init(
                    "No \u{2013} I go through this alone",
                    emoji: "\u{1F9D8}",
                    selected: draft?.calmingPersonContext == .alone
                ) {
                    selectContext(.alone)
                },
            ]
        }
    }
}

private struct QuestionnaireReferenceOption: View {
    struct Content: Identifiable {
        let title: String
        let emoji: String
        let selected: Bool
        let action: () -> Void

        var id: String {
            title
        }

        init(_ title: String, emoji: String, selected: Bool, action: @escaping () -> Void) {
            self.title = title
            self.emoji = emoji
            self.selected = selected
            self.action = action
        }
    }

    let option: Content

    var body: some View {
        Button(action: option.action) {
            HStack(spacing: 16) {
                Text(option.emoji)
                    .font(.system(size: 25))
                    .frame(width: 44, height: 44)
                    .background(Color(red: 0.18, green: 0.11, blue: 0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityHidden(true)

                Text(option.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(option.selected ? .white : OnboardingStyle.secondaryText)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: option.selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 25, weight: .regular))
                    .foregroundStyle(
                        option.selected
                            ? Color(red: 0.65, green: 0.56, blue: 1)
                            : Color(red: 0.47, green: 0.39, blue: 0.91)
                    )
                    .frame(width: 25, height: 25)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 66)
            .background(OnboardingStyle.rowFill)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).stroke(OnboardingStyle.rowStroke) }
        }
        .buttonStyle(.plain)
        .accessibilityValue(option.selected ? "Selected" : "Not selected")
    }
}

private struct QuestionnaireBottomProgress: View {
    let current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0 ..< 3, id: \.self) { index in
                Capsule()
                    .fill(
                        index == current
                            ? LinearGradient(
                                colors: [
                                    Color(red: 0.55, green: 0.23, blue: 0.98),
                                    Color(red: 0.12, green: 0.42, blue: 0.95),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            : LinearGradient(
                                colors: [Color(red: 0.22, green: 0.15, blue: 0.45)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                    )
                    .frame(width: index == current ? 24 : 6, height: 6)
                    .shadow(
                        color: index == current ? Color(red: 0.50, green: 0.26, blue: 1).opacity(0.75) : .clear,
                        radius: 10
                    )
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(current + 1) of 3")
    }
}

private struct QuestionnaireTopProgress: View {
    let current: Int

    var body: some View {
        ZStack {
            ForEach(0 ..< 3, id: \.self) { index in
                QuestionnaireProgressMoon(index: index, current: current)
                    .position(x: [38, 191, 322][index], y: 14)
            }
        }
        .frame(width: 360, height: 28)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Question \(current + 1) of 3")
    }
}

private struct QuestionnaireProgressMoon: View {
    let index: Int
    let current: Int

    private let outline = Color(red: 0.49, green: 0.40, blue: 0.86)
    private let fill = Color(red: 0.67, green: 0.58, blue: 1)
    private let background = Color(red: 0.035, green: 0.02, blue: 0.12)

    var body: some View {
        ZStack {
            Circle().fill(background)
            if index == 1 {
                Circle()
                    .fill(current >= 1 ? fill : background)
                    .mask(Rectangle().frame(width: 14).offset(x: -7))
                Rectangle()
                    .fill(outline)
                    .frame(width: 1, height: 28)
            } else if index == 2, current >= 2 {
                Circle().fill(fill)
            }
            Circle().strokeBorder(outline, lineWidth: 1.4)
        }
        .frame(width: 28, height: 28)
        .shadow(color: index == current ? fill.opacity(0.72) : .clear, radius: 18)
        .accessibilityHidden(true)
    }
}

struct RecommendedSetupView: View {
    let persona: PersonaAnswerAggregate
    let continueAction: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityLayout
            } else {
                ProfileCreatedReferenceLayout(
                    recommendation: ProfileCreatedRecommendation(persona: persona),
                    continueAction: continueAction
                )
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var accessibilityLayout: some View {
        OnboardingScreen {
            VStack(spacing: 0) {
                Spacer(minLength: 44)
                ProfileCreatedArtwork()
                Text("Your sleep profile is ready")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, 24)
                Text("Based on your answers, we've prepared\nthe best support plan for your nights.")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(OnboardingStyle.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.top, 14)
                ProfileCreatedRecommendationCard(recommendation: ProfileCreatedRecommendation(persona: persona))
                    .padding(.top, 28)
                ProfileCreatedPrimaryAction(action: continueAction)
                    .padding(.top, 32)
            }
            .frame(minHeight: 720)
        }
    }
}

private struct ProfileCreatedReferenceLayout: View {
    let recommendation: ProfileCreatedRecommendation
    let continueAction: () -> Void

    private let referenceSize = CGSize(width: 430, height: 932)

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / referenceSize.width, proxy.size.height / referenceSize.height)

            ZStack {
                FeatureIntroductionBackdrop()
                canvas
                    .frame(width: referenceSize.width, height: referenceSize.height)
                    .scaleEffect(scale)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
            .ignoresSafeArea()
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
    }

    private var canvas: some View {
        ZStack {
            ProfileCreatedArtwork()
                .frame(width: 164, height: 164)
                .position(x: 215, y: 197)
                .accessibilityHidden(true)

            Text("Your sleep profile is ready")
                .font(.system(size: 26, weight: .bold))
                .tracking(-0.5)
                .frame(width: 376, height: 34)
                .position(x: 215, y: 336)
                .accessibilityAddTraits(.isHeader)

            Text("Based on your answers, we've prepared\nthe best support plan for your nights.")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color(red: 0.61, green: 0.57, blue: 0.74))
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .frame(width: 376, height: 58)
                .position(x: 215, y: 387)

            ProfileCreatedRecommendationCard(recommendation: recommendation)
                .frame(width: 376, height: 167)
                .position(x: 215, y: 521)

            ProfileCreatedPrimaryAction(action: continueAction)
                .frame(width: 350, height: 62)
                .position(x: 215, y: 667)
        }
    }
}

private struct ProfileCreatedRecommendation {
    struct Row {
        let icon: String
        let title: String
        let detail: String
    }

    let alarmRow: Row
    let episodeRow: Row

    init(persona: PersonaAnswerAggregate) {
        let longAudio = Row(
            icon: "\u{1F319}",
            title: "Long Audio Journey",
            detail: "Sleep stories + Calming exercises"
        )
        let comfortAudio = Row(
            icon: "\u{1F399}\u{FE0F}",
            title: "Comfort Audio Priority",
            detail: "Calming support during episodes"
        )

        switch persona.derivedPersona {
        case .frequentIntensePersonNotAlwaysPresent:
            alarmRow = longAudio
            episodeRow = Row(
                icon: "\u{1F4DE}",
                title: "Partner Call Priority",
                detail: "Quick access during episodes"
            )
        case .frequentIntensePersonBesideUser:
            alarmRow = longAudio
            episodeRow = Row(
                icon: "\u{1F399}\u{FE0F}",
                title: "Partner Voice Priority",
                detail: "A familiar voice, ready to play"
            )
        case .frequentIntenseNoCalmingPerson:
            alarmRow = longAudio
            episodeRow = comfortAudio
        case .generalDefault:
            alarmRow = Row(
                icon: "\u{26A1}",
                title: "Short Wind-Down",
                detail: "15-minute calming track"
            )
            episodeRow = comfortAudio
        }
    }
}

private struct ProfileCreatedArtwork: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.31, green: 0.19, blue: 0.82).opacity(0.42))
                .frame(width: 102, height: 102)
                .blur(radius: 24)
                .offset(x: -9, y: 17)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.54, green: 0.33, blue: 1),
                            Color(red: 0.15, green: 0.07, blue: 0.39),
                        ],
                        center: UnitPoint(x: 0.28, y: 0.78),
                        startRadius: 2,
                        endRadius: 72
                    )
                )
                .frame(width: 130, height: 130)

            Circle()
                .fill(Color(red: 0.045, green: 0.015, blue: 0.16))
                .frame(width: 95, height: 95)
                .offset(x: 28, y: -18)

            Circle()
                .fill(Color(red: 0.60, green: 0.46, blue: 1).opacity(0.36))
                .frame(width: 17, height: 17)
                .blur(radius: 2)
                .offset(x: -31, y: -15)
            Circle()
                .fill(Color(red: 0.64, green: 0.49, blue: 1).opacity(0.48))
                .frame(width: 19, height: 19)
                .blur(radius: 2)
                .offset(x: -43, y: 11)
            Circle()
                .fill(Color(red: 0.64, green: 0.49, blue: 1).opacity(0.39))
                .frame(width: 11, height: 11)
                .blur(radius: 1)
                .offset(x: -24, y: 37)
        }
    }
}

private struct ProfileCreatedRecommendationCard: View {
    let recommendation: ProfileCreatedRecommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Tonight's Recommended Setup")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color(red: 0.63, green: 0.58, blue: 0.88))
                .padding(.top, 14)

            ProfileCreatedRecommendationRow(row: recommendation.alarmRow)
                .padding(.top, 11)
                .padding(.leading, -10)

            Divider()
                .overlay(Color(red: 0.38, green: 0.31, blue: 0.67).opacity(0.82))
                .padding(.horizontal, -8)
                .padding(.top, 9)
                .padding(.bottom, 11)

            ProfileCreatedRecommendationRow(row: recommendation.episodeRow)
                .padding(.leading, -10)
        }
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(red: 0.075, green: 0.08, blue: 0.23))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

private struct ProfileCreatedRecommendationRow: View {
    let row: ProfileCreatedRecommendation.Row

    var body: some View {
        HStack(spacing: 13) {
            Text(row.icon)
                .font(.system(size: 27))
                .frame(width: 28, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(row.detail)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color(red: 0.62, green: 0.58, blue: 0.76))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 40)
    }
}

private struct ProfileCreatedPrimaryAction: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 22) {
                Text("Continue to comfort audio")
                Image(systemName: "arrow.right")
                    .font(.system(size: 24, weight: .regular))
            }
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.36, green: 0.24, blue: 0.78), Color(red: 0.21, green: 0.49, blue: 0.84)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
