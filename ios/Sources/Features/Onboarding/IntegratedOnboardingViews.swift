import SwiftUI

struct SplashView: View {
    let continueAction: () -> Void

    var body: some View {
        NightScreen {
            VStack(spacing: AppSpacing.spacious) {
                Spacer(minLength: 110)
                MoonMark(size: 132)
                Text("Understand your nights.\nOwn your sleep.")
                    .font(AppTypographyRole.hero)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text("A few quick questions help build your personal sleep-paralysis setup.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                Spacer(minLength: 80)
                Button("See what’s inside", systemImage: "arrow.right", action: continueAction)
                    .buttonStyle(AppPrimaryButtonStyle())
                    .accessibilityIdentifier("splash.continue")
            }
            .frame(maxWidth: .infinity, minHeight: 760)
        }
    }
}

struct FeatureIntroductionView: View {
    let page: Int
    let continueAction: () -> Void

    private var content: (title: String, detail: String, icon: String, card: String) {
        switch FeatureIntroductionPage(rawValue: page) ?? .gentleWake {
        case .gentleWake:
            ("Wake up gently", "Set an ordinary sleep reminder and return to your schedule whenever you choose.", "alarm.fill", "Sleep schedule")
        case .postEpisodeSupport:
            ("Support when you need it most", "Open calming visual grounding and your selected recovery audio after an episode.", "message.fill", "Post-episode support")
        case .familiarVoice:
            ("A familiar voice guiding you to calmness", "Record or import a private comfort clip that remains on this device.", "mic.fill", "Comfort audio")
        }
    }

    var body: some View {
        NightScreen {
            VStack(spacing: AppSpacing.spacious) {
                Spacer(minLength: 80)
                MoonMark(size: 92)
                Text(content.title)
                    .font(AppTypographyRole.hero)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                NightCard {
                    Label(content.card, systemImage: content.icon)
                        .font(AppTypographyRole.cardTitle)
                    Text(content.detail)
                        .foregroundStyle(.white.opacity(0.72))
                        .padding(.top, AppSpacing.compact)
                }
                HStack {
                    ForEach(FeatureIntroductionPage.allCases) { item in
                        Capsule()
                            .fill(item.rawValue == page ? Color.cyan : Color.white.opacity(0.25))
                            .frame(width: item.rawValue == page ? 26 : 8, height: 6)
                    }
                }
                Spacer(minLength: 80)
                Button(
                    page == FeatureIntroductionPage.allCases.count - 1 ? "Continue to sign in" : "Continue",
                    systemImage: "arrow.right",
                    action: continueAction
                )
                .buttonStyle(AppPrimaryButtonStyle())
            }
            .frame(maxWidth: .infinity, minHeight: 760)
        }
    }
}

struct AuthenticationView: View {
    let state: AuthenticationPresentationState
    let feedback: String?
    let isConfigured: Bool
    let signIn: (AuthenticationProvider) -> Void

