import SwiftUI

/// Create/edit surface for both recurring sleep schedules and one-time
/// wake-only alarms. The engine supplies audio choices and receives the
/// complete draft when the user taps Save.
struct AlarmScheduleEditorView: View {
    let originalSchedule: ScheduleUIModel?
    let audioOptions: [ScheduleUIAudioSelection]
    let onCancel: () -> Void
    let onSave: (ScheduleUIModel) -> Void
    let onDelete: ((ScheduleUIModel) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var nameIsFocused: Bool
    @State private var draft: ScheduleUIModel
    @State private var isDeleteConfirmationPresented = false
    @State private var isAudioExpanded = false

    init(
        schedule: ScheduleUIModel? = nil,
        audioOptions: [ScheduleUIAudioSelection] = [],
        onCancel: @escaping () -> Void = {},
        onSave: @escaping (ScheduleUIModel) -> Void = { _ in },
        onDelete: ((ScheduleUIModel) -> Void)? = nil
    ) {
        originalSchedule = schedule
        self.audioOptions = audioOptions
        self.onCancel = onCancel
        self.onSave = onSave
        self.onDelete = onDelete
        _draft = State(initialValue: schedule ?? .newSleep)
    }

    var body: some View {
        ZStack {
            NightBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    editorTypePicker

                    if draft.isWakeOnly {
                        wakeOnlyFields
                    } else {
                        sleepScheduleFields
                    }

                    optionsCard

                    saveButton

                    if originalSchedule != nil, onDelete != nil {
                        deleteButton
                    }
                }
                .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 18 : 24)
                .padding(.top, 18)
                .padding(.bottom, 34)
                .frame(maxWidth: 600, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("schedule.editor")
        .alert("Delete schedule?", isPresented: $isDeleteConfirmationPresented) {
            Button("Delete", role: .destructive) {
                guard let onDelete else { return }
                onDelete(draft)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This schedule will be removed from your alarm list.")
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: cancel) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.07))
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")
            .accessibilityIdentifier("schedule.editor.back")

            Text(originalSchedule == nil ? "New schedule" : "Edit schedule")
                .font(AppFont.latoBold(size: dynamicTypeSize.isAccessibilitySize ? 24 : 26, relativeTo: .title))
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 8)

