import SwiftUI

struct SleepScheduleView: View {
    @Bindable var model: AppModel
    var isOnboarding = false

    @State private var schedule = SleepSchedule.defaultValue
    @State private var initialized = false

    var body: some View {
        FigmaSleepScheduleContent(
            schedule: $schedule,
            isOnboarding: isOnboarding,
            wakeAlarmOutcome: model.wakeAlarmOutcome
        ) {
            if isOnboarding {
                schedule.isEnabled = true
                schedule.reminderLeadMinutes = 15
            }
            model.saveSleepSchedule(
                schedule,
                requestPermission: schedule.isEnabled && model.reminderAuthorization == .notDetermined
            )
        }
        .navigationTitle(isOnboarding ? "" : "Sleep schedule")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isOnboarding ? .hidden : .visible, for: .navigationBar)
        .task {
            guard !initialized else { return }
            schedule = model.sleepSchedule
            initialized = true
        }
    }
}
