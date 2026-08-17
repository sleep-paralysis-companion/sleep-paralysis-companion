import SwiftUI

struct HelpLegalView: View {
    var body: some View {
        List {
            Section("Product boundary") {
                Text(HelpLegalCopy.productBoundary)
                Text(HelpLegalCopy.manualEpisodeBoundary)
            }
            Section("Using Sleep Paralysis Companion") {
                Label(
                    "Choose “I just had an episode” for manual visual grounding.",
                    systemImage: "moon.stars"
                )
                Label(HelpLegalCopy.personalAudioBoundary, systemImage: "waveform")
                Label(HelpLegalCopy.notificationBoundary, systemImage: "bell")
            }
            Section("Legal and support") {
                Link(destination: LegalSupport.privacyURL) {
                    Label("Privacy", systemImage: "hand.raised")
                }
                .accessibilityIdentifier("helpLegal.privacy")
                Link(destination: LegalSupport.termsURL) {
                    Label("Terms", systemImage: "doc.text")
                }
                .accessibilityIdentifier("helpLegal.terms")
                Link(destination: LegalSupport.supportURL) {
                    Label("Support", systemImage: "questionmark.circle")
                }
                .accessibilityIdentifier("helpLegal.support")
                Link(destination: LegalSupport.accountDeletionURL) {
                    Label("Delete Account", systemImage: "person.crop.circle.badge.minus")
                }
                .accessibilityIdentifier("helpLegal.deleteAccount")
            }
            Section("If you need urgent help") {
                Text(HelpLegalCopy.emergencyBoundary)
            }
        }
        .navigationTitle("Help and legal")
        .navigationBarTitleDisplayMode(.inline)
    }
}
