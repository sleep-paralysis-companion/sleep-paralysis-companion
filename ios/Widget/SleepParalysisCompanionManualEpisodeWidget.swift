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

    func getTimeline(in context: Context, completion: @escaping (Timeline<SleepParalysisCompanionWidgetEntry>) -> Void) {
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

@main
struct SleepParalysisCompanionWidgetBundle: WidgetBundle {
    var body: some Widget {
        SleepParalysisCompanionManualEpisodeWidget()
    }
}
