import AVFoundation
import Foundation
import UserNotifications

nonisolated enum SystemAudioAssetRole: Sendable {
    case alarm
    case notification
}

nonisolated enum SystemAudioAssetError: Error, Equatable, Sendable {
    case notFound
    case unsupportedFormat
    case invalidDuration
    case installFailed
}

nonisolated struct SystemAudioAssetResolution: Equatable, Sendable {
    let fileName: String
    let usedFallback: Bool
}

nonisolated enum AlarmSoundSelectionStore {
    private static let selectedAlarmAssetIDKey = "app.sleepcompanion.alarm.selectedAssetID"
    private static let selectedAlarmFileNameKey = "app.sleepcompanion.alarm.selectedFileName"
    private static let selectedNotificationAssetIDKey = "app.sleepcompanion.notification.selectedAssetID"
    private static let selectedNotificationFileNameKey = "app.sleepcompanion.notification.selectedFileName"

    static func selectedAlarmAssetID() -> String? {
        UserDefaults.standard.string(forKey: selectedAlarmAssetIDKey)
    }

    static func selectedAlarmSoundFileName() -> String? {
        UserDefaults.standard.string(forKey: selectedAlarmFileNameKey)
    }

    static func selectAlarm(assetID: String, fileName: String) {
        UserDefaults.standard.set(assetID, forKey: selectedAlarmAssetIDKey)
        UserDefaults.standard.set(fileName, forKey: selectedAlarmFileNameKey)
    }

    static func selectedNotificationAssetID() -> String? {
        UserDefaults.standard.string(forKey: selectedNotificationAssetIDKey)
    }

    static func selectNotification(assetID: String, fileName: String) {
        UserDefaults.standard.set(assetID, forKey: selectedNotificationAssetIDKey)
        UserDefaults.standard.set(fileName, forKey: selectedNotificationFileNameKey)
    }

    static func selectedNotificationSoundFileName() -> String? {
        UserDefaults.standard.string(forKey: selectedNotificationFileNameKey)
    }
}

