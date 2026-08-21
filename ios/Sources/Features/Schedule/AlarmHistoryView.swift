import Foundation
import SwiftUI

/// The schedule-management screen shown from Home.
///
/// This view deliberately receives values and mutations through closures. The
/// schedule engine can own persistence, collision validation, and device
/// reconciliation without making this screen depend on `AppModel`.
struct AlarmHistoryView: View {
    let schedules: [ScheduleUIModel]
    let maximumScheduleCount: Int
    let onBack: () -> Void
    let onAdd: () -> Void
    let onEdit: (ScheduleUIModel) -> Void
    let onToggle: (ScheduleUIModel, Bool) -> Void
    let onDelete: (ScheduleUIModel) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var localSchedules: [ScheduleUIModel]
    @State private var pendingDeletion: ScheduleUIModel?

    init(
        schedules: [ScheduleUIModel],
        maximumScheduleCount: Int = ScheduleUIModel.maximumCount,
        onBack: @escaping () -> Void = {},
        onAdd: @escaping () -> Void = {},
        onEdit: @escaping (ScheduleUIModel) -> Void = { _ in },
        onToggle: @escaping (ScheduleUIModel, Bool) -> Void = { _, _ in },
        onDelete: @escaping (ScheduleUIModel) -> Void = { _ in }
    ) {
        self.schedules = schedules
        self.maximumScheduleCount = maximumScheduleCount
        self.onBack = onBack
        self.onAdd = onAdd
        self.onEdit = onEdit
        self.onToggle = onToggle
        self.onDelete = onDelete
        _localSchedules = State(initialValue: schedules)
    }

