import SwiftUI

enum SleepTabMode: String, CaseIterable, Identifiable, Sendable {
    case sleep
    case wakeOnly

    var id: String {
        rawValue
    }
}

struct SleepTabView: View {
    @Bindable var model: AppModel
    @State private var mode: SleepTabMode = .sleep
    @State private var draft: ScheduleUIModel = .newSleep
    @State private var isInitialized = false
    @State private var isSaveConfirmed = false
    @State private var resetConfirmationTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .bottom) {
            NightBackground()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 10)

                segmentedSwitcher
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                TabView(selection: $mode) {
                    ScrollView {
                        fullAlarmContent
                            .padding(.horizontal, 20)
                            .padding(.top, 4)
                            .padding(.bottom, 140)
                    }
                    .scrollIndicators(.hidden)
                    .tag(SleepTabMode.sleep)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("sleep.fullAlarmPage")

                    ScrollView {
                        wakeOnlyContent
                            .padding(.horizontal, 20)
                            .padding(.top, 4)
                            .padding(.bottom, 140)
                    }
                    .scrollIndicators(.hidden)
                    .tag(SleepTabMode.wakeOnly)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("sleep.wakeOnlyPage")
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .simultaneousGesture(
                    DragGesture().onChanged { _ in
                        AppHaptics.preparePageSnap()
                    }
                )
            }

            saveAlarmFloatingBar
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sleep.tab")
        .onAppear {
            if !isInitialized {
                draft = model.tonightScheduleUIModel
                if draft.isWakeOnly {
                    draft.updateWakeOnlyNextOccurrence()
                }
                mode = draft.kind == .wakeOnly ? .wakeOnly : .sleep
                isInitialized = true
            }
        }
        .onChange(of: mode) { _, newMode in
            AppHaptics.pageSnap(hapticsEnabled: model.settings?.hapticsEnabled != false)
            if newMode == .sleep {
                draft.kind = .sleep
                if draft.repeatWeekdaysMask == 0 {
                    draft.repeatWeekdaysMask = 0b0111_1111
                }
                draft.oneTimeDate = nil
                if draft.bedtimeHour == 0, draft.bedtimeMinute == 0 {
                    draft.bedtimeHour = model.sleepSchedule.sleepHour
                    draft.bedtimeMinute = model.sleepSchedule.sleepMinute
                }
            } else {
                draft.kind = .wakeOnly
                draft.repeatWeekdaysMask = 0
                draft.updateWakeOnlyNextOccurrence()
            }
        }
        .onChange(of: draft.wakeHour) { _, _ in
            if draft.isWakeOnly {
                draft.updateWakeOnlyNextOccurrence()
            }
        }
        .onChange(of: draft.wakeMinute) { _, _ in
            if draft.isWakeOnly {
                draft.updateWakeOnlyNextOccurrence()
            }
        }
        .onChange(of: model.tonightScheduleID) { _, _ in
            let latest = model.tonightScheduleUIModel
            if draft.id == latest.id {
                draft.isEnabled = latest.isEnabled
            } else {
                draft = latest
                if draft.isWakeOnly {
                    draft.updateWakeOnlyNextOccurrence()
                }
                mode = draft.kind == .wakeOnly ? .wakeOnly : .sleep
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Tonight's Alarm")
                    .font(AppFont.inter(size: 11, relativeTo: .caption, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Color(red: 0.72, green: 0.58, blue: 1).opacity(0.85))
                    .textCase(.uppercase)

                Text("Sleep Setup")
                    .font(AppFont.latoBold(size: 26, relativeTo: .title))
                    .foregroundStyle(.white)
            }

            Spacer()
        }
    }

    // MARK: - Segmented Switcher

    private var segmentedSwitcher: some View {
        HStack(spacing: 0) {
            Button {
                AppHaptics.preparePageSnap()
                withAnimation(.easeInOut(duration: 0.22)) {
                    mode = .sleep
                }
            } label: {
                Text("Full Alarm (Bed + Wake)")
                    .font(AppFont.inter(size: 12, relativeTo: .caption, weight: .semibold))
                    .foregroundStyle(mode == .sleep ? Color.white : Color.white.opacity(0.55))
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .background {
                        if mode == .sleep {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(red: 0.50, green: 0.28, blue: 0.94))
                                .shadow(color: Color(red: 0.50, green: 0.28, blue: 0.94).opacity(0.4), radius: 5, y: 2)
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("sleep.segment.full")

            Button {
                AppHaptics.preparePageSnap()
                withAnimation(.easeInOut(duration: 0.22)) {
                    mode = .wakeOnly
                }
            } label: {
                Text("Wake Only")
                    .font(AppFont.inter(size: 12, relativeTo: .caption, weight: .semibold))
                    .foregroundStyle(mode == .wakeOnly ? Color.white : Color.white.opacity(0.55))
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .background {
                        if mode == .wakeOnly {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(red: 0.50, green: 0.28, blue: 0.94))
                                .shadow(color: Color(red: 0.50, green: 0.28, blue: 0.94).opacity(0.4), radius: 5, y: 2)
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("sleep.segment.wakeOnly")
        }
        .padding(3)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }

    // MARK: - Full Alarm Content (Screen A)

    private var fullAlarmContent: some View {
        VStack(spacing: 14) {
            // Bedtime Card with Stacked Wheel
            ScheduleEditorCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color(red: 0.72, green: 0.58, blue: 1))
                        Text("BEDTIME")
                            .font(AppFont.inter(size: 12, relativeTo: .caption, weight: .bold))
                            .tracking(1.0)
                            .foregroundStyle(Color(red: 0.82, green: 0.74, blue: 1))
                        Spacer()
                        Text(formatTime(hour: draft.bedtimeHour, minute: draft.bedtimeMinute))
                            .font(AppFont.latoBold(size: 18, relativeTo: .headline))
                            .foregroundStyle(.white)
                    }

                    ScheduleTimeWheelPicker(hour: $draft.bedtimeHour, minute: $draft.bedtimeMinute)
                        .accessibilityIdentifier("sleep.bedtimeWheel")

                    Divider().overlay(Color.white.opacity(0.10))

                    HStack {
                        Text("Bedtime reminder")
                            .font(AppFont.inter(size: 13, relativeTo: .footnote))
                            .foregroundStyle(Color.white.opacity(0.65))
                        Spacer()
                        Menu {
                            ForEach([0, 5, 10, 15, 30, 60], id: \.self) { minutes in
                                Button {
                                    draft.bedtimeReminderLeadMinutes = minutes == 0 ? nil : minutes
                                } label: {
                                    HStack {
                                        Text(minutes == 0 ? "Off" : "\(minutes) min before")
                                        if (draft.bedtimeReminderLeadMinutes ?? 0) == minutes {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Text(reminderLabel(draft.bedtimeReminderLeadMinutes))
                                .font(AppFont.inter(size: 13, relativeTo: .footnote, weight: .medium))
                                .foregroundStyle(Color(red: 0.72, green: 0.58, blue: 1))
                        }
                        .accessibilityIdentifier("sleep.bedtimeReminder")
                    }
                }
            }

            // Wake Up Card with Stacked Wheel
            ScheduleEditorCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color(red: 1.0, green: 0.67, blue: 0.24))
                        Text("WAKE UP TIME")
                            .font(AppFont.inter(size: 12, relativeTo: .caption, weight: .bold))
                            .tracking(1.0)
                            .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.54))
                        Spacer()
                        Text(formatTime(hour: draft.wakeHour, minute: draft.wakeMinute))
                            .font(AppFont.latoBold(size: 18, relativeTo: .headline))
                            .foregroundStyle(.white)
                    }

                    ScheduleTimeWheelPicker(hour: $draft.wakeHour, minute: $draft.wakeMinute)
                        .accessibilityIdentifier("sleep.wakeWheel")

                    Divider().overlay(Color.white.opacity(0.10))

                    HStack {
                        Text("Quick adjust")
                            .font(AppFont.inter(size: 13, relativeTo: .footnote))
                            .foregroundStyle(Color.white.opacity(0.65))
                        Spacer()
                        HStack(spacing: 8) {
                            quickStepButton("-15m", delta: -15)
                            quickStepButton("+15m", delta: 15)
                            quickStepButton("+30m", delta: 30)
                        }
                    }
                }
            }

            // Repeat Days and Wake Sound Card
            ScheduleEditorCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Repeat Days")
                            .font(AppFont.inter(size: 13, relativeTo: .subheadline, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.85))
                        Spacer()
                    }

                    WeekdaySelector(mask: $draft.repeatWeekdaysMask)

                    Divider().overlay(Color.white.opacity(0.10))

                    HStack {
                        Text("Wake Sound")
                            .font(AppFont.inter(size: 13, relativeTo: .subheadline, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.85))
                        Spacer()
                        Menu {
                            ForEach(model.scheduleAudioOptions) { option in
                                Button {
                                    draft.wakeAudio = option
                                } label: {
                                    HStack {
                                        Text(option.title)
                                        if option.id == draft.wakeAudio.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Text("\(draft.wakeAudio.title) ›")
                                .font(AppFont.inter(size: 13, relativeTo: .subheadline, weight: .medium))
                                .foregroundStyle(Color(red: 0.72, green: 0.58, blue: 1))
                        }
                        .accessibilityIdentifier("sleep.soundSelector")
                    }
                }
            }

            // Manage all schedules link
            Button {
                model.open(.alarmHistory)
            } label: {
                Text("Manage all schedules in History ›")
                    .font(AppFont.inter(size: 13, relativeTo: .footnote, weight: .medium))
                    .foregroundStyle(Color(red: 0.72, green: 0.58, blue: 1).opacity(0.9))
                    .underline()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Manage sleep schedules")
            .accessibilityIdentifier("home.editSchedule")
        }
    }

    // MARK: - Wake Only Content (Screen B)

    private var wakeOnlyContent: some View {
        VStack(spacing: 14) {
            ScheduleEditorCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color(red: 1.0, green: 0.67, blue: 0.24))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("WAKE ONLY ALARM")
                                .font(AppFont.inter(size: 12, relativeTo: .caption, weight: .bold))
                                .tracking(1.0)
                                .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.54))
                            Text("Single wake alarm without bedtime tracking")
                                .font(AppFont.inter(size: 11, relativeTo: .caption2))
                                .foregroundStyle(Color.white.opacity(0.55))
                        }
                        Spacer()
                        Text(formatTime(hour: draft.wakeHour, minute: draft.wakeMinute))
                            .font(AppFont.latoBold(size: 20, relativeTo: .headline))
                            .foregroundStyle(.white)
                    }

                    ScheduleTimeWheelPicker(hour: $draft.wakeHour, minute: $draft.wakeMinute)
                        .accessibilityIdentifier("sleep.wakeOnlyWheel")

                    Divider().overlay(Color.white.opacity(0.10))

                    HStack {
                        Text("Quick adjust")
                            .font(AppFont.inter(size: 13, relativeTo: .footnote))
                            .foregroundStyle(Color.white.opacity(0.65))
                        Spacer()
                        HStack(spacing: 8) {
                            quickStepButton("-15m", delta: -15)
                            quickStepButton("+15m", delta: 15)
                            quickStepButton("+30m", delta: 30)
                        }
                    }

                    Divider().overlay(Color.white.opacity(0.10))

                    HStack {
                        Text("Occurrence")
                            .font(AppFont.inter(size: 13, relativeTo: .subheadline))
                            .foregroundStyle(Color.white.opacity(0.75))
                        Spacer()
                        Text(occurrenceLabel)
                            .font(AppFont.inter(size: 13, relativeTo: .subheadline, weight: .semibold))
                            .foregroundStyle(Color(red: 0.72, green: 0.58, blue: 1))
                    }
                    .padding(.vertical, 2)

                    Divider().overlay(Color.white.opacity(0.10))

                    HStack {
                        Text("Alarm Sound")
                            .font(AppFont.inter(size: 13, relativeTo: .subheadline))
                            .foregroundStyle(Color.white.opacity(0.75))
                        Spacer()
                        Menu {
                            ForEach(model.scheduleAudioOptions) { option in
                                Button {
                                    draft.wakeAudio = option
                                } label: {
                                    HStack {
                                        Text(option.title)
                                        if option.id == draft.wakeAudio.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Text("\(draft.wakeAudio.title) ›")
                                .font(AppFont.inter(size: 13, relativeTo: .subheadline, weight: .medium))
                                .foregroundStyle(Color(red: 0.72, green: 0.58, blue: 1))
                        }
                        .accessibilityIdentifier("sleep.soundSelector")
                    }
                }
            }

            Text("Swipe left to return to Full Sleep Schedule")
                .font(AppFont.inter(size: 12, relativeTo: .footnote))
                .foregroundStyle(Color.white.opacity(0.45))
                .padding(.top, 4)

            Button {
                model.open(.alarmHistory)
            } label: {
                Text("Manage all schedules in History ›")
                    .font(AppFont.inter(size: 13, relativeTo: .footnote, weight: .medium))
                    .foregroundStyle(Color(red: 0.72, green: 0.58, blue: 1).opacity(0.9))
                    .underline()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Manage sleep schedules")
            .accessibilityIdentifier("home.editSchedule")
        }
    }

    // MARK: - Helpers

    private var occurrenceLabel: String {
        if let oneTimeDate = draft.oneTimeDate {
            let calendar = Calendar.current
            let period = draft.wakeHour < 12 ? "Morning" : (draft.wakeHour < 17 ? "Afternoon" : "Evening")
            if calendar.isDateInTomorrow(oneTimeDate) {
                return "Tomorrow \(period) (One-Time)"
            } else if calendar.isDateInToday(oneTimeDate) {
                return "Today \(period) (One-Time)"
            } else {
                return "\(oneTimeDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())) (One-Time)"
            }
        } else if draft.repeatWeekdaysMask != 0 {
            return "Repeats on selected days"
        } else {
            return "Tomorrow Morning (One-Time)"
        }
    }

    private func quickStepButton(_ title: String, delta: Int) -> some View {
        Button {
            adjustWakeTime(by: delta)
        } label: {
            Text(title)
                .font(AppFont.inter(size: 12, relativeTo: .caption, weight: .semibold))
                .foregroundStyle(Color(red: 0.82, green: 0.74, blue: 1))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("sleep.quickStep.\(delta > 0 ? "plus" : "minus")\(abs(delta))")
    }

    private func adjustWakeTime(by deltaMinutes: Int) {
        let totalMinutes = (draft.wakeHour * 60 + draft.wakeMinute + deltaMinutes) % (24 * 60)
        let nonNegativeMinutes = (totalMinutes + 24 * 60) % (24 * 60)
        draft.wakeHour = nonNegativeMinutes / 60
        draft.wakeMinute = nonNegativeMinutes % 60
        if draft.isWakeOnly {
            draft.updateWakeOnlyNextOccurrence()
        }
        AppHaptics.stepAdjustment(
            direction: deltaMinutes > 0 ? .increase : .decrease,
            hapticsEnabled: model.settings?.hapticsEnabled != false
        )
    }

    private func formatTime(hour: Int, minute: Int) -> String {
        let displayedHour = ((hour + 11) % 12) + 1
        let isPM = hour >= 12
        return String(format: "%d:%02d %@", displayedHour, minute, isPM ? "PM" : "AM")
    }

    private func reminderLabel(_ minutes: Int?) -> String {
        guard let minutes, minutes > 0 else { return "Off" }
        return "\(minutes) min before"
    }

    // MARK: - Floating Save Alarm Bar

    private var saveAlarmFloatingBar: some View {
        VStack(spacing: 0) {
            Button {
                saveAlarm()
            } label: {
                HStack(spacing: 8) {
                    if isSaveConfirmed {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                        Text("Saved ✓")
                            .font(AppFont.inter(size: 16, relativeTo: .headline, weight: .semibold))
                    } else {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Save Alarm")
                            .font(AppFont.inter(size: 16, relativeTo: .headline, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(
                    isSaveConfirmed
                        ? Color(red: 0.20, green: 0.70, blue: 0.40)
                        : Color(red: 0.50, green: 0.28, blue: 0.94)
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(
                    color: (isSaveConfirmed
                        ? Color(red: 0.20, green: 0.70, blue: 0.40)
                        : Color(red: 0.50, green: 0.28, blue: 0.94)).opacity(0.4),
                    radius: 12,
                    y: 4
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("sleep.saveAlarmButton")
            .accessibilityLabel(isSaveConfirmed ? "Saved ✓" : "Save Alarm")
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 16)
        }
        .background {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.02, blue: 0.09).opacity(0),
                    Color(red: 0.03, green: 0.02, blue: 0.09).opacity(0.8),
                    Color(red: 0.03, green: 0.02, blue: 0.09)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private func saveAlarm() {
        draft.isEnabled = true
        if draft.isWakeOnly {
            draft.updateWakeOnlyNextOccurrence()
        }
        AppHaptics.primaryCTA(hapticsEnabled: model.settings?.hapticsEnabled != false)
        let saved = model.saveTonightScheduleDraft(draft, immediate: true)
        guard saved else {
            AppHaptics.warning(hapticsEnabled: model.settings?.hapticsEnabled != false)
            return
        }
        AppHaptics.success(hapticsEnabled: model.settings?.hapticsEnabled != false)
        model.feedbackMessage = "Tonight's alarm saved"
        withAnimation(.easeInOut(duration: 0.2)) {
            isSaveConfirmed = true
        }
        resetConfirmationTask?.cancel()
        resetConfirmationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                isSaveConfirmed = false
            }
        }
    }
}
