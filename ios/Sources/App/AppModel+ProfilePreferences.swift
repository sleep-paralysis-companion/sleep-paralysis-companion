import UIKit

@MainActor
extension AppModel {
    func updateDisplayName(_ value: String) {
        guard let userID, var profile else { return }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 80 else {
            feedbackMessage = "Enter a display name between 1 and 80 characters."
            return
        }
        profile.displayName = trimmed
        profile.revision += 1
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await store.saveProfile(profile, userID: userID)
                self.profile = profile
            } catch {
                feedbackMessage = "Your display name was not changed."
            }
        }
    }

    func saveDefaultSupport(sleep: DefaultEpisodeSupport, postEpisode: DefaultEpisodeSupport) {
        guard let userID, var settings else { return }
        settings.defaultSleepSupport = sleep
        settings.defaultPostEpisodeSupport = postEpisode
        settings.updatedAt = Date()
        settings.revision += 1
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await store.saveSettings(settings, userID: userID)
                self.settings = settings
                feedbackMessage = "Preferences saved."
            } catch {
                feedbackMessage = "Your preferences were not saved."
            }
        }
    }

    func manageNotifications() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                reminderAuthorization = try await reminders.requestPermission()
                if reminderAuthorization == .denied {
                    feedbackMessage = "Notifications are off. Enable them in iOS Settings to receive sleep reminders."
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } catch {
                feedbackMessage = "Notification permission could not be requested."
            }
        }
    }

    func completeMorningCheckIn() {
        isMorningCheckInPresented = false
        selectedTab = .home
        path = []
    }
}
