import SwiftUI

struct MorningCheckInFlowView: View {
    @Bindable var model: AppModel

    @State private var form = MorningCheckInForm()
    @State private var step = MorningCheckInStep.episode
    @State private var isSaving = false

    var body: some View {
        ZStack {
            MorningCheckInBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    MorningCheckInHeader(step: step, occurrence: form.occurrence)

                    if case let .affirmation(occurrence) = step {
                        affirmationContent(for: occurrence)
                    } else {
                        questionCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 28)
            }
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("morningCheckIn.flow")
    }

    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(step.questionTitle)
                .font(AppFont.latoSemiBold(size: 17, relativeTo: .headline))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            switch step {
            case .episode:
                HStack(spacing: 14) {
                    episodeAnswer(title: "YES", emoji: "😟", occurrence: .yes)
                    episodeAnswer(title: "NO", emoji: "🙂", occurrence: .no)
                }
            case .feeling:
                answerList(
                    [
                        AnswerOption("😌", "I'm fine now") { chooseFeeling(.fineNow) },
                        AnswerOption("😟", "Still a bit shaken") { chooseFeeling(.stillShaken) },
                        AnswerOption("😴", "Exhausted") { chooseFeeling(.exhausted) },
                    ]
                )
            case .spcOutcome:
                answerList(
                    [
                        AnswerOption("🌙", "Calmer") { chooseSPCOutcome(.calmer) },
                        AnswerOption("😐", "No difference") { chooseSPCOutcome(.noDifference) },
                    ]
                )
            case .postEpisodeSupport:
                answerList(
                    [
                        AnswerOption("📞", "Partner Call") { chooseSupport(.partnerCall) },
                        AnswerOption("🎧", "Calming Audio") { chooseSupport(.calmingAudio) },
                        AnswerOption("🫂", "Partner Audio") { chooseSupport(.partnerAudio) },
                    ]
                )
            case .sleepHelp:
                answerList(
                    [
                        AnswerOption("😌", "Audio helped") { chooseSleepHelp(.audioHelped) },
                        AnswerOption("◯", "Didn't use it") { chooseSleepHelp(.didNotUseIt) },
                        AnswerOption("💭", "Forget it was there") { chooseSleepHelp(.forgotItWasThere) },
                    ]
                )
            case .affirmation:
                EmptyView()
            }

