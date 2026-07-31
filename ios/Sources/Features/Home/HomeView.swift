import SwiftUI

struct HomeView: View {
    @Bindable var model: AppModel

    var body: some View {
        NightScreen {
            VStack(alignment: .leading, spacing: AppSpacing.spacious) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .textCase(.uppercase)
                Text("Good evening")
                    .font(AppTypographyRole.hero)
                    .accessibilityAddTraits(.isHeader)
                Text("Your private setup is ready whenever you choose to use it.")
                    .foregroundStyle(.white.opacity(0.72))

                Button {
                    model.beginManualGrounding()
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 42))
                        Text("I just had an episode")
                            .font(.title2.bold())
                        Text("Open visual grounding and your selected local recovery audio")
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.72))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 28)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [Color.indigo, Color.blue.opacity(0.75)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppShape.cardRadius))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the manual grounding screen. It does not automatically create a history entry.")
                .accessibilityIdentifier("home.manualEpisode")

                NightCard {
                    Label("Tonight’s sleep schedule", systemImage: "alarm.fill")
                        .font(.headline)
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Sleep")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.58))
                            Text(time(hour: model.sleepSchedule.sleepHour, minute: model.sleepSchedule.sleepMinute))
                                .font(.title2.bold())
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.white.opacity(0.45))
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Wake")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.58))
                            Text(time(hour: model.sleepSchedule.wakeHour, minute: model.sleepSchedule.wakeMinute))
                                .font(.title2.bold())
                        }
                    }
                    .padding(.vertical, 6)
                    Button("Edit schedule", systemImage: "calendar") {
                        model.open(.sleepSchedule)
                    }
                    .buttonStyle(.bordered)
                }

                HStack(spacing: AppSpacing.standard) {
                    quickAction("Comfort audio", icon: "waveform") {
                        model.open(.audioLibrary)
                    }
                    quickAction("Morning check-in", icon: "sunrise.fill") {
                        model.open(.morningCheckIn)
                    }
                }
            }
        }
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func quickAction(
        _ title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.cyan)
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.leading)
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            .background(Color.white.opacity(0.075))
            .clipShape(RoundedRectangle(cornerRadius: AppShape.cardRadius))
        }
        .buttonStyle(.plain)
    }

    private func time(hour: Int, minute: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }
}
