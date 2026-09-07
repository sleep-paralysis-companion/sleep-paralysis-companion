import SwiftUI

struct ScheduleEditorCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(17)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
    }
}

struct ScheduleEditorToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Toggle("", isOn: $isOn)
            .labelsHidden()
            .tint(Color(red: 0.48, green: 0.20, blue: 0.94))
            .accessibilityLabel("Turn on after saving")
    }
}

// MARK: - Time Wheel Picker

struct ScheduleTimeWheelPicker: View {
    @Binding var hour: Int
    @Binding var minute: Int

    var body: some View {
        HStack(spacing: 8) {
            ScheduleWheelColumn(
                selection: displayedHour,
                values: Array(1 ... 12),
                label: { String(format: "%02d", $0) }
            )

            Text(":")
                .font(AppFont.latoBold(size: 32, relativeTo: .title))
                .foregroundStyle(Color.white.opacity(0.55))

            ScheduleWheelColumn(
                selection: $minute,
                values: Array(0 ... 59),
                label: { String(format: "%02d", $0) }
            )

            ScheduleWheelColumn(
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
                hour = isPM.wrappedValue ? (selectedHour % 12) + 12 : (selectedHour % 12)
            }
        )
    }

    private var isPM: Binding<Bool> {
        Binding(
            get: { hour >= 12 },
            set: { selectedPM in
                let twelveHourValue = ((hour + 11) % 12) + 1
                hour = selectedPM ? (twelveHourValue % 12) + 12 : (twelveHourValue % 12)
            }
        )
    }
}

struct ScheduleWheelColumn<Value: Hashable>: View {
    @Binding var selection: Value
    let values: [Value]
    let label: (Value) -> String

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(values, id: \.self) { value in
                let isSelected = value == selection
                Text(label(value))
                    .font(
                        isSelected
                            ? AppFont.latoBold(size: 36, relativeTo: .title)
                            : AppFont.inter(size: 22, relativeTo: .body, weight: .regular)
                    )
                    .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.40))
                    .tag(value)
            }
        }
        .pickerStyle(.wheel)
        .labelsHidden()
        .frame(width: 84, height: 160)
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white, location: 0.25),
                    .init(color: .white, location: 0.75),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Weekday Selector

struct WeekdaySelector: View {
    @Binding var mask: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1 ... 7, id: \.self) { weekday in
                Button {
                    mask ^= 1 << (weekday - 1)
                } label: {
                    Text(shortLabel(for: weekday))
                        .font(AppFont.inter(size: 14, relativeTo: .caption, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(
                            includes(weekday)
                                ? Color(red: 0.45, green: 0.28, blue: 0.90)
                                : Color.white.opacity(0.08)
                        )
                        .foregroundStyle(includes(weekday) ? .white : Color.white.opacity(0.65))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(
                                    includes(weekday)
                                        ? Color(red: 0.72, green: 0.60, blue: 1).opacity(0.6)
                                        : Color.white.opacity(0.12),
                                    lineWidth: 1
                                )
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(fullLabel(for: weekday))
                .accessibilityValue(includes(weekday) ? "Selected" : "Not selected")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("schedule.editor.repeatDays")
    }

    private func includes(_ weekday: Int) -> Bool {
        mask & (1 << (weekday - 1)) != 0
    }

    private func shortLabel(for weekday: Int) -> String {
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
        return symbols.indices.contains(weekday - 1) ? symbols[weekday - 1] : "\(weekday)"
    }

    private func fullLabel(for weekday: Int) -> String {
        let symbols = Calendar.current.standaloneWeekdaySymbols
        return symbols.indices.contains(weekday - 1) ? symbols[weekday - 1] : "Day \(weekday)"
    }
}

struct AudioChoiceRow: View {
    let option: ScheduleUIAudioSelection
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isSelected ? Color(red: 0.76, green: 0.64, blue: 1) : Color.white.opacity(0.58))
                    .frame(width: 26)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(option.title)
                        .font(AppTypographyRole.control)
                        .foregroundStyle(option.isAvailable ? .white : Color.white.opacity(0.52))
                    Text(option.sourceTitle)
                        .font(AppTypographyRole.caption)
                        .foregroundStyle(Color.white.opacity(0.47))
                }
                Spacer(minLength: 8)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(red: 0.72, green: 0.57, blue: 1))
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!option.isAvailable)
        .accessibilityLabel(option.title)
        .accessibilityValue(isSelected ? "Selected" : option.sourceTitle)
    }

    private var icon: String {
        switch option {
        case .bundled:
            "waveform"
        case .catalog:
            "music.note.list"
        case .personal:
            "person.wave.2"
        case .unavailable:
            "exclamationmark.triangle"
        }
    }
}
