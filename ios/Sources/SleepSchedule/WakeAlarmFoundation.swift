import Foundation

nonisolated struct WakeAlarmPlan: Equatable, Sendable {
    let hour: Int
    let minute: Int
    let weekdays: [Int]
    let maximumPlaybackSeconds: Int
}

nonisolated enum WakeAlarmPlanner {
    static func plan(for schedule: SleepSchedule) -> WakeAlarmPlan? {
        guard schedule.isValid,
              let leadMinutes = schedule.wakeReminderLeadMinutes,
              schedule.weekdaysMask != 0
        else {
            return nil
        }

        let unwrappedMinutes = schedule.wakeHour * 60 + schedule.wakeMinute - leadMinutes
        let startsOnPreviousDay = unwrappedMinutes < 0
        let minuteOfDay = (unwrappedMinutes + 24 * 60) % (24 * 60)
        let weekdays = (1 ... 7).compactMap { wakeWeekday -> Int? in
            guard schedule.weekdaysMask & (1 << (wakeWeekday - 1)) != 0 else {
                return nil
            }
            guard startsOnPreviousDay else { return wakeWeekday }
            return wakeWeekday == 1 ? 7 : wakeWeekday - 1
        }

        return WakeAlarmPlan(
            hour: minuteOfDay / 60,
            minute: minuteOfDay % 60,
            weekdays: weekdays,
            maximumPlaybackSeconds: leadMinutes * 60
        )
    }
}

nonisolated enum WakeAlarmSchedulingOutcome: Equatable, Sendable {
    case notRequested
    case audioAssetUnavailable
    case scheduled
    case fallbackScheduled
    case denied
    case failed

    var accessibilityDescription: String {
        switch self {
        case .notRequested:
            "Wake-up audio is off"
        case .audioAssetUnavailable:
            "Wake-up audio was not scheduled because no compatible local sound is available"
        case .scheduled:
            "Wake-up audio alarm is scheduled"
        case .fallbackScheduled:
            "Wake-up audio alarm is scheduled with the bundled fallback sound"
        case .denied:
            "Wake-up audio alarm permission is denied"
        case .failed:
            "Wake-up audio alarm needs attention"
        }
    }
}
