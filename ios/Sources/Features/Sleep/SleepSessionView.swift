import SwiftUI

struct SleepSessionView: View {
    @Bindable var model: AppModel

    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var isEndControlVisible = false
    @State private var endControlTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                SleepSessionBackground()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: revealEndControl)

                if dynamicTypeSize.isAccessibilitySize {
                    accessibleContent
                } else {
                    figmaMatchedContent(in: proxy.size)
                }

                if isEndControlVisible || voiceOverEnabled {
                    endSessionControl
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.horizontal, 64)
                        .padding(.bottom, max(proxy.safeAreaInsets.bottom + 22, 34))
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                minimizeControl
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, max(proxy.safeAreaInsets.top + 10, 20))
                    .padding(.trailing, 18)
            }
            .simultaneousGesture(minimizeGesture)
        }
        .ignoresSafeArea()
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sleepSession.active")
        .accessibilityAction(.escape) {
            model.minimizeSleepSession()
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            revealEndControl()
        }
        .onDisappear {
            endControlTask?.cancel()
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                UIApplication.shared.isIdleTimerDisabled = true
            }
        }
    }

    private func figmaMatchedContent(in size: CGSize) -> some View {
        let scale = min(size.width / 393, size.height / 932)
        let canvasSize = CGSize(width: 393 * scale, height: 932 * scale)

        return ZStack(alignment: .topLeading) {
            SleepSessionClock()
                .frame(width: canvasSize.width - 40 * scale, height: 156 * scale)
                .position(x: canvasSize.width / 2, y: 238 * scale)

            Image("SleepSessionMoon")
                .resizable()
                .scaledToFit()
                .frame(width: 226 * scale, height: 226 * scale)
                .position(x: canvasSize.width / 2, y: 440 * scale)
                .accessibilityHidden(true)

            episodeButton
                .frame(width: 329 * scale, height: 120 * scale)
                .position(x: canvasSize.width / 2, y: 673 * scale)

            HStack(spacing: 6) {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                Text("No unlock required")
                    .font(AppTypographyRole.footnote)
                    .foregroundStyle(.white.opacity(0.55))
            }
            .accessibilityHidden(true)
            .frame(width: 220 * scale)
            .position(x: canvasSize.width / 2, y: 762 * scale)
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .position(x: size.width / 2, y: size.height / 2)
    }

    private var accessibleContent: some View {
        ScrollView {
            VStack(spacing: AppSpacing.spacious) {
                SleepSessionClock()
                Image("SleepSessionMoon")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 226)
                    .accessibilityHidden(true)
                episodeButton
                    .frame(maxWidth: 329, minHeight: 120)
                HStack(spacing: 6) {
                    Image(systemName: "lock.open.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("Authenticate when requested")
                        .font(AppTypographyRole.footnote)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.vertical, 72)
            .frame(maxWidth: .infinity)
        }
    }

    private var episodeButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                _ = model.performSleepSessionAudioAction(audioAction, presentSession: false)
            }
        } label: {
            HStack(spacing: 12) {
                episodeButtonIcon
                Text(audioButtonTitle)
                    .font(AppTypographyRole.screenTitle)
                    .lineSpacing(0)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 210)
                    .contentTransition(.interpolate)
            }
            .padding(.horizontal, 40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                LinearGradient(
                    colors: [
                        Color(red: 90.0 / 255.0, green: 71.0 / 255.0, blue: 180.0 / 255.0),
                        Color(red: 65.0 / 255.0, green: 119.0 / 255.0, blue: 201.0 / 255.0),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(
                color: Color(red: 90.0 / 255.0, green: 71.0 / 255.0, blue: 180.0 / 255.0).opacity(0.35),
                radius: 18,
                y: 6
            )
            .shadow(color: .black.opacity(0.25), radius: 25, y: 25)
        }
        .buttonStyle(SleepSessionActionButtonStyle())
        .accessibilityLabel(audioButtonTitle.replacingOccurrences(of: "\n", with: " "))
        .accessibilityHint(audioButtonHint)
        .accessibilityIdentifier("sleepSession.episode")
    }

    @ViewBuilder
    private var episodeButtonIcon: some View {
        if model.sleepSessionAudioStatus == .ready {
            Image("EpisodeSparkle")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 35)
                .accessibilityHidden(true)
        } else {
            Image(systemName: model.sleepSessionAudioStatus == .playing ? "pause.fill" : "play.fill")
                .font(.system(size: 26, weight: .semibold))
                .frame(width: 24, height: 35)
                .accessibilityHidden(true)
        }
    }

    private var audioButtonTitle: String {
        switch model.sleepSessionAudioStatus {
        case .ready: "I just had an\nepisode"
        case .playing: "Pause grounding\naudio"
        case .paused: "Resume grounding\naudio"
        }
    }

    private var audioButtonHint: String {
        switch model.sleepSessionAudioStatus {
        case .ready: "Starts your selected grounding audio."
        case .playing: "Pauses grounding audio without ending the sleep session."
        case .paused: "Continues grounding audio from where it was paused."
        }
    }

    private var audioAction: SleepSessionAudioAction {
        switch model.sleepSessionAudioStatus {
        case .ready: .startOrResume
        case .playing: .pause
        case .paused: .resume
        }
    }

    private var minimizeControl: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            model.minimizeSleepSession()
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Minimize sleep session")
        .accessibilityHint("Keeps the session and any grounding audio active.")
        .accessibilityIdentifier("sleepSession.minimize")
    }

    private var minimizeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let verticalDistance = value.translation.height
                let horizontalDistance = abs(value.translation.width)
                guard verticalDistance > 90, verticalDistance > horizontalDistance else { return }
                model.minimizeSleepSession()
            }
    }

    private var endSessionControl: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            model.endSleepSession()
        } label: {
            Label("End sleep session", systemImage: "xmark")
                .font(AppTypographyRole.control)
                .foregroundStyle(.white.opacity(0.92))
                .padding(.horizontal, 20)
                .frame(minHeight: 50)
                .background {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .overlay {
                            Capsule()
                                .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                        }
                }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Stops grounding audio and removes the Lock Screen companion.")
        .accessibilityIdentifier("sleepSession.end")
    }

    private func revealEndControl() {
        endControlTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) {
            isEndControlVisible = true
        }
        endControlTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled, !voiceOverEnabled else { return }
            withAnimation(.easeIn(duration: 0.2)) {
                isEndControlVisible = false
            }
        }
    }
}

