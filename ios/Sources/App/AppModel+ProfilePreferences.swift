import UIKit

@MainActor
extension AppModel {
    var restorationValue: String {
        guard let profileID, launchDestination == .home else { return "" }
        return restorationCodec.encode(
            RouteRestorationEnvelope(
                profileID: profileID,
                selectedTab: selectedTab,
                path: path,
                sheet: presentedSheet
            )
        ) ?? ""
    }

    var selectedCheckIn: SubmittedCheckIn? {
        checkIns.first { $0.id == selectedCheckInID }
    }

    var isAuthenticationConfigured: Bool {
        authentication.isConfigured
    }

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

    func savePartnerCallSettings(
        sleep: DefaultEpisodeSupport,
        postEpisode: DefaultEpisodeSupport,
        partnerName: String,
        partnerPhoneNumber: String
    ) {
        guard let userID, let profileID, var settings else { return }
        let trimmedPhoneNumber = partnerPhoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = partnerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let contact: PartnerContact?

        if trimmedPhoneNumber.isEmpty {
            guard trimmedName.isEmpty else {
                feedbackMessage = "Add a phone number before saving the partner name."
                return
            }
            contact = nil
        } else {
            guard let validatedContact = PartnerContact(name: trimmedName, phoneNumber: trimmedPhoneNumber) else {
                feedbackMessage = "Enter a valid phone number with 7 to 15 digits."
                return
            }
            contact = validatedContact
        }

        settings.defaultSleepSupport = sleep
        settings.defaultPostEpisodeSupport = postEpisode
        settings.updatedAt = Date()
        settings.revision += 1
        let updatedSettings = settings

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                if let contact {
                    try await store.savePartnerContact(contact, profileID: profileID, userID: userID)
                } else {
                    try await store.deletePartnerContact(profileID: profileID, userID: userID)
                }
                try await store.saveSettings(updatedSettings, userID: userID)
                self.updatePartnerContact(contact)
                self.settings = updatedSettings
                feedbackMessage = "Preferences saved."
            } catch {
                feedbackMessage = "Your partner call settings were not saved."
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
                        await UIApplication.shared.open(url)
                    }
                }
            } catch {
                feedbackMessage = "Notification permission could not be requested."
            }
        }
    }

    func completeMorningCheckIn() {
        isMorningCheckInPresented = false
        selectedTab = .sleep
        path = []
    }
}
