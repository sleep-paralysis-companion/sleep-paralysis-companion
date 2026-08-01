import SwiftUI

struct MorningCheckInView: View {
    @Bindable var model: AppModel
    let editing: SubmittedCheckIn?
    @State private var form: MorningCheckInForm

    init(model: AppModel, editing: SubmittedCheckIn? = nil) {
        self.model = model
        self.editing = editing
        _form = State(
            initialValue: MorningCheckInForm(
                occurrence: editing?.occurrence,
                presentState: editing?.presentState,
                perceivedIntensity: editing?.perceivedIntensity,
                note: editing?.note ?? ""
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
                Section("How are you feeling now?") {
                    Picker("Present state", selection: $form.presentState) {
                        Text("Choose").tag(PresentState?.none)
                        Text("I’m fine now").tag(PresentState?.some(.fineNow))
                        Text("Still a bit shaken").tag(PresentState?.some(.stillShaken))
                        Text("Exhausted").tag(PresentState?.some(.exhausted))
                    }
                    Picker("How intense did it feel? (optional)", selection: $form.perceivedIntensity) {
                        Text("Not entered").tag(PerceivedIntensity?.none)
                        ForEach(PerceivedIntensity.allCases, id: \.self) { value in
                            Text(value.rawValue.capitalized).tag(PerceivedIntensity?.some(value))
                        }
                    }
                }
            }
            Section("Private note (optional)") {
                TextField("What would you like to remember?", text: $form.note, axis: .vertical)
                    .lineLimit(3 ... 7)
            }
            Section {
                Button(editing == nil ? "Save check-in" : "Save changes") {
                    model.submitCheckIn(form, editing: editing)
                }
                .disabled(!form.canSubmit || form.note.count > 500)
            } footer: {
                Text(
                    "This information is descriptive. Paralux does not calculate a clinical score, diagnosis, or risk."
                )
            }
        }
        .navigationTitle(editing == nil ? "Morning check-in" : "Edit check-in")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CheckInDetailView: View {
    @Bindable var model: AppModel
    @State private var showingDelete = false
    @State private var editing = false

    var body: some View {
        Group {
            if let value = model.selectedCheckIn {
                List {
                    Section("Date") {
                        LabeledContent("Reported for", value: value.reportedForLocalDate)
                        LabeledContent("Episode", value: value.occurrence == .yes ? "Yes" : "No")
                    }
                    if value.occurrence == .yes {
                        Section("Descriptive details") {
                            if let presentState = value.presentState {
                                LabeledContent("Current feeling", value: presentState.displayName)
                            }
                            if let intensity = value.perceivedIntensity {
                                LabeledContent("Entered intensity", value: intensity.rawValue.capitalized)
                            }
                        }
                    }
                    if let note = value.note {
                        Section("Private note") { Text(note) }
                    }
                    Section {
                        Button("Edit entry", systemImage: "pencil") { editing = true }
                        Button("Delete entry", systemImage: "trash", role: .destructive) {
                            showingDelete = true
                        }
                    }
                }
                .sheet(isPresented: $editing) {
                    NavigationStack {
                        MorningCheckInView(model: model, editing: value)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Close") { editing = false }
                                }
                            }
                    }
                }
                .confirmationDialog("Delete this history entry?", isPresented: $showingDelete) {
                    Button("Delete", role: .destructive) { model.deleteCheckIn(value) }
                    Button("Cancel", role: .cancel) {}
                }
            } else {
                ContentUnavailableView("Entry unavailable", systemImage: "clock.badge.questionmark")
            }
        }
        .navigationTitle("History detail")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension PresentState {
    var displayName: String {
        switch self {
        case .fineNow: "I’m fine now"
        case .stillShaken: "Still a bit shaken"
        case .exhausted: "Exhausted"
        }
    }
}
