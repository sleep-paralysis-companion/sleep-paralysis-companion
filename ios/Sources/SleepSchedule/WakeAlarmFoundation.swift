import Foundation

nonisolated struct WakeAlarmPlan: Equatable, Sendable {
    let hour: Int
    let minute: Int
    let weekdays: [Int]
    let maximumPlaybackSeconds: Int
    let scheduleID: UUID?
    let role: WakeAlarmEventRole
    let date: AlarmLocalDate?

    init(
        hour: Int,
        minute: Int,
        weekdays: [Int],
        maximumPlaybackSeconds: Int,
        scheduleID: UUID? = nil,
        role: WakeAlarmEventRole = .gentleAudio,
        date: AlarmLocalDate? = nil
    ) {
        self.hour = hour
        self.minute = minute
        self.weekdays = weekdays
        self.maximumPlaybackSeconds = maximumPlaybackSeconds
        self.scheduleID = scheduleID
        self.role = role
        self.date = date
    }

    /// A stable role-specific namespace for device scheduling. AlarmKit UUIDs
    /// are persisted separately, but this identifier is useful for collision
    /// diagnostics and notification ownership.
    var scheduleSpecificIdentifier: String? {
        guard let scheduleID else { return nil }
        return "sleepcompanion.wake.\(scheduleID.uuidString.lowercased()).\(role.rawValue)"
    }
}

