import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct PersonalAudioSetupView: View {
    @Bindable var model: AppModel
    var isOnboarding = false

    @State private var isImporting = false
    @State private var clipToDelete: PersonalAudioClipMetadata?

    var body: some View {
        NightScreen {
            VStack(alignment: .leading, spacing: AppSpacing.spacious) {
                Text(isOnboarding ? "Add a comfort voice" : "Comfort audio")
                    .font(AppTypographyRole.screenTitle)
                    .accessibilityAddTraits(.isHeader)
                Text("Record only when you tap Record, or import an audio file. Personal audio stays on this device.")
                    .foregroundStyle(.white.opacity(0.72))

                NightCard {
                    Label(
                        model.isRecording ? "Recording in progress" : "Record a private clip",
                        systemImage: model.isRecording ? "waveform.circle.fill" : "mic.circle.fill"
                    )
                    .font(.headline)
                    Text("A visible recording can be stopped or cancelled at any time.")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.68))
                        .padding(.vertical, 6)
                    if model.isRecording {
                        HStack {
                            Button("Stop and save", systemImage: "stop.fill") {
                                model.stopAndSaveRecording()
                            }
                            .buttonStyle(.borderedProminent)
                            Button("Cancel", role: .cancel) {
                                model.cancelRecording()
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        Button("Record", systemImage: "mic.fill") {
                            model.startRecording()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                Button("Import audio file", systemImage: "square.and.arrow.down") {
                    isImporting = true
                }
                .buttonStyle(AppSecondaryButtonStyle())

                if model.personalClips.isEmpty {
                    NightCard {
                        Label("No personal clips yet", systemImage: "waveform.slash")
                            .font(.headline)
                        Text("You can continue without audio. Silent visual grounding remains available.")
                            .foregroundStyle(.white.opacity(0.68))
                    }
                } else {
                    Text("Personal clips")
                        .font(AppTypographyRole.sectionTitle)
                    ForEach(model.personalClips, id: \.id) { clip in
                        clipRow(clip)
                    }
                }

                Text("Paralux-provided audio")
                    .font(AppTypographyRole.sectionTitle)
                ForEach(model.providedAudio) { item in
                    NightCard {
                        Label(item.title, systemImage: "music.note")
                            .font(.headline)
                        Text(item.isBundled ? item.detail : "\(item.detail) Production asset not bundled.")
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.68))
                        Button("Select", systemImage: "checkmark.circle") {
                            model.selectProvidedAudio(item)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!item.isBundled)
                        .padding(.top, 4)
                    }
                }

                if isOnboarding {
                    Button("Continue to sleep schedule", systemImage: "arrow.right") {
                        model.continueFromAudioSetup()
                    }
                    .buttonStyle(AppPrimaryButtonStyle())
                }
                Text(
                    "Personal audio is never included in structured export, analytics, diagnostics, notifications, widgets, or Supabase."
                )
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.58))
            }
            .padding(.top, isOnboarding ? 32 : 0)
        }
        .navigationTitle(isOnboarding ? "" : "Comfort audio")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                model.importAudio(from: url)
            }
        }
        .confirmationDialog(
            "Delete this local clip?",
            isPresented: Binding(
                get: { clipToDelete != nil },
                set: {
                    if !$0 {
                        clipToDelete = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete clip", role: .destructive) {
                if let clipToDelete {
                    model.deleteClip(clipToDelete)
                }
                clipToDelete = nil
            }
            Button("Cancel", role: .cancel) { clipToDelete = nil }
        } message: {
            Text(
                "This removes the clip bytes, metadata, and any device-local default reference. It does not change server data."
            )
        }
        .sheet(
            isPresented: Binding(
                get: { model.audioExportURL != nil },
                set: {
                    if !$0 {
                        model.cleanupAudioExport()
                    }
                }
            )
        ) {
            if let url = model.audioExportURL {
                ShareSheet(items: [url], completion: model.cleanupAudioExport)
            }
        }
    }

    private func clipRow(_ clip: PersonalAudioClipMetadata) -> some View {
        NightCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(clip.source == .recorded ? "Recorded comfort clip" : "Imported comfort clip")
                        .font(.headline)
                    Text(clip.createdOrImportedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                }
                Spacer()
                if model.recoveryAudioDefault == .personalClip(clip.id) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.cyan)
                        .accessibilityLabel("Selected recovery audio")
                }
            }
            HStack {
                Button("Play", systemImage: "play.fill") { model.play(clip) }
                    .buttonStyle(.bordered)
                Button("Use", systemImage: "checkmark") { model.selectPersonalClip(clip) }
                    .buttonStyle(.borderedProminent)
                Menu {
                    Button("Export clip", systemImage: "square.and.arrow.up") {
                        model.prepareAudioExport(clip)
                    }
                    Button("Delete clip", systemImage: "trash", role: .destructive) {
                        clipToDelete = clip
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("More clip actions")
            }
            .padding(.top, 6)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let completion: () -> Void

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in completion() }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {
        _ = controller
        _ = context
    }
}
