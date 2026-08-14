import SwiftUI
import UIKit

struct MeProfileView: View {
    @Bindable var model: AppModel
    @Environment(\.openURL) private var openURL
    @State private var confirmCancellation = false

    var body: some View {
        NightScreen {
            VStack(alignment: .leading, spacing: 28) {
                header
                planCard
                founderCard
                menu
            }
            .padding(.bottom, 24)
        }
        .confirmationDialog("Manage subscription?", isPresented: $confirmCancellation) {
            Button("Open subscription settings") {
                openURL(URL(string: "https://apps.apple.com/account/subscriptions")!)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Apple manages subscriptions and cancellation.")
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                Circle().fill(Color.purple.opacity(0.62)).frame(width: 76, height: 76)
                    .overlay { Image(systemName: "moon.fill").font(.system(size: 40)).foregroundStyle(.yellow) }
                Circle().fill(.green).frame(width: 18, height: 18).overlay { Circle().stroke(.black, lineWidth: 3) }
            }
            Text("Hi, \(model.profile?.displayName ?? "")")
                .font(.system(size: 34, weight: .bold)).lineLimit(1)
            Spacer(minLength: 0)
            Text("FREE").font(.headline).foregroundStyle(Color(red: 0.72, green: 0.61, blue: 1))
                .padding(.horizontal, 14).padding(.vertical, 9)
                .overlay { Capsule().stroke(Color.purple.opacity(0.8)) }
        }
    }

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Free plan", systemImage: "circle.fill").foregroundStyle(.white); Spacer(); Text("No renewal")
                    .foregroundStyle(.white.opacity(0.58))
            }
            Text("Upgrade availability will appear here when subscriptions are configured.").font(.callout)
                .foregroundStyle(.white.opacity(0.6))
            Button("Manage subscription", role: .destructive) { confirmCancellation = true }
                .frame(maxWidth: .infinity, alignment: .trailing)
        }.padding(20).background(Color.indigo.opacity(0.24), in: RoundedRectangle(cornerRadius: 28))
            .overlay { RoundedRectangle(cornerRadius: 28).stroke(Color.indigo.opacity(0.65)) }
    }

    private var founderCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("👩‍💻")
                    .font(.system(size: 42)); VStack(alignment: .leading) {
                        Text("Shraddha").font(.title2.bold()); Text("Founder").foregroundStyle(.white.opacity(0.58))
                    }; Spacer(); Text("FOUNDER").foregroundStyle(Color(
                        red: 0.72,
                        green: 0.61,
                        blue: 1
                    ))
            }
            Text(
                "Building this for people like you. I’d love to hear about your experience " +
                    "and answer any questions directly."
            )
            .font(.title3).foregroundStyle(.white.opacity(0.68))
            Button { openURL(URL(string: "mailto:companionsp2026@gmail.com")!) } label: {
                Text("Connect to the founder").font(.title3.bold()).frame(maxWidth: .infinity).padding(
                    .vertical,
                    16
                ).background(
                    LinearGradient(
                        colors: [.purple.opacity(0.65), .blue.opacity(0.65)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 26)
                )
            }
        }.padding(28).background(Color.indigo.opacity(0.24), in: RoundedRectangle(cornerRadius: 32))
            .overlay { RoundedRectangle(cornerRadius: 32).stroke(.cyan.opacity(0.45)) }
    }

    private var menu: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ACCOUNT").font(.headline).foregroundStyle(.white.opacity(0.5)).padding(.bottom, 10)
            row("📝", "Edit Profile") { model.open(.editProfile) }
            row("🔔", "Notifications", detail: model.reminderAuthorization == .authorized ? "On" : "Off") {
                model.manageNotifications()
            }
            row("🔒", "Privacy & Data") { model.open(.dataPrivacy) }
            Text("PREFERENCES").font(.headline).foregroundStyle(.white.opacity(0.5)).padding(.top, 26).padding(
                .bottom,
                10
            )
            row("⚙️", "Default Settings") { model.open(.defaultSettings) }
        }
    }

    private func row(
        _ icon: String,
        _ title: String,
        detail: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) { HStack(spacing: 16) { Text(icon).font(.title2).frame(width: 48, height: 48).background(
            Color.purple.opacity(0.25),
            in: RoundedRectangle(cornerRadius: 13)
        ); Text(title)
            .font(.title3.weight(.medium)); Spacer(); if let detail
        {
            Text(detail).foregroundStyle(.white.opacity(0.6))
        }; Image(systemName: "chevron.right").font(.headline).foregroundStyle(.white.opacity(0.6))
        }.padding(
            .vertical,
            12
        ) }.buttonStyle(.plain)
    }
}

