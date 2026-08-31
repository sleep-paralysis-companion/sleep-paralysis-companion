import SwiftUI

struct AudioPlayerView: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isSeeking = false
    @State private var seekValue: Double = 0
    @State private var isBreathingExpanded = false
    @State private var showSleepTimerPicker = false
    @State private var showGroundingTips = false

    var body: some View {
        ZStack {
            playerBackground

            VStack(spacing: 0) {
                topNavigationBar
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                Spacer(minLength: 12)

                ambientVisualizer
                    .padding(.vertical, 20)

                Spacer(minLength: 12)

                trackMetadata
                    .padding(.horizontal, 24)

                scrubberSection
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                mainPlaybackControls
                    .padding(.top, 24)

                bottomUtilities
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    .padding(.bottom, 24)
            }
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("audioPlayer.screen")
        .sheet(isPresented: $showSleepTimerPicker) {
            sleepTimerSheet
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showGroundingTips) {
            groundingTipsSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                    isBreathingExpanded = true
                }
            }
        }
    }

    // MARK: - Background

    private var playerBackground: some View {
        ZStack {
            LinearGradient(
                colors: [HomeScreenPalette.backgroundTop, HomeScreenPalette.backgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(HomeScreenPalette.accent.opacity(0.18))
                .frame(width: 320, height: 320)
                .blur(radius: 80)
                .offset(y: -100)

            Circle()
                .fill(HomeScreenPalette.iconTint.opacity(0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 70)
                .offset(x: 100, y: 160)
        }
    }

    // MARK: - Navigation Bar

    private var topNavigationBar: some View {
        HStack {
            Button {
                if !model.path.isEmpty {
                    model.pop()
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(HomeScreenPalette.cardSecondary.opacity(0.85))
                    .clipShape(Circle())
                    .overlay {
                        Circle().stroke(HomeScreenPalette.cardBorder.opacity(0.8), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to home")
            .accessibilityIdentifier("audioPlayer.back")

            Spacer()

            Text("Now Playing")
                .font(AppFont.inter(size: 16, relativeTo: .headline, weight: .semibold))
                .foregroundStyle(HomeScreenPalette.textSecondary)

            Spacer()

            Button {
                model.open(.curatedAudioLibrary)
            } label: {
                Image(systemName: "waveform.badge.plus")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(HomeScreenPalette.iconTint)
                    .frame(width: 44, height: 44)
                    .background(HomeScreenPalette.cardSecondary.opacity(0.85))
                    .clipShape(Circle())
                    .overlay {
                        Circle().stroke(HomeScreenPalette.blueBorder.opacity(0.8), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open Audio Library")
            .accessibilityIdentifier("audioPlayer.openLibrary")
        }
    }

    // MARK: - Center Visualizer

    private var ambientVisualizer: some View {
        ZStack {
            // Outer pulsating ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            HomeScreenPalette.accent.opacity(isPlaying ? 0.45 : 0.15),
                            HomeScreenPalette.iconTint.opacity(isPlaying ? 0.35 : 0.10),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isPlaying && !reduceMotion ? (isBreathingExpanded ? 18 : 10) : 12
                )
                .frame(
                    width: isPlaying && !reduceMotion ? (isBreathingExpanded ? 240 : 210) : 220,
                    height: isPlaying && !reduceMotion ? (isBreathingExpanded ? 240 : 210) : 220
                )
                .animation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true), value: isBreathingExpanded)

            // Inner glowing disc
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            HomeScreenPalette.card.opacity(0.95),
                            HomeScreenPalette.iconBackground.opacity(0.85),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 176, height: 176)
                .overlay {
                    Circle()
                        .stroke(HomeScreenPalette.cardBorder, lineWidth: 1.2)
                }
                .shadow(
                    color: HomeScreenPalette.accent.opacity(isPlaying ? 0.35 : 0.10),
                    radius: isPlaying ? 24 : 8
                )

            // Center Symbol & Wave
            VStack(spacing: 8) {
                Image(systemName: isPlaying ? "waveform" : "waveform.circle")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(HomeScreenPalette.iconTint)
                    .symbolEffect(.variableColor.iterative, isActive: isPlaying)

                Text(isPlaying ? "Breathe slowly" : "Paused")
                    .font(AppFont.inter(size: 13, relativeTo: .caption, weight: .medium))
                    .foregroundStyle(HomeScreenPalette.textSecondary)
            }
        }
        .frame(height: 250)
    }

    // MARK: - Track Metadata

    private var trackMetadata: some View {
        VStack(spacing: 6) {
            Text(model.activeTrackTitle)
                .font(AppFont.latoBold(size: 24, relativeTo: .title2))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Text(model.activeTrackSubtitle)
                .font(AppFont.inter(size: 15, relativeTo: .subheadline))
                .foregroundStyle(HomeScreenPalette.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Scrubber

    private var scrubberSection: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            let duration = max(model.playbackDuration, 180)
            let current = isSeeking ? seekValue : model.playbackCurrentTime
            let progress = min(max(current / duration, 0), 1)

            VStack(spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(HomeScreenPalette.cardSecondary)
                            .frame(height: 5)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [HomeScreenPalette.iconTint, HomeScreenPalette.accent],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * CGFloat(progress), height: 5)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isSeeking = true
                                let percent = max(0, min(1, value.location.x / geometry.size.width))
                                seekValue = Double(percent) * duration
                            }
                            .onEnded { value in
                                let percent = max(0, min(1, value.location.x / geometry.size.width))
                                let targetTime = Double(percent) * duration
                                model.seekPlayback(to: targetTime)
                                isSeeking = false
                            }
                    )
                }
                .frame(height: 18)

                HStack {
                    Text(formatTime(current))
                        .font(AppFont.inter(size: 13, relativeTo: .caption, weight: .medium))
                        .foregroundStyle(HomeScreenPalette.textSecondary)

                    Spacer()

                    Text("-\(formatTime(max(0, duration - current)))")
                        .font(AppFont.inter(size: 13, relativeTo: .caption, weight: .medium))
                        .foregroundStyle(HomeScreenPalette.textSecondary)
                }
            }
        }
    }

    // MARK: - Playback Controls

    private var mainPlaybackControls: some View {
        HStack(spacing: 36) {
            Button {
                model.skipPlayback(by: -15)
            } label: {
                Image(systemName: "gobackward.15")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(HomeScreenPalette.textSecondary)
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Rewind 15 seconds")

            Button {
                model.toggleHeroPlayback()
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    HomeScreenPalette.accent,
                                    HomeScreenPalette.iconTint,
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 74, height: 74)
                        .shadow(color: HomeScreenPalette.accent.opacity(0.55), radius: 14)

                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(x: isPlaying ? 0 : 2)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "Pause audio" : "Play audio")
            .accessibilityIdentifier("audioPlayer.playPause")

            Button {
                model.skipPlayback(by: 15)
            } label: {
                Image(systemName: "goforward.15")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(HomeScreenPalette.textSecondary)
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fast forward 15 seconds")
        }
    }

    // MARK: - Bottom Utilities

    private var bottomUtilities: some View {
        HStack(spacing: 16) {
            Button {
                showSleepTimerPicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "timer")
                        .font(.system(size: 15, weight: .medium))
                    if let remaining = model.sleepTimerRemaining {
                        Text(formatTimer(remaining))
                            .font(AppFont.inter(size: 14, relativeTo: .footnote, weight: .semibold))
                    } else {
                        Text("Timer")
                            .font(AppFont.inter(size: 14, relativeTo: .footnote, weight: .medium))
                    }
                }
                .foregroundStyle(
                    model.sleepTimerRemaining != nil
                        ? HomeScreenPalette.accent
                        : HomeScreenPalette.textSecondary
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(HomeScreenPalette.cardSecondary)
                .clipShape(Capsule())
                .overlay {
                    Capsule().stroke(HomeScreenPalette.cardBorder, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Set sleep timer")
            .accessibilityIdentifier("audioPlayer.sleepTimer")

            Button {
                showGroundingTips = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .medium))
                    Text("Grounding")
                        .font(AppFont.inter(size: 14, relativeTo: .footnote, weight: .medium))
                }
                .foregroundStyle(HomeScreenPalette.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(HomeScreenPalette.cardSecondary)
                .clipShape(Capsule())
                .overlay {
                    Capsule().stroke(HomeScreenPalette.cardBorder, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View grounding guide")
            .accessibilityIdentifier("audioPlayer.groundingTips")
        }
    }

    // MARK: - Sheets

    private var sleepTimerSheet: some View {
        ZStack {
            HomeScreenPalette.backgroundTop.ignoresSafeArea()

            VStack(spacing: 18) {
                Text("Sleep Timer")
                    .font(AppFont.latoBold(size: 20, relativeTo: .headline))
                    .foregroundStyle(.white)
                    .padding(.top, 16)

                Text("Audio will automatically fade and stop after the selected time.")
                    .font(AppFont.inter(size: 14, relativeTo: .footnote))
                    .foregroundStyle(HomeScreenPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                HStack(spacing: 12) {
                    timerButton(minutes: 5, label: "5m")
                    timerButton(minutes: 15, label: "15m")
                    timerButton(minutes: 30, label: "30m")
                    timerButton(minutes: 60, label: "60m")
                }
                .padding(.horizontal, 20)

                if model.sleepTimerRemaining != nil {
                    Button("Turn Off Timer") {
                        model.cancelSleepTimer()
                        showSleepTimerPicker = false
                    }
                    .font(AppFont.inter(size: 14, relativeTo: .footnote, weight: .semibold))
                    .foregroundStyle(Color.red.opacity(0.85))
                    .padding(.top, 4)
                }
            }
        }
    }

    private func timerButton(minutes: Int, label: String) -> some View {
        Button {
            model.setSleepTimer(minutes: minutes)
            showSleepTimerPicker = false
        } label: {
            Text(label)
                .font(AppFont.inter(size: 16, relativeTo: .body, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(HomeScreenPalette.card)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(HomeScreenPalette.cardBorder, lineWidth: 1.2)
                }
        }
        .buttonStyle(.plain)
    }

    private var groundingTipsSheet: some View {
        ZStack {
            HomeScreenPalette.backgroundTop.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Grounding Technique (5-4-3-2-1)")
                        .font(AppFont.latoBold(size: 20, relativeTo: .title3))
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        showGroundingTips = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(HomeScreenPalette.textSecondary)
                    }
                }

                Text("When coming out of an episode, gently bring your awareness to your senses:")
                    .font(AppFont.inter(size: 15, relativeTo: .body))
                    .foregroundStyle(HomeScreenPalette.textSecondary)

                VStack(alignment: .leading, spacing: 12) {
                    groundingStep(number: "5", text: "Look around for 5 things you can see.")
                    groundingStep(number: "4", text: "Notice 4 things you can physically feel.")
                    groundingStep(number: "3", text: "Listen for 3 distinct sounds around you.")
                    groundingStep(number: "2", text: "Notice 2 things you can smell.")
                    groundingStep(number: "1", text: "Take 1 slow, deep, relaxing breath.")
                }

                Spacer()
            }
            .padding(24)
        }
    }

    private func groundingStep(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(AppFont.latoBold(size: 16, relativeTo: .headline))
                .foregroundStyle(HomeScreenPalette.accent)
                .frame(width: 28, height: 28)
                .background(HomeScreenPalette.card)
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(HomeScreenPalette.cardBorder, lineWidth: 1)
                }

            Text(text)
                .font(AppFont.inter(size: 15, relativeTo: .body))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Helpers

    private var isPlaying: Bool {
        if case .playing = model.playbackState {
            return true
        }
        return false
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let mins = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    private func formatTimer(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