            Button(action: skipCurrentQuestion) {
                Text(skipButtonTitle)
                    .font(AppTypographyRole.control)
                    .foregroundStyle(Color(red: 0.66, green: 0.62, blue: 0.86))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isSaving)
            .accessibilityIdentifier("morningCheckIn.skip")
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.07, green: 0.09, blue: 0.24).opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(red: 0.20, green: 0.21, blue: 0.45), lineWidth: 1)
        }
    }

    private func episodeAnswer(title: String, emoji: String, occurrence: EpisodeOccurrence) -> some View {
        Button {
            AppHaptics.selectionChanged(hapticsEnabled: model.settings?.hapticsEnabled != false)
            form.occurrence = occurrence
            withAnimation(.easeInOut(duration: 0.24)) {
                step = occurrence == .yes ? .feeling : .sleepHelp
            }
        } label: {
            VStack(spacing: 10) {
                Text(emoji)
                    .font(.system(size: 32))
                Text(title)
                    .font(AppFont.inter(size: 14, relativeTo: .subheadline, weight: .semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 110)
            .background(Color(red: 0.08, green: 0.10, blue: 0.25))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(red: 0.16, green: 0.17, blue: 0.38), lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title == "YES" ? "Yes, I had an episode" : "No, I did not have an episode")
    }

    private func answerList(_ answers: [AnswerOption]) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(answers.enumerated()), id: \.offset) { _, answer in
                Button {
                    AppHaptics.selectionChanged(hapticsEnabled: model.settings?.hapticsEnabled != false)
                    answer.action()
                } label: {
                    HStack(spacing: 12) {
                        Text(answer.emoji)
                            .font(.system(size: 20))
                            .frame(width: 38, height: 38)
                            .background(Color(red: 0.11, green: 0.12, blue: 0.31))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        Text(answer.title)
                            .font(AppFont.inter(size: 15, relativeTo: .subheadline))
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                    .background(Color(red: 0.08, green: 0.10, blue: 0.25))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isSaving)
            }
        }
    }

    private func affirmationContent(for occurrence: EpisodeOccurrence) -> some View {
        let affirmation = MorningAffirmation.message(for: occurrence, on: .now)

        return VStack(spacing: 24) {
            MoonMark(size: 160)
                .padding(.top, 6)
            VStack(spacing: 14) {
                Text(affirmation.title)
                    .font(AppFont.latoSemiBold(size: 18, relativeTo: .headline))
                    .multilineTextAlignment(.center)
                Text(affirmation.detail)
                    .font(AppFont.inter(size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Color(red: 0.65, green: 0.62, blue: 0.84))
                    .multilineTextAlignment(.center)
                Text(affirmation.supportingDetail)
                    .font(AppFont.inter(size: 13, relativeTo: .caption))
                    .foregroundStyle(Color(red: 0.65, green: 0.62, blue: 0.84))
                    .multilineTextAlignment(.center)
            }
            Button("Return To Home") {
                AppHaptics.primaryCTA(hapticsEnabled: model.settings?.hapticsEnabled != false)
                model.completeMorningCheckIn()
            }
            .font(AppFont.inter(size: 15, relativeTo: .headline, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.39, green: 0.27, blue: 0.75), Color(red: 0.25, green: 0.52, blue: 0.85)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.top, 14)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
    }

    private func chooseFeeling(_ value: PresentState) {
        form.presentState = value
        advance(to: .spcOutcome)
    }

    private func chooseSPCOutcome(_ value: SPCOutcome) {
        form.spcOutcome = value
        advance(to: .postEpisodeSupport)
    }

    private func chooseSupport(_ value: PostEpisodeSupport) {
        form.postEpisodeSupport = value
        saveAndShowAffirmation(for: .yes)
    }

    private func chooseSleepHelp(_ value: SleepHelpOutcome) {
        form.sleepHelpOutcome = value
        saveAndShowAffirmation(for: .no)
    }

    private func advance(to next: MorningCheckInStep) {
        withAnimation(.easeInOut(duration: 0.24)) {
            step = next
        }
    }

    private var skipButtonTitle: String {
        step == .episode ? "Skip check-in" : "Skip"
    }

    private func skipCurrentQuestion() {
        AppHaptics.secondaryCTA(hapticsEnabled: model.settings?.hapticsEnabled != false)
        switch step {
        case .episode:
            model.completeMorningCheckIn()
        case .feeling:
            advance(to: .spcOutcome)
        case .spcOutcome:
            advance(to: .postEpisodeSupport)
        case .postEpisodeSupport:
            saveAndShowAffirmation(for: .yes, isSkipping: true)
        case .sleepHelp:
            saveAndShowAffirmation(for: .no, isSkipping: true)
        case .affirmation:
            break
        }
    }

    private func saveAndShowAffirmation(for occurrence: EpisodeOccurrence, isSkipping: Bool = false) {
        isSaving = true
        Task {
            let saved = await model.submitCheckIn(form)
            if isSkipping {
                model.clearFeedback()
            }
            isSaving = false
            if saved || isSkipping {
                AppHaptics.success(hapticsEnabled: model.settings?.hapticsEnabled != false)
                withAnimation(.easeInOut(duration: 0.24)) {
                    step = .affirmation(occurrence)
                }
            }
        }
    }
}

private struct AnswerOption {
    let emoji: String
    let title: String
    let action: () -> Void

    init(_ emoji: String, _ title: String, action: @escaping () -> Void) {
        self.emoji = emoji
        self.title = title
        self.action = action
    }
}

nonisolated enum MorningCheckInStep: Equatable, Sendable {
    case episode
    case feeling
    case spcOutcome
    case postEpisodeSupport
    case sleepHelp
    case affirmation(EpisodeOccurrence)

    var questionTitle: String {
        switch self {
        case .episode:
            "Did you have an episode\nlast night?"
        case .feeling:
            "How are you feeling now?"
        case .spcOutcome:
            "How did you feel after using\nguided sleep meditation?"
        case .postEpisodeSupport:
            "What did you use after the\nepisode?"
        case .sleepHelp:
            "Did SPC help you fall asleep?"
        case .affirmation:
            ""
        }
    }

    var progressTitle: String? {
        progressTitle(for: nil)
    }

    func progressTitle(for occurrence: EpisodeOccurrence?) -> String? {
        switch self {
        case .episode:
            occurrence == .no ? "QUESTION 1 OF 2" : "QUESTION 1 OF 4"
        case .feeling:
            "QUESTION 2 OF 4"
        case .spcOutcome:
            "QUESTION 3 OF 4"
        case .postEpisodeSupport:
            "QUESTION 4 OF 4"
        case .sleepHelp:
            "QUESTION 2 OF 2"
        case .affirmation:
            nil
        }
    }

    var progressIndex: Int {
        switch self {
        case .episode: 0
        case .feeling, .sleepHelp: 1
        case .spcOutcome: 2
        case .postEpisodeSupport: 3
        case .affirmation: 4
        }
    }
}

struct MorningCheckInHeader: View {
    let step: MorningCheckInStep
    var occurrence: EpisodeOccurrence?

    nonisolated static func totalSteps(for step: MorningCheckInStep, occurrence: EpisodeOccurrence? = nil) -> Int {
        if step == .sleepHelp || occurrence == .no {
            return 2
        }
        return 4
    }

    nonisolated static func headerMoonEmoji(
        for step: MorningCheckInStep,
        occurrence: EpisodeOccurrence? = nil
    ) -> String {
        let total = totalSteps(for: step, occurrence: occurrence)
        if total == 2 {
            return step.progressIndex >= 1 ? "🌕" : "🌙"
        }
        return switch step.progressIndex {
        case 0: "🌙"
        case 1: "🌓"
        case 2: "🌔"
        default: "🌕"
        }
    }

    nonisolated static func moonPhaseName(index: Int, total: Int) -> String {
        if total == 2 {
            return index == 0 ? "crescent" : "full"
        }
        return switch index {
        case 0: "crescent"
        case 1: "half"
        case 2: "gibbous"
        default: "full"
        }
    }

    nonisolated var totalSteps: Int {
        Self.totalSteps(for: step, occurrence: occurrence)
    }

    private var headerMoonEmoji: String {
        Self.headerMoonEmoji(for: step, occurrence: occurrence)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(headerDate)
                        .font(AppFont.inter(size: 13, relativeTo: .footnote, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(Color(red: 0.57, green: 0.54, blue: 0.78))
                    Text("Good morning,\nthere 🌤️")
                        .font(AppFont.latoSemiBold(size: 20, relativeTo: .title3))
                    Text("Let's check in with your night.")
                        .font(AppFont.inter(size: 13, relativeTo: .caption))
                        .foregroundStyle(Color(red: 0.64, green: 0.61, blue: 0.82))
                }
                Spacer(minLength: 12)
                ZStack {
                    Circle()
                        .fill(Color(red: 0.42, green: 0.26, blue: 0.75))
                    Text(headerMoonEmoji)
                        .font(.system(size: 30))
                        .id(headerMoonEmoji)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.7).combined(with: .opacity),
                            removal: .scale(scale: 1.1).combined(with: .opacity)
                        ))
                }
                .frame(width: 72, height: 72)
                .animation(.easeInOut(duration: 0.28), value: headerMoonEmoji)
                .padding(.top, 6)
            }

            if let progressTitle = step.progressTitle(for: occurrence) {
                Text(progressTitle)
                    .font(AppFont.inter(size: 14, relativeTo: .footnote, weight: .medium))
                    .foregroundStyle(Color(red: 0.57, green: 0.54, blue: 0.78))
                HStack(spacing: 0) {
                    ForEach(0 ..< totalSteps, id: \.self) { index in
                        progressMoon(index: index, currentIndex: step.progressIndex, total: totalSteps)
                        if index < totalSteps - 1 {
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.horizontal, totalSteps == 2 ? 110 : 62)
            }
        }
    }

    private var headerDate: String {
        let date = Date.now
        let weekday = date.formatted(.dateTime.weekday(.wide)).uppercased()
        let monthDay = date.formatted(.dateTime.month(.abbreviated).day()).uppercased()
        return "\(weekday) • \(monthDay)"
    }

    private func progressMoon(index: Int, currentIndex: Int, total: Int) -> some View {
        let isCompleted = index < currentIndex
        let isActive = index == currentIndex
        let fillColor = isActive ? Color(red: 0.71, green: 0.61, blue: 1) : Color(red: 0.42, green: 0.32, blue: 0.74)

        return ZStack {
            Circle()
                .stroke(Color(red: 0.43, green: 0.35, blue: 0.76), lineWidth: 3)
                .frame(width: 30, height: 30)

            if isCompleted || isActive {
                moonPhaseShape(index: index, total: total, color: fillColor)
                    .shadow(
                        color: isActive ? Color(red: 0.62, green: 0.49, blue: 1).opacity(0.9) : .clear,
                        radius: isActive ? 12 : 0
                    )
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func moonPhaseShape(index: Int, total: Int, color: Color) -> some View {
        if total == 2 {
            if index == 0 {
                crescentShape(color: color)
            } else {
                fullMoonShape(color: color)
            }
        } else {
            switch index {
            case 0:
                crescentShape(color: color)
            case 1:
                halfMoonShape(color: color)
            case 2:
                gibbousShape(color: color)
            default:
                fullMoonShape(color: color)
            }
        }
    }

    private func crescentShape(color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 29, height: 29)
            .overlay(alignment: .trailing) {
                Circle()
                    .fill(Color(red: 0.03, green: 0.02, blue: 0.16))
                    .frame(width: 26, height: 29)
                    .offset(x: 5)
            }
            .clipShape(Circle())
    }

    private func halfMoonShape(color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 29, height: 29)
            .mask(alignment: .leading) {
                Rectangle()
                    .frame(width: 14.5, height: 29)
            }
    }

    private func gibbousShape(color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 29, height: 29)
            .overlay(alignment: .trailing) {
                Circle()
                    .fill(Color(red: 0.03, green: 0.02, blue: 0.16))
                    .frame(width: 16, height: 29)
                    .offset(x: 9)
            }
            .clipShape(Circle())
    }

    private func fullMoonShape(color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 30, height: 30)
    }
}

