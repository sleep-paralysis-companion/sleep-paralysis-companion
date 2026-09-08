import SwiftUI

struct AudioPlayerView: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var isSeeking = false
    @State private var seekValue: Double = 0
    @State private var showSleepTimerPicker = false
    @State private var showGroundingTips = false

    var body: some View {
        ZStack {
            playerBackground

            VStack(spacing: 0) {
                topNavigationBar
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 16)

                trackSelectionSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                artworkSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                Spacer(minLength: 0)

                VStack(spacing: 0) {
                    scrubberSection
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)

                    mainPlaybackControls
                        .padding(.bottom, 20)

                    bottomUtilities
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                }
            }
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("audioPlayer.screen")
        .sheet(isPresented: $showSleepTimerPicker) {
            sleepTimerSheet
                .presentationDetents([.height(340)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showGroundingTips) {
            groundingTipsSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Background

    private var playerBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.04, blue: 0.18),
                    Color(red: 0.02, green: 0.02, blue: 0.09),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(red: 0.45, green: 0.35, blue: 0.85).opacity(0.12))
                .frame(width: 340, height: 340)
                .blur(radius: 90)
                .offset(y: -140)

            Circle()
                .fill(Color(red: 0.25, green: 0.45, blue: 0.95).opacity(0.10))
                .frame(width: 280, height: 280)
                .blur(radius: 80)
                .offset(x: 120, y: 160)

            ForEach(0 ..< 20, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(index.isMultiple(of: 3) ? 0.65 : 0.35))
                    .frame(width: index.isMultiple(of: 5) ? 2.5 : 1.5)
                    .position(
                        x: pseudoCoord(index * 47 + 13, max: 400),
                        y: pseudoCoord(index * 71 + 29, max: 800)
                    )
                    .accessibilityHidden(true)
            }
        }
    }

    private func pseudoCoord(_ seed: Int, max: CGFloat) -> CGFloat {
        CGFloat((seed * 37 + 19) % Int(max))
    }

    // MARK: - Navigation Bar

    private var topNavigationBar: some View {
        HStack {
            Button {
                AppHaptics.secondaryCTA(hapticsEnabled: model.settings?.hapticsEnabled != false)
                if !model.path.isEmpty {
                    model.setPath(Array(model.path.dropLast()))
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color(red: 0.12, green: 0.10, blue: 0.28).opacity(0.6))
                    .clipShape(Circle())
                    .overlay {
                        Circle().stroke(Color.white.opacity(0.15), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to home")
            .accessibilityIdentifier("audioPlayer.back")

            Spacer()

            Text("Sleep Player")
                .font(AppFont.inter(size: 20, relativeTo: .headline, weight: .bold))
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            Menu {
                Button {
                    model.open(.curatedAudioLibrary)
                } label: {
                    Label("Browse Audio Library", systemImage: "music.note.list")
                }
                .accessibilityIdentifier("audioPlayer.menu.curatedLibrary")

                Button {
                    model.open(.audioLibrary)
                } label: {
                    Label("Personal Recordings", systemImage: "mic")
                }
                .accessibilityIdentifier("audioPlayer.menu.personalAudio")
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color(red: 0.12, green: 0.10, blue: 0.28).opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    }
            }
            .accessibilityLabel("More options")
            .accessibilityIdentifier("audioPlayer.openLibrary")
        }
    }

    // MARK: - Track Selection Section

    private var trackSelectionSection: some View {
        HStack(spacing: 8) {
            trackPill(
                id: "quick-unwind",
                title: "Quick Unwind",
                icon: "bolt.fill",
                iconColor: Color(red: 1.0, green: 0.78, blue: 0.22)
            )

            trackPill(
                id: "slow-unwind",
                title: "Slow Unwind",
                icon: "moon.fill",
                iconColor: Color(red: 0.95, green: 0.85, blue: 0.45)
            )

            trackPill(
                id: "second-sleep",
                title: "Second Sleep",
                icon: "sparkles",
                iconColor: Color(red: 0.72, green: 0.58, blue: 1.0)
            )
        }
        .accessibilityIdentifier("audioPlayer.trackList")
    }

    private func trackPill(id: String, title: String, icon: String, iconColor: Color) -> some View {
        let active = isCurrentTrack(id: id)
        let playing = isTrackPlaying(id: id)

        return Button {
            if active {
                AppHaptics.playbackToggle(hapticsEnabled: model.settings?.hapticsEnabled != false)
                model.togglePlayback()
            } else {
                AppHaptics.selectionChanged(hapticsEnabled: model.settings?.hapticsEnabled != false)
                if let asset = CatalogAudioManifest.bundled.assets.first(where: { $0.id == id }) {
                    model.playCatalogAsset(asset)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor)

                Text(title)
                    .font(AppFont.inter(size: 13, relativeTo: .subheadline, weight: .semibold))
                    .foregroundStyle(active ? .white : HomeScreenPalette.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background {
                if active {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(red: 0.16, green: 0.24, blue: 0.42).opacity(0.85))
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(red: 0.10, green: 0.08, blue: 0.24).opacity(0.65))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        active ? Color(red: 0.35, green: 0.58, blue: 0.95) : Color(red: 0.22, green: 0.16, blue: 0.42).opacity(0.7),
                        lineWidth: active ? 1.5 : 1
                    )
            }
            .shadow(
                color: active ? Color(red: 0.35, green: 0.58, blue: 0.95).opacity(0.28) : .clear,
                radius: 10,
                y: 3
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("audioPlayer.track.\(id)")
        .accessibilityLabel(title)
        .accessibilityHint(playing ? "Pauses audio" : "Plays \(title)")
    }

    // MARK: - Artwork Section

    private var artworkSection: some View {
        Image("SleepPlayerArtwork", bundle: .main)
            .resizable()
            .aspectRatio(805.0 / 638.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.45), radius: 18, y: 8)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Moonlit ocean nightscape artwork")
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
                            .fill(Color(red: 0.16, green: 0.15, blue: 0.30))
                            .frame(height: 5)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.45, green: 0.55, blue: 0.95),
                                        Color(red: 0.65, green: 0.50, blue: 0.95),
                                    ],
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

                    Text(formatTime(duration))
                        .font(AppFont.inter(size: 13, relativeTo: .caption, weight: .medium))
                        .foregroundStyle(HomeScreenPalette.textSecondary)
                }
            }
        }
        .accessibilityIdentifier("audioPlayer.scrubber")
    }

    // MARK: - Playback Controls

    private var mainPlaybackControls: some View {
        HStack(spacing: 34) {
            Button {
                AppHaptics.stepAdjustment(
                    direction: .decrease,
                    hapticsEnabled: model.settings?.hapticsEnabled != false
                )
                model.skipPlayback(by: -15)
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.13, green: 0.13, blue: 0.30).opacity(0.75))
                        .frame(width: 58, height: 58)
                        .overlay {
                            Circle().stroke(Color.white.opacity(0.12), lineWidth: 1)
                        }

                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Rewind 15 seconds")
            .accessibilityIdentifier("audioPlayer.rewind")

            Button {
                AppHaptics.playbackToggle(hapticsEnabled: model.settings?.hapticsEnabled != false)
                model.togglePlayback()
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.58, green: 0.52, blue: 0.85),
                                    Color(red: 0.38, green: 0.50, blue: 0.80),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 78, height: 78)
                        .shadow(color: Color(red: 0.48, green: 0.45, blue: 0.85).opacity(0.55), radius: 18, y: 4)

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
                AppHaptics.stepAdjustment(
                    direction: .increase,
                    hapticsEnabled: model.settings?.hapticsEnabled != false
                )
                model.skipPlayback(by: 15)
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.13, green: 0.13, blue: 0.30).opacity(0.75))
                        .frame(width: 58, height: 58)
                        .overlay {
                            Circle().stroke(Color.white.opacity(0.12), lineWidth: 1)
                        }

                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fast forward 15 seconds")
            .accessibilityIdentifier("audioPlayer.fastForward")
        }
    }

    // MARK: - Bottom Utilities

    private var bottomUtilities: some View {
        HStack(spacing: 16) {
            Button {
                AppHaptics.secondaryCTA(hapticsEnabled: model.settings?.hapticsEnabled != false)
                showSleepTimerPicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "timer")
                        .font(.system(size: 15, weight: .medium))
                    if let remaining = model.sleepTimerRemaining {
                        Text(formatTimer(remaining))
                            .font(AppFont.inter(size: 14, relativeTo: .footnote, weight: .semibold))
                    } else {
                        Text("Fade Timer")
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
                .background(HomeScreenPalette.cardSecondary.opacity(0.85))
                .clipShape(Capsule())
                .overlay {
                    Capsule().stroke(HomeScreenPalette.cardBorder, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Set sleep timer")
            .accessibilityIdentifier("audioPlayer.sleepTimer")

            Button {
                AppHaptics.secondaryCTA(hapticsEnabled: model.settings?.hapticsEnabled != false)
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
                .background(HomeScreenPalette.cardSecondary.opacity(0.85))
                .clipShape(Capsule())
                .overlay {
                    Capsule().stroke(HomeScreenPalette.cardBorder, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Grounding support")
            .accessibilityIdentifier("audioPlayer.groundingTips")
        }
    }

    // MARK: - Sheets

    private var sleepTimerSheet: some View {
        ZStack {
            HomeScreenPalette.backgroundTop.ignoresSafeArea()

            VStack(spacing: 18) {
                Text("Sleep Fade-Away Timer")
                    .font(AppFont.latoBold(size: 20, relativeTo: .headline))
                    .foregroundStyle(.white)
                    .padding(.top, 16)

                Text("Audio will gently fade out and stop after the selected duration.")
                    .font(AppFont.inter(size: 14, relativeTo: .footnote))
                    .foregroundStyle(HomeScreenPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        timerButton(minutes: 15, label: "15m")
                        timerButton(minutes: 30, label: "30m")
                        timerButton(minutes: 45, label: "45m")
                        timerButton(minutes: 60, label: "60m")
                    }

                    Button {
                        AppHaptics.selectionChanged(hapticsEnabled: model.settings?.hapticsEnabled != false)
                        model.setSleepTimerToEndOfTrack()
                        showSleepTimerPicker = false
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "forward.end.fill")
                                .font(.system(size: 13, weight: .medium))
                            Text("End of track")
                                .font(AppFont.inter(size: 15, relativeTo: .body, weight: .semibold))
                        }
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
                    .accessibilityIdentifier("audioPlayer.timer.endOfTrack")
                }
                .padding(.horizontal, 20)

                if model.sleepTimerRemaining != nil {
                    Button("Turn Off Timer") {
                        AppHaptics.secondaryCTA(hapticsEnabled: model.settings?.hapticsEnabled != false)
                        model.cancelSleepTimer()
                        showSleepTimerPicker = false
                    }
                    .font(AppFont.inter(size: 14, relativeTo: .footnote, weight: .semibold))
                    .foregroundStyle(Color.red.opacity(0.85))
                    .padding(.top, 4)
                }
            }
            .padding(.bottom, 16)
        }
    }

    private func timerButton(minutes: Int, label: String) -> some View {
        Button {
            AppHaptics.selectionChanged(hapticsEnabled: model.settings?.hapticsEnabled != false)
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
        .accessibilityIdentifier("audioPlayer.timer.\(minutes)m")
    }

    private var groundingTipsSheet: some View {
        ZStack {
            HomeScreenPalette.backgroundTop.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Grounding Support")
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

                Button {
                    AppHaptics.primaryCTA(hapticsEnabled: model.settings?.hapticsEnabled != false)
                    showGroundingTips = false
                    model.open(.grounding)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                        Text("Start Grounding Audio")
                    }
                    .font(AppFont.inter(size: 16, relativeTo: .headline, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(HomeScreenPalette.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("audioPlayer.startGroundingFromTips")

                Text("When feeling fear or disorientation, use the 5-4-3-2-1 technique:")
                    .font(AppFont.inter(size: 15, relativeTo: .body))
                    .foregroundStyle(HomeScreenPalette.textSecondary)

                VStack(alignment: .leading, spacing: 10) {
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

    private func isCurrentTrack(id: String) -> Bool {
        if let selected = model.selectedCatalogAsset {
            return selected.id == id
        }
        if case let .playing(currentID) = model.playbackState {
            return currentID == id
        }
        if case let .paused(currentID) = model.playbackState {
            return currentID == id
        }
        return id == "quick-unwind"
    }

    private func isTrackPlaying(id: String) -> Bool {
        if isCurrentTrack(id: id) {
            switch model.playbackState {
            case .playing:
                return true
            default:
                return false
            }
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
