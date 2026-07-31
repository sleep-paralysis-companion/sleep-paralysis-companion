import SwiftUI

struct EditQuestionnaireView: View {
    @Bindable var model: AppModel
    @State private var frequency: EpisodeFrequency
    @State private var feeling: PostEpisodeFeeling
    @State private var context: CalmingPersonContext

    init(model: AppModel) {
        self.model = model
        _frequency = State(initialValue: model.persona?.episodeFrequency ?? .rarely)
        _feeling = State(initialValue: model.persona?.postEpisodeFeeling ?? .shakeItOff)
        _context = State(initialValue: model.persona?.calmingPersonContext ?? .alone)
    }

    var body: some View {
        Form {
            Section("How often do you experience Sleep Paralysis?") {
                Picker("Frequency", selection: $frequency) {
                    Text("Rarely – a few times a year").tag(EpisodeFrequency.rarely)
                    Text("Monthly – a few times a month").tag(EpisodeFrequency.monthly)
                    Text("Weekly").tag(EpisodeFrequency.weekly)
                    Text("Almost Nightly").tag(EpisodeFrequency.almostNightly)
                }
            }
            Section("How do you feel after the episode?") {
                Picker("Feeling", selection: $feeling) {
                    Text("I shake it off and go back to sleep").tag(PostEpisodeFeeling.shakeItOff)
                    Text("I lie awake scared for a while").tag(PostEpisodeFeeling.awakeScared)
                    Text("I’m too frightened to close my eyes again").tag(PostEpisodeFeeling.tooFrightenedToCloseEyes)
                }
            }
            Section("Do you have someone whose voice calms you down?") {
                Picker("Context", selection: $context) {
                    Text("Yes – They sleep beside me").tag(CalmingPersonContext.besideMe)
                    Text("Yes – But they are not always with me").tag(CalmingPersonContext.notAlwaysPresent)
                    Text("No – I go through this alone").tag(CalmingPersonContext.alone)
                }
            }
            Section {
                Button("Save and update recommended setup") {
                    model.updateQuestionnaire(
                        frequency: frequency,
                        feeling: feeling,
                        context: context
                    )
                }
            } footer: {
                Text("All three answers and the internally derived setup update in one local transaction. No profile identifier, diagnosis, score, or risk result is shown.")
            }
        }
        .navigationTitle("Questionnaire answers")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AccessibilitySettingsView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        List {
            Section("Current system settings") {
                LabeledContent("Text size", value: dynamicTypeSize.isAccessibilitySize ? "Accessibility size" : "Standard size")
                LabeledContent("Reduce Motion", value: reduceMotion ? "On" : "Off")
                LabeledContent("Reduce Transparency", value: reduceTransparency ? "On" : "Off")
            }
            Section {
                Text("Paralux follows iOS Dynamic Type, VoiceOver labels, Reduce Motion, contrast, and safe-area behavior. Change these settings in the iOS Settings app.")
            }
        }
        .navigationTitle("Accessibility")
        .navigationBarTitleDisplayMode(.inline)
    }
}
