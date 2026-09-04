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
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        trackListSection
                            .padding(.horizontal, 20)
                            .padding(.top, 6)
                    }
                    .padding(.bottom, 24)
                }
                .frame(maxHeight: .infinity)

                VStack(spacing: 0) {
                    trackMetadata
                        .padding(.horizontal, 24)
                        .padding(.top, 12)

                    scrubberSection
                        .padding(.horizontal, 24)
                        .padding(.top, 14)

                    mainPlaybackControls
                        .padding(.top, 16)

                    bottomUtilities
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 24)
                }
                .background {
                    LinearGradient(
                        colors: [
                            HomeScreenPalette.backgroundBottom.opacity(0.0),
                            HomeScreenPalette.backgroundBottom.opacity(0.92),
                            HomeScreenPalette.backgroundBottom,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea(edges: .bottom)
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
                colors: [HomeScreenPalette.backgroundTop, HomeScreenPalette.backgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(HomeScreenPalette.accent.opacity(0.14))
                .frame(width: 320, height: 320)
                .blur(radius: 80)
                .offset(y: -120)

            Circle()
                .fill(HomeScreenPalette.iconTint.opacity(0.10))
                .frame(width: 260, height: 260)
                .blur(radius: 70)
                .offset(x: 100, y: 140)
        }
    }

    // MARK: - Navigation Bar

    private var topNavigationBar: some View {
        HStack {
            Button {
                if !model.path.isEmpty {
                    model.setPath(Array(model.path.dropLast()))
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

            VStack(spacing: 2) {
                Text("Sleep Player")
                    .font(AppFont.inter(size: 17, relativeTo: .headline, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Bedtime Routine")
                    .font(AppFont.inter(size: 12, relativeTo: .caption2, weight: .medium))
                    .foregroundStyle(HomeScreenPalette.textSecondary)
            }

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

    // MARK: - Track List Section

    private var trackListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Bedtime Unwind Tracks")
                    .font(AppFont.inter(size: 14, relativeTo: .subheadline, weight: .semibold))
                    .foregroundStyle(HomeScreenPalette.textSecondary)
                Spacer()
                Text("\(model.sleepPlayerTracks.count) tracks")
                    .font(AppFont.inter(size: 12, relativeTo: .caption))
                    .foregroundStyle(HomeScreenPalette.textSecondary.opacity(0.7))
            }
            .padding(.horizontal, 4)

            ForEach(model.sleepPlayerTracks) { asset in
                trackRow(for: asset)
            }
        }
        .accessibilityIdentifier("audioPlayer.trackList")
    }

    private func trackRow(for asset: CatalogAudioAsset) -> some View {
        let active = isCurrentTrack(asset)
        let playing = isTrackPlaying(asset)
        let duration = model.sleepTrackDurationText(for: asset)
        let isDownloaded = model.isSleepTrackDownloaded(asset)

        return Button {
            if active {
                model.togglePlayback()
            } else {
                model.playCatalogAsset(asset)
            }
        } label: {
            HStack(spacing: 14) {
                // Play / Pause status indicator
                ZStack {
                    Circle()
                        .fill(
                            active
                                ? HomeScreenPalette.accent.opacity(0.35)
                                : HomeScreenPalette.cardSecondary
                        )
                        .frame(width: 44, height: 44)
                        .overlay {
                            Circle().stroke(
                                active ? HomeScreenPalette.accent : HomeScreenPalette.cardBorder,
                                lineWidth: 1
                            )
                        }

                    Image(systemName: playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(active ? .white : HomeScreenPalette.iconTint)
                        .offset(x: playing ? 0 : 1)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(asset.title)
                        .font(AppFont.inter(size: 16, relativeTo: .headline, weight: .semibold))
                        .foregroundStyle(.white)

                    HStack(spacing: 6) {
                        Text(duration)
                            .font(AppFont.inter(size: 13, relativeTo: .subheadline, weight: .medium))
                            .foregroundStyle(HomeScreenPalette.textSecondary)

                        Text("•")
                            .font(.system(size: 10))
                            .foregroundStyle(HomeScreenPalette.textSecondary.opacity(0.6))

                        Text(asset.shortDescription)
                            .font(AppFont.inter(size: 13, relativeTo: .footnote))
                            .foregroundStyle(HomeScreenPalette.textSecondary.opacity(0.85))
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Dedicated Download / Offline status button
                downloadOrOfflineButton(for: asset, isDownloaded: isDownloaded)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                LinearGradient(
                    colors: [
                        HomeScreenPalette.card,
                        HomeScreenPalette.cardSecondary.opacity(0.9),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        active ? HomeScreenPalette.accent : HomeScreenPalette.cardBorder.opacity(0.6),
                        lineWidth: active ? 1.5 : 1
                    )
            }
            .shadow(
                color: active ? HomeScreenPalette.accent.opacity(0.25) : Color.clear,
                radius: 10,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(asset.title), \(duration)")
        .accessibilityHint(playing ? "Pauses audio" : "Plays this track")
        .accessibilityIdentifier("audioPlayer.track.\(asset.id)")
    }

    @ViewBuilder
    private func downloadOrOfflineButton(for asset: CatalogAudioAsset, isDownloaded: Bool) -> some View {
        if isDownloaded {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(HomeScreenPalette.iconTint)
            }
            .frame(width: 36, height: 36)
            .accessibilityLabel("Available offline")
            .accessibilityIdentifier("audioPlayer.downloadState.\(asset.id)")
        } else {
            Button {
                Task {
                    _ = try? await model.catalogAudioService.download(asset)
                }
            } label: {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(HomeScreenPalette.textSecondary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Download track")
            .accessibilityIdentifier("audioPlayer.downloadAction.\(asset.id)")
        }
    }

    // MARK: - Track Metadata

    private var trackMetadata: some View {
        VStack(spacing: 4) {
            Text(model.activeTrackTitle)
                .font(AppFont.latoBold(size: 20, relativeTo: .title3))
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Text(model.activeTrackSubtitle)
                .font(AppFont.inter(size: 14, relativeTo: .subheadline))
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

    private func isCurrentTrack(_ asset: CatalogAudioAsset) -> Bool {
        if let selected = model.selectedCatalogAsset {
            return selected.id == asset.id
        }
        if case let .playing(id) = model.playbackState {
            return id == asset.id
        }
        if case let .paused(id) = model.playbackState {
            return id == asset.id
        }
        return false
    }

    private func isTrackPlaying(_ asset: CatalogAudioAsset) -> Bool {
        if isCurrentTrack(asset) {
            switch model.playbackState {
            case .playing, .streaming:
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
