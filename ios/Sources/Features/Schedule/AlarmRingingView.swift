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

    private var actionButtons: some View {
        VStack(spacing: 16) {
            Button {
                AppHaptics.primaryCTA(hapticsEnabled: model.settings?.hapticsEnabled != false)
                model.snoozeAlarm(minutes: effectiveSnoozeMinutes)
            } label: {
                VStack(spacing: 4) {
                    Text("Snooze (\(effectiveSnoozeMinutes) min)")
                        .font(AppFont.inter(size: 20, relativeTo: .headline, weight: .semibold))
                    Text("Ring again in \(effectiveSnoozeMinutes) minutes")
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
            .accessibilityLabel("Snooze (\(effectiveSnoozeMinutes) min)")
            .accessibilityHint("Pauses the alarm and rings again in \(effectiveSnoozeMinutes) minutes.")
            .accessibilityIdentifier("alarm.snooze")

            SlideToStopControl(
                hapticsEnabled: model.settings?.hapticsEnabled != false,
                onCompleted: {
                    model.stopAlarm()
                }
            )
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

    private var effectiveSnoozeMinutes: Int {
        model.ringingAlarmSchedule?.snoozeMinutes ?? 10
    }
}

// MARK: - Slide To Stop Control

struct SlideToStopControl: View {
    var hapticsEnabled: Bool = true
    var onCompleted: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var hasTriggeredInitialHaptic = false
    @State private var isCompleted = false

    init(
        hapticsEnabled: Bool = true,
        onCompleted: @escaping () -> Void
    ) {
        self.hapticsEnabled = hapticsEnabled
        self.onCompleted = onCompleted
    }

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let thumbSize: CGFloat = 56
            let padding: CGFloat = 4
            let maxDistance = max(0, totalWidth - thumbSize - (padding * 2))
            let progress = maxDistance > 0 ? (dragOffset / maxDistance) : 0

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .overlay {
                        Capsule()
                            .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                    }

                VStack(spacing: 2) {
                    Text("Slide to Stop")
                        .font(AppFont.inter(size: 17, relativeTo: .headline, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.9))
                    Text("Begin Morning Check-in")
                        .font(AppFont.inter(size: 12, relativeTo: .footnote, weight: .medium))
                        .foregroundStyle(Color(red: 0.90, green: 0.88, blue: 1).opacity(0.75))
                }
                .opacity(max(0, 1.0 - progress))
                .frame(maxWidth: .infinity, alignment: .center)
                .allowsHitTesting(false)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color(red: 0.90, green: 0.88, blue: 1),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: thumbSize, height: thumbSize)
                    .overlay {
                        Image(systemName: "chevron.right.2")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color(red: 0.35, green: 0.20, blue: 0.75))
                    }
                    .shadow(color: Color.black.opacity(0.25), radius: 4, x: 1, y: 2)
                    .offset(x: padding + dragOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                guard !isCompleted else { return }
                                if !hasTriggeredInitialHaptic && value.translation.width > 4 {
                                    hasTriggeredInitialHaptic = true
                                    AppHaptics.selectionChanged(hapticsEnabled: hapticsEnabled)
                                }
                                let translation = max(0, min(value.translation.width, maxDistance))
                                dragOffset = translation
                            }
                            .onEnded { _ in
                                guard !isCompleted else { return }
                                hasTriggeredInitialHaptic = false
                                if dragOffset >= maxDistance * 0.85 {
                                    isCompleted = true
                                    withAnimation(.easeOut(duration: 0.15)) {
                                        dragOffset = maxDistance
                                    }
                                    AppHaptics.success(hapticsEnabled: hapticsEnabled)
                                    onCompleted()
                                } else {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                        dragOffset = 0
                                    }
                                }
                            }
                    )
            }
        }
        .frame(height: 64)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Slide to stop alarm")
        .accessibilityHint("Double tap to dismiss the alarm and begin morning check-in.")
        .accessibilityAction {
            guard !isCompleted else { return }
            isCompleted = true
            AppHaptics.success(hapticsEnabled: hapticsEnabled)
            onCompleted()
        }
        .accessibilityIdentifier("alarm.stop")
    }
}

