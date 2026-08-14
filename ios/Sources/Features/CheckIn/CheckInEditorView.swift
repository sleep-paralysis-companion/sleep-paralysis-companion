import SwiftUI

struct CheckInEditorView: View {
    @Bindable var model: AppModel
    let editing: SubmittedCheckIn

    @Environment(\.dismiss) private var dismiss
    @State private var form: MorningCheckInForm
    @State private var isSaving = false

    init(model: AppModel, editing: SubmittedCheckIn) {
        self.model = model
        self.editing = editing
        _form = State(
            initialValue: MorningCheckInForm(
                occurrence: editing.occurrence,
                presentState: editing.presentState,
                spcOutcome: editing.spcOutcome,
                postEpisodeSupport: editing.postEpisodeSupport,
                sleepHelpOutcome: editing.sleepHelpOutcome
            )
        )
    }

    var body: some View {
        Form {
            Section {
                Picker("Did you have an episode last night?", selection: $form.occurrence) {
                    Text("Choose").tag(EpisodeOccurrence?.none)
                    Text("Yes").tag(EpisodeOccurrence?.some(.yes))
                    Text("No").tag(EpisodeOccurrence?.some(.no))
                }
                .pickerStyle(.segmented)
            }
            if form.occurrence == .yes {
                episodeSections
            }
            if form.occurrence == .no {
                Section("Did SPC help you fall asleep?") {
                    Picker("Sleep help", selection: $form.sleepHelpOutcome) {
                        Text("Choose").tag(SleepHelpOutcome?.none)
                        Text("Audio helped").tag(SleepHelpOutcome?.some(.audioHelped))
                        Text("Didn't use it").tag(SleepHelpOutcome?.some(.didNotUseIt))
                        Text("Forget it was there").tag(SleepHelpOutcome?.some(.forgotItWasThere))
                    }
                }
            }
            Section {
                Button("Save changes") {
                    isSaving = true
                    Task {
                        if await model.submitCheckIn(form, editing: editing) {
                            dismiss()
                        }
                        isSaving = false
                    }
                }
                .disabled(!form.canSubmit || isSaving)
            }
        }
        .navigationTitle("Edit check-in")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var episodeSections: some View {
        Group {
            Section("How are you feeling now?") {
                Picker("Current feeling", selection: $form.presentState) {
                    Text("Choose").tag(PresentState?.none)
                    Text("I'm fine now").tag(PresentState?.some(.fineNow))
                    Text("Still a bit shaken").tag(PresentState?.some(.stillShaken))
                    Text("Exhausted").tag(PresentState?.some(.exhausted))
                }
            }
            Section("How did you feel after using guided sleep meditation?") {
                Picker("After SPC", selection: $form.spcOutcome) {
                    Text("Choose").tag(SPCOutcome?.none)
                    Text("Calmer").tag(SPCOutcome?.some(.calmer))
                    Text("No difference").tag(SPCOutcome?.some(.noDifference))
                }
            }
            Section("What did you use after the episode?") {
                Picker("Support used", selection: $form.postEpisodeSupport) {
                    Text("Choose").tag(PostEpisodeSupport?.none)
                    Text("Partner Call").tag(PostEpisodeSupport?.some(.partnerCall))
                    Text("Calming Audio").tag(PostEpisodeSupport?.some(.calmingAudio))
                    Text("Partner Audio").tag(PostEpisodeSupport?.some(.partnerAudio))
                }
            }
        }
    }
}