nonisolated enum SystemAudioAssets {
    // The default resources are intentionally tiny and local. Catalog choices
    // must be downloaded and installed before they can be used by AlarmKit.
    static let defaultAlarmAssetID = "felt-dawn"
    static let defaultNotificationAssetID = "notification"
    static let defaultAlarmFileName = "SPCWakeUpGentleLoop.caf"
    static let defaultNotificationFileName = "SPCNotification.caf"

    static func downloadedAlarmFileName(assetID: String, version: Int) -> String {
        let safeID = assetID.replacingOccurrences(
            of: "[^A-Za-z0-9._-]",
            with: "_",
            options: .regularExpression
        )
        return "SPCAlarm-\(safeID)-v\(version).caf"
    }

    static func resolveAlarmSound(
        requestedFileName: String?
    ) -> SystemAudioAssetResolution? {
        if let requestedFileName,
           !requestedFileName.isEmpty,
           localURL(for: requestedFileName).map({ isUsable($0, role: .alarm) }) == true
        {
            return SystemAudioAssetResolution(fileName: requestedFileName, usedFallback: false)
        }

        guard localURL(for: defaultAlarmFileName)
            .map({ isUsable($0, role: .alarm) }) == true
        else {
            return nil
        }

        return SystemAudioAssetResolution(
            fileName: defaultAlarmFileName,
            usedFallback: requestedFileName != nil
        )
    }

    static func notificationSound() -> UNNotificationSound {
        let requested = AlarmSoundSelectionStore.selectedNotificationSoundFileName()
            ?? defaultNotificationFileName
        if localURL(for: requested).map({ isUsable($0, role: .notification) }) == true {
            return UNNotificationSound(named: UNNotificationSoundName(rawValue: requested))
        }
        if localURL(for: defaultNotificationFileName)
            .map({ isUsable($0, role: .notification) }) == true
        {
            return UNNotificationSound(
                named: UNNotificationSoundName(rawValue: defaultNotificationFileName)
            )
        }
        return .default
    }

    static func preflightNotification(resourceName: String) throws -> URL {
        guard let url = localURL(for: resourceName) else {
            throw SystemAudioAssetError.notFound
        }
        try validate(url, role: .notification)
        return url
    }

    static func bundledURL(for fileName: String) -> URL? {
        guard isSafeFileName(fileName) else { return nil }
        let fileURL = URL(fileURLWithPath: fileName)
        return Bundle.main.url(
            forResource: fileURL.deletingPathExtension().lastPathComponent,
            withExtension: fileURL.pathExtension
        )
    }

    static func validateAlarmSoundForCatalog(url: URL) throws {
        try validate(url, role: .alarm)
    }

    static func installDownloadedAlarm(
        from sourceURL: URL,
        assetID: String,
        version: Int
    ) throws -> URL {
        try validate(sourceURL, role: .alarm)
        let fileName = downloadedAlarmFileName(assetID: assetID, version: version)
        let soundsDirectory = try soundsDirectoryURL()
        let destination = soundsDirectory.appendingPathComponent(fileName, isDirectory: false)
        let temporary = soundsDirectory.appendingPathComponent(
            ".\(fileName).\(UUID().uuidString).partial",
            isDirectory: false
        )

        do {
            try FileManager.default.copyItem(at: sourceURL, to: temporary)
            try SystemProtectedFileApplicator().applyProtection(
                to: temporary,
                kind: .downloadedAudioCache
            )
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: temporary, to: destination)
            try SystemProtectedFileApplicator().applyProtection(
                to: destination,
                kind: .downloadedAudioCache
            )
            try validate(destination, role: .alarm)
            return destination
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            try? FileManager.default.removeItem(at: destination)
            throw SystemAudioAssetError.installFailed
        }
    }

    private static func localURL(for fileName: String) -> URL? {
        guard isSafeFileName(fileName) else { return nil }
        let libraryURL = try? soundsDirectoryURL()
        let librarySound = libraryURL?.appendingPathComponent(fileName, isDirectory: false)
        if let librarySound, FileManager.default.fileExists(atPath: librarySound.path) {
            return librarySound
        }

        return bundledURL(for: fileName)
    }

    private static func isSafeFileName(_ fileName: String) -> Bool {
        guard !fileName.isEmpty,
              fileName != ".",
              fileName != "..",
              !fileName.contains("/"),
              !fileName.contains("\\")
        else {
            return false
        }
        return URL(fileURLWithPath: fileName).lastPathComponent == fileName
    }

    private static func soundsDirectoryURL() throws -> URL {
        guard let libraryURL = FileManager.default.urls(
            for: .libraryDirectory,
            in: .userDomainMask
        ).first else {
            throw SystemAudioAssetError.installFailed
        }
        let soundsDirectory = libraryURL.appendingPathComponent("Sounds", isDirectory: true)
        try FileManager.default.createDirectory(
            at: soundsDirectory,
            withIntermediateDirectories: true
        )
        return soundsDirectory
    }

    private static func validate(
        _ url: URL,
        role: SystemAudioAssetRole
    ) throws {
        guard FileManager.default.fileExists(atPath: url.path),
              url.pathExtension.lowercased() == "caf"
        else {
            throw SystemAudioAssetError.notFound
        }

        do {
            let audioFile = try AVAudioFile(forReading: url)
            let format = audioFile.fileFormat
            guard format.channelCount == 1,
                  [44_100.0, 48_000.0].contains(format.sampleRate),
                  format.commonFormat == .pcmFormatInt16,
                  audioFile.length > 0
            else {
                throw SystemAudioAssetError.unsupportedFormat
            }
            let duration = Double(audioFile.length) / format.sampleRate
            guard duration.isFinite, duration > 0 else {
                throw SystemAudioAssetError.invalidDuration
            }
            if role == .notification, duration >= 30 {
                throw SystemAudioAssetError.invalidDuration
            }
        } catch let error as SystemAudioAssetError {
            throw error
        } catch {
            throw SystemAudioAssetError.unsupportedFormat
        }
    }

    private static func isUsable(
        _ url: URL,
        role: SystemAudioAssetRole
    ) -> Bool {
        (try? validate(url, role: role)) != nil
    }
}
