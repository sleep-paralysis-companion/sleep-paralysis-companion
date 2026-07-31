import AppIntents
import SwiftUI
import WidgetKit

struct ParaluxWidgetEntry: TimelineEntry {
    let date: Date
}

struct ParaluxWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ParaluxWidgetEntry {
        _ = context
        return ParaluxWidgetEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (ParaluxWidgetEntry) -> Void) {
        _ = context
        completion(ParaluxWidgetEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ParaluxWidgetEntry>) -> Void) {
        _ = context
        completion(Timeline(entries: [ParaluxWidgetEntry(date: Date())], policy: .never))
    }
}

struct ParaluxManualEpisodeWidgetView: View {
    let entry: ParaluxWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "moon.stars.fill")
                .font(.title)
                .foregroundStyle(.cyan)
            Text("Paralux")
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

struct ParaluxManualEpisodeWidget: Widget {
    let kind = "ParaluxManualEpisodeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ParaluxWidgetProvider()) { entry in
            ParaluxManualEpisodeWidgetView(entry: entry)
        }
        .configurationDisplayName("Manual grounding")
        .description("Open the user-initiated Paralux grounding experience.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct ParaluxWidgetBundle: WidgetBundle {
    var body: some Widget {
        ParaluxManualEpisodeWidget()
    }
}