    var body: some View {
        ZStack {
            NightBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.top, 18)

                    if localSchedules.isEmpty {
                        emptyState
                            .padding(.top, 44)
                    } else {
                        tonightSection
                            .padding(.top, 32)

                        otherSchedulesSection
                            .padding(.top, 30)
                    }

                    if localSchedules.count >= maximumScheduleCount {
                        maximumCountMessage
                            .padding(.top, 24)
                    }
                }
                .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 18 : 24)
                .padding(.bottom, 32)
                .frame(maxWidth: 680, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("schedule.alarmHistory")
        .onChange(of: schedules) { _, newValue in
            localSchedules = newValue
        }
        .alert(item: $pendingDeletion) { schedule in
            Alert(
                title: Text("Delete \(schedule.name)?"),
                message: Text("This schedule will be removed from your alarm list."),
                primaryButton: .destructive(Text("Delete")) {
                    delete(schedule)
                },
                secondaryButton: .cancel()
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 21, weight: .medium))
                        .frame(width: 48, height: 48)
                        .background(Color.white.opacity(0.07))
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
                .accessibilityIdentifier("schedule.history.back")

                Spacer()

                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 28, weight: .regular))
                        .frame(width: 56, height: 56)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.43, green: 0.18, blue: 0.94),
                                    Color(red: 0.31, green: 0.13, blue: 0.73),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: Color.purple.opacity(0.45), radius: 14, y: 5)
                }
                .buttonStyle(.plain)
                .disabled(localSchedules.count >= maximumScheduleCount)
                .opacity(localSchedules.count >= maximumScheduleCount ? 0.48 : 1)
                .accessibilityLabel("Add schedule")
                .accessibilityHint(
                    localSchedules.count >= maximumScheduleCount
                        ? "The maximum number of schedules has been reached."
                        : "Creates another sleep schedule or wake-only alarm."
                )
                .accessibilityIdentifier("schedule.history.add")
            }

            Text("Alarm History")
                .font(AppFont.latoBold(size: dynamicTypeSize.isAccessibilitySize ? 30 : 32, relativeTo: .largeTitle))
                .tracking(-0.6)
                .padding(.top, 26)
                .accessibilityAddTraits(.isHeader)

            Text("Manage your sleep schedules without\ncreating a new alarm every night.")
                .font(AppFont.inter(size: dynamicTypeSize.isAccessibilitySize ? 17 : 18, relativeTo: .callout))
                .foregroundStyle(Color.white.opacity(0.65))
                .lineSpacing(7)
                .padding(.top, 11)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tonightSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeading("Tonight")

            if let tonightSchedule {
                ScheduleHeroCard(
                    schedule: tonightSchedule,
                    onToggle: { setEnabled(tonightSchedule, enabled: $0) },
                    onEdit: { onEdit(tonightSchedule) }
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    deleteButton(for: tonightSchedule)
                }
            } else {
                NightCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Nothing scheduled tonight", systemImage: "moon.zzz.fill")
                            .font(AppTypographyRole.subsectionTitle)
                        Text("Turn on a schedule or add a one-time wake alarm when you need one.")
                            .font(AppTypographyRole.body)
                            .foregroundStyle(Color.white.opacity(0.62))
                    }
                }
            }
        }
    }

    private var otherSchedulesSection: some View {
        let others = localSchedules.filter { $0.id != tonightSchedule?.id }

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Text("OTHER SCHEDULES")
                    .font(AppFont.inter(size: 13, relativeTo: .caption, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Color.white.opacity(0.58))
                    .fixedSize(horizontal: true, vertical: false)

                Rectangle()
                    .fill(Color.white.opacity(0.14))
                    .frame(height: 1)
                    .accessibilityHidden(true)
            }

            if others.isEmpty {
                Text("Your other schedules will appear here.")
                    .font(AppTypographyRole.body)
                    .foregroundStyle(Color.white.opacity(0.58))
                    .padding(.vertical, 12)
            } else {
                ForEach(Array(others.enumerated()), id: \.element.id) { index, schedule in
                    ScheduleCompactCard(
                        schedule: schedule,
                        accent: accent(for: index),
                        onToggle: { setEnabled(schedule, enabled: $0) },
                        onEdit: { onEdit(schedule) }
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        deleteButton(for: schedule)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        NightCard {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "alarm.waves.left.and.right")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(Color(red: 0.70, green: 0.56, blue: 1))
                    .accessibilityHidden(true)

                Text("No schedules yet")
                    .font(AppTypographyRole.sectionTitle)
                    .accessibilityAddTraits(.isHeader)

                Text("Create a sleep schedule or a one-time wake alarm to make your mornings easier.")
                    .font(AppTypographyRole.body)
                    .foregroundStyle(Color.white.opacity(0.64))

                Button(action: onAdd) {
                    Label("Add a schedule", systemImage: "plus")
                }
                .buttonStyle(AppPrimaryButtonStyle())
                .accessibilityIdentifier("schedule.history.empty.add")
            }
        }
        .accessibilityIdentifier("schedule.history.empty")
    }

    private var maximumCountMessage: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(Color(red: 0.67, green: 0.57, blue: 1))
                .accessibilityHidden(true)
            Text("You can keep up to \(maximumScheduleCount) schedules. Delete one before adding another.")
                .font(AppTypographyRole.footnote)
                .foregroundStyle(Color.white.opacity(0.62))
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("schedule.history.maximumCount")
    }

    private var tonightSchedule: ScheduleUIModel? {
        let today = Calendar.current.startOfDay(for: .now)
        let weekday = Calendar.current.component(.weekday, from: .now)

        return localSchedules.first { schedule in
            guard schedule.isEnabled else { return false }
            if schedule.isWakeOnly {
                if let date = schedule.oneTimeDate {
                    return Calendar.current.isDate(date, inSameDayAs: today)
                }
                return schedule.includes(weekday: weekday)
            }
            return schedule.includes(weekday: weekday)
        }
    }

    private func sectionHeading(_ title: String) -> some View {
        HStack(spacing: 14) {
            Text(title)
                .font(AppFont.latoSemiBold(size: 22, relativeTo: .title2))
                .foregroundStyle(Color.white.opacity(0.55))
            Rectangle()
                .fill(Color.white.opacity(0.13))
                .frame(height: 1)
                .accessibilityHidden(true)
        }
    }

    private func deleteButton(for schedule: ScheduleUIModel) -> some View {
        Button(role: .destructive) {
            pendingDeletion = schedule
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func delete(_ schedule: ScheduleUIModel) {
        localSchedules.removeAll { $0.id == schedule.id }
        onDelete(schedule)
    }

    private func setEnabled(_ schedule: ScheduleUIModel, enabled: Bool) {
        guard let index = localSchedules.firstIndex(where: { $0.id == schedule.id }) else { return }
        localSchedules[index].isEnabled = enabled
        onToggle(localSchedules[index], enabled)
    }

    private func accent(for index: Int) -> Color {
        index.isMultiple(of: 2)
            ? Color(red: 0.35, green: 0.57, blue: 1)
            : Color(red: 1, green: 0.55, blue: 0.20)
    }
}

private struct ScheduleHeroCard: View {
    let schedule: ScheduleUIModel
    let onToggle: (Bool) -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Button(action: onEdit) {
                    HStack(spacing: 12) {
                        ScheduleIconBadge(
                            systemImage: schedule.isWakeOnly ? "clock" : "moon.fill",
                            tint: Color(red: 0.74, green: 0.64, blue: 1),
                            background: Color(red: 0.22, green: 0.10, blue: 0.48)
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Text(schedule.name)
                                .font(AppFont.latoSemiBold(size: 20, relativeTo: .title3))
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)

                            Text(schedule.isEnabled ? "ON TONIGHT" : "OFF")
                                .font(AppFont.inter(size: 13, relativeTo: .caption, weight: .medium))
                                .tracking(0.5)
                                .foregroundStyle(schedule.isEnabled ? Color.green : Color.white.opacity(0.58))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color.clear)
                                .clipShape(Capsule())
                                .overlay {
                                    Capsule()
                                        .stroke(
                                            schedule.isEnabled ? Color.green.opacity(0.58) : Color.white.opacity(0.20),
                                            lineWidth: 1
                                        )
                                }
                        }

                        Spacer(minLength: 8)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                ScheduleToggle(isOn: schedule.isEnabled, action: onToggle)
            }

            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 0) {
                    if schedule.isWakeOnly {
                        wakeOnlyHeroTime
                    } else {
                        sleepHeroTime
                    }

                    scheduleSummary(schedule)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.08, blue: 0.29),
                    Color(red: 0.06, green: 0.06, blue: 0.22),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("schedule.history.hero.\(schedule.id.uuidString)")
    }

    private var sleepHeroTime: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ScheduleTimeColumn(title: "Sleep Time", hour: schedule.bedtimeHour, minute: schedule.bedtimeMinute)
            Text("→")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Color.white.opacity(0.35))
                .padding(.bottom, 17)
                .accessibilityHidden(true)
            ScheduleTimeColumn(title: "Wake Time", hour: schedule.wakeHour, minute: schedule.wakeMinute)
        }
        .padding(.top, 26)
    }

    private var wakeOnlyHeroTime: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(schedule.oneTimeDate.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "One time")
                .font(AppTypographyRole.subsectionTitle)
                .foregroundStyle(Color.white.opacity(0.56))
            ScheduleTimeColumn(title: "Wake Time", hour: schedule.wakeHour, minute: schedule.wakeMinute)
        }
        .padding(.top, 24)
    }

    private func scheduleSummary(_ schedule: ScheduleUIModel) -> some View {
        HStack(spacing: 10) {
            Image(systemName: schedule.isWakeOnly ? "calendar" : "repeat")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.58))
                .accessibilityHidden(true)
            Text(schedule.isWakeOnly ? "One time" : weekdaySummary(schedule.repeatWeekdaysMask))

            Circle()
                .fill(Color.white.opacity(0.34))
                .frame(width: 4, height: 4)
                .accessibilityHidden(true)

            Image(systemName: "bell.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.58))
                .accessibilityHidden(true)
            Text(reminderSummary(schedule))
        }
        .font(AppFont.inter(size: 13, relativeTo: .footnote))
        .foregroundStyle(Color.white.opacity(0.56))
        .lineLimit(2)
        .padding(.top, 24)
    }
}

