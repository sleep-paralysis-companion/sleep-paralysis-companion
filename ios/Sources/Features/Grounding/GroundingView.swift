import SwiftUI

struct GroundingView: View {
    @Bindable var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NightScreen {
            VStack(spacing: AppSpacing.spacious) {
                Text("You’re awake. You’re here.")
                    .font(AppTypographyRole.hero)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(
                    "Take the next moment at your own pace. This is a manual wellness tool, not an emergency response."
                )
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)

                ZStack {
                    Circle()
                        .stroke(Color.cyan.opacity(0.25), lineWidth: 18)
                        .frame(width: 210, height: 210)
                    Circle()
                        .fill(Color.indigo.opacity(0.42))
                        .frame(width: reduceMotion ? 138 : 154, height: reduceMotion ? 138 : 154)
                    VStack {
                        Text("Breathe slowly")
                            .font(.title2.bold())
                        Text("Notice five things you can see")
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.68))
                    }
                    .multilineTextAlignment(.center)
                    .padding(40)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Visual grounding")
                .accessibilityValue("Breathe slowly. Notice five things you can see.")

                NightCard {
                    Label(playbackTitle, systemImage: playbackIcon)
                        .font(.headline)
                    Text(playbackDetail)
                        .foregroundStyle(.white.opacity(0.68))
                    HStack {
                        if case .playing = model.playbackState {
                            Button("Pause", systemImage: "pause.fill") { model.togglePlayback() }
                                .buttonStyle(.borderedProminent)
                        } else if case .paused = model.playbackState {
                            Button("Resume", systemImage: "play.fill") { model.togglePlayback() }
                                .buttonStyle(.borderedProminent)
                        }
                        Button("Stop", systemImage: "stop.fill") { model.stopPlayback() }
                            .buttonStyle(.bordered)
                            .disabled(model.playbackState == .idle)
                    }
                    .padding(.top, 6)
                }

                Button("Optional check-in", systemImage: "square.and.pencil") {
                    model.open(.morningCheckIn)
                }
                .buttonStyle(AppSecondaryButtonStyle())
                Text(
                    "No episode record is created by opening this screen. " +
                        "A history entry exists only after you explicitly submit a check-in."
                )
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.58))
            }
            .padding(.top, 24)
        }
        .navigationTitle("Grounding")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var playbackTitle: String {
        switch model.playbackState {
        case .playing: "Recovery audio is playing"
        case .paused: "Recovery audio is paused"
        case .visualFallback: "Silent visual grounding"
        case .failed: "Audio unavailable"
        case .idle: "No audio playing"
        }
    }

    private var playbackDetail: String {
        switch model.playbackState {
        case .visualFallback:
            "The selected audio is unavailable, so the visual grounding remains ready."
        case .failed:
            "Choose another local clip or continue silently."
        case .playing, .paused:
            "Playback is local and never overlaps another Paralux clip."
        case .idle:
            "Use the manual action again after selecting an available personal clip."
        }
    }

    private var playbackIcon: String {
        switch model.playbackState {
        case .playing: "speaker.wave.2.fill"
        case .paused: "pause.circle.fill"
        case .visualFallback: "eye.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .idle: "speaker.slash"
        }
    }
}