nonisolated enum WakeAlarmEventRole: String, Codable, CaseIterable, Sendable {
    case gentleAudio = "gentle_audio"
    case finalWake = "final_wake"
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

    /// Returns every independent wake event for a named schedule. A full sleep
    /// schedule can therefore produce a gentle pre-wake plan and a distinct
    /// final wake plan; a wake-only schedule simply omits bedtime handling.
    static func plans(for schedule: AlarmSchedule) -> [WakeAlarmPlan] {
        guard schedule.isValid, schedule.isEnabled else { return [] }

        switch schedule.kind {
        case .wakeOnlyOneTime:
            guard let date = schedule.oneTimeDate else { return [] }
            return oneTimePlans(for: schedule, date: date)
        case .wakeOnlyRecurring:
            return recurringWakePlans(
                for: schedule,
                wakeWeekdays: selectedWeekdays(schedule.weekdaysMask),
                scheduleID: schedule.id
            )
        case .sleep:
            guard let bedtimeHour = schedule.bedtimeHour,
                  let bedtimeMinute = schedule.bedtimeMinute
            else { return [] }
            let bedtimeMinuteOfDay = bedtimeHour * 60 + bedtimeMinute
            let wakeMinuteOfDay = schedule.wakeHour * 60 + schedule.wakeMinute
            let wakeWeekdays = selectedWeekdays(schedule.weekdaysMask).map { sleepWeekday in
                let overnight = wakeMinuteOfDay <= bedtimeMinuteOfDay
                return overnight ? (sleepWeekday == 7 ? 1 : sleepWeekday + 1) : sleepWeekday
            }
            return recurringWakePlans(
                for: schedule,
                wakeWeekdays: wakeWeekdays,
                scheduleID: schedule.id
            )
        }
    }

    static func plan(for schedule: AlarmSchedule) -> WakeAlarmPlan? {
        plans(for: schedule).first
    }

    private static func recurringWakePlans(
        for schedule: AlarmSchedule,
        wakeWeekdays: [Int],
        scheduleID: UUID
    ) -> [WakeAlarmPlan] {
        var result: [WakeAlarmPlan] = []
        let wakeMinuteOfDay = schedule.wakeHour * 60 + schedule.wakeMinute
        if let leadMinutes = schedule.wakeReminderLeadMinutes {
            let (minute, shiftedWeekdays) = shiftedWakeTime(
                minuteOfDay: wakeMinuteOfDay,
                leadMinutes: leadMinutes,
                weekdays: wakeWeekdays
            )
            result.append(
                WakeAlarmPlan(
                    hour: minute / 60,
                    minute: minute % 60,
                    weekdays: shiftedWeekdays,
                    maximumPlaybackSeconds: leadMinutes * 60,
                    scheduleID: scheduleID,
                    role: .gentleAudio
                )
            )
        }
        if schedule.finalWakeAlarmEnabled {
            result.append(
                WakeAlarmPlan(
                    hour: schedule.wakeHour,
                    minute: schedule.wakeMinute,
                    weekdays: wakeWeekdays,
                    maximumPlaybackSeconds: 0,
                    scheduleID: scheduleID,
                    role: .finalWake
                )
            )
        }
        return result
    }

    private static func oneTimePlans(
        for schedule: AlarmSchedule,
        date: AlarmLocalDate
    ) -> [WakeAlarmPlan] {
        let wakeMinuteOfDay = schedule.wakeHour * 60 + schedule.wakeMinute
        let weekday = date.date().map { Calendar.current.component(.weekday, from: $0) } ?? 1
        var result: [WakeAlarmPlan] = []
        if let leadMinutes = schedule.wakeReminderLeadMinutes {
            let (date, minute) = subtractingMinutes(
                leadMinutes,
                from: date,
                minuteOfDay: wakeMinuteOfDay
            )
            let adjustedWeekday = date.date().map {
                Calendar.current.component(.weekday, from: $0)
            } ?? weekday
            result.append(
                WakeAlarmPlan(
                    hour: minute / 60,
                    minute: minute % 60,
                    weekdays: [adjustedWeekday],
                    maximumPlaybackSeconds: leadMinutes * 60,
                    scheduleID: schedule.id,
                    role: .gentleAudio,
                    date: date
                )
            )
        }
        if schedule.finalWakeAlarmEnabled {
            result.append(
                WakeAlarmPlan(
                    hour: schedule.wakeHour,
                    minute: schedule.wakeMinute,
                    weekdays: [weekday],
                    maximumPlaybackSeconds: 0,
                    scheduleID: schedule.id,
                    role: .finalWake,
                    date: date
                )
            )
        }
        return result
    }

    private static func shiftedWakeTime(
        minuteOfDay: Int,
        leadMinutes: Int,
        weekdays: [Int]
    ) -> (Int, [Int]) {
        let total = minuteOfDay - leadMinutes
        let startsPreviousDay = total < 0
        let minute = ((total % (24 * 60)) + (24 * 60)) % (24 * 60)
        let shifted = startsPreviousDay
            ? weekdays.map { $0 == 1 ? 7 : $0 - 1 }
            : weekdays
        return (minute, shifted)
    }

    private static func subtractingMinutes(
        _ value: Int,
        from date: AlarmLocalDate,
        minuteOfDay: Int
    ) -> (AlarmLocalDate, Int) {
        let total = minuteOfDay - value
        let dayOffset = Int(floor(Double(total) / Double(24 * 60)))
        let minute = ((total % (24 * 60)) + (24 * 60)) % (24 * 60)
        return (date.addingDays(dayOffset), minute)
    }

    private static func selectedWeekdays(_ mask: Int) -> [Int] {
        (1 ... 7).filter { mask & (1 << ($0 - 1)) != 0 }
    }

    /// Determines if an enabled schedule has an active wake alarm due at the specified time.
    static func isWakeAlarmDue(
        for schedule: AlarmSchedule,
        at date: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard schedule.isValid, schedule.isEnabled else { return false }
        let plans = plans(for: schedule)
        let currentHour = calendar.component(.hour, from: date)
        let currentMinute = calendar.component(.minute, from: date)
        let currentWeekday = calendar.component(.weekday, from: date)
        let currentDate = AlarmLocalDate(date: date, calendar: calendar)

        for plan in plans {
            guard plan.role == .finalWake || (!schedule.finalWakeAlarmEnabled && plan.role == .gentleAudio) else {
                continue
            }
            guard plan.hour == currentHour && plan.minute == currentMinute else {
                continue
            }
            if let planDate = plan.date {
                if planDate == currentDate {
                    return true
                }
            } else if !plan.weekdays.isEmpty {
                if plan.weekdays.contains(currentWeekday) {
                    return true
                }
            }
        }
        return false
    }

    /// Stable key identifying a schedule's specific minute occurrence for deduplication.
    static func occurrenceMinuteKey(
        for scheduleID: UUID,
        at date: Date,
        calendar: Calendar = .current
    ) -> String {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return "\(scheduleID.uuidString)-\(year)-\(month)-\(day)-\(hour)-\(minute)"
    }

    /// Computes the exact next upcoming wake fire date for a schedule after a given date.
    static func nextWakeDate(
        for schedule: AlarmSchedule,
        after date: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        guard schedule.isValid, schedule.isEnabled else { return nil }
        let plans = plans(for: schedule)
        var candidates: [Date] = []

        for plan in plans {
            guard plan.role == .finalWake || (!schedule.finalWakeAlarmEnabled && plan.role == .gentleAudio) else {
                continue
            }

            if let planDate = plan.date, let baseDate = planDate.date(in: calendar) {
                var comp = calendar.dateComponents([.year, .month, .day], from: baseDate)
                comp.calendar = calendar
                comp.timeZone = calendar.timeZone
                comp.hour = plan.hour
                comp.minute = plan.minute
                comp.second = 0
                if let target = calendar.date(from: comp), target >= date.addingTimeInterval(-59) {
                    candidates.append(target)
                }
            } else if !plan.weekdays.isEmpty {
                for dayOffset in 0...7 {
                    guard let checkDay = calendar.date(byAdding: .day, value: dayOffset, to: date) else { continue }
                    let weekday = calendar.component(.weekday, from: checkDay)
                    if plan.weekdays.contains(weekday) {
                        var comp = calendar.dateComponents([.year, .month, .day], from: checkDay)
                        comp.calendar = calendar
                        comp.timeZone = calendar.timeZone
                        comp.hour = plan.hour
                        comp.minute = plan.minute
                        comp.second = 0
                        if let target = calendar.date(from: comp), target >= date.addingTimeInterval(-59) {
                            candidates.append(target)
                            break
                        }
                    }
                }
            }
        }

        return candidates.min()
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