private struct ScheduleCompactCard: View {
    let schedule: ScheduleUIModel
    let accent: Color
    let onToggle: (Bool) -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onEdit) {
                HStack(spacing: 16) {
                    ScheduleIconBadge(
                        systemImage: schedule.isWakeOnly ? "clock" : "sunrise.fill",
                        tint: accent,
                        background: accent.opacity(0.16)
                    )

                    VStack(alignment: .leading, spacing: 5) {
                        Text(schedule.name)
                            .font(AppFont.latoSemiBold(size: 18, relativeTo: .headline))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)

                        Text(compactTimeSummary(schedule))
                            .font(AppFont.inter(size: 15, relativeTo: .subheadline))
                            .foregroundStyle(Color.white.opacity(0.62))
                            .lineLimit(1)

                        Text(compactDaySummary(schedule))
                            .font(AppFont.inter(size: 14, relativeTo: .footnote))
                            .foregroundStyle(Color.white.opacity(0.48))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            ScheduleToggle(isOn: schedule.isEnabled, action: onToggle)
                .accessibilityIdentifier("schedule.history.toggle.\(schedule.id.uuidString)")

            Button(action: onEdit) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.36))
                    .frame(width: 28, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(schedule.name)")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
        .background(Color.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .stroke(Color.white.opacity(0.11), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("schedule.history.card.\(schedule.id.uuidString)")
    }
}

private struct ScheduleIconBadge: View {
    let systemImage: String
    let tint: Color
    let background: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 26, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: 58, height: 58)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .accessibilityHidden(true)
    }
}

