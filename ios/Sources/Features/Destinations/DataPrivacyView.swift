import SwiftUI

struct DataPrivacyView: View {
    @Bindable var model: AppModel
    @State private var confirmLocalDeletion = false

    var body: some View {
        List {
            Section("Local protection") {
                Label(
                    "Questionnaire, history, schedule, and clip metadata use protected account-bound local storage.",
                    systemImage: "lock.shield"
                )
                Label(
                    "Personal audio bytes remain in protected app-owned storage on this device.",
                    systemImage: "iphone"
                )
            }
            Section("Structured export") {
                Text(
                    "The ZIP includes settings, schedule, check-ins, and a redacted persona.json. " +
                        "It never includes personal audio."
                )
                Button("Create structured export", systemImage: "square.and.arrow.up") {
                    model.createStructuredExport()
                }
                if model.exportURL != nil {
                    Label("Protected ZIP ready to share", systemImage: "archivebox")
                }
            }
            Section("Delete app data") {
                Button("Delete all local app data", systemImage: "trash", role: .destructive) {
                    confirmLocalDeletion = true
                }
            } footer: {
                Text(
                    "This removes this device’s Paralux data and local personal audio. " +
                        "It is distinct from deleting the Supabase account and does not cancel an Apple subscription."
                )
            }
        }
        .navigationTitle("Data and privacy")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete all local Paralux data?", isPresented: $confirmLocalDeletion) {
            Button("Delete local data", role: .destructive) { model.deleteAllLocalData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "This removes protected local records, schedules, reminders, exports, " +
                    "and all personal audio from this device."
            )
        }
        .sheet(
            isPresented: Binding(
                get: { model.exportURL != nil },
                set: {
                    if !$0 {
                        model.cleanupStructuredExport()
                    }
                }
            )
        ) {
            if let url = model.exportURL {
                ShareSheet(items: [url], completion: model.cleanupStructuredExport)
            }
        }
    }
}
