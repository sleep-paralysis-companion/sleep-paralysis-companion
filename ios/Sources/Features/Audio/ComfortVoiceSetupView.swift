import SwiftUI
import UniformTypeIdentifiers

struct PersonalAudioSetupView: View {
    @Bindable var model: AppModel
    var isOnboarding = false

    @State private var isImporting = false
    @State private var clipToDelete: PersonalAudioClipMetadata?
    @State private var recordingStartedAt: Date?

    var body: some View {
        ZStack {
            ComfortVoiceBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    heading
                    microphoneStage

                    if model.isRecording || latestClip != nil {
                        suggestedScript.padding(.top, 30)
                    }

                    if let latestClip {
                        voiceRecordingCard(latestClip).padding(.top, 34)
                        saveAndContinueButton(latestClip).padding(.top, 32)
                    }
                }
                .frame(maxWidth: 430, alignment: .leading)
                .padding(.horizontal, 26)
                .padding(.bottom, 36)
            }

            if isOnboarding {
                Button("Skip") {
                    model.continueFromAudioSetup()
                }
                .font(.callout.weight(.semibold))
                .foregroundStyle(ComfortVoiceStyle.secondaryText)
                .padding(.top, 28)
                .padding(.trailing, 26)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .accessibilityIdentifier("comfortVoice.skip")
            }
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
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
            }
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("YOUR CALMING VOICE", systemImage: "sparkles")
                .font(.callout.weight(.medium))
                .foregroundStyle(ComfortVoiceStyle.kicker)
                .labelStyle(.titleAndIcon)
                .accessibilityHidden(true)

            Text("Record a loved\none’s voice")
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .tracking(-0.8)
                .lineSpacing(1)
                .padding(.top, 20)
                .accessibilityAddTraits(.isHeader)

            Text("This voice will play automatically during an\nepisode to calm and guide you back.")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .lineSpacing(4)
                .foregroundStyle(ComfortVoiceStyle.secondaryText)
                .padding(.top, 25)
        }
        .padding(.top, 16)
    }

    private var microphoneStage: some View {
        VStack(spacing: 0) {
            Button(action: toggleRecording) {
                ZStack {
                    Circle()
                        .stroke(ComfortVoiceStyle.ringOuter, lineWidth: 2)
                        .frame(width: 180, height: 180)
                    Circle()
                        .stroke(ComfortVoiceStyle.ringInner, lineWidth: 3)
                        .frame(width: 158, height: 158)
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [ComfortVoiceStyle.micStart, ComfortVoiceStyle.micEnd],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 140, height: 140)
                        .shadow(color: ComfortVoiceStyle.micEnd.opacity(0.3), radius: 30)
                    Image(systemName: model.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: model.isRecording ? 34 : 51, weight: .medium))
                        .foregroundStyle(.white)
                }
                .frame(width: 192, height: 192)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.isRecording ? "Stop recording" : "Start recording")
            .accessibilityHint(model.isRecording ? "Saves this recording" : "Starts a private voice recording")
            .accessibilityIdentifier("comfortVoice.record")

            recordingLabel.padding(.top, 20)

            if !model.isRecording, latestClip == nil {
                Button {
                    isImporting = true
                } label: {
                    Label("Upload Recording", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(ComfortVoiceStyle.uploadText)
                        .padding(.horizontal, 19)
                        .frame(height: 40)
                        .background(ComfortVoiceStyle.uploadFill)
                        .clipShape(Capsule())
                        .overlay {
                            Capsule().stroke(ComfortVoiceStyle.uploadStroke, lineWidth: 1.4)
                        }
                }
                .buttonStyle(.plain)
                .padding(.top, 14)
                .accessibilityIdentifier("comfortVoice.upload")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 14)
    }

    private var recordingLabel: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(model.isRecording ? "Recording · \(recordingDuration(at: context.date))" : microphoneStatus)
                .font(.system(size: 17, weight: .regular, design: .rounded))
                .foregroundStyle(ComfortVoiceStyle.secondaryText)
                .monospacedDigit()
        }
    }

    private var suggestedScript: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("SUGGESTED SCRIPT", systemImage: "circle.fill")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(ComfortVoiceStyle.scriptLabel)
                .symbolRenderingMode(.hierarchical)
                .padding(.leading, 4)

            Text(
                "\"You're safe. You're dreaming. Take a slow\n" +
                    "breath and let go — I'm right here, and\n" +
                    "you're going to be okay.\""
            )
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .lineSpacing(5)
                .foregroundStyle(ComfortVoiceStyle.scriptText)
                .padding(.top, 27)

            Label("Say it calmly and slowly · Ideal length 20–40 seconds", systemImage: "info.circle")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(ComfortVoiceStyle.secondaryText)
                .padding(.top, 22)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ComfortVoiceStyle.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 27))
        .overlay {
            RoundedRectangle(cornerRadius: 27)
                .stroke(ComfortVoiceStyle.cardStroke, lineWidth: 1.2)
        }
    }

    private func voiceRecordingCard(_ clip: PersonalAudioClipMetadata) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                Button(action: { togglePlayback(clip) }) {
                    Image(systemName: isPlaying(clip) ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 54, height: 54)
                        .background(ComfortVoiceStyle.playFill)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPlaying(clip) ? "Pause voice recording" : "Play voice recording")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Voice recording")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                    Text("\(clipDuration(clip)) · Ready to save")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(ComfortVoiceStyle.secondaryText)
                }
                Spacer(minLength: 0)

                Button(role: .destructive) {
                    clipToDelete = clip
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 17, weight: .medium))
                        .frame(width: 46, height: 46)
                        .foregroundStyle(ComfortVoiceStyle.destructive)
                        .background(ComfortVoiceStyle.destructive.opacity(0.08))
                        .clipShape(Circle())
                        .overlay { Circle().stroke(ComfortVoiceStyle.destructive.opacity(0.7), lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete voice recording")
            }

            AnimatedWaveform(isPlaying: isPlaying(clip))
                .frame(height: 35)
                .padding(.top, 16)
                .accessibilityHidden(true)
        }
        .padding(16)
        .background(ComfortVoiceStyle.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 27))
        .overlay {
            RoundedRectangle(cornerRadius: 27)
                .stroke(ComfortVoiceStyle.cardStroke, lineWidth: 1.2)
        }
    }

    private func saveAndContinueButton(_ clip: PersonalAudioClipMetadata) -> some View {
        Button {
            model.selectPersonalClip(clip)
            if isOnboarding {
                model.continueFromAudioSetup()
            }
        } label: {
            HStack(spacing: 14) {
                Text(isOnboarding ? "Save this voice & continue" : "Use this voice")
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.title3.weight(.regular))
            }
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 25)
            .frame(maxWidth: .infinity, minHeight: 62)
            .background(
                LinearGradient(
                    colors: [ComfortVoiceStyle.buttonStart, ComfortVoiceStyle.buttonEnd],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("comfortVoice.saveAndContinue")
    }

    private var latestClip: PersonalAudioClipMetadata? {
        model.personalClips.max(by: { $0.createdOrImportedAt < $1.createdOrImportedAt })
    }

    private var microphoneStatus: String {
        guard let latestClip else { return "Tap to record" }
        return "Recording · \(clipDuration(latestClip))"
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
        return durationText(milliseconds: Int64(duration * 1_000))
    }

    private func clipDuration(_ clip: PersonalAudioClipMetadata) -> String {
        durationText(milliseconds: clip.durationMilliseconds ?? 0)
    }

    private func durationText(milliseconds: Int64) -> String {
        let seconds = max(0, milliseconds / 1_000)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

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

private struct AnimatedWaveform: View {
    let isPlaying: Bool

    private let heights: [CGFloat] = [
        18, 29, 23, 39, 46, 40, 31, 22, 37, 51, 30, 20, 25, 31, 42, 50, 32, 48, 58, 45,
        35, 29, 40, 32, 19, 27, 36, 40, 34, 31, 54, 43, 36, 19, 24, 31, 44, 52, 36, 22,
        38, 50, 43, 26,
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            HStack(alignment: .center, spacing: 5) {
                ForEach(Array(heights.enumerated()), id: \.offset) { index, baseHeight in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(index < 20 ? ComfortVoiceStyle.scriptLabel : Color.white.opacity(0.2))
                        .frame(width: 4, height: animatedHeight(baseHeight, index: index, at: context.date))
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func animatedHeight(_ base: CGFloat, index: Int, at date: Date) -> CGFloat {
        guard isPlaying else { return base }
        let time = date.timeIntervalSinceReferenceDate
        let multiplier = 0.62 + 0.38 * abs(sin(time * 5 + Double(index) * 0.66))
        return max(8, base * multiplier / 1.7)
    }
}
