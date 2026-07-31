import SwiftUI

struct SleepScheduleView: View {
    @Bindable var model: AppModel
    var isOnboarding = false

    @State private var schedule = SleepSchedule.defaultValue
    @State private var initialized = false

    var body: some View {
        NightScreen {
            VStack(alignment: .leading, spacing: AppSpacing.spacious) {
                Text("Sleep schedule")
                    .font(AppTypographyRole.screenTitle)
                    .accessibilityAddTraits(.isHeader)
                Text("Create an ordinary sleep reminder. Paralux does not claim to wake you like a system alarm.")
                    .foregroundStyle(.white.opacity(0.72))

                NightCard {
                    DatePicker(
                        "Time to sleep",
                        selection: sleepTime,
                        displayedComponents: .hourAndMinute
                    )
                    DatePicker(
                        "Wake-up time",
                        selection: wakeTime,
                        displayedComponents: .hourAndMinute
                    )
                }

                NightCard {
                    Toggle("Enable sleep reminders", isOn: $schedule.isEnabled)
                    Picker("Remind me before bedtime", selection: $schedule.reminderLeadMinutes) {
                        Text("At bedtime").tag(0)
                        Text("5 minutes").tag(5)
                        Text("10 minutes").tag(10)
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                        Text("1 hour").tag(60)
                    }
                    .disabled(!schedule.isEnabled)
                }

                NightCard {
                    Text("Reminder days")
                        .font(.headline)
                    HStack(spacing: 7) {
                        ForEach(1 ... 7, id: \.self) { weekday in
                            Button {
                                toggle(weekday: weekday)
                            } label: {
                                Text(weekdayLabel(weekday))
                                    .font(.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 34)
                            }
                            .buttonStyle(
                                .borderedProminent
                            )
                            .tint(includes(weekday: weekday) ? .indigo : .gray.opacity(0.45))
                            .accessibilityValue(includes(weekday: weekday) ? "Selected" : "Not selected")
                        }
                    }
                    .disabled(!schedule.isEnabled)
                }

                NightCard {
                    Label(permissionTitle, systemImage: permissionIcon)
                        .font(.headline)
                    Text(permissionDetail)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.68))
                }

                Button(isOnboarding ? "Save schedule and open Home" : "Save schedule") {
                    model.saveSleepSchedule(
                        schedule,
                        requestPermission: schedule.isEnabled && model.reminderAuthorization == .notDetermined
                    )
                }
                .buttonStyle(AppPrimaryButtonStyle())
                .disabled(!schedule.isValid)

                Text("If notifications are denied or later revoked, the schedule remains available in the app.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.58))
            }
            .padding(.top, isOnboarding ? 32 : 0)
        }
        .navigationTitle(isOnboarding ? "" : "Sleep schedule")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !initialized else { return }
            schedule = model.sleepSchedule
            initialized = true
        }
    }

    private var sleepTime: Binding<Date> {
        Binding(
            get: { date(hour: schedule.sleepHour, minute: schedule.sleepMinute) },
            set: {
                let components = Calendar.current.dateComponents([.hour, .minute], from: $0)
                schedule.sleepHour = components.hour ?? schedule.sleepHour
                schedule.sleepMinute = components.minute ?? schedule.sleepMinute
            }
        )
    }

    private var wakeTime: Binding<Date> {
        Binding(
            get: { date(hour: schedule.wakeHour, minute: schedule.wakeMinute) },
            set: {
                let components = Calendar.current.dateComponents([.hour, .minute], from: $0)
                schedule.wakeHour = components.hour ?? schedule.wakeHour
                schedule.wakeMinute = components.minute ?? schedule.wakeMinute
            }
        )
    }

    private func date(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    private func includes(weekday: Int) -> Bool {
        schedule.weekdaysMask & (1 << (weekday - 1)) != 0
    }

    private func toggle(weekday: Int) {
        schedule.weekdaysMask ^= 1 << (weekday - 1)
    }

    private func weekdayLabel(_ weekday: Int) -> String {
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
        guard symbols.indices.contains(weekday - 1) else { return "\(weekday)" }
        return symbols[weekday - 1]
    }

    private var permissionTitle: String {
        switch model.reminderAuthorization {
        case .notDetermined: "Permission requested when you save"
        case .authorized, .provisional: "Notifications allowed"
        case .denied: "Notifications are off"
        case .unavailable: "Notifications unavailable"
        }
    }

    private var permissionDetail: String {
        switch model.reminderAuthorization {
        case .notDetermined: "The system prompt appears only if reminders are enabled."
        case .authorized, .provisional: "Paralux can schedule the ordinary reminders you selected."
        case .denied: "Open iOS Settings if you want reminders. App access is not blocked."
        case .unavailable: "Use the in-app schedule without notifications."
        }
    }

    private var permissionIcon: String {
        switch model.reminderAuthorization {
        case .authorized, .provisional: "bell.badge.fill"
        case .denied: "bell.slash.fill"
        case .notDetermined, .unavailable: "bell"
        }
    }
}
