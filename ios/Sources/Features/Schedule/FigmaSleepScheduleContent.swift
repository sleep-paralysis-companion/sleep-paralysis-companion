import SwiftUI

struct FigmaSleepScheduleContent: View {
    @Binding var schedule: SleepSchedule
    let isOnboarding: Bool
    let wakeAlarmOutcome: WakeAlarmSchedulingOutcome
    let save: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isWakeReminderPresented = false

    var body: some View {
        ZStack {
            NightBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MoonMark(size: 115)
                        .frame(maxWidth: .infinity)
                        .padding(.top, isOnboarding ? 46 : 22)

                    Text("What time do you want to sleep?")
                        .font(.system(size: dynamicTypeSize.isAccessibilitySize ? 28 : 34, weight: .bold))
                        .tracking(-0.7)
                        .padding(.top, 32)
                        .accessibilityAddTraits(.isHeader)

                    Text(
                        "We'll remind you 15 minutes before bedtime, giving you time to relax "
                            + "and prepare for sleep peacefully."
                    )
                    .font(.system(size: 18, weight: .regular, design: .rounded))
                    .foregroundStyle(Color(red: 0.62, green: 0.59, blue: 0.76))
                    .lineSpacing(4)
                    .padding(.top, 12)

                    scheduleHeading(title: "Bedtime", symbol: "moon.fill")
                        .padding(.top, 42)
                    SleepTimeWheelPicker(hour: $schedule.sleepHour, minute: $schedule.sleepMinute)
                        .padding(.top, 14)

                    scheduleHeading(title: "Wake up time", symbol: "sun.max.fill")
                        .padding(.top, 38)
                    SleepTimeWheelPicker(hour: $schedule.wakeHour, minute: $schedule.wakeMinute)
                        .padding(.top, 14)

                    reminderDays
                        .padding(.top, 18)

                    wakeReminderRow
                        .padding(.top, 26)

                    if schedule.wakeAlarmIsRequested, wakeAlarmOutcome == .audioAssetUnavailable {
                        Text(
                            "Your wake-up reminder choice is saved. Gentle audio will become available "
                                + "once it is added to the app."
                        )
                        .font(.footnote)
                        .foregroundStyle(Color(red: 0.64, green: 0.60, blue: 0.78))
                        .padding(.top, 12)
                        .accessibilityIdentifier("schedule.wakeReminder.assetUnavailable")
                    }

                    saveButton
                        .padding(.top, 30)

                    if !isOnboarding {
                        Text(
                            "Bedtime reminders use your notification preference. Wake-up audio needs its own "
                                + "alarm permission once the audio asset is included."
                        )
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.62))
                        .padding(.top, 16)
                    }
                }
                .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 18 : 30)
                .padding(.bottom, 34)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $isWakeReminderPresented) {
            WakeReminderConfigurationView(
                leadMinutes: $schedule.wakeReminderLeadMinutes,
                alarmOutcome: wakeAlarmOutcome
            )
        }
    }

    private func scheduleHeading(title: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title2.weight(.medium))
                .foregroundStyle(
                    title == "Bedtime"
                        ? Color(red: 0.69, green: 0.54, blue: 1)
                        : Color(red: 1, green: 0.78, blue: 0.29)
                )
                .frame(width: 30)
                .accessibilityHidden(true)
            Text(title)
                .font(.system(size: 26, weight: .bold))
        }
    }

    private var reminderDays: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reminder days")
                .font(.headline)
            HStack(spacing: 7) {
                ForEach(1 ... 7, id: \.self) { weekday in
                    Button {
                        toggle(weekday: weekday)
                    } label: {
                        Text(weekdayLabel(weekday))
                            .font(.caption.weight(.bold))
                            .frame(width: 38, height: 38)
                            .background(
                                includes(weekday: weekday)
                                    ? Color.indigo.opacity(0.78)
                                    : Color.white.opacity(0.08)
                            )
                            .clipShape(Circle())
                            .overlay {
                                Circle()
                                    .stroke(
                                        includes(weekday: weekday)
                                            ? Color(red: 0.54, green: 0.43, blue: 1)
                                            : Color.white.opacity(0.18),
                                        lineWidth: 1
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(weekdayAccessibilityLabel(weekday))
                    .accessibilityValue(includes(weekday: weekday) ? "Selected" : "Not selected")
                }
            }
        }
    }

    private var wakeReminderRow: some View {
        Button {
            isWakeReminderPresented = true
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "bell.badge.fill")
                    .font(.title3)
                    .foregroundStyle(Color(red: 0.73, green: 0.63, blue: 1))
                    .frame(width: 58, height: 58)
                    .background(Color(red: 0.18, green: 0.17, blue: 0.49))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Wake-up reminder")
                        .font(.headline)
                    Text(wakeReminderDescription)
                        .font(.subheadline)
                        .foregroundStyle(Color(red: 0.62, green: 0.59, blue: 0.76))
                }
                Spacer(minLength: 12)
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.46))
                    .accessibilityHidden(true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.08, green: 0.05, blue: 0.22).opacity(0.88))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color(red: 0.33, green: 0.25, blue: 0.62).opacity(0.52))
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("schedule.wakeReminder")
        .accessibilityHint("Choose when gentle wake-up audio begins")
    }

    private var saveButton: some View {
        Button(action: save) {
            Label("Save Sleep Schedule", systemImage: "sparkles")
                .font(.system(size: 19, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 64)
        }
        .foregroundStyle(.white)
        .background(
            LinearGradient(
                colors: [Color(red: 0.40, green: 0.28, blue: 0.83), Color(red: 0.20, green: 0.49, blue: 0.84)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .disabled(!schedule.isValid || schedule.weekdaysMask == 0)
        .opacity(schedule.isValid && schedule.weekdaysMask != 0 ? 1 : 0.48)
        .accessibilityIdentifier("schedule.save")
    }

    private var wakeReminderDescription: String {
        guard let leadMinutes = schedule.wakeReminderLeadMinutes else {
            return "Off"
        }
        return "\(leadMinutes) minutes before wake-up"
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

    private func weekdayAccessibilityLabel(_ weekday: Int) -> String {
        let symbols = Calendar.current.standaloneWeekdaySymbols
        guard symbols.indices.contains(weekday - 1) else { return "Day \(weekday)" }
        return symbols[weekday - 1]
    }
}

private struct SleepTimeWheelPicker: View {
    @Binding var hour: Int
    @Binding var minute: Int

    var body: some View {
        HStack(spacing: 14) {
            SleepWheelColumn(
                selection: displayedHour,
                values: Array(1 ... 12),
                label: { String(format: "%02d", $0) }
            )
            SleepWheelColumn(
                selection: $minute,
                values: Array(0 ... 59),
                label: { String(format: "%02d", $0) }
            )
            SleepWheelColumn(
                selection: isPM,
                values: [false, true],
                label: { $0 ? "PM" : "AM" }
            )
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    private var displayedHour: Binding<Int> {
        Binding(
            get: { ((hour + 11) % 12) + 1 },
            set: { selectedHour in
                hour = isPM.wrappedValue ? selectedHour % 12 + 12 : selectedHour % 12
            }
        )
    }

    private var isPM: Binding<Bool> {
        Binding(
            get: { hour >= 12 },
            set: { selectedPM in
                let twelveHourValue = ((hour + 11) % 12) + 1
                hour = selectedPM ? twelveHourValue % 12 + 12 : twelveHourValue % 12
            }
        )
    }
}

private struct SleepWheelColumn<Value: Hashable>: View {
    @Binding var selection: Value
    let values: [Value]
    let label: (Value) -> String

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(values, id: \.self) { value in
                Text(label(value))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .tag(value)
            }
        }
        .pickerStyle(.wheel)
        .labelsHidden()
        .frame(width: 88, height: 168)
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white, location: 0.28),
                    .init(color: .white, location: 0.72),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .accessibilityElement(children: .contain)
    }
}

private struct WakeReminderConfigurationView: View {
    @Binding var leadMinutes: Int?
    let alarmOutcome: WakeAlarmSchedulingOutcome

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Start gentle wake-up audio") {
                    ForEach(SleepSchedule.wakeReminderLeadOptions, id: \.self) { option in
                        Button {
                            leadMinutes = option
                            dismiss()
                        } label: {
                            HStack {
                                Text("\(option) minutes before wake-up")
                                Spacer()
                                if leadMinutes == option {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.indigo)
                                }
                            }
                        }
                    }

                    Button(role: .destructive) {
                        leadMinutes = nil
                        dismiss()
                    } label: {
                        HStack {
                            Text("Off")
                            Spacer()
                            if leadMinutes == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                if alarmOutcome == .audioAssetUnavailable {
                    Section {
                        Text(
                            "Your chosen time was saved, but the wake-up alarm was not scheduled "
                                + "because its local sound is unavailable or invalid."
                        )
                        .font(.footnote)
                    }
                }

                if alarmOutcome == .fallbackScheduled {
                    Section {
                        Text(
                            "The selected wake-up sound was unavailable, so the bundled local "
                                + "fallback was scheduled instead."
                        )
                        .font(.footnote)
                    }
                }
            }
            .navigationTitle("Wake-up reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: dismiss.callAsFunction)
                }
            }
        }
    }
}