private struct MorningCheckInBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.06, green: 0.03, blue: 0.24),
                        Color(red: 0.02, green: 0.01, blue: 0.12),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                constellation(in: proxy.size)
                ForEach(0 ..< 40, id: \.self) { index in
                    Circle()
                        .fill(index.isMultiple(of: 5) ? Color(red: 0.42, green: 0.31, blue: 0.75) : .white
                            .opacity(0.36))
                        .frame(width: index.isMultiple(of: 7) ? 4 : 2)
                        .position(
                            x: starPosition(index, width: proxy.size.width, modulus: 97),
                            y: starPosition(index + 29, width: proxy.size.height, modulus: 89)
                        )
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func constellation(in size: CGSize) -> some View {
        Path { path in
            path.move(to: CGPoint(x: size.width * 0.12, y: size.height * 0.29))
            path.addLine(to: CGPoint(x: size.width * 0.54, y: size.height * 0.25))
            path.move(to: CGPoint(x: size.width * 0.70, y: size.height * 0.37))
            path.addLine(to: CGPoint(x: size.width * 0.92, y: size.height * 0.32))
            path.addLine(to: CGPoint(x: size.width * 0.93, y: size.height * 0.20))
            path.move(to: CGPoint(x: size.width * 0.70, y: size.height * 0.37))
            path.addLine(to: CGPoint(x: size.width * 0.74, y: size.height * 0.45))
        }
        .stroke(Color(red: 0.10, green: 0.37, blue: 0.60).opacity(0.55), lineWidth: 1)
    }

    private func starPosition(_ seed: Int, width: CGFloat, modulus: Int) -> CGFloat {
        CGFloat((seed * 37 + 19) % modulus) / CGFloat(modulus) * width
    }
}

