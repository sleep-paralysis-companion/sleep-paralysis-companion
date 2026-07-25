import AlarmKit
import SwiftUI
import UIKit

struct RootView: View {
    @StateObject private var alarmModel = AlarmSpikeModel()
    @StateObject private var storeKitModel = StoreKitProbeModel()
    @State private var showGrounding = false

    var body: some View {
        NavigationStack {
            List {
                Section("Boundary") {
                    Text("DISPOSABLE - NOT FOR SHIPPING")
                        .font(.headline)
                        .foregroundStyle(.red)
                    Text(
                        "No accounts, personal data, microphone, detection, "
                            + "health claims, or production services."
                    )
                }

                Section("AlarmKit") {
                    LabeledContent("Authorization", value: alarmModel.authorization)

                    Button("Request alarm authorization") {
                        Task { await alarmModel.requestAuthorization() }
                    }

                    DatePicker(
                        "One-time alarm",
                        selection: $alarmModel.scheduledDate,
                        in: Date().addingTimeInterval(30)...,
                        displayedComponents: [.date, .hourAndMinute]
                    )

                    Button("Schedule neutral test alarm") {
                        Task { await alarmModel.schedule() }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Refresh system state") {
                        alarmModel.refresh()
                    }

                    Text(alarmModel.status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Latest alarm operation")
                }

                Section("Scheduled by this app") {
                    if alarmModel.alarms.isEmpty {
                        Text("No scheduled alarms")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(alarmModel.alarms) { alarm in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(alarm.id.uuidString)
                                    .font(.caption.monospaced())
                                Text(String(describing: alarm.state))
                                    .font(.caption)
                                Button("Cancel this alarm", role: .destructive) {
                                    Task { await alarmModel.cancel(alarm) }
                                }
                            }
                        }
                    }
                }

                Section("Manual fixture") {
                    Button("Open test grounding") {
                        showGrounding = true
                    }
                }

                Section("StoreKit probe") {
                    Button("Load disposable products") {
                        Task { await storeKitModel.load() }
                    }

                    if storeKitModel.products.isEmpty {
                        Text(storeKitModel.status)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(storeKitModel.products, id: \.id) { product in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(product.displayName)
                                    .font(.headline)
                                Text(product.displayPrice)
                                Text(product.id)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                Button("Open Apple purchase sheet") {
                                    Task { await storeKitModel.purchase(product) }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }

                    Button("Restore purchases") {
                        Task { await storeKitModel.restore() }
                    }

                    if !storeKitModel.entitledProductIDs.isEmpty {
                        Text(
                            "Verified: "
                                + storeKitModel.entitledProductIDs.sorted()
                                    .joined(separator: ", ")
                        )
                        .font(.caption)
                    }

                    Text(storeKitModel.status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Evidence") {
                    ShareLink(item: EvidenceLogger.shared.fileURL) {
                        Label("Export privacy-safe JSONL", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .navigationTitle("Phase 0 Spike")
            .navigationDestination(isPresented: $showGrounding) {
                GroundingFixtureView()
            }
            .onAppear(perform: routePendingIntent)
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIApplication.didBecomeActiveNotification
                )
            ) { _ in
                alarmModel.refresh()
                routePendingIntent()
            }
        }
    }

    private func routePendingIntent() {
        guard UserDefaults.standard.bool(forKey: "pendingGroundingRoute") else {
            return
        }
        UserDefaults.standard.set(false, forKey: "pendingGroundingRoute")
        showGrounding = true
        Task {
            await EvidenceLogger.shared.record(
                "custom_alarm_action_opened_app",
                details: [
                    "alarm_id": UserDefaults.standard.string(
                        forKey: "lastIntentAlarmID"
                    ) ?? ""
                ]
            )
        }
    }
}

private struct GroundingFixtureView: View {
    @StateObject private var tonePlayer = SyntheticTonePlayer()

    var body: some View {
        VStack(spacing: 24) {
            Text("Test grounding fixture")
                .font(.title.bold())

            Text("Take a moment. Choose what feels helpful.")
                .multilineTextAlignment(.center)

            Text("Silent option: notice one point of contact with the surface beneath you.")
                .padding()
                .frame(maxWidth: .infinity)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))

            if tonePlayer.isPlaying {
                Button("Stop synthetic tone", role: .destructive) {
                    Task { await tonePlayer.stop() }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Play low-volume synthetic tone") {
                    Task { await tonePlayer.start() }
                }
                .buttonStyle(.borderedProminent)
            }

            Text(tonePlayer.status)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            Task { await tonePlayer.stop() }
        }
    }
}
