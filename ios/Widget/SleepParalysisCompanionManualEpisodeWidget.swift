import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct SleepParalysisCompanionWidgetEntry: TimelineEntry {
    let date: Date
}

struct SleepParalysisCompanionWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> SleepParalysisCompanionWidgetEntry {
        _ = context
        return SleepParalysisCompanionWidgetEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SleepParalysisCompanionWidgetEntry) -> Void) {
        _ = context
        completion(SleepParalysisCompanionWidgetEntry(date: Date()))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<SleepParalysisCompanionWidgetEntry>) -> Void
    ) {
        _ = context
        completion(Timeline(entries: [SleepParalysisCompanionWidgetEntry(date: Date())], policy: .never))
    }
}

struct SleepParalysisCompanionManualEpisodeWidgetView: View {
    let entry: SleepParalysisCompanionWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "moon.stars.fill")
                .font(.title)
                .foregroundStyle(.cyan)
            Text("Sleep Paralysis Companion")
                .font(.headline)
            Button(intent: ManualEpisodeIntent()) {
                Label("I just had an episode", systemImage: "arrow.right.circle.fill")
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.leading)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            Text("Opens manual grounding")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color(red: 0.035, green: 0.02, blue: 0.16),
                    Color(red: 0.09, green: 0.035, blue: 0.24),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .accessibilityElement(children: .contain)
    }
}

struct SleepParalysisCompanionManualEpisodeWidget: Widget {
    // Stable WidgetKit kind retained so existing widget placements continue to resolve.
    let kind = "ParaluxManualEpisodeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SleepParalysisCompanionWidgetProvider()) { entry in
            SleepParalysisCompanionManualEpisodeWidgetView(entry: entry)
        }
        .configurationDisplayName("Manual grounding")
        .description("Open the user-initiated Sleep Paralysis Companion grounding experience.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct SleepSessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SleepSessionAttributes.self) { context in
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "moon.stars.fill")
                        .foregroundStyle(Color(red: 0.52, green: 0.67, blue: 1))
                    Text("Sleep session active")
                        .font(.headline)
                    Spacer()
                    if context.state.audioStatus != .ready {
                        Label(context.state.audioStatus.statusLabel, systemImage: context.state.audioStatus.statusIcon)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(red: 0.52, green: 0.67, blue: 1))
                            .labelStyle(.iconOnly)
                            .accessibilityLabel(context.state.audioStatus.statusLabel)
                    }
                }

                Button(intent: ManualEpisodeIntent(action: context.state.audioStatus.action)) {
                    Label(context.state.audioStatus.buttonTitle, systemImage: context.state.audioStatus.buttonIcon)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.32, green: 0.41, blue: 0.78))
                .accessibilityHint(context.state.audioStatus.foregroundActionHint)
            }
            .padding(.vertical, 4)
            .activityBackgroundTint(Color(red: 0.05, green: 0.02, blue: 0.19))
            .activitySystemActionForegroundColor(.white)
            .widgetURL(URL(string: "spc://sleep-session"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Sleep mode", systemImage: "moon.stars.fill")
                        .font(.headline)
                        .foregroundStyle(Color(red: 0.52, green: 0.67, blue: 1))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: context.state.audioStatus.statusIcon)
                        .foregroundStyle(Color(red: 0.52, green: 0.67, blue: 1))
                        .accessibilityLabel(context.state.audioStatus.statusLabel)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Button(intent: SleepSessionPlaybackIntent(action: context.state.audioStatus.action)) {
                        Label(context.state.audioStatus.buttonTitle, systemImage: context.state.audioStatus.buttonIcon)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.32, green: 0.41, blue: 0.78))
                }
            } compactLeading: {
                Image(systemName: "moon.stars.fill")
                    .foregroundStyle(Color(red: 0.52, green: 0.67, blue: 1))
                    .accessibilityLabel("Sleep session active")
            } compactTrailing: {
                Image(systemName: context.state.audioStatus.compactIcon)
                    .foregroundStyle(Color(red: 0.52, green: 0.67, blue: 1))
                    .accessibilityLabel(context.state.audioStatus.statusLabel)
            } minimal: {
                Image(systemName: "moon.stars.fill")
                    .foregroundStyle(Color(red: 0.52, green: 0.67, blue: 1))
                    .accessibilityLabel("Sleep session active")
            }
            .keylineTint(Color(red: 0.32, green: 0.41, blue: 0.78))
            .widgetURL(URL(string: "spc://sleep-session"))
        }
    }
}

private extension SleepSessionAudioStatus {
    var action: SleepSessionAudioAction {
        switch self {
        case .ready: .startOrResume
        case .playing: .pause
        case .paused: .resume
        }
    }

    var buttonTitle: String {
        switch self {
        case .ready: "I just had an episode"
        case .playing: "Pause grounding audio"
        case .paused: "Resume grounding audio"
        }
    }

    var buttonIcon: String {
        switch self {
        case .ready: "sparkles"
        case .playing: "pause.fill"
        case .paused: "play.fill"
        }
    }

    var compactIcon: String {
        switch self {
        case .ready: "sparkles"
        case .playing: "waveform"
        case .paused: "pause.fill"
        }
    }

    var statusIcon: String {
        switch self {
        case .ready: "bed.double.fill"
        case .playing: "waveform"
        case .paused: "pause.fill"
        }
    }

    var statusLabel: String {
        switch self {
        case .ready: "Grounding audio ready"
        case .playing: "Grounding audio is playing"
        case .paused: "Grounding audio is paused"
        }
    }

    var foregroundActionHint: String {
        switch self {
        case .ready: "Authenticates if needed, starts grounding audio, and opens the active session."
        case .playing: "Authenticates if needed, pauses grounding audio, and opens the active session."
        case .paused: "Authenticates if needed, resumes grounding audio, and opens the active session."
        }
    }
}

@main
struct SleepParalysisCompanionWidgetBundle: WidgetBundle {
    var body: some Widget {
        SleepParalysisCompanionManualEpisodeWidget()
        SleepSessionLiveActivity()
    }
}
