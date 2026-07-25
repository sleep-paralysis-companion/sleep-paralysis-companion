import AlarmKit
import Foundation
import SwiftUI

struct SpikeAlarmMetadata: AlarmMetadata {
    let fixtureVersion: String
}

@MainActor
final class AlarmSpikeModel: ObservableObject {
    @Published var authorization = "Checking"
    @Published var alarms: [Alarm] = []
    @Published var status = "No operation yet"
    @Published var scheduledDate = Date().addingTimeInterval(120)

    private let manager = AlarmManager.shared

    init() {
        refresh()
        Task {
            for await updates in manager.alarmUpdates {
                alarms = updates
            }
        }
    }

    func refresh() {
        authorization = String(describing: manager.authorizationState)
        alarms = manager.alarms
    }

    func requestAuthorization() async {
        do {
            let result = try await manager.requestAuthorization()
            authorization = String(describing: result)
            status = "Authorization result: \(authorization)"
            await EvidenceLogger.shared.record(
                "alarm_authorization_result",
                details: ["state": authorization]
            )
        } catch {
            status = "Authorization failed: \(error.localizedDescription)"
            await logFailure("alarm_authorization_failed", error)
        }
    }

    func schedule() async {
        let id = UUID()
        let dismiss = AlarmButton(
            text: "Dismiss",
            textColor: .white,
            systemImageName: "stop.circle"
        )
        let open = AlarmButton(
            text: "Open",
            textColor: .white,
            systemImageName: "arrow.right.circle.fill"
        )
        let alert = AlarmPresentation.Alert(
            title: "Bedtime reminder",
            stopButton: dismiss,
            secondaryButton: open,
            secondaryButtonBehavior: .custom
        )
        let attributes = AlarmAttributes<SpikeAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert),
            metadata: SpikeAlarmMetadata(fixtureVersion: "phase0-v1"),
            tintColor: .indigo
        )
        let configuration =
            AlarmManager.AlarmConfiguration<SpikeAlarmMetadata>.alarm(
                schedule: .fixed(scheduledDate),
                attributes: attributes,
                secondaryIntent: OpenGroundingIntent(alarmID: id.uuidString),
                sound: .default
            )

        do {
            let alarm = try await manager.schedule(
                id: id,
                configuration: configuration
            )
            status = "Scheduled \(alarm.id) for \(scheduledDate.formatted())"
            refresh()
            await EvidenceLogger.shared.record(
                "alarm_scheduled",
                details: [
                    "alarm_id": id.uuidString,
                    "schedule": scheduledDate.ISO8601Format()
                ]
            )
        } catch {
            status = "Schedule failed: \(error.localizedDescription)"
            await logFailure("alarm_schedule_failed", error)
        }
    }

    func cancel(_ alarm: Alarm) async {
        do {
            try manager.cancel(id: alarm.id)
            status = "Canceled \(alarm.id)"
            refresh()
            await EvidenceLogger.shared.record(
                "alarm_canceled",
                details: ["alarm_id": alarm.id.uuidString]
            )
        } catch {
            status = "Cancel failed: \(error.localizedDescription)"
            await logFailure("alarm_cancel_failed", error)
        }
    }

    private func logFailure(_ event: String, _ error: Error) async {
        await EvidenceLogger.shared.record(
            event,
            details: ["error": String(describing: error)]
        )
    }
}

