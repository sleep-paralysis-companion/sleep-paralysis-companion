import SwiftUI

enum HomeScreenPalette {
    static let backgroundTop = Color(red: 0.031, green: 0.039, blue: 0.184)
    static let backgroundBottom = Color(red: 0.012, green: 0.014, blue: 0.090)
    static let card = Color(red: 0.062, green: 0.047, blue: 0.224)
    static let cardSecondary = Color(red: 0.030, green: 0.029, blue: 0.160)
    static let cardBorder = Color(red: 0.204, green: 0.100, blue: 0.470)
    static let blueBorder = Color(red: 0.090, green: 0.190, blue: 0.480)
    static let iconBackground = Color(red: 0.075, green: 0.120, blue: 0.370)
    static let iconTint = Color(red: 0.350, green: 0.570, blue: 1.000)
    static let accent = Color(red: 0.600, green: 0.410, blue: 1.000)
    static let textSecondary = Color(red: 0.720, green: 0.710, blue: 0.820)
}

struct HomeView: View {
    @Bindable var model: AppModel
    var showsSleepSessionAction = false

    var body: some View {
        ZStack {
            HomeBackground()

            ScrollView {
                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 24)
                        .padding(.top, 28)

                    HomeHeroCard(
                        playbackState: model.playbackState,
                        onPlayPause: {
                            model.open(.grounding)
                        },
                        onOpenPlayer: {
                            model.startSleepSession()
                        }
                    )
                    .padding(.top, 16)
                    .padding(.bottom, -12)

                    VStack(spacing: 16) {
                        if showsSleepSessionAction {
                            sleepSessionAction
                        }
                        scheduleSummary
                        editScheduleLink
                        quickActions
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 84)
                }
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("home.screen")
    }