private struct SleepSessionActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

private struct SleepSessionClock: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(spacing: 6) {
                Text(context.date.formatted(date: .omitted, time: .shortened))
                    .font(AppFont.inter(size: 72, relativeTo: .largeTitle).weight(.bold))
                    .tracking(-1.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .shadow(color: .white.opacity(0.12), radius: 16, x: 0, y: 0)
                Text(context.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(AppFont.inter(size: 20, relativeTo: .title3))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .multilineTextAlignment(.center)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "\(context.date.formatted(date: .complete, time: .shortened))"
            )
        }
    }
}

private struct SleepSessionBackground: View {
    @State private var isTwinkling = false

    private static let stars: [SleepSessionStar] = [
        .init(xPosition: 150.87, yPosition: 332.93, size: 4.01, opacity: 0.20),
        .init(xPosition: 61.36, yPosition: 829.94, size: 5.31, opacity: 0.45),
        .init(xPosition: 63.14, yPosition: 512.22, size: 5.37, opacity: 0.46),
        .init(xPosition: 344.17, yPosition: 563.74, size: 4.71, opacity: 0.33),
        .init(xPosition: 10.02, yPosition: 405.82, size: 4.98, opacity: 0.38),
        .init(xPosition: 290.18, yPosition: 762.60, size: 5.07, opacity: 0.54),
        .init(xPosition: 334.91, yPosition: 304.55, size: 4.53, opacity: 0.29),
        .init(xPosition: 208.21, yPosition: 178.87, size: 4.86, opacity: 0.36),
        .init(xPosition: 3.99, yPosition: 518.45, size: 5.53, opacity: 0.49),
        .init(xPosition: 382.46, yPosition: 674.90, size: 4.74, opacity: 0.43),
        .init(xPosition: 162.22, yPosition: 789.15, size: 4.47, opacity: 0.28),
        .init(xPosition: 93.61, yPosition: 832.62, size: 5.60, opacity: 0.50),
        .init(xPosition: 192.30, yPosition: 51.65, size: 6.00, opacity: 0.58),
        .init(xPosition: 94.24, yPosition: 453.67, size: 5.52, opacity: 0.71),
        .init(xPosition: 4.05, yPosition: 567.83, size: 5.77, opacity: 0.78),
        .init(xPosition: 125.88, yPosition: 725.35, size: 4.73, opacity: 0.43),
        .init(xPosition: 325.71, yPosition: 192.89, size: 5.95, opacity: 0.66),
        .init(xPosition: 59.87, yPosition: 391.48, size: 4.14, opacity: 0.22),
        .init(xPosition: 227.57, yPosition: 390.38, size: 5.98, opacity: 0.63),
        .init(xPosition: 336.25, yPosition: 233.24, size: 5.58, opacity: 0.74),
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    stops: [
                        .init(
                            color: Color(red: 19.0 / 255.0, green: 11.0 / 255.0, blue: 63.0 / 255.0),
                            location: 0
                        ),
                        .init(
                            color: Color(red: 7.0 / 255.0, green: 2.0 / 255.0, blue: 37.0 / 255.0),
                            location: 0.5
                        ),
                        .init(color: Color(red: 2.0 / 255.0, green: 0, blue: 20.0 / 255.0), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                ForEach(Array(Self.stars.enumerated()), id: \.offset) { index, star in
                    let isSpecialStar = index.isMultiple(of: 3)
                    let starOpacity = isSpecialStar
                        ? (isTwinkling ? star.opacity * 0.6 : star.opacity * 0.2)
                        : star.opacity * 0.3

                    Circle()
                        .fill(.white.opacity(starOpacity))
                        .frame(
                            width: star.size * proxy.size.width / 393,
                            height: star.size * proxy.size.width / 393
                        )
                        .position(
                            x: star.xPosition / 393 * proxy.size.width,
                            y: star.yPosition / 932 * proxy.size.height
                        )
                        .animation(
                            isSpecialStar
                                ? .easeInOut(
                                    duration: Double(2.5 + Double(index % 4) * 0.8)
                                ).repeatForever(autoreverses: true)
                                : nil,
                            value: isTwinkling
                        )
                }
            }
        }
        .onAppear {
            isTwinkling = true
        }
        .accessibilityHidden(true)
    }
}

private struct SleepSessionStar {
    let xPosition: CGFloat
    let yPosition: CGFloat
    let size: CGFloat
    let opacity: Double
}
