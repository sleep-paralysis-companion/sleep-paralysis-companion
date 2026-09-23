import SwiftUI

struct AlarmRingingView: View {
    @Bindable var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var isPulsing = false
    @State private var isActionTriggered = false

    var body: some View {
        ZStack {
            NightBackground()

            VStack(spacing: 0) {
                Spacer()

                alarmHeader
                    .padding(.horizontal, 24)

                Spacer()

                actionButtons
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
            }
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(true)
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
        }
        .accessibilityIdentifier("alarm.ringing.screen")
    }

    private var alarmHeader: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.45, green: 0.28, blue: 0.90).opacity(isPulsing ? 0.45 : 0.15))
                    .frame(width: 140, height: 140)
                    .blur(radius: 20)

                Image(systemName: "alarm.waves.left.and.right.fill")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(Color(red: 0.72, green: 0.60, blue: 1))
                    .scaleEffect(isPulsing ? 1.08 : 1.0)
            }

            Text(currentTimeString)
                .font(AppFont.latoBold(size: 52, relativeTo: .largeTitle))
                .tracking(2)

            Text(alarmTitle)
                .font(AppFont.inter(size: 20, relativeTo: .title3, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.75))
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 16) {
                snoozeButton
                stopButton
            }
        } else {
            HStack(spacing: 12) {
                snoozeButton
                stopButton
            }
        }
    }

    private var snoozeButton: some View {
        Button {
            guard !isActionTriggered else { return }
            isActionTriggered = true
            AppHaptics.secondaryCTA(hapticsEnabled: model.settings?.hapticsEnabled != false)
            model.snoozeAlarm(minutes: effectiveSnoozeMinutes)
        } label: {
            VStack(spacing: 2) {
                Text("Snooze")
                    .font(AppFont.inter(size: 18, relativeTo: .headline, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text("\(effectiveSnoozeMinutes) min")
                    .font(AppFont.inter(size: 13, relativeTo: .footnote))
                    .foregroundStyle(Color.white.opacity(0.65))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(Color.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.20), lineWidth: 1.2)
            }
        }
        .buttonStyle(.plain)
        .disabled(isActionTriggered)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Snooze (\(effectiveSnoozeMinutes) min)")
        .accessibilityHint("Pauses the alarm and rings again in \(effectiveSnoozeMinutes) minutes.")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("alarm.snooze")
    }

    private var stopButton: some View {
        Button {
            guard !isActionTriggered else { return }
            isActionTriggered = true
            let hapticsEnabled = model.settings?.hapticsEnabled != false
            AppHaptics.primaryCTA(hapticsEnabled: hapticsEnabled)
            AppHaptics.success(hapticsEnabled: hapticsEnabled)
            model.stopAlarm()
        } label: {
            VStack(spacing: 2) {
                Text("Stop")
                    .font(AppFont.inter(size: 18, relativeTo: .headline, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text("Check-in")
                    .font(AppFont.inter(size: 13, relativeTo: .footnote, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.45, green: 0.28, blue: 0.90),
                        Color(red: 0.25, green: 0.40, blue: 0.95),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(
                color: Color(red: 0.45, green: 0.28, blue: 0.90).opacity(0.40),
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(.plain)
        .disabled(isActionTriggered)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Stop alarm")
        .accessibilityHint("Dismisses the alarm and immediately begins morning check-in.")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("alarm.stop")
    }

    private var currentTimeString: String {
        Date.now.formatted(date: .omitted, time: .shortened)
    }

    private var alarmTitle: String {
        if let schedule = model.ringingAlarmSchedule, !schedule.name.isEmpty {
            return schedule.name
        }
        return "Wake up"
    }

    private var effectiveSnoozeMinutes: Int {
        model.ringingAlarmSchedule?.snoozeMinutes ?? 10
    }
}
