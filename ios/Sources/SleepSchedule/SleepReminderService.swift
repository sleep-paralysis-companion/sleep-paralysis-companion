import Foundation
import UserNotifications

nonisolated struct SleepReminderPlan: Equatable, Sendable {
    let identifier: String
    let weekday: Int
    let hour: Int
    let minute: Int
    let scheduleID: UUID?
    let date: AlarmLocalDate?
    let repeats: Bool

    init(
        identifier: String,
        weekday: Int,
        hour: Int,
        minute: Int,
        scheduleID: UUID? = nil,
        date: AlarmLocalDate? = nil,
        repeats: Bool = true
    ) {
        self.identifier = identifier
        self.weekday = weekday
        self.hour = hour
        self.minute = minute
        self.scheduleID = scheduleID
        self.date = date
        self.repeats = repeats
    }
}

nonisolated enum SleepReminderPlanner {
    static let identifierPrefix = "sleepcompanion.sleep.reminder."
    private static let legacyIdentifierPrefixes = ["paralux.sleep.reminder."]

    static func owns(identifier: String) -> Bool {
        identifier.hasPrefix(identifierPrefix)
            || legacyIdentifierPrefixes.contains { identifier.hasPrefix($0) }
    }

    static func owns(identifier: String, scheduleID: UUID) -> Bool {
        let prefix = "\(identifierPrefix)\(scheduleID.uuidString.lowercased())."
        return identifier.hasPrefix(prefix)
    }

    static func identifier(for scheduleID: UUID, weekday: Int) -> String {
        "\(identifierPrefix)\(scheduleID.uuidString.lowercased()).\(weekday)"
    }

    static func plans(for schedule: SleepSchedule) -> [SleepReminderPlan] {
        guard schedule.isValid, schedule.isEnabled else { return [] }
        let unwrappedMinutes = schedule.sleepHour * 60
            + schedule.sleepMinute
            - schedule.reminderLeadMinutes
        let crossesMidnight = unwrappedMinutes < 0
        let minuteOfDay = (unwrappedMinutes + 24 * 60) % (24 * 60)

        return (1 ... 7).compactMap { sleepWeekday in
            guard schedule.weekdaysMask & (1 << (sleepWeekday - 1)) != 0 else {
                return nil
            }
            let reminderWeekday = crossesMidnight
                ? (sleepWeekday == 1 ? 7 : sleepWeekday - 1)
                : sleepWeekday
            return SleepReminderPlan(
                identifier: "\(identifierPrefix)\(sleepWeekday)",
                weekday: reminderWeekday,
                hour: minuteOfDay / 60,
                minute: minuteOfDay % 60
            )
        }
    }

    static func plans(for schedule: AlarmSchedule) -> [SleepReminderPlan] {
        guard schedule.isValid,
              schedule.isEnabled,
              schedule.kind == .sleep,
              let bedtimeHour = schedule.bedtimeHour,
              let bedtimeMinute = schedule.bedtimeMinute,
              let reminderLead = schedule.bedtimeReminderLeadMinutes
        else { return [] }

        let unwrappedMinutes = bedtimeHour * 60 + bedtimeMinute - reminderLead
        let crossesMidnight = unwrappedMinutes < 0
        let minuteOfDay = (unwrappedMinutes + 24 * 60) % (24 * 60)

        return (1 ... 7).compactMap { sleepWeekday in
            guard schedule.weekdaysMask & (1 << (sleepWeekday - 1)) != 0 else {
                return nil
            }
            let reminderWeekday = crossesMidnight
                ? (sleepWeekday == 1 ? 7 : sleepWeekday - 1)
                : sleepWeekday
            return SleepReminderPlan(
                identifier: identifier(for: schedule.id, weekday: sleepWeekday),
                weekday: reminderWeekday,
                hour: minuteOfDay / 60,
                minute: minuteOfDay % 60,
                scheduleID: schedule.id
            )
        }
    }
}

nonisolated protocol ReminderNotificationScheduling: Sendable {
    func authorizationState() async -> ReminderAuthorizationState
    func requestAuthorization() async throws -> Bool
    func pendingIdentifiers() async -> [String]
    func remove(identifiers: [String]) async
    func add(_ plan: SleepReminderPlan) async throws
}

