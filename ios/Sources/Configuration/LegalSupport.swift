import Foundation

nonisolated enum LegalSupport {
    static let founderName = "Preshit Rakshe"
    static let supportEmail = "founder@sleepparalysis.app"

    static let privacyURL = URL(string: "https://sleepparalysis.app/privacy")!
    static let termsURL = URL(string: "https://sleepparalysis.app/terms")!
    static let supportURL = URL(string: "https://sleepparalysis.app/support")!
    static let accountDeletionURL = URL(string: "https://sleepparalysis.app/delete-account")!
    static let supportEmailURL = URL(string: "mailto:\(supportEmail)")!
}

nonisolated enum HelpLegalCopy {
    static let productBoundary =
        "Sleep Paralysis Companion is a nonmedical wellness companion. " +
        "It does not diagnose, detect, monitor, predict, " +
        "prevent, or treat sleep paralysis and is not an emergency service."

    static let manualEpisodeBoundary =
        "Every episode action and check-in is started by you. " +
        "The app never automatically infers an episode."

    static let personalAudioBoundary = "Personal audio remains on this device."

    static let notificationBoundary = "Notification reminders are ordinary reminders, not guaranteed alarms."

    static let emergencyBoundary =
        "Use the emergency and support resources available in your location. " +
        "Sleep Paralysis Companion does not contact emergency services."
}
