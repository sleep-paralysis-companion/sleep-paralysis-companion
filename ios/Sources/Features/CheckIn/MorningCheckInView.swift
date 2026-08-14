import SwiftUI

struct MorningCheckInView: View {
    @Bindable var model: AppModel

    var body: some View {
        MorningCheckInFlowView(model: model)
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
                            if let spcOutcome = value.spcOutcome {
                                LabeledContent("After SPC", value: spcOutcome.displayName)
                            }
                            if let support = value.postEpisodeSupport {
                                LabeledContent("Used after episode", value: support.displayName)
                            }
                        }
                    } else if let sleepHelp = value.sleepHelpOutcome {
                        Section("SPC and sleep") {
                            LabeledContent("Outcome", value: sleepHelp.displayName)
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
                        CheckInEditorView(model: model, editing: value)
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

private extension SPCOutcome {
    var displayName: String {
        switch self {
        case .calmer: "Calmer"
        case .noDifference: "No difference"
        }
    }
}

private extension PostEpisodeSupport {
    var displayName: String {
        switch self {
        case .partnerCall: "Partner Call"
        case .calmingAudio: "Calming Audio"
        case .partnerAudio: "Partner Audio"
        }
    }
}

private extension SleepHelpOutcome {
    var displayName: String {
        switch self {
        case .audioHelped: "Audio helped"
        case .didNotUseIt: "Didn't use it"
        case .forgotItWasThere: "Forget it was there"
        }
    }
}
