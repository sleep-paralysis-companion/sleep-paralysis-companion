import SwiftUI

struct AlarmRingingView: View {
    @Bindable var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isPulsing = false

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

    private var actionButtons: some View {
        VStack(spacing: 16) {
            Button {
                model.snoozeAlarm()
            } label: {
                VStack(spacing: 4) {
                    Text("Snooze")
                        .font(AppFont.inter(size: 20, relativeTo: .headline, weight: .semibold))
                    Text("Ring again in 9 minutes")
                        .font(AppFont.inter(size: 14, relativeTo: .footnote))
                        .foregroundStyle(Color.white.opacity(0.65))
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
            .accessibilityLabel("Snooze alarm")
            .accessibilityHint("Pauses the alarm and rings again in 9 minutes.")
            .accessibilityIdentifier("alarm.ringing.snooze")

            Button {
                model.stopAlarm()
            } label: {
                VStack(spacing: 4) {
                    Text("Stop")
                        .font(AppFont.inter(size: 20, relativeTo: .headline, weight: .bold))
                    Text("Begin Morning Check-in")
                        .font(AppFont.inter(size: 14, relativeTo: .footnote, weight: .medium))
                        .foregroundStyle(Color(red: 0.90, green: 0.88, blue: 1).opacity(0.85))
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
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1.2)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stop alarm")
            .accessibilityHint("Dismisses the alarm and immediately opens the morning questionnaire.")
            .accessibilityIdentifier("alarm.ringing.stop")
        }
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
}
