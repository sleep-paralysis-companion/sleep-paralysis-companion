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
                VStack(alignment: .leading, spacing: 22) {
                    header
                    editorTypePicker
                    nameField

                    if draft.isWakeOnly {
                        wakeOnlyFields
                    } else {
                        sleepScheduleFields
                    }

                    enabledField
                    audioField
                    saveButton

                    if originalSchedule != nil, onDelete != nil {
                        deleteButton
                    }
                }
                .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 18 : 24)
                .padding(.top, 18)
                .padding(.bottom, 34)
                .frame(maxWidth: 680, alignment: .leading)
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

    private var nameField: some View {
        ScheduleEditorCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(AppTypographyRole.label)
                    .foregroundStyle(Color.white.opacity(0.58))
                TextField("e.g. Work nights", text: $draft.name)
                    .font(AppFont.inter(size: 18, relativeTo: .body))
                    .focused($nameIsFocused)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .accessibilityIdentifier("schedule.editor.name")
            }
        }
    }

    private var sleepScheduleFields: some View {
        VStack(alignment: .leading, spacing: 18) {
            ScheduleEditorCard {
                VStack(alignment: .leading, spacing: 13) {
                    Text("Sleep times")
                        .font(AppTypographyRole.subsectionTitle)
                    timePickerRow(title: "Bedtime", symbol: "moon.fill", selection: bedtimeBinding)
                    Divider().overlay(Color.white.opacity(0.10))
                    timePickerRow(title: "Wake time", symbol: "sun.max.fill", selection: wakeTimeBinding)
                }
            }

            ScheduleEditorCard {
                VStack(alignment: .leading, spacing: 13) {
                    Text("Repeat days")
                        .font(AppTypographyRole.subsectionTitle)
                    WeekdaySelector(mask: $draft.repeatWeekdaysMask)
                    Text(weekdaySummary(draft.repeatWeekdaysMask))
                        .font(AppTypographyRole.footnote)
                        .foregroundStyle(Color.white.opacity(0.55))
                }
            }

            ScheduleEditorCard {
                VStack(alignment: .leading, spacing: 2) {
                    reminderMenu(
                        title: "Bedtime reminder",
                        selection: $draft.bedtimeReminderLeadMinutes,
                        options: [5, 10, 15, 30, 60],
                        identifier: "schedule.editor.bedtimeReminder"
                    )
                    Divider().overlay(Color.white.opacity(0.10))
                    reminderMenu(
                        title: "Wake-up reminder",
                        selection: $draft.preWakeReminderLeadMinutes,
                        options: [5, 10, 15, 30],
                        identifier: "schedule.editor.preWakeReminder"
                    )
                }
            }
        }
    }

    private var wakeOnlyFields: some View {
        VStack(alignment: .leading, spacing: 18) {
            ScheduleEditorCard {
                VStack(alignment: .leading, spacing: 13) {
                    Text("One-time alarm")
                        .font(AppTypographyRole.subsectionTitle)
                    DatePicker(
                        "Date",
                        selection: oneTimeDateBinding,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .tint(Color(red: 0.72, green: 0.57, blue: 1))
                    .accessibilityIdentifier("schedule.editor.oneTimeDate")

                    Divider().overlay(Color.white.opacity(0.10))

                    timePickerRow(title: "Wake time", symbol: "clock.fill", selection: wakeTimeBinding)
                }
            }

            Text("This alarm rings once on the selected date, then turns itself off.")
                .font(AppTypographyRole.footnote)
                .foregroundStyle(Color.white.opacity(0.55))
                .padding(.horizontal, 4)
        }
    }

    private var enabledField: some View {
        ScheduleEditorCard {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Turn on after saving")
                        .font(AppTypographyRole.control)
                    Text(draft.isEnabled ? "This alarm will be scheduled." : "Save it as off for now.")
                        .font(AppTypographyRole.footnote)
                        .foregroundStyle(Color.white.opacity(0.55))
                }
                Spacer(minLength: 8)
                ScheduleEditorToggle(isOn: $draft.isEnabled)
            }
        }
        .accessibilityIdentifier("schedule.editor.enabled")
    }

    private var audioField: some View {
        ScheduleEditorCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Wake-up audio")
                            .font(AppTypographyRole.subsectionTitle)
                        Text(draft.wakeAudio.sourceTitle)
                            .font(AppTypographyRole.footnote)
                            .foregroundStyle(Color.white.opacity(0.54))
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "music.note")
                        .foregroundStyle(Color(red: 0.72, green: 0.57, blue: 1))
                        .accessibilityHidden(true)
                }

                VStack(spacing: 0) {
                    ForEach(audioChoices) { option in
                        AudioChoiceRow(
                            option: option,
                            isSelected: option.id == draft.wakeAudio.id,
                            action: { draft.wakeAudio = option }
                        )
                        if option.id != audioChoices.last?.id {
                            Divider().overlay(Color.white.opacity(0.10))
                        }
                    }
                }

                if !draft.wakeAudio.isAvailable {
                    Label("Audio unavailable on this device", systemImage: "exclamationmark.triangle.fill")
                        .font(AppTypographyRole.footnote)
                        .foregroundStyle(Color.orange.opacity(0.92))
                        .padding(.top, 4)
                        .accessibilityIdentifier("schedule.editor.audioUnavailable")
                }
            }
        }
        .accessibilityIdentifier("schedule.editor.audio")
    }

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

    private func timePickerRow(title: String, symbol: String, selection: Binding<Date>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(
                    title == "Bedtime"
                        ? Color(red: 0.72, green: 0.58, blue: 1)
                        : Color(red: 1, green: 0.67, blue: 0.24)
                )
                .frame(width: 26)
                .accessibilityHidden(true)

            Text(title)
                .font(AppTypographyRole.control)
            Spacer(minLength: 8)
            DatePicker(title, selection: selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(Color(red: 0.72, green: 0.57, blue: 1))
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
                VStack(alignment: .leading, spacing: 4) {
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

    private var bedtimeBinding: Binding<Date> {
        Binding(
            get: { date(hour: draft.bedtimeHour, minute: draft.bedtimeMinute) },
            set: { updateTime($0, bedtime: true) }
        )
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
                }
            }
        )
    }

    private var wakeTimeBinding: Binding<Date> {
        Binding(
            get: { date(hour: draft.wakeHour, minute: draft.wakeMinute) },
            set: { updateTime($0, bedtime: false) }
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

    private func updateTime(_ value: Date, bedtime: Bool) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: value)
        guard let hour = components.hour, let minute = components.minute else { return }
        if bedtime {
            draft.bedtimeHour = hour
            draft.bedtimeMinute = minute
        } else {
            draft.wakeHour = hour
            draft.wakeMinute = minute
        }
    }

    private func date(hour: Int, minute: Int) -> Date {
        Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: .now
        ) ?? .now
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

private struct WeekdaySelector: View {
    @Binding var mask: Int

    var body: some View {
        HStack(spacing: 7) {
            ForEach(1 ... 7, id: \.self) { weekday in
                Button {
                    mask ^= 1 << (weekday - 1)
                } label: {
                    Text(shortLabel(for: weekday))
                        .font(AppFont.inter(size: 12, relativeTo: .caption, weight: .semibold))
                        .frame(width: 35, height: 35)
                        .background(includes(weekday) ? Color.indigo.opacity(0.82) : Color.white.opacity(0.08))
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .stroke(
                                    includes(weekday)
                                        ? Color(red: 0.66, green: 0.53, blue: 1)
                                        : Color.white.opacity(0.16),
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
