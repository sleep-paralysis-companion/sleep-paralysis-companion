import ActivityKit
@preconcurrency import AlarmKit
import CryptoKit
import Foundation
import SwiftUI

private nonisolated struct WakeAlarmMetadata: AlarmMetadata {
    let contentVersion: Int
    let scheduleID: UUID?
    let role: WakeAlarmEventRole?

    init(
        contentVersion: Int,
        scheduleID: UUID? = nil,
        role: WakeAlarmEventRole? = nil
    ) {
        self.contentVersion = contentVersion
        self.scheduleID = scheduleID
        self.role = role
    }
}

private nonisolated enum WakeAlarmReconciliationError: Error {
    case verificationFailed
}

@MainActor
private final class WakeAlarmServiceGate {
    // Alarm reconciliation intentionally handles several independent failure states.
    // swiftlint:disable cyclomatic_complexity
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
                    .compactMap(\.self)
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

    /// Reconciles every AlarmKit event owned by one named schedule.
    ///
    /// A full schedule can own two independent alarms: gentle audio before
    /// wake-up and a distinct final wake alert. The IDs are role-specific and
    /// remain stable across edits, so reconciling one schedule never cancels a
    /// different schedule's alarms.
    func reconcile(
        schedule: AlarmSchedule,
        state: AlarmScheduleSchedulingState
    ) async -> (AlarmScheduleSchedulingState, WakeAlarmSchedulingOutcome) {
        let state = normalizedState(for: schedule, state: state)
        let plans = WakeAlarmPlanner.plans(for: schedule)

        guard !plans.isEmpty else {
            do {
                try cancelOwnedAlarms(for: schedule, state: state)
                return (
                    updated(
                        state,
                        scheduleID: schedule.id,
                        gentleAlarmID: nil,
                        finalAlarmID: nil,
                        systemState: .notScheduled,
                        result: .none
                    ),
                    .notRequested
                )
            } catch {
                return (
                    updated(
                        state,
                        scheduleID: schedule.id,
                        gentleAlarmID: state.gentleAlarmID,
                        finalAlarmID: state.finalAlarmID,
                        systemState: .failed,
                        result: .failed
                    ),
                    .failed
                )
            }
        }

        guard let soundName = alarmSoundName(for: schedule.wakeAudio) else {
            do {
                try cancelOwnedAlarms(for: schedule, state: state)
            } catch {
                return (
                    updated(
                        state,
                        scheduleID: schedule.id,
                        gentleAlarmID: state.gentleAlarmID,
                        finalAlarmID: state.finalAlarmID,
                        systemState: .failed,
                        result: .failed
                    ),
                    .failed
                )
            }
            return (
                updated(
                    state,
                    scheduleID: schedule.id,
                    gentleAlarmID: nil,
                    finalAlarmID: nil,
                    systemState: .needsAttention,
                    result: .failed
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
                return (
                    updated(
                        state,
                        scheduleID: schedule.id,
                        gentleAlarmID: state.gentleAlarmID,
                        finalAlarmID: state.finalAlarmID,
                        systemState: .denied,
                        result: .denied
                    ),
                    .denied
                )
            }

            let existing = try AlarmManager.shared.alarms
            let ownedIDs = ownedAlarmIDs(for: schedule, state: state)
            let externalIDs = Set(existing.map { $0.id.uuidString }).subtracting(ownedIDs)
            try cancelOwnedAlarms(for: schedule, state: state, alarms: existing)

            var scheduledIDs: [String: String] = [:]
            do {
                for plan in plans {
                    let preferredID = persistedAlarmID(for: plan.role, state: state)
                        ?? deterministicAlarmID(scheduleID: schedule.id, role: plan.role)
                    let alarmID = externalIDs.contains(preferredID.uuidString) ? UUID() : preferredID
                    let alarm = try await AlarmManager.shared.schedule(
                        id: alarmID,
                        configuration: configuration(
                            for: plan,
                            soundName: soundName,
                            scheduleID: schedule.id
                        )
                    )
                    let verified = try AlarmManager.shared.alarms.contains {
                        $0.id.uuidString == alarm.id.uuidString
                    }
                    guard verified else {
                        try? AlarmManager.shared.cancel(id: alarm.id)
                        throw WakeAlarmReconciliationError.verificationFailed
                    }
                    scheduledIDs[plan.role.rawValue] = alarm.id.uuidString
                }
            } catch {
                for alarmID in scheduledIDs.values {
                    if let id = UUID(uuidString: alarmID) {
                        try? AlarmManager.shared.cancel(id: id)
                    }
                }
                return (
                    updated(
                        state,
                        scheduleID: schedule.id,
                        gentleAlarmID: nil,
                        finalAlarmID: nil,
                        systemState: .failed,
                        result: .failed
                    ),
                    .failed
                )
            }

            return (
                updated(
                    state,
                    scheduleID: schedule.id,
                    gentleAlarmID: scheduledIDs[WakeAlarmEventRole.gentleAudio.rawValue],
                    finalAlarmID: scheduledIDs[WakeAlarmEventRole.finalWake.rawValue],
                    systemState: .scheduled,
                    result: .success
                ),
                .scheduled
            )
        } catch {
            return (
                updated(
                    state,
                    scheduleID: schedule.id,
                    gentleAlarmID: state.gentleAlarmID,
                    finalAlarmID: state.finalAlarmID,
                    systemState: .failed,
                    result: .failed
                ),
                .failed
            )
        }
    }

    /// Cancels only this schedule's AlarmKit events, including both role IDs.
    func cancel(
        schedule: AlarmSchedule,
        state: AlarmScheduleSchedulingState
    ) async -> AlarmScheduleSchedulingState {
        let state = normalizedState(for: schedule, state: state)
        do {
            try cancelOwnedAlarms(for: schedule, state: state)
            return updated(
                state,
                scheduleID: schedule.id,
                gentleAlarmID: nil,
                finalAlarmID: nil,
                systemState: .notScheduled,
                result: .none
            )
        } catch {
            return updated(
                state,
                scheduleID: schedule.id,
                gentleAlarmID: state.gentleAlarmID,
                finalAlarmID: state.finalAlarmID,
                systemState: .failed,
                result: .failed
            )
        }
    }

    // swiftlint:enable cyclomatic_complexity

    private func normalizedState(
        for schedule: AlarmSchedule,
        state: AlarmScheduleSchedulingState
    ) -> AlarmScheduleSchedulingState {
        guard state.scheduleID == schedule.id else {
            return AlarmScheduleSchedulingState(scheduleID: schedule.id)
        }
        return state
    }

    private func persistedAlarmID(
        for role: WakeAlarmEventRole,
        state: AlarmScheduleSchedulingState
    ) -> UUID? {
        switch role {
        case .gentleAudio:
            state.gentleAlarmID.flatMap(UUID.init(uuidString:))
        case .finalWake:
            state.finalAlarmID.flatMap(UUID.init(uuidString:))
        }
    }

    private func ownedAlarmIDs(
        for schedule: AlarmSchedule,
        state: AlarmScheduleSchedulingState
    ) -> Set<String> {
        var result = Set(state.systemAlarmIDs)
        // The legacy single-alarm bridge used the schedule UUID itself. Keep
        // that identifier in this schedule's ownership set while stores move
        // to the two role-specific IDs.
        result.insert(schedule.id.uuidString)
        result.insert(
            deterministicAlarmID(scheduleID: schedule.id, role: .gentleAudio).uuidString
        )
        result.insert(
            deterministicAlarmID(scheduleID: schedule.id, role: .finalWake).uuidString
        )
        return result
    }

    private func cancelOwnedAlarms(
        for schedule: AlarmSchedule,
        state: AlarmScheduleSchedulingState,
        alarms: [Alarm]? = nil
    ) throws {
        let ownedIDs = ownedAlarmIDs(for: schedule, state: state)
        let current = try alarms ?? AlarmManager.shared.alarms
        for alarm in current where ownedIDs.contains(alarm.id.uuidString) {
            try AlarmManager.shared.cancel(id: alarm.id)
        }
    }

    private func deterministicAlarmID(
        scheduleID: UUID,
        role: WakeAlarmEventRole
    ) -> UUID {
        let input = Data("sleepcompanion.alarm.\(scheduleID.uuidString).\(role.rawValue)".utf8)
        let digest = Array(SHA256.hash(data: input))
        return UUID(uuid: (
            digest[0], digest[1], digest[2], digest[3],
            digest[4], digest[5], digest[6], digest[7],
            digest[8], digest[9], digest[10], digest[11],
            digest[12], digest[13], digest[14], digest[15]
        ))
    }

    private func alarmSoundName(for selection: AlarmAudioSelection?) -> String? {
        guard let selection,
              selection.isAvailableOnThisDevice
        else {
            return nil
        }

        let requestedFileName: String?
        switch selection.reference {
        case let .bundled(resourceName):
            requestedFileName = selection.localFileName ?? resourceName
        case .catalog, .personal:
            // Catalog and personal audio must already resolve to a verified
            // local file. Calling resolveAlarmSound with nil would otherwise
            // permit a bundled fallback, which would silently change intent.
            requestedFileName = selection.localFileName
        }

        guard let requestedFileName,
              let resolved = SystemAudioAssets.resolveAlarmSound(
                  requestedFileName: requestedFileName
              ),
              !resolved.usedFallback
        else {
            return nil
        }
        return resolved.fileName
    }

    private func updated(
        _ state: AlarmScheduleSchedulingState,
        scheduleID: UUID,
        gentleAlarmID: String?,
        finalAlarmID: String?,
        systemState: AlarmSystemState,
        result: AlarmScheduleResult
    ) -> AlarmScheduleSchedulingState {
        AlarmScheduleSchedulingState(
            scheduleID: scheduleID,
            gentleAlarmID: gentleAlarmID,
            finalAlarmID: finalAlarmID,
            systemState: systemState,
            lastScheduleResult: result,
            updatedAt: Date(),
            revision: state.revision + 1
        )
    }

    private func cancelOwnedAlarms(
        for preference: AlarmPreference,
        alarms: [Alarm]? = nil
    ) throws {
        let ownedIDs = Set(
            [preference.id.uuidString, preference.systemAlarmID]
                .compactMap(\.self)
        )
        let current = try alarms ?? AlarmManager.shared.alarms
        for alarm in current where ownedIDs.contains(alarm.id.uuidString) {
            try AlarmManager.shared.cancel(id: alarm.id)
        }
    }

    private func configuration(
        for plan: WakeAlarmPlan,
        soundName: String,
        scheduleID: UUID? = nil
    ) -> AlarmManager.AlarmConfiguration<WakeAlarmMetadata> {
        let stopButton = AlarmButton(
            text: "Stop",
            textColor: .white,
            systemImageName: "stop.fill"
        )
        let alert = AlarmPresentation.Alert(
            title: plan.role == .finalWake ? "Wake up" : "Gentle wake-up",
            stopButton: stopButton
        )
        let attributes = AlarmAttributes<WakeAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert),
            metadata: WakeAlarmMetadata(
                contentVersion: 1,
                scheduleID: scheduleID ?? plan.scheduleID,
                role: plan.role
            ),
            tintColor: .indigo
        )
        let time = Alarm.Schedule.Relative.Time(hour: plan.hour, minute: plan.minute)
        let schedule: Alarm.Schedule
        if let fixedDate = fixedDate(for: plan) {
            schedule = .fixed(fixedDate)
        } else {
            let repeats: Alarm.Schedule.Relative.Recurrence = plan.weekdays.isEmpty
                ? .never
                : .weekly(plan.weekdays.map(localeWeekday))
            schedule = .relative(
                .init(
                    time: time,
                    repeats: repeats
                )
            )
        }

        return .alarm(
            schedule: schedule,
            attributes: attributes,
            sound: .named(soundName)
        )
    }

    private func fixedDate(for plan: WakeAlarmPlan) -> Date? {
        guard let localDate = plan.date,
              let date = localDate.date()
        else {
            return nil
        }
        var components = Calendar.current.dateComponents(
            [.year, .month, .day],
            from: date
        )
        components.hour = plan.hour
        components.minute = plan.minute
        components.second = 0
        return Calendar.current.date(from: components)
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

    func reconcile(
        schedule: AlarmSchedule,
        state: AlarmScheduleSchedulingState
    ) async -> (AlarmScheduleSchedulingState, WakeAlarmSchedulingOutcome) {
        await gate.reconcile(schedule: schedule, state: state)
    }

    func cancel(
        schedule: AlarmSchedule,
        state: AlarmScheduleSchedulingState
    ) async -> AlarmScheduleSchedulingState {
        await gate.cancel(schedule: schedule, state: state)
    }
}