private struct MorningAffirmation: Equatable {
    let title: String
    let detail: String
    let supportingDetail: String

    static func message(for occurrence: EpisodeOccurrence, on date: Date) -> Self {
        let messages: [Self] = switch occurrence {
        case .yes:
            [
                Self(
                    title: "You woke up. Again.",
                    detail: "That takes more strength than most people will ever know.",
                    supportingDetail: "Every episode teaches your brain that you're safe."
                ),
                Self(
                    title: "You made it through the night.",
                    detail: "Be gentle with yourself this morning.",
                    supportingDetail: "You deserve a slow, steady start."
                ),
                Self(
                    title: "You are here, and you are not alone.",
                    detail: "Thank you for checking in with yourself.",
                    supportingDetail: "One caring choice at a time is enough."
                ),
            ]
        case .no:
            [
                Self(
                    title: "A calmer night is worth celebrating.",
                    detail: "Carry that gentle momentum into your day.",
                    supportingDetail: "You've given yourself a strong start."
                ),
                Self(
                    title: "Good morning. You did it.",
                    detail: "Let today begin with something kind for you.",
                    supportingDetail: "Small routines can make a real difference."
                ),
                Self(
                    title: "Rest looks good on you.",
                    detail: "Keep choosing the things that help you feel settled.",
                    supportingDetail: "Your morning is yours to enjoy."
                ),
            ]
        }
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 0
        return messages[day % messages.count]
    }
}
