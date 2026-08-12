import ActivityKit
import AlarmKit
import Foundation
import SwiftUI

private nonisolated struct WakeAlarmMetadata: AlarmMetadata {
    let contentVersion: Int
}

private nonisolated enum WakeAlarmAudioAsset {
    /// The approved asset will be added in a later pass. Until then, the AlarmKit path stays unavailable.
    static let resourceName = "SPCWakeUpGentleLoop"
    static let resourceExtension = "caf"

    static var alertSoundName: String? {
        guard Bundle.main.url(forResource: resourceName, withExtension: resourceExtension) != nil else {
            return nil
        }
        return "\(resourceName).\(resourceExtension)"
    }
}

nonisolated struct WakeAlarmService: Sendable {
    func reconcile(
        schedule: SleepSchedule,
        preference: AlarmPreference
    ) async -> (AlarmPreference, WakeAlarmSchedulingOutcome) {
        guard let plan = WakeAlarmPlanner.plan(for: schedule) else {
            try? AlarmManager.shared.cancel(id: preference.id)
            return (updated(preference, systemState: .notScheduled, result: .none, systemAlarmID: nil), .notRequested)
        }

        guard let soundName = WakeAlarmAudioAsset.alertSoundName else {
            try? AlarmManager.shared.cancel(id: preference.id)
            return (
                updated(
                    preference,
                    systemState: .notScheduled,
                    result: .none,
                    systemAlarmID: nil
                ),
                .audioAssetUnavailable
            )
        }

        do {
            let authorization = AlarmManager.shared.authorizationState
            let authorized = if authorization == .authorized {
                true
            } else if authorization == .notDetermined {
                try await AlarmManager.shared.requestAuthorization() == .authorized
            } else {
                false
            }
            guard authorized else {
                return (updated(preference, systemState: .denied, result: .denied, systemAlarmID: nil), .denied)
            }

            try? AlarmManager.shared.cancel(id: preference.id)
            let alarm = try await AlarmManager.shared.schedule(
                id: preference.id,
                configuration: configuration(for: plan, soundName: soundName)
            )
            return (
                updated(
                    preference,
                    systemState: .scheduled,
                    result: .success,
                    systemAlarmID: alarm.id.uuidString
                ),
                .scheduled
            )
        } catch {
            return (updated(preference, systemState: .failed, result: .failed, systemAlarmID: nil), .failed)
        }
    }

    private func configuration(
        for plan: WakeAlarmPlan,
        soundName: String
    ) -> AlarmManager.AlarmConfiguration<WakeAlarmMetadata> {
        let stopButton = AlarmButton(
            text: "Stop",
            textColor: .white,
            systemImageName: "stop.fill"
        )
        let alert = AlarmPresentation.Alert(
            title: "Gentle wake-up",
            stopButton: stopButton
        )
        let attributes = AlarmAttributes<WakeAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert),
            metadata: WakeAlarmMetadata(contentVersion: 1),
            tintColor: .indigo
        )
        let time = Alarm.Schedule.Relative.Time(hour: plan.hour, minute: plan.minute)
        let schedule = Alarm.Schedule.relative(
            .init(
                time: time,
                repeats: .weekly(plan.weekdays.map(localeWeekday))
            )
        )

        return .alarm(
            schedule: schedule,
            attributes: attributes,
            sound: .named(soundName)
        )
    }

    private func updated(
        _ preference: AlarmPreference,
        systemState: AlarmSystemState,
        result: AlarmScheduleResult,
        systemAlarmID: String?
    ) -> AlarmPreference {
        var value = preference
        value.systemAlarmID = systemAlarmID
        value.systemState = systemState
        value.lastScheduleResult = result
        value.updatedAt = Date()
        value.revision += 1
        return value
    }

    private func localeWeekday(_ calendarWeekday: Int) -> Locale.Weekday {
        switch calendarWeekday {
        case 1: .sunday
        case 2: .monday
        case 3: .tuesday
        case 4: .wednesday
        case 5: .thursday
        case 6: .friday
        default: .saturday
        }
    }
}