    private var sleepSessionAction: some View {
        Button {
            model.startSleepSession()
        } label: {
            HStack(spacing: 16) {
                HomeIconBadge(systemImage: "bed.double.fill")

                VStack(alignment: .leading, spacing: 5) {
                    Text(model.sleepSessionStartedAt == nil ? "Start sleep session" : "Return to sleep session")
                        .font(AppFont.inter(size: 18, relativeTo: .headline, weight: .semibold))
                    Text("Keep grounding audio available from the Lock Screen")
                        .font(AppFont.inter(size: 14, relativeTo: .footnote))
                        .foregroundStyle(HomeScreenPalette.textSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(HomeScreenPalette.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 82)
            .background {
                LinearGradient(
                    colors: [HomeScreenPalette.card, HomeScreenPalette.iconBackground],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(HomeScreenPalette.accent.opacity(0.72), lineWidth: 1.2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(
            model.sleepSessionStartedAt == nil
                ? "Opens sleep mode and starts its Lock Screen companion."
                : "Returns to the active sleep session."
        )
        .accessibilityIdentifier("sleepSession.start")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(AppFont.inter(size: 14, relativeTo: .footnote, weight: .medium))
                .tracking(1.4)
                .foregroundStyle(HomeScreenPalette.textSecondary.opacity(0.82))
                .textCase(.uppercase)

            Text(greeting)
                .font(AppFont.latoBold(size: 34, relativeTo: .largeTitle))
                .accessibilityAddTraits(.isHeader)

            Text("Your private setup is ready whenever\nyou choose to use it.")
                .font(AppFont.inter(size: 18, relativeTo: .callout))
                .foregroundStyle(HomeScreenPalette.textSecondary)
                .lineSpacing(9)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var scheduleSummary: some View {
        Button {
            model.beginNewSchedule()
            model.open(.alarmScheduleEditor)
        } label: {
            HomeScheduleSummary(
                sleep: time(hour: model.sleepSchedule.sleepHour, minute: model.sleepSchedule.sleepMinute),
                wake: time(hour: model.sleepSchedule.wakeHour, minute: model.sleepSchedule.wakeMinute)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sleep schedule summary")
        .accessibilityHint("Opens alarm schedule editor")
        .accessibilityIdentifier("home.scheduleSummary")
    }

    private var editScheduleLink: some View {
        Button {
            model.open(.alarmHistory)
        } label: {
            HStack(spacing: 16) {
                HomeIconBadge(systemImage: "calendar")

                Text("Manage schedules")
                    .font(AppFont.inter(size: 18, relativeTo: .callout))

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(HomeScreenPalette.textSecondary)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 68)
            .background(HomeScreenPalette.cardSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(HomeScreenPalette.blueBorder, lineWidth: 1.2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Manage sleep schedules")
        .accessibilityIdentifier("home.editSchedule")
    }

    private var quickActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 32) {
                quickAction(
                    title: "Calm your mind",
                    detail: "Recovery audio",
                    icon: "waveform",
                    action: { model.startUnwindSession() }
                )
                quickAction(
                    title: "Morning\ncheck-in",
                    detail: "Start your day\nmindfully",
                    icon: "sunrise",
                    action: { model.open(.morningCheckIn) }
                )
            }

            VStack(spacing: 16) {
                quickAction(
                    title: "Calm your mind",
                    detail: "Recovery audio",
                    icon: "waveform",
                    action: { model.startUnwindSession() }
                )
                quickAction(
                    title: "Morning check-in",
                    detail: "Start your day mindfully",
                    icon: "sunrise",
                    action: { model.open(.morningCheckIn) }
                )
            }
        }
    }

    private func quickAction(
        title: String,
        detail: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HomeIconBadge(systemImage: icon)
                    .padding(.bottom, 20)

                Text(title)
                    .font(AppFont.inter(size: 17, relativeTo: .headline, weight: .semibold))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                Text(detail)
                    .font(AppFont.inter(size: 16, relativeTo: .body))
                    .foregroundStyle(HomeScreenPalette.textSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity, minHeight: 185, alignment: .topLeading)
            .background(HomeScreenPalette.card)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(HomeScreenPalette.cardBorder, lineWidth: 1.2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title.replacingOccurrences(of: "\n", with: " "))
        .accessibilityHint(detail.replacingOccurrences(of: "\n", with: " "))
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 0 ..< 12: "Good morning"
        case 12 ..< 17: "Good afternoon"
        default: "Good evening"
        }
    }

    private func time(hour: Int, minute: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }
}

private struct HomeBackground: View {
    var body: some View {
        LinearGradient(
            colors: [HomeScreenPalette.backgroundTop, HomeScreenPalette.backgroundBottom],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

private struct HomeHeroCard: View {
    let playbackState: GroundingPlaybackState
    let onPlayPause: () -> Void
    let onOpenPlayer: () -> Void

    private var isPlaying: Bool {
        if case .playing = playbackState {
            return true
        }
        return false
    }

    var body: some View {
        Button(action: onOpenPlayer) {
            ZStack {
                Image("HomeHero")
                    .resizable()
                    .scaledToFit()
                    .accessibilityHidden(true)

                VStack(spacing: 10) {
                    Text("Enable Lock screen")
                        .font(AppFont.latoBold(size: 24, relativeTo: .title2))
                        .multilineTextAlignment(.center)

                    Text("Keep grounding companion ready on your Lock Screen")
                        .font(AppFont.inter(size: 17, relativeTo: .body))
                        .foregroundStyle(HomeScreenPalette.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.top, 52)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .aspectRatio(860.0 / 586.0, contentMode: .fit)
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Enable Lock Screen")
        .accessibilityHint("Starts sleep session and activates Lock Screen companion.")
        .accessibilityIdentifier("home.heroCard")
        .overlay {
            GeometryReader { proxy in
                Button(action: onPlayPause) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        HomeScreenPalette.accent,
                                        HomeScreenPalette.iconTint,
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 58, height: 58)
                            .shadow(
                                color: HomeScreenPalette.accent.opacity(isPlaying ? 0.6 : 0.25),
                                radius: isPlaying ? 10 : 4
                            )

                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: isPlaying ? 0 : 2)
                    }
                    .frame(width: 76, height: 76)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPlaying ? "Pause recovery audio" : "Play recovery audio")
                .accessibilityHint("Plays or pauses your selected recovery audio.")
                .accessibilityIdentifier("home.manualEpisode")
                .position(
                    x: proxy.size.width * 0.790,
                    y: proxy.size.height * 0.552
                )
            }
        }
    }
}

private struct HomeIconBadge: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 23, weight: .medium))
            .foregroundStyle(HomeScreenPalette.iconTint)
            .frame(width: 36, height: 36)
            .background(HomeScreenPalette.iconBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(HomeScreenPalette.blueBorder, lineWidth: 1.1)
            }
    }
}

private struct HomeScheduleSummary: View {
    let sleep: String
    let wake: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            horizontalLayout
            verticalLayout
        }
    }

    private var horizontalLayout: some View {
        HStack(spacing: 12) {
            timeColumn(label: "SLEEP", value: sleep, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "arrow.right")
                .font(.system(size: 27, weight: .medium))
                .foregroundStyle(HomeScreenPalette.accent)

            timeColumn(label: "WAKE", value: wake, alignment: .trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, minHeight: 112)
        .background(HomeScreenPalette.cardSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(HomeScreenPalette.blueBorder.opacity(0.75), lineWidth: 1.2)
        }
    }

    private var verticalLayout: some View {
        VStack(spacing: 14) {
            timeColumn(label: "SLEEP", value: sleep, alignment: .center)
            Image(systemName: "arrow.down")
                .foregroundStyle(HomeScreenPalette.accent)
            timeColumn(label: "WAKE", value: wake, alignment: .center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(HomeScreenPalette.cardSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(HomeScreenPalette.blueBorder.opacity(0.75), lineWidth: 1.2)
        }
    }

    private func timeColumn(
        label: String,
        value: String,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 12) {
            Text(label)
                .font(AppFont.inter(size: 14, relativeTo: .footnote, weight: .semibold))
                .tracking(1.7)
                .foregroundStyle(HomeScreenPalette.textSecondary)

            Text(value)
                .font(AppFont.latoBold(size: 28, relativeTo: .title))
                .minimumScaleFactor(0.72)
                .lineLimit(1)
        }
    }
}
