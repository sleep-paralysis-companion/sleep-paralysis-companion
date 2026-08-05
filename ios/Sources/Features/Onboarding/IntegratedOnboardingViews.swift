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

    private struct Content {
        let title: String
        let detail: String
        let icon: String
        let cardTitle: String
        let actionTitle: String
    }

    private var content: Content {
        switch FeatureIntroductionPage(rawValue: page) ?? .gentleWake {
        case .gentleWake:
            Content(
                title: "Wake up gently!",
                detail: "",
                icon: "alarm",
                cardTitle: "Sleep reminder",
                actionTitle: "Build my sleep profile"
            )
        case .postEpisodeSupport:
            Content(
                title: "Support when you need it most",
                detail: "Open calming visual grounding and selected recovery audio after an episode.",
                icon: "sparkles",
                cardTitle: "Post-episode support",
                actionTitle: "Continue"
            )
        case .familiarVoice:
            Content(
                title: "A familiar voice guiding you to calmness",
                detail: "Record or import a private comfort clip that remains on this device.",
                icon: "waveform",
                cardTitle: "Comfort audio",
                actionTitle: "Continue to sign in"
            )
        }
    }

    var body: some View {
        OnboardingScreen {
            VStack(spacing: 0) {
                Spacer(minLength: 70)
                Text(content.title)
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                OnboardingArtwork(size: 110, symbol: content.icon)
                    .padding(.top, 50)
                featureCard
                    .padding(.top, 44)
                OnboardingProgress(current: page, count: FeatureIntroductionPage.allCases.count)
                    .padding(.top, 36)
                Spacer(minLength: 52)
                OnboardingPrimaryAction(title: content.actionTitle, identifier: nil, action: continueAction)
            }
            .frame(minHeight: 720)
        }
    }

    private var featureCard: some View {
        HStack(alignment: .top, spacing: AppSpacing.standard) {
            Image(systemName: content.icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(Color(red: 0.26, green: 0.21, blue: 0.83))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AppSpacing.tight) {
                Text(content.cardTitle)
                    .font(.headline)
                Text(
                    content.detail.isEmpty
                        ? "Set an ordinary reminder to support a consistent sleep routine."
                        : content.detail
                )
                .font(.callout)
                .foregroundStyle(OnboardingStyle.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.07, green: 0.04, blue: 0.18).opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.14))
        }
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
                Text(state == .sessionExpired ? "Sign in again" : "Welcome to Paralux")
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

    var body: some View {
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

private struct QuestionnaireTopProgress: View {
    let current: Int

    var body: some View {
        HStack {
            ForEach(0 ..< 3, id: \.self) { index in
                Circle()
                    .strokeBorder(Color(red: 0.59, green: 0.49, blue: 1), lineWidth: 1)
                    .background(Circle().fill(index == current ? Color(red: 0.67, green: 0.58, blue: 1) : .clear))
                    .frame(width: 28, height: 28)
                if index < 2 {
                    Spacer()
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Question \(current + 1) of 3")
    }
}

struct RecommendedSetupView: View {
    let persona: PersonaAnswerAggregate
    let continueAction: () -> Void

    var body: some View {
        OnboardingScreen {
            VStack(spacing: 0) {
                Spacer(minLength: 44)
                OnboardingArtwork(size: 82, symbol: nil)
                Text("Your sleep profile is ready")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, 24)
                Text("Based on your answers, we've prepared a simple setup for your nights.")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(OnboardingStyle.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.top, 14)
                recommendedSurface
                    .padding(.top, 28)
                OnboardingPrimaryAction(
                    title: "Continue to comfort audio",
                    identifier: nil,
                    action: continueAction
                )
                .padding(.top, 32)
            }
            .frame(minHeight: 720)
        }
    }

    private var recommendedSurface: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Tonight's Recommended Setup")
                .font(.headline)
                .foregroundStyle(Color(red: 0.68, green: 0.60, blue: 1))
            Label(audioTitle, systemImage: "moon.fill")
                .font(.headline)
            Text(audioDetail)
                .font(.callout)
                .foregroundStyle(OnboardingStyle.secondaryText)
            Divider().overlay(Color.white.opacity(0.18))
            Label("Sleep reminder", systemImage: "bell.fill")
                .font(.headline)
            Text("Choose a sleep and wake time when you continue.")
                .font(.callout)
                .foregroundStyle(OnboardingStyle.secondaryText)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.08, green: 0.08, blue: 0.24))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var audioTitle: String {
        persona.derivedPersona == .generalDefault ? "Comfort audio" : "Your comfort audio"
    }

    private var audioDetail: String {
        "Choose a private personal clip or a Paralux-provided recovery item."
    }
}