            Button("Save", action: save)
                .font(AppFont.inter(size: 16, relativeTo: .headline, weight: .semibold))
                .foregroundStyle(draft.isValid ? Color(red: 0.72, green: 0.60, blue: 1) : Color.white.opacity(0.35))
                .disabled(!draft.isValid)
                .accessibilityIdentifier("schedule.editor.headerSave")
        }
    }

    private var editorTypePicker: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Alarm type")
                .font(AppTypographyRole.label)
                .foregroundStyle(Color.white.opacity(0.58))

            Picker("Alarm type", selection: kindBinding) {
                Text("Sleep schedule").tag(ScheduleUIKind.sleep)
                Text("Wake only").tag(ScheduleUIKind.wakeOnly)
            }
            .pickerStyle(.segmented)
            .tint(Color(red: 0.45, green: 0.22, blue: 0.92))
            .accessibilityIdentifier("schedule.editor.kind")
        }
    }

    // MARK: - Sleep Schedule Fields

    private var sleepScheduleFields: some View {
        VStack(alignment: .leading, spacing: 18) {
            ScheduleEditorCard {
                VStack(alignment: .leading, spacing: 14) {
                    scheduleSectionHeader(
                        title: "Bedtime",
                        symbol: "moon.fill",
                        color: Color(red: 0.72, green: 0.58, blue: 1)
                    )
                    ScheduleTimeWheelPicker(hour: $draft.bedtimeHour, minute: $draft.bedtimeMinute)
                }
            }

            ScheduleEditorCard {
                VStack(alignment: .leading, spacing: 14) {
                    scheduleSectionHeader(
                        title: "Wake up time",
                        symbol: "sun.max.fill",
                        color: Color(red: 1, green: 0.67, blue: 0.24)
                    )
                    ScheduleTimeWheelPicker(hour: $draft.wakeHour, minute: $draft.wakeMinute)
                }
            }

            ScheduleEditorCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Repeat days")
                        .font(AppFont.inter(size: 16, relativeTo: .headline, weight: .semibold))
                    WeekdaySelector(mask: $draft.repeatWeekdaysMask)
                    Text(weekdaySummary(draft.repeatWeekdaysMask))
                        .font(AppTypographyRole.footnote)
                        .foregroundStyle(Color.white.opacity(0.55))
                }
            }
        }
    }

    // MARK: - Wake Only Fields

    private var wakeOnlyFields: some View {
        VStack(alignment: .leading, spacing: 18) {
            ScheduleEditorCard {
                VStack(alignment: .leading, spacing: 14) {
                    scheduleSectionHeader(
                        title: "Date",
                        symbol: "calendar",
                        color: Color(red: 0.72, green: 0.57, blue: 1)
                    )
                    DatePicker(
                        "Date",
                        selection: oneTimeDateBinding,
                        in: Calendar.current.startOfDay(for: .now)...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(Color(red: 0.72, green: 0.57, blue: 1))
                    .accessibilityIdentifier("schedule.editor.oneTimeDate")
                }
            }

            ScheduleEditorCard {
                VStack(alignment: .leading, spacing: 14) {
                    scheduleSectionHeader(
                        title: "Wake up time",
                        symbol: "clock.fill",
                        color: Color(red: 1, green: 0.67, blue: 0.24)
                    )
                    ScheduleTimeWheelPicker(hour: $draft.wakeHour, minute: $draft.wakeMinute)
                }
            }

            Text("This alarm rings once on the selected date, then turns itself off.")
                .font(AppTypographyRole.footnote)
                .foregroundStyle(Color.white.opacity(0.55))
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Options Card

    private var optionsCard: some View {
        ScheduleEditorCard {
            VStack(alignment: .leading, spacing: 16) {
                // Name Field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Schedule name (optional)")
                        .font(AppTypographyRole.label)
                        .foregroundStyle(Color.white.opacity(0.58))
                    TextField("e.g. Work nights", text: $draft.name)
                        .font(AppFont.inter(size: 16, relativeTo: .body))
                        .focused($nameIsFocused)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityIdentifier("schedule.editor.name")
                }

                Divider().overlay(Color.white.opacity(0.10))

                // Bedtime reminder lead time
                if !draft.isWakeOnly {
                    reminderMenu(
                        title: "Bedtime reminder",
                        selection: $draft.bedtimeReminderLeadMinutes,
                        options: [5, 10, 15, 30, 60],
                        identifier: "schedule.editor.bedtimeReminder"
                    )
                    Divider().overlay(Color.white.opacity(0.10))
                }

                // Audio Selection
                audioSection

                Divider().overlay(Color.white.opacity(0.10))

                // Enabled Toggle
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Turn on after saving")
                            .font(AppTypographyRole.control)
                        Text(draft.isEnabled ? "This alarm will be scheduled." : "Save it as off for now.")
                            .font(AppTypographyRole.footnote)
                            .foregroundStyle(Color.white.opacity(0.55))
                    }
                    Spacer(minLength: 8)
                    ScheduleEditorToggle(isOn: $draft.isEnabled)
                }
                .accessibilityIdentifier("schedule.editor.enabled")
            }
        }
    }

    // MARK: - Audio Section

    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isAudioExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "music.note")
                        .foregroundStyle(Color(red: 0.72, green: 0.57, blue: 1))
                        .frame(width: 26)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Wake-up sound")
                            .font(AppTypographyRole.control)
                        Text(draft.wakeAudio.title)
                            .font(AppTypographyRole.footnote)
                            .foregroundStyle(Color.white.opacity(0.65))
                    }

                    Spacer(minLength: 8)

                    Image(systemName: isAudioExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.45))
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Wake-up sound: \(draft.wakeAudio.title)")
            .accessibilityIdentifier("schedule.editor.audio")

            if isAudioExpanded {
                VStack(spacing: 0) {
                    ForEach(audioChoices) { option in
                        AudioChoiceRow(
                            option: option,
                            isSelected: option.id == draft.wakeAudio.id,
                            action: {
                                draft.wakeAudio = option
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isAudioExpanded = false
                                }
                            }
                        )
                        if option.id != audioChoices.last?.id {
                            Divider().overlay(Color.white.opacity(0.10))
                        }
                    }
                }
                .padding(.top, 4)
            }

            if !draft.wakeAudio.isAvailable {
                Label("Audio unavailable on this device", systemImage: "exclamationmark.triangle.fill")
                    .font(AppTypographyRole.footnote)
                    .foregroundStyle(Color.orange.opacity(0.92))
                    .padding(.top, 2)
                    .accessibilityIdentifier("schedule.editor.audioUnavailable")
            }
        }
    }

    // MARK: - Save and Delete Buttons

    private var saveButton: some View {
        Button(action: save) {
            Label(originalSchedule == nil ? "Create schedule" : "Save changes", systemImage: "checkmark")
        }
        .buttonStyle(AppPrimaryButtonStyle())
        .disabled(!draft.isValid)
        .accessibilityIdentifier("schedule.editor.save")
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            isDeleteConfirmationPresented = true
        } label: {
            Label("Delete schedule", systemImage: "trash")
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .font(AppTypographyRole.control)
        .foregroundStyle(Color.red.opacity(0.9))
        .accessibilityIdentifier("schedule.editor.delete")
    }

    // MARK: - Helpers

    private func scheduleSectionHeader(title: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(title)
                .font(AppFont.latoBold(size: 20, relativeTo: .title3))
        }
    }

    private func reminderMenu(
        title: String,
        selection: Binding<Int?>,
        options: [Int],
        identifier: String
    ) -> some View {
        Menu {
            Button("Off") { selection.wrappedValue = nil }
            ForEach(options, id: \.self) { option in
                Button("\(option) minutes before") {
                    selection.wrappedValue = option
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: title == "Bedtime reminder" ? "bell.fill" : "sunrise.fill")
                    .foregroundStyle(Color(red: 0.72, green: 0.57, blue: 1))
                    .frame(width: 26)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(AppTypographyRole.control)
                    Text(selection.wrappedValue.map { "\($0) min before" } ?? "Off")
                        .font(AppTypographyRole.footnote)
                        .foregroundStyle(Color.white.opacity(0.55))
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(selection.wrappedValue.map { "\($0) minutes before" } ?? "Off")
        .accessibilityIdentifier(identifier)
    }

    private var kindBinding: Binding<ScheduleUIKind> {
        Binding(
            get: { draft.kind },
            set: { kind in
                draft.kind = kind
                if kind == .wakeOnly {
                    if draft.oneTimeDate == nil {
                        draft.oneTimeDate = Calendar.current.date(byAdding: .day, value: 1, to: .now)
                    }
                    draft.repeatWeekdaysMask = 0
                } else {
                    draft.oneTimeDate = nil
                    if draft.repeatWeekdaysMask == 0 {
                        draft.repeatWeekdaysMask = 0b0111_1111
                    }
                    if draft.bedtimeReminderLeadMinutes == nil {
                        draft.bedtimeReminderLeadMinutes = 15
                    }
                }
            }
        )
    }

    private var oneTimeDateBinding: Binding<Date> {
        Binding(
            get: { draft.oneTimeDate ?? Calendar.current.startOfDay(for: .now) },
            set: { draft.oneTimeDate = Calendar.current.startOfDay(for: $0) }
        )
    }

    private var audioChoices: [ScheduleUIAudioSelection] {
        let choices = audioOptions.isEmpty
            ? [.bundled(id: SystemAudioAssets.defaultAlarmAssetID, title: "Gentle rise")]
            : audioOptions
        guard !choices.contains(where: { $0.id == draft.wakeAudio.id }) else { return choices }
        return [draft.wakeAudio] + choices
    }

    private func cancel() {
        onCancel()
        dismiss()
    }

    private func save() {
        guard draft.isValid else {
            nameIsFocused = true
            return
        }
        onSave(draft)
        dismiss()
    }
}

private struct ScheduleEditorCard<Content: View>: View {
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

private struct ScheduleEditorToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Toggle("", isOn: $isOn)
            .labelsHidden()
            .tint(Color(red: 0.48, green: 0.20, blue: 0.94))
            .accessibilityLabel("Turn on after saving")
    }
}

// MARK: - Time Wheel Picker

private struct ScheduleTimeWheelPicker: View {
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
                .font(AppFont.latoBold(size: 26, relativeTo: .title2))
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

private struct ScheduleWheelColumn<Value: Hashable>: View {
    @Binding var selection: Value
    let values: [Value]
    let label: (Value) -> String

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(values, id: \.self) { value in
                Text(label(value))
                    .font(AppFont.latoBold(size: 26, relativeTo: .title2))
                    .tag(value)
            }
        }
        .pickerStyle(.wheel)
        .labelsHidden()
        .frame(width: 80, height: 130)
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

private struct WeekdaySelector: View {
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

private struct AudioChoiceRow: View {
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
