import SwiftUI

struct HelpLegalView: View {
    var body: some View {
        List {
            Section("Product boundary") {
                Text("Paralux is a nonmedical wellness companion. It does not diagnose, detect, monitor, predict, prevent, or treat sleep paralysis and is not an emergency service.")
                Text("Every episode action and check-in is started by you. The app never automatically infers an episode.")
            }
            Section("Using Paralux") {
                Label("Choose “I just had an episode” for manual visual grounding.", systemImage: "moon.stars")
                Label("Personal audio remains on this device.", systemImage: "waveform")
                Label("Notification reminders are ordinary reminders, not guaranteed alarms.", systemImage: "bell")
            }
            Section("Legal and support") {
                Text("Final public privacy, terms, and support URLs are not configured in this checkout. Release must remain blocked until approved live pages are supplied.")
            }
            Section("If you need urgent help") {
                Text("Use the emergency and support resources available in your location. Paralux does not contact emergency services.")
            }
        }
        .navigationTitle("Help and legal")
        .navigationBarTitleDisplayMode(.inline)
    }
}
