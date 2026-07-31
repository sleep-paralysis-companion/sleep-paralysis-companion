import Foundation
import UserNotifications

actor SleepReminderService: AppCreatedAlarmRemoving {
    private let center = UNUserNotificationCenter.current()
    private let identifierPrefix = "paralux.sleep.reminder."

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

    func requestPermissionAndSchedule(_ schedule: SleepSchedule) async throws -> ReminderAuthorizationState {
        guard schedule.isValid else { throw Phase1ActionError.invalidSchedule }
        let state = await authorizationState()
        let authorized: Bool
        switch state {
        case .notDetermined:
            authorized = try await center.requestAuthorization(options: [.alert, .sound])
        case .authorized, .provisional:
            authorized = true
        case .denied, .unavailable:
            authorized = false
        }
        guard authorized else { return .denied }
        try await replaceRequests(schedule)
        return await authorizationState()
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
        let requests = await center.pendingNotificationRequests()
        let identifiers = requests.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private func replaceRequests(_ schedule: SleepSchedule) async throws {
        try await removeAllAppCreatedAlarms()
        guard schedule.isEnabled else { return }
        for weekday in 1 ... 7 where schedule.weekdaysMask & (1 << (weekday - 1)) != 0 {
            var components = DateComponents()
            components.weekday = weekday
            let totalMinutes = schedule.sleepHour * 60 + schedule.sleepMinute - schedule.reminderLeadMinutes
            components.hour = (totalMinutes + 24 * 60) % (24 * 60) / 60
            components.minute = (totalMinutes + 24 * 60) % 60
            let content = UNMutableNotificationContent()
            content.title = "Wind down for sleep"
            content.body = "Your sleep reminder is ready. Open Paralux when you want to prepare."
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "\(identifierPrefix)\(weekday)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            )
            try await center.add(request)
        }
    }
}