    var body: some View {
        NightScreen {
            VStack(alignment: .leading, spacing: AppSpacing.spacious) {
                Spacer(minLength: 80)
                MoonMark(size: 92)
                    .frame(maxWidth: .infinity)
                Text(state == .sessionExpired ? "Sign in again" : "Welcome to Paralux")
                    .font(AppTypographyRole.hero)
                    .accessibilityAddTraits(.isHeader)
                Text(state == .sessionExpired
                    ? "Your session expired. Your protected local data remains on this device."
                    : "Sign in to keep your questionnaire and wellness history account-bound.")
                    .foregroundStyle(.white.opacity(0.72))

                if let feedback {
                    AppFeedbackBanner(message: feedback)
                }
                if !isConfigured {
                    NightCard {
                        Label("Provider configuration required", systemImage: "wrench.and.screwdriver")
                            .font(.headline)
                        Text("Add the project publishable key and configure Apple and Google provider credentials before sign-in can run.")
                            .foregroundStyle(.white.opacity(0.72))
                            .padding(.top, 6)
                    }
                }

                Button {
                    signIn(.apple)
                } label: {
                    Label("Sign in with Apple", systemImage: "apple.logo")
                }
                .buttonStyle(AppPrimaryButtonStyle())
                .disabled(!isConfigured || isProcessing)
                .accessibilityIdentifier("authentication.apple")

                Button {
                    signIn(.google)
                } label: {
                    Label("Sign in with Google", systemImage: "g.circle.fill")
                }
                .buttonStyle(AppSecondaryButtonStyle())
                .disabled(!isConfigured || isProcessing)
                .accessibilityIdentifier("authentication.google")

                if isProcessing {
                    ProgressView("Opening provider")
                        .frame(maxWidth: .infinity)
                }
                Text("No email/password, phone, OTP, guest account, or required full name is used.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, minHeight: 760, alignment: .leading)
        }
    }

    private var isProcessing: Bool {
        if case .processing = state { return true }
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
        NightScreen {
            VStack(alignment: .leading, spacing: AppSpacing.spacious) {
                HStack {
                    MoonMark(size: 58)
                    Spacer()
                    Text("Question \(questionNumber) of 3")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.65))
                }
                Text(title)
                    .font(AppTypographyRole.screenTitle)
                    .accessibilityAddTraits(.isHeader)
                VStack(spacing: AppSpacing.standard) {
                    switch question {
                    case .episodeFrequency:
                        option("Rarely – a few times a year", selected: draft?.episodeFrequency == .rarely) { selectFrequency(.rarely) }
                        option("Monthly – a few times a month", selected: draft?.episodeFrequency == .monthly) { selectFrequency(.monthly) }
                        option("Weekly", selected: draft?.episodeFrequency == .weekly) { selectFrequency(.weekly) }
                        option("Almost Nightly", selected: draft?.episodeFrequency == .almostNightly) { selectFrequency(.almostNightly) }
                    case .postEpisodeFeeling:
                        option("I shake it off and go back to sleep", selected: draft?.postEpisodeFeeling == .shakeItOff) { selectFeeling(.shakeItOff) }
                        option("I lie awake scared for a while", selected: draft?.postEpisodeFeeling == .awakeScared) { selectFeeling(.awakeScared) }
                        option("I’m too frightened to close my eyes again", selected: draft?.postEpisodeFeeling == .tooFrightenedToCloseEyes) { selectFeeling(.tooFrightenedToCloseEyes) }
                    case .calmingPersonContext:
                        option("Yes – They sleep beside me", selected: draft?.calmingPersonContext == .besideMe) { selectContext(.besideMe) }
                        option("Yes – But they are not always with me", selected: draft?.calmingPersonContext == .notAlwaysPresent) { selectContext(.notAlwaysPresent) }
                        option("No – I go through this alone", selected: draft?.calmingPersonContext == .alone) { selectContext(.alone) }
                    }
                }
                Text("Your answer is saved privately before moving on. A setup is derived only after all three answers are valid.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.top, 48)
        }
        .accessibilityIdentifier("questionnaire.\(question.rawValue)")
    }

    private var questionNumber: Int {
        switch question {
        case .episodeFrequency: 1
        case .postEpisodeFeeling: 2
        case .calmingPersonContext: 3
        }
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
            HStack(spacing: AppSpacing.standard) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(selected ? Color.indigo : Color.indigo.opacity(0.28))
                    .frame(width: 44, height: 44)
                    .overlay {
                        if selected {
                            Image(systemName: "checkmark")
                        }
                    }
                    .accessibilityHidden(true)
                Text(title)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Color.cyan : Color.white.opacity(0.5))
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 68)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: AppShape.controlRadius))
        }
        .buttonStyle(.plain)
        .accessibilityValue(selected ? "Selected" : "Not selected")
    }
}

struct RecommendedSetupView: View {
    let persona: PersonaAnswerAggregate
    let continueAction: () -> Void

    var body: some View {
        NightScreen {
            VStack(alignment: .leading, spacing: AppSpacing.spacious) {
                Spacer(minLength: 70)
                MoonMark(size: 92)
                    .frame(maxWidth: .infinity)
                Text("Here’s what we’ve set up for you.")
                    .font(AppTypographyRole.hero)
                    .accessibilityAddTraits(.isHeader)
                Text("Based on your answers, this neutral setup keeps the next steps simple. You can change your answers later in Settings.")
                    .foregroundStyle(.white.opacity(0.72))
                NightCard {
                    Label("Comfort audio setup", systemImage: "waveform")
                        .font(.headline)
                    Text(audioDetail)
                        .foregroundStyle(.white.opacity(0.72))
                }
                NightCard {
                    Label("Sleep reminder", systemImage: "moon.stars.fill")
                        .font(.headline)
                    Text("Choose a sleep and wake time. Reminder permission is requested only if you turn reminders on.")
                        .foregroundStyle(.white.opacity(0.72))
                }
                Text("This is not a diagnosis, score, risk result, or clinical profile.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.6))
                Button("Continue to comfort audio", systemImage: "arrow.right", action: continueAction)
                    .buttonStyle(AppPrimaryButtonStyle())
            }
            .frame(minHeight: 760)
        }
    }

    private var audioDetail: String {
        persona.derivedPersona == .generalDefault
            ? "Choose a private personal clip or a Paralux-provided recovery item."
            : "Comfort audio is placed first so it is ready when you choose the manual episode action."
    }
}
