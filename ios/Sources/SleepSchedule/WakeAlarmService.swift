import ActivityKit
import AlarmKit
import Foundation
import SwiftUI

private nonisolated struct WakeAlarmMetadata: AlarmMetadata {
    let contentVersion: Int
}

private actor WakeAlarmServiceGate {
    func reconcile(
        schedule: SleepSchedule,
        preference: AlarmPreference
    ) async -> (AlarmPreference, WakeAlarmSchedulingOutcome) {
        guard let plan = WakeAlarmPlanner.plan(for: schedule) else {
            do {
                try cancelOwnedAlarms(for: preference)
                return (
                    updated(
                        preference,
                        systemState: .notScheduled,
                        result: .none,
                        systemAlarmID: nil
                    ),
                    .notRequested
                )
            } catch {
                return (
                    updated(
                        preference,
                        systemState: .failed,
                        result: .failed,
                        systemAlarmID: preference.systemAlarmID
                    ),
                    .failed
                )
            }
        }

        guard let sound = SystemAudioAssets.resolveAlarmSound(
            requestedFileName: preference.alarmSoundFileName
        ) else {
            do {
                try cancelOwnedAlarms(for: preference)
            } catch {
                return (
                    updated(
                        preference,
                        systemState: .failed,
                        result: .failed,
                        systemAlarmID: preference.systemAlarmID
                    ),
                    .failed
                )
            }
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

        var effectivePreference = preference
        if sound.usedFallback {
            effectivePreference.alarmSoundFileName = sound.fileName
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
                return (
                    updated(
                        effectivePreference,
                        systemState: .denied,
                        result: .denied,
                        systemAlarmID: effectivePreference.systemAlarmID
                    ),
                    .denied
                )
            }

            let existing = try AlarmManager.shared.alarms
            let ownedAlarms = existing.filter { alarm in
                [effectivePreference.id.uuidString, effectivePreference.systemAlarmID]
                    .compactMap { $0 }
                    .contains(alarm.id.uuidString)
            }
            if !sound.usedFallback,
               effectivePreference.systemState == .scheduled,
               let systemAlarmID = effectivePreference.systemAlarmID,
               ownedAlarms.count == 1,
               ownedAlarms.contains(where: { $0.id.uuidString == systemAlarmID })
            {
                return (effectivePreference, .scheduled)
            }

            try cancelOwnedAlarms(for: effectivePreference, alarms: existing)
            let alarm = try await AlarmManager.shared.schedule(
                id: effectivePreference.id,
                configuration: configuration(for: plan, soundName: sound.fileName)
            )
            let verified = try AlarmManager.shared.alarms.contains {
                $0.id.uuidString == alarm.id.uuidString
            }
            guard verified else {
                try? AlarmManager.shared.cancel(id: alarm.id)
                return (
                    updated(
                        effectivePreference,
                        systemState: .failed,
                        result: .failed,
                        systemAlarmID: nil
                    ),
                    .failed
                )
            }

            return (
                updated(
                    effectivePreference,
                    systemState: .scheduled,
                    result: .success,
                    systemAlarmID: alarm.id.uuidString
                ),
                sound.usedFallback ? .fallbackScheduled : .scheduled
            )
        } catch {
            return (
                updated(
                    effectivePreference,
                    systemState: .failed,
                    result: .failed,
                    systemAlarmID: nil
                ),
                .failed
            )
        }
    }

    private func cancelOwnedAlarms(
        for preference: AlarmPreference,
        alarms: [Alarm]? = nil
    ) throws {
        let ownedIDs = Set(
            [preference.id.uuidString, preference.systemAlarmID]
                .compactMap { $0 }
        )
        let current = try alarms ?? AlarmManager.shared.alarms
        for alarm in current where ownedIDs.contains(alarm.id.uuidString) {
            try AlarmManager.shared.cancel(id: alarm.id)
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

nonisolated struct WakeAlarmService: Sendable {
    private let gate: WakeAlarmServiceGate

    init() {
        self.gate = WakeAlarmServiceGate()
    }

    func reconcile(
        schedule: SleepSchedule,
        preference: AlarmPreference
    ) async -> (AlarmPreference, WakeAlarmSchedulingOutcome) {
        await gate.reconcile(schedule: schedule, preference: preference)
    }
}