struct EditProfileView: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    var body: some View {
        NightScreen {
            VStack(alignment: .leading, spacing: 24) { Text("Edit Profile").font(.largeTitle.bold()); TextField(
                "Display name",
                text: $name
            ).textFieldStyle(.roundedBorder).textContentType(.name)
                .accessibilityIdentifier("profile.displayName"); Button("Save") {
                    model.updateDisplayName(name); dismiss()
                }
                .buttonStyle(.borderedProminent).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear { name = model.profile?.displayName ?? "" }.navigationBarBackButtonHidden(false)
    }
}

struct DefaultSupportSettingsView: View {
    @Bindable var model: AppModel
    @State private var sleep: DefaultEpisodeSupport = .quickSleep
    @State private var post: DefaultEpisodeSupport = .calmingAudio
    var body: some View {
        NightScreen {
            VStack(alignment: .leading, spacing: 14) {
                Text("Default settings")
                    .font(.title2.bold()); Text("Choose what happens automatically during sleep and after an episode.")
                    .foregroundStyle(.white.opacity(0.6)); Text("Sleep Alarm Preference")
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(
                        .top,
                        12
                    ); option(
                        "☾",
                        "Quick Sleep",
                        "Short calming audio designed to help you fall asleep faster.",
                        .quickSleep,
                        $sleep
                    ); option(
                        "≋",
                        "Long Sleep Aid",
                        "Extended overnight support audio for deeper sleep.",
                        .longSleepAid,
                        $sleep
                    ); Text("Post - Episode Support").foregroundStyle(.white.opacity(0.7)).padding(
                        .top,
                        8
                    ); option(
                        "☎",
                        "Call Partner",
                        "Immediately contact your chosen support partner.",
                        .callPartner,
                        $post
                    ); option(
                        "♫",
                        "Calming Audio",
                        "Play guided calming audio after detection.",
                        .calmingAudio,
                        $post
                    ); option(
                        "♩",
                        "Partner Voice",
                        "Play a recorded voice message from your partner.",
                        .partnerVoice,
                        $post
                    ); Button("Save Preferences") { model.saveDefaultSupport(
                        sleep: sleep,
                        postEpisode: post
                    ) }.buttonStyle(.borderedProminent).frame(maxWidth: .infinity).padding(.top, 12)
            }
        }
        .onAppear {
            sleep = model.settings?.defaultSleepSupport ?? .quickSleep; post = model.settings?
                .defaultPostEpisodeSupport ?? .calmingAudio
        }
    }

    private func option(
        _ icon: String,
        _ title: String,
        _ subtitle: String,
        _ value: DefaultEpisodeSupport,
        _ selection: Binding<DefaultEpisodeSupport>
    ) -> some View {
        Button { selection.wrappedValue = value } label: { HStack { Text(icon).font(.title2).frame(
            width: 46,
            height: 46
        )
        .background(.purple, in: RoundedRectangle(cornerRadius: 7)); VStack(alignment: .leading) {
            Text(title).font(.headline); Text(subtitle).font(.caption).foregroundStyle(.white.opacity(0.55))
        }; Spacer(); Image(systemName: selection.wrappedValue == value ? "checkmark.circle.fill" : "circle")
        .foregroundStyle(.blue).font(.title3)
        }.padding(14).background(
            Color.indigo.opacity(0.35),
            in: RoundedRectangle(cornerRadius: 18)
        ).overlay { RoundedRectangle(cornerRadius: 18).stroke(selection.wrappedValue == value ? .indigo : .clear) } }
            .buttonStyle(.plain)
    }
}