private struct ScheduleToggle: View {
    let isOn: Bool
    let action: (Bool) -> Void

    var body: some View {
        Button {
            action(!isOn)
        } label: {
            Capsule()
                .fill(isOn ? Color(red: 0.48, green: 0.20, blue: 0.94) : Color.white.opacity(0.13))
                .frame(width: 52, height: 32)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(.white)
                        .frame(width: 28, height: 28)
                        .padding(2)
                        .shadow(color: .black.opacity(0.28), radius: 3, y: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Schedule")
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
    }
}

private struct ScheduleTimeColumn: View {
    let title: String
    let hour: Int
    let minute: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(AppFont.inter(size: 14, relativeTo: .footnote, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.54))
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(String(format: "%d:%02d", displayHour, minute))
                    .font(AppFont.latoBold(size: 42, relativeTo: .largeTitle))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(hour >= 12 ? "PM" : "AM")
                    .font(AppFont.inter(size: 14, relativeTo: .footnote))
                    .foregroundStyle(Color.white.opacity(0.52))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var displayHour: Int {
        let value = hour % 12
        return value == 0 ? 12 : value
    }
}

private func weekdaySummary(_ mask: Int) -> String {
    let symbols = Calendar.current.shortStandaloneWeekdaySymbols
    let days = (1 ... 7).compactMap { day -> String? in
        guard mask & (1 << (day - 1)) != 0,
              symbols.indices.contains(day - 1)
        else { return nil }
        return symbols[day - 1]
    }

    if days.count == 7 { return "Every day" }
    if mask == 0b0011_1110 { return "Mon – Fri" }
    if mask == 0b0100_0001 { return "Sat – Sun" }
    return days.joined(separator: " · ")
}

private func reminderSummary(_ schedule: ScheduleUIModel) -> String {
    if let bedtime = schedule.bedtimeReminderLeadMinutes {
        return "\(bedtime) min before bedtime"
    }
    if let preWake = schedule.preWakeReminderLeadMinutes {
        return "\(preWake) min before wake"
    }
    return "No reminder"
}

private func compactTimeSummary(_ schedule: ScheduleUIModel) -> String {
    if schedule.isWakeOnly {
        return timeString(hour: schedule.wakeHour, minute: schedule.wakeMinute)
    }
    return timeString(hour: schedule.bedtimeHour, minute: schedule.bedtimeMinute)
        + " → "
        + timeString(hour: schedule.wakeHour, minute: schedule.wakeMinute)
}

private func compactDaySummary(_ schedule: ScheduleUIModel) -> String {
    if schedule.isWakeOnly {
        return schedule.oneTimeDate?.formatted(date: .abbreviated, time: .omitted) ?? "One time"
    }
    return weekdaySummary(schedule.repeatWeekdaysMask)
}

private func timeString(hour: Int, minute: Int) -> String {
    "\(hour % 12 == 0 ? 12 : hour % 12):\(String(format: "%02d", minute)) \(hour >= 12 ? "PM" : "AM")"
}
