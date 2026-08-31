import SwiftUI
import UniformTypeIdentifiers

struct PersonalAudioSetupView: View {
    @Bindable var model: AppModel
    var isOnboarding = false

    @State private var isImporting = false
    @State private var clipToDelete: PersonalAudioClipMetadata?
    @State private var recordingStartedAt: Date?
    @State private var isScriptExpanded = true
    @State private var isSeeking = false
    @State private var seekProgress: Double = 0

    var body: some View {
        ZStack {
            ComfortVoiceBackground()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 6)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        heading

                        microphoneStage
                            .padding(.top, 14)

                        suggestedScript
                            .padding(.top, 24)

                        if let latestClip {
                            voiceRecordingCard(latestClip)
                                .padding(.top, 24)

                            saveAndContinueButton(latestClip)
                                .padding(.top, 24)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 36)
                }
            }
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if latestClip != nil {
                isScriptExpanded = false
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                model.importAudio(from: url)
            }
        }
        .confirmationDialog(
            "Delete this local clip?",
            isPresented: Binding(
                get: { clipToDelete != nil },
                set: {
                    if !$0 {
                        clipToDelete = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete clip", role: .destructive) {
                if let clipToDelete {
                    model.deleteClip(clipToDelete)
                }
                clipToDelete = nil
            }
            Button("Cancel", role: .cancel) { clipToDelete = nil }
        } message: {
            Text("This removes the clip from this device.")
        }
        .onChange(of: model.isRecording) { wasRecording, isRecording in
            if isRecording {
                recordingStartedAt = .now
            } else if wasRecording {
                recordingStartedAt = nil
                if latestClip != nil {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isScriptExpanded = false
                    }
                }
            }
        }
    }

    // MARK: - Top Navigation Bar

    private var topBar: some View {
        HStack {
            if !isOnboarding {
                Button {
                    if !model.path.isEmpty {
                        model.setPath(Array(model.path.dropLast()))
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(ComfortVoiceStyle.cardFill)
                        .clipShape(Circle())
                        .overlay {
                            Circle().stroke(ComfortVoiceStyle.cardStroke, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to Settings")
                .accessibilityIdentifier("comfortVoice.back")
            }

            Spacer()

            if isOnboarding {
                Button("Skip") {
                    model.continueFromAudioSetup()
                }
                .font(AppTypographyRole.control)
                .foregroundStyle(ComfortVoiceStyle.secondaryText)
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
                .accessibilityIdentifier("comfortVoice.skip")
            }
        }
        .frame(height: 44)
    }

    // MARK: - Heading

    private var heading: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("YOUR CALMING VOICE", systemImage: "sparkles")
                .font(.callout.weight(.medium))
                .foregroundStyle(ComfortVoiceStyle.kicker)
                .labelStyle(.titleAndIcon)
                .accessibilityHidden(true)

            Text("Record a loved\none’s voice")
                .font(AppFont.latoSemiBold(size: 28, relativeTo: .title))
                .tracking(-0.6)
                .lineSpacing(1)
                .padding(.top, 14)
                .accessibilityAddTraits(.isHeader)

            Text("This voice will play automatically during an\nepisode to calm and guide you back.")
                .font(AppFont.inter(size: 16, relativeTo: .callout, weight: .normal))
                .lineSpacing(3)
                .foregroundStyle(ComfortVoiceStyle.secondaryText)
                .padding(.top, 10)
        }
        .padding(.top, 4)
    }

    // MARK: - Microphone Stage

    private var microphoneStage: some View {
        VStack(spacing: 0) {
            ZStack {
                if model.isRecording {
                    TimelineView(.animation(minimumInterval: 1 / 20)) { context in
                        let time = context.date.timeIntervalSinceReferenceDate
                        let pulse = 1.0 + 0.08 * sin(time * 4)
                        Circle()
                            .fill(ComfortVoiceStyle.destructive.opacity(0.18))
                            .frame(width: 176 * pulse, height: 176 * pulse)
                    }
                }

                Circle()
                    .stroke(
                        model.isRecording ? ComfortVoiceStyle.destructive.opacity(0.7) : ComfortVoiceStyle.ringOuter,
                        lineWidth: 2
                    )
                    .frame(width: 164, height: 164)

                Circle()
                    .stroke(
                        model.isRecording ? ComfortVoiceStyle.destructive.opacity(0.85) : ComfortVoiceStyle.ringInner,
                        lineWidth: 3
                    )
                    .frame(width: 144, height: 144)

                Button(action: toggleRecording) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: model.isRecording
                                    ? [ComfortVoiceStyle.destructive, ComfortVoiceStyle.destructive.opacity(0.8)]
                                    : [ComfortVoiceStyle.micStart, ComfortVoiceStyle.micEnd],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 126, height: 126)
                        .shadow(
                            color: (model.isRecording ? ComfortVoiceStyle.destructive : ComfortVoiceStyle.micEnd)
                                .opacity(0.4),
                            radius: 24
                        )
                        .overlay {
                            Image(systemName: model.isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: model.isRecording ? 32 : 44, weight: .medium))
                                .foregroundStyle(.white)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(model.isRecording ? "Stop recording" : "Start recording")
                .accessibilityHint(model.isRecording ? "Saves this recording" : "Starts a private voice recording")
                .accessibilityIdentifier("comfortVoice.record")
            }
            .frame(height: 176)

            recordingLabel
                .padding(.top, 16)

            if model.isRecording {
                Button {
                    model.cancelRecording()
                } label: {
                    Label("Cancel Recording", systemImage: "xmark")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(ComfortVoiceStyle.destructive)
                        .padding(.horizontal, 16)
                        .frame(height: 36)
                        .background(ComfortVoiceStyle.destructive.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay {
                            Capsule().stroke(ComfortVoiceStyle.destructive.opacity(0.5), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
            } else {
                Button {
                    isImporting = true
                } label: {
                    Label(
                        latestClip == nil ? "Upload Recording" : "Replace with Audio File",
                        systemImage: "square.and.arrow.up"
                    )
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ComfortVoiceStyle.uploadText)
                    .padding(.horizontal, 18)
                    .frame(height: 38)
                    .background(ComfortVoiceStyle.uploadFill)
                    .clipShape(Capsule())
                    .overlay {
                        Capsule().stroke(ComfortVoiceStyle.uploadStroke, lineWidth: 1.2)
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
                .accessibilityIdentifier("comfortVoice.upload")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var recordingLabel: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            Text(model.isRecording ? "Recording · \(recordingDuration(at: context.date))" : microphoneStatus)
                .font(AppFont.inter(size: 16, relativeTo: .body, weight: .medium))
                .foregroundStyle(model.isRecording ? ComfortVoiceStyle.destructive : ComfortVoiceStyle.secondaryText)
                .monospacedDigit()
        }
    }

    // MARK: - Suggested Script (Collapsible)

    private var suggestedScript: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isScriptExpanded.toggle()
                }
            } label: {
                HStack {
                    Label("SUGGESTED SCRIPT", systemImage: "circle.fill")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(ComfortVoiceStyle.scriptLabel)
                        .symbolRenderingMode(.hierarchical)

                    Spacer()

                    Image(systemName: isScriptExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ComfortVoiceStyle.secondaryText)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isScriptExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    Text(
                        "\"You're safe. You're dreaming. Take a slow breath and let go — "
                            + "I'm right here, and you're going to be okay.\""
                    )
                    .font(AppFont.inter(size: 17, relativeTo: .title3, weight: .medium))
                    .lineSpacing(5)
                    .foregroundStyle(ComfortVoiceStyle.scriptText)
                    .padding(.top, 14)

                    Label("Say it calmly and slowly · Ideal length 20–40 seconds", systemImage: "info.circle")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(ComfortVoiceStyle.secondaryText)
                        .padding(.top, 14)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ComfortVoiceStyle.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(ComfortVoiceStyle.cardStroke, lineWidth: 1.2)
        }
    }

    // MARK: - Voice Recording Card

    private func voiceRecordingCard(_ clip: PersonalAudioClipMetadata) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                Button(
                    action: { togglePlayback(clip) },
                    label: {
                        Image(systemName: isPlaying(clip) ? "pause.fill" : "play.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 50, height: 50)
                            .background(ComfortVoiceStyle.playFill)
                            .clipShape(Circle())
                    }
                )
                .buttonStyle(.plain)
                .accessibilityLabel(isPlaying(clip) ? "Pause voice recording" : "Play voice recording")

                VStack(alignment: .leading, spacing: 4) {
                    Text("Voice recording")
                        .font(AppFont.inter(size: 17, relativeTo: .callout, weight: .semibold))

                    playbackSubtitle(clip)
                        .font(AppFont.inter(size: 13, relativeTo: .footnote))
                        .foregroundStyle(ComfortVoiceStyle.secondaryText)
                        .monospacedDigit()
                }

                Spacer(minLength: 0)

                Button(role: .destructive) {
                    clipToDelete = clip
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 42, height: 42)
                        .foregroundStyle(ComfortVoiceStyle.destructive)
                        .background(ComfortVoiceStyle.destructive.opacity(0.1))
                        .clipShape(Circle())
                        .overlay {
                            Circle().stroke(ComfortVoiceStyle.destructive.opacity(0.6), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete voice recording")
            }

            // Real-time dynamic audio waveform scrubber
            TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                let duration = max(Double(clip.durationMilliseconds ?? 0) / 1000.0, 1.0)
                let current = isSeeking
                    ? (seekProgress * duration)
                    : (isPlaying(clip) ? model.playbackCurrentTime : 0)
                let progress = min(max(current / duration, 0), 1)

                DynamicAudioWaveform(
                    progress: progress,
                    isPlaying: isPlaying(clip),
                    onSeekChanged: { p in
                        isSeeking = true
                        seekProgress = p
                    },
                    onSeekEnded: { p in
                        isSeeking = false
                        let target = p * duration
                        if isPlaying(clip) {
                            model.seekPlayback(to: target)
                        } else {
                            model.play(clip)
                            model.seekPlayback(to: target)
                        }
                    }
                )
                .frame(height: 38)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(ComfortVoiceStyle.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(ComfortVoiceStyle.cardStroke, lineWidth: 1.2)
        }
    }

    private func playbackSubtitle(_ clip: PersonalAudioClipMetadata) -> some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { _ in
            let total = Double(clip.durationMilliseconds ?? 0) / 1000.0
            if isPlaying(clip) {
                let current = isSeeking ? (seekProgress * total) : model.playbackCurrentTime
                Text("\(formatSeconds(current)) / \(formatSeconds(total)) · Playing")
            } else {
                Text("\(clipDuration(clip)) · Ready to use")
            }
        }
    }

    private func saveAndContinueButton(_ clip: PersonalAudioClipMetadata) -> some View {
        Button {
            model.selectPersonalClip(clip)
            if isOnboarding {
                model.continueFromAudioSetup()
            } else if !model.path.isEmpty {
                model.setPath(Array(model.path.dropLast()))
            }
        } label: {
            HStack(spacing: 12) {
                Text(isOnboarding ? "Save this voice & continue" : "Use this voice")
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.headline.weight(.semibold))
            }
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                LinearGradient(
                    colors: [ComfortVoiceStyle.buttonStart, ComfortVoiceStyle.buttonEnd],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("comfortVoice.saveAndContinue")
    }

    private var latestClip: PersonalAudioClipMetadata? {
        model.personalClips.max(by: { $0.createdOrImportedAt < $1.createdOrImportedAt })
    }

    private var microphoneStatus: String {
        if latestClip != nil {
            return "Tap to record again"
        }
        return "Tap to record"
    }

    private func toggleRecording() {
        if model.isRecording {
            model.stopAndSaveRecording()
        } else {
            recordingStartedAt = .now
            model.startRecording()
        }
    }

    private func togglePlayback(_ clip: PersonalAudioClipMetadata) {
        if isPlaying(clip) {
            model.togglePlayback()
        } else {
            model.play(clip)
        }
    }

    private func isPlaying(_ clip: PersonalAudioClipMetadata) -> Bool {
        if case let .playing(identifier) = model.playbackState {
            return identifier == clip.id.uuidString
        }
        return false
    }

    private func recordingDuration(at date: Date) -> String {
        let duration = max(0, date.timeIntervalSince(recordingStartedAt ?? date))
        return durationText(milliseconds: Int64(duration * 1000))
    }

    private func clipDuration(_ clip: PersonalAudioClipMetadata) -> String {
        durationText(milliseconds: clip.durationMilliseconds ?? 0)
    }

    private func durationText(milliseconds: Int64) -> String {
        let seconds = max(0, milliseconds / 1000)
        return formatSeconds(Double(seconds))
    }

    private func formatSeconds(_ seconds: Double) -> String {
        let total = Int(max(0, seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - Dynamic Audio Waveform

private struct DynamicAudioWaveform: View {
    let progress: Double
    let isPlaying: Bool
    let onSeekChanged: (Double) -> Void
    let onSeekEnded: (Double) -> Void

    /// Normalized pattern of relative bar heights (0.15 to 1.0)
    private let normalizedPattern: [CGFloat] = [
        0.30, 0.50, 0.40, 0.68, 0.80, 0.70, 0.54, 0.38, 0.65, 0.90,
        0.52, 0.35, 0.44, 0.54, 0.74, 0.88, 0.56, 0.84, 1.00, 0.78,
        0.61, 0.50, 0.70, 0.56, 0.33, 0.47, 0.63, 0.70, 0.60, 0.54,
        0.95, 0.75, 0.63, 0.33, 0.42, 0.54, 0.77, 0.91, 0.63, 0.38,
        0.66, 0.88, 0.75, 0.45,
    ]

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let barWidth: CGFloat = 3.2
            let barSpacing: CGFloat = 3.2
            let totalPitch = barWidth + barSpacing
            let count = max(16, min(normalizedPattern.count, Int((width + barSpacing) / totalPitch)))
            let activeIndex = Int(progress * Double(count))

            HStack(alignment: .center, spacing: barSpacing) {
                ForEach(0 ..< count, id: \.self) { index in
                    let baseFraction = patternFraction(index: index, count: count)
                    let barHeight = animatedBarHeight(baseFraction: baseFraction, index: index, height: height)
                    let isHighlighted = index <= activeIndex

                    RoundedRectangle(cornerRadius: 1.8)
                        .fill(isHighlighted ? ComfortVoiceStyle.scriptLabel : Color.white.opacity(0.22))
                        .frame(width: barWidth, height: barHeight)
                }
            }
            .frame(width: width, height: height, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let clamped = max(0, min(1, value.location.x / width))
                        onSeekChanged(Double(clamped))
                    }
                    .onEnded { value in
                        let clamped = max(0, min(1, value.location.x / width))
                        onSeekEnded(Double(clamped))
                    }
            )
        }
    }

    private func patternFraction(index: Int, count: Int) -> CGFloat {
        guard count > 0 else { return 0.5 }
        let patternIndex = Int(Double(index) / Double(count) * Double(normalizedPattern.count))
        return normalizedPattern[min(patternIndex, normalizedPattern.count - 1)]
    }

    private func animatedBarHeight(baseFraction: CGFloat, index: Int, height: CGFloat) -> CGFloat {
        let base = max(6, baseFraction * height)
        guard isPlaying else { return base }
        let time = Date().timeIntervalSinceReferenceDate
        let wave = 0.75 + 0.25 * sin(time * 6.0 + Double(index) * 0.5)
        return max(6, base * wave)
    }
}

// MARK: - Styles & Backgrounds

private enum ComfortVoiceStyle {
    static let kicker = Color(red: 0.76, green: 0.36, blue: 1)
    static let secondaryText = Color(red: 0.63, green: 0.59, blue: 0.76)
    static let scriptLabel = Color(red: 0.67, green: 0.61, blue: 0.91)
    static let scriptText = Color(red: 0.72, green: 0.69, blue: 0.82)
    static let micStart = Color(red: 0.68, green: 0.32, blue: 0.83)
    static let micEnd = Color(red: 0.78, green: 0.39, blue: 0.84)
    static let ringOuter = Color(red: 0.26, green: 0.18, blue: 0.53).opacity(0.82)
    static let ringInner = Color(red: 0.31, green: 0.20, blue: 0.62).opacity(0.82)
    static let cardFill = Color(red: 0.045, green: 0.025, blue: 0.15).opacity(0.82)
    static let cardStroke = Color(red: 0.37, green: 0.28, blue: 0.66).opacity(0.78)
    static let playFill = Color(red: 0.34, green: 0.25, blue: 0.79)
    static let destructive = Color(red: 0.98, green: 0.30, blue: 0.47)
    static let uploadFill = Color(red: 0.12, green: 0.08, blue: 0.28).opacity(0.9)
    static let uploadStroke = Color(red: 0.39, green: 0.28, blue: 0.75).opacity(0.9)
    static let uploadText = Color(red: 0.77, green: 0.70, blue: 1)
    static let buttonStart = Color(red: 0.34, green: 0.25, blue: 0.78)
    static let buttonEnd = Color(red: 0.21, green: 0.49, blue: 0.83)
}

private struct ComfortVoiceBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.025, green: 0.015, blue: 0.11),
                        Color(red: 0.055, green: 0.025, blue: 0.18),
                        Color(red: 0.015, green: 0.01, blue: 0.08),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                RadialGradient(
                    colors: [Color(red: 0.23, green: 0.15, blue: 0.49).opacity(0.6), .clear],
                    center: .topTrailing,
                    startRadius: 20,
                    endRadius: proxy.size.width * 1.1
                )
                ComfortVoiceConstellation(size: proxy.size)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private struct ComfortVoiceConstellation: View {
    let size: CGSize

    // Decorative star data is most readable as fixed x/y/size/color tuples.
    // swiftlint:disable:next large_tuple
    private let stars: [(CGFloat, CGFloat, CGFloat, Color)] = [
        (0.19, 0.03, 4, .purple), (0.71, 0, 4, .purple), (0.94, 0.04, 4, .purple),
        (0.30, 0.10, 4, .purple), (0.74, 0.12, 3, .cyan), (0.88, 0.18, 3, .cyan),
        (0.15, 0.18, 4, .white), (0.39, 0.22, 4, .purple), (0.58, 0.24, 5, .white),
        (0.92, 0.29, 3, .cyan), (0.12, 0.39, 2, .cyan), (0.20, 0.43, 4, .white),
        (0.73, 0.46, 3, .cyan), (0.87, 0.49, 4, .white), (0.27, 0.55, 5, .white),
        (0.07, 0.67, 2, .cyan), (0.44, 0.70, 3, .cyan), (0.62, 0.70, 5, .white),
        (0.88, 0.79, 4, .purple), (0.31, 0.90, 4, .purple),
    ]

    var body: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: size.width * 0.12, y: size.height * 0.29))
                path.addLine(to: CGPoint(x: size.width * 0.61, y: size.height * 0.25))
                path.addLine(to: CGPoint(x: size.width * 0.72, y: size.height * 0.36))
                path.addLine(to: CGPoint(x: size.width * 0.93, y: size.height * 0.32))
                path.addLine(to: CGPoint(x: size.width * 0.91, y: size.height * 0.22))
            }
            .stroke(Color(red: 0.12, green: 0.35, blue: 0.62).opacity(0.55), lineWidth: 1)

            ForEach(Array(stars.enumerated()), id: \.offset) { _, star in
                Circle()
                    .fill(star.3.opacity(0.65))
                    .frame(width: star.2, height: star.2)
                    .position(x: star.0 * size.width, y: star.1 * size.height)
            }
        }
    }
}