actor SystemReminderNotificationScheduler: ReminderNotificationScheduling {
    private let center = UNUserNotificationCenter.current()

    func authorizationState() async -> ReminderAuthorizationState {
        let settings = await center.notificationSettings()
        return switch settings.authorizationStatus {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .authorized, .ephemeral: .authorized
        case .provisional: .provisional
        @unknown default: .unavailable
        }
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func pendingIdentifiers() async -> [String] {
        await center.pendingNotificationRequests().map(\.identifier)
    }

    func remove(identifiers: [String]) async {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func add(_ plan: SleepReminderPlan) async throws {
        var components = DateComponents()
        components.weekday = plan.weekday
        components.hour = plan.hour
        components.minute = plan.minute
        let content = UNMutableNotificationContent()
        content.title = "Wind down for sleep"
        content.body = "Your sleep reminder is ready. Open Sleep Paralysis Companion when you want to prepare."
        content.sound = SystemAudioAssets.notificationSound()
        try await center.add(
            UNNotificationRequest(
                identifier: plan.identifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(
                    dateMatching: components,
                    repeats: true
                )
            )
        )
    }
}

actor SleepReminderService: AppCreatedAlarmRemoving {
    private let scheduler: any ReminderNotificationScheduling

    init(
        scheduler: any ReminderNotificationScheduling = SystemReminderNotificationScheduler()
    ) {
        self.scheduler = scheduler
    }

    func authorizationState() async -> ReminderAuthorizationState {
        await scheduler.authorizationState()
    }

    func requestPermissionAndSchedule(_ schedule: SleepSchedule) async throws -> ReminderAuthorizationState {
        guard schedule.isValid else { throw Phase1ActionError.invalidSchedule }
        let state = await authorizationState()
        let authorized: Bool = switch state {
        case .notDetermined:
            try await scheduler.requestAuthorization()
        case .authorized, .provisional:
            true
        case .denied, .unavailable:
            false
        }
        guard authorized else { return .denied }
        try await replaceRequests(schedule)
        return await authorizationState()
    }

    func requestPermission() async throws -> ReminderAuthorizationState {
        let state = await authorizationState()
        guard state == .notDetermined else { return state }
        _ = try await scheduler.requestAuthorization()
        return await authorizationState()
    }

    func requestPermissionAndSchedule(
        _ schedules: [AlarmSchedule]
    ) async throws -> ReminderAuthorizationState {
        try AlarmScheduleValidator.validate(schedules)
        let state = await authorizationState()
        let authorized: Bool = switch state {
        case .notDetermined:
            try await scheduler.requestAuthorization()
        case .authorized, .provisional:
            true
        case .denied, .unavailable:
            false
        }
        guard authorized else { return .denied }
        try await replaceRequests(schedules)
        return await authorizationState()
    }

    func updateWithoutPrompt(
        _ schedules: [AlarmSchedule]
    ) async throws -> ReminderAuthorizationState {
        try AlarmScheduleValidator.validate(schedules)
        let state = await authorizationState()
        guard state == .authorized || state == .provisional else {
            // Disabling or deleting schedules must still cancel their owned requests.
            if schedules.allSatisfy({ !$0.isEnabled }) {
                try await replaceRequests(schedules)
            }
            return state
        }
        try await replaceRequests(schedules)
        return state
    }

    func updateWithoutPrompt(_ schedule: SleepSchedule) async throws -> ReminderAuthorizationState {
        let state = await authorizationState()
        if !schedule.isEnabled {
            try await replaceRequests(schedule)
            return state
        }
        guard state == .authorized || state == .provisional else { return state }
        try await replaceRequests(schedule)
        return state
    }

    func removeAllAppCreatedAlarms() async throws {
        let identifiers = await scheduler.pendingIdentifiers().filter {
            SleepReminderPlanner.owns(identifier: $0)
        }
        await scheduler.remove(identifiers: identifiers)
    }

    private func replaceRequests(_ schedule: SleepSchedule) async throws {
        try await removeAllAppCreatedAlarms()
        for plan in SleepReminderPlanner.plans(for: schedule) {
            try await scheduler.add(plan)
        }
    }

    private func replaceRequests(_ schedules: [AlarmSchedule]) async throws {
        try await removeAllAppCreatedAlarms()
        for schedule in schedules {
            for plan in SleepReminderPlanner.plans(for: schedule) {
                try await scheduler.add(plan)
            }
        }
    }

}
