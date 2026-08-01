import SwiftUI

struct AccountView: View {
    @Bindable var model: AppModel
    @State private var confirmSignOut = false
    @State private var confirmAccountDeletion = false

    var body: some View {
        List {
            Section("Signed-in account") {
                Label("Authenticated with Apple or Google", systemImage: "person.crop.circle.badge.checkmark")
                Text("Session tokens are stored in Keychain. Sensitive local records remain account-bound.")
            }
            Section {
                Button("Sign out", systemImage: "rectangle.portrait.and.arrow.right") {
                    confirmSignOut = true
                }
                Button(
                    "Delete Supabase account",
                    systemImage: "person.crop.circle.badge.minus",
                    role: .destructive
                ) {
                    confirmAccountDeletion = true
                }
            } footer: {
                Text(
                    "Deleting the Supabase account is distinct from deleting local app data. " +
                        "Neither action cancels an Apple subscription."
                )
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Sign out?", isPresented: $confirmSignOut) {
            Button("Sign out", role: .destructive) { model.signOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Protected local data remains on this device and requires the same account to reopen.")
        }
        .confirmationDialog("Delete the Supabase account?", isPresented: $confirmAccountDeletion) {
            Button("Reauthenticate and delete account", role: .destructive) {
                model.deleteRemoteAccount()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "A fresh provider sign-in is required. " +
                    "Local data is removed only after the server confirms account deletion."
            )
        }
    }
}
