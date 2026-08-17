import AVFoundation
import CoreMedia
import Foundation

nonisolated enum PersonalAudioDurationValidator {
    static func milliseconds(from duration: CMTime) throws -> Int64 {
        guard duration.isValid,
              duration.isNumeric,
              !duration.isIndefinite
        else {
            throw PersonaAudioValidationError.invalidAudioMetadata
        }
        let seconds = duration.seconds
        guard seconds.isFinite,
              seconds >= 0,
              seconds * 1000 <= Double(PersonalAudioPolicy.maximumDurationMilliseconds)
        else {
            throw PersonaAudioValidationError.invalidAudioMetadata
        }
        return Int64((seconds * 1000).rounded(.towardZero))
    }

    static func milliseconds(from seconds: TimeInterval) throws -> Int64 {
        guard seconds.isFinite,
              seconds >= 0,
              seconds * 1000 <= Double(PersonalAudioPolicy.maximumDurationMilliseconds)
        else {
            throw PersonaAudioValidationError.invalidAudioMetadata
        }
        return Int64((seconds * 1000).rounded(.towardZero))
    }
}

nonisolated enum RecordingLifecycleBoundary {
    static func requiresCancellation(isRecording: Bool, sceneIsActive: Bool) -> Bool {
        isRecording && !sceneIsActive
    }
}

nonisolated struct PersonalAudioDeletionToken: Sendable {
    let originalURL: URL
    let quarantinedURL: URL?
}

@MainActor
enum PersonalAudioLifecycleCoordinator {
    static func persistImported(
        persistMetadata: () async throws -> Void,
        removeCommittedBytes: () async throws -> Void
    ) async throws {
        do {
            try await persistMetadata()
        } catch {
            do {
                try await removeCommittedBytes()
            } catch {
                throw Phase1ActionError.audioUnavailable
            }
            throw error
        }
    }

    static func delete(
        stageBytes: () async throws -> PersonalAudioDeletionToken,
        deleteMetadata: () async throws -> Void,
        restoreMetadata: () async throws -> Void,
        commitBytes: (PersonalAudioDeletionToken) async throws -> Void,
        rollbackBytes: (PersonalAudioDeletionToken) async throws -> Void
    ) async throws {
        let token = try await stageBytes()
        do {
            try await deleteMetadata()
        } catch {
            try await rollbackBytes(token)
            throw error
        }
        do {
            try await commitBytes(token)
        } catch {
            try await restoreMetadata()
            try await rollbackBytes(token)
            throw error
        }
    }
}

actor PersonalAudioFileStore {
    private let protection: any ProtectedFileApplying

    init(protection: any ProtectedFileApplying = SystemProtectedFileApplicator()) {
        self.protection = protection
    }

    func importClip(
        from sourceURL: URL,
        profileID: UUID,
        clipID: UUID
    ) async throws -> PersonalAudioClipMetadata {
        let scoped = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }
        let format = try Self.format(for: sourceURL)
        let directory = try directoryURL(profileID: profileID)
        let destination = try clipURL(
            profileID: profileID,
            clipID: clipID,
            format: format
        )
        let temporary = directory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        do {
            try FileManager.default.copyItem(at: sourceURL, to: temporary)
            let values = try temporary.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values.isRegularFile == true,
                  let byteCount = values.fileSize,
                  byteCount > 0
            else {
                throw Phase1ActionError.audioUnavailable
            }
            let asset = AVURLAsset(url: temporary)
            let duration = try await asset.load(.duration)
            try Task.checkCancellation()
            let milliseconds = try PersonalAudioDurationValidator.milliseconds(from: duration)
            guard PersonalAudioPolicy.validates(
                source: .imported,
                storageFormat: format,
                byteCount: Int64(byteCount),
                durationMilliseconds: milliseconds
            ) else {
                throw PersonaAudioValidationError.invalidAudioMetadata
            }
            try Task.checkCancellation()
            try FileManager.default.moveItem(at: temporary, to: destination)
            try protection.applyProtection(to: destination, kind: .personalAudio)
            return PersonalAudioClipMetadata(
                id: clipID,
                profileID: profileID,
                source: .imported,
                storageFormat: format,
                byteCount: Int64(byteCount),
                durationMilliseconds: milliseconds,
                createdOrImportedAt: Date(),
                availability: .ready,
                protectionVersion: 1
            )
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }

    func recordingURL(profileID: UUID, clipID: UUID) throws -> URL {
        let url = try clipURL(profileID: profileID, clipID: clipID, format: .m4a)
        try protection.applyProtection(to: url.deletingLastPathComponent(), kind: .personalAudio)
        return url
    }

    func metadataForRecording(
        profileID: UUID,
        clipID: UUID,
        duration: TimeInterval
    ) throws -> PersonalAudioClipMetadata {
        let url = try clipURL(profileID: profileID, clipID: clipID, format: .m4a)
        let byteCount = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        let milliseconds = try PersonalAudioDurationValidator.milliseconds(from: duration)
        guard PersonalAudioPolicy.validates(
            source: .recorded,
            storageFormat: .m4a,
            byteCount: Int64(byteCount),
            durationMilliseconds: milliseconds
        ) else {
            throw PersonaAudioValidationError.invalidAudioMetadata
        }
        try protection.applyProtection(to: url, kind: .personalAudio)
        return PersonalAudioClipMetadata(
            id: clipID,
            profileID: profileID,
            source: .recorded,
            storageFormat: .m4a,
            byteCount: Int64(byteCount),
            durationMilliseconds: milliseconds,
            createdOrImportedAt: Date(),
            availability: .ready,
            protectionVersion: 1
        )
    }

    func discardRecording(profileID: UUID, clipID: UUID) {
        guard let url = try? clipURL(profileID: profileID, clipID: clipID, format: .m4a) else {
            return
        }
        try? FileManager.default.removeItem(at: url)
    }

    func existingURL(for metadata: PersonalAudioClipMetadata) throws -> URL {
        let url = try clipURL(
            profileID: metadata.profileID,
            clipID: metadata.id,
            format: metadata.storageFormat
        )
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw Phase1ActionError.audioUnavailable
        }
        return url
    }

    func delete(_ metadata: PersonalAudioClipMetadata) throws {
        let token = try stageDeletion(metadata)
        try commitDeletion(token)
    }

    func stageDeletion(_ metadata: PersonalAudioClipMetadata) throws -> PersonalAudioDeletionToken {
        let url = try clipURL(
            profileID: metadata.profileID,
            clipID: metadata.id,
            format: metadata.storageFormat
        )
        guard FileManager.default.fileExists(atPath: url.path) else {
            return PersonalAudioDeletionToken(originalURL: url, quarantinedURL: nil)
        }
        let quarantineDirectory = url.deletingLastPathComponent()
            .appendingPathComponent(".PendingDeletion", isDirectory: true)
        try FileManager.default.createDirectory(
            at: quarantineDirectory,
            withIntermediateDirectories: true
        )
        try protection.applyProtection(to: quarantineDirectory, kind: .personalAudio)
        let quarantinedURL = quarantineDirectory.appendingPathComponent(
            "\(UUID().uuidString).\(metadata.storageFormat.rawValue)"
        )
        try FileManager.default.moveItem(at: url, to: quarantinedURL)
        return PersonalAudioDeletionToken(originalURL: url, quarantinedURL: quarantinedURL)
    }

    func commitDeletion(_ token: PersonalAudioDeletionToken) throws {
        guard let quarantinedURL = token.quarantinedURL else { return }
        try FileManager.default.removeItem(at: quarantinedURL)
    }

    func rollbackDeletion(_ token: PersonalAudioDeletionToken) throws {
        guard let quarantinedURL = token.quarantinedURL,
              FileManager.default.fileExists(atPath: quarantinedURL.path)
        else { return }
        try FileManager.default.moveItem(at: quarantinedURL, to: token.originalURL)
    }

    func deleteAll(profileID: UUID) throws {
        let directory = try directoryURL(profileID: profileID)
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
        try cleanupTemporaryExports()
    }

    func protectedExportURL(for metadata: PersonalAudioClipMetadata) throws -> URL {
        let source = try existingURL(for: metadata)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SleepParalysisCompanionAudioExports", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try protection.applyProtection(to: directory, kind: .sensitiveTemporaryExport)
        let url = directory.appendingPathComponent(
            "\(UUID().uuidString).\(metadata.storageFormat.rawValue)",
            isDirectory: false
        )
        try FileManager.default.copyItem(at: source, to: url)
        try protection.applyProtection(to: url, kind: .sensitiveTemporaryExport)
        return url
    }

    func removeTemporaryExport(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private func cleanupTemporaryExports() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SleepParalysisCompanionAudioExports", isDirectory: true)
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }

    private func directoryURL(profileID: UUID) throws -> URL {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = root
            .appendingPathComponent("SleepParalysisCompanion", isDirectory: true)
            .appendingPathComponent("PersonalAudio", isDirectory: true)
            .appendingPathComponent(profileID.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func clipURL(
        profileID: UUID,
        clipID: UUID,
        format: PersonalAudioStorageFormat
    ) throws -> URL {
        try directoryURL(profileID: profileID)
            .appendingPathComponent("\(clipID.uuidString).\(format.rawValue)", isDirectory: false)
    }

    private nonisolated static func format(for url: URL) throws -> PersonalAudioStorageFormat {
        switch url.pathExtension.lowercased() {
        case "m4a": .m4a
        case "mp3": .mp3
        case "wav": .wav
        case "aif", "aiff": .aiff
        case "caf": .caf
        default: throw Phase1ActionError.audioUnavailable
        }
    }
}

@MainActor
final class RecoveryAudioController: NSObject, AVAudioPlayerDelegate, AVAudioRecorderDelegate {
    static let maximumRecordingDuration: TimeInterval = 180

    private(set) var playbackState = GroundingPlaybackState.idle
    private(set) var isRecording = false
    private(set) var recordingDuration: TimeInterval = 0

    private var player: AVAudioPlayer?
    private var recorder: AVAudioRecorder?
    private var recordingStartedAt: Date?
    private var interruptionTask: Task<Void, Never>?
    var recordingEndedUnexpectedly: (@MainActor @Sendable () -> Void)?

    override init() {
        super.init()
        interruptionTask = Task { @MainActor [weak self] in
            for await notification in NotificationCenter.default.notifications(
                named: AVAudioSession.interruptionNotification
            ) {
                guard let self,
                      isRecording,
                      let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                      AVAudioSession.InterruptionType(rawValue: rawType) == .began
                else { continue }
                cancelRecording()
                recordingEndedUnexpectedly?()
            }
        }
    }

    func microphonePermission() -> AVAudioApplication.recordPermission {
        AVAudioApplication.shared.recordPermission
    }

    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }
    }

    func startRecording(to url: URL) throws {
        guard !isRecording else { throw Phase1ActionError.audioUnavailable }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
            try session.setActive(true)
            let recorder = try AVAudioRecorder(
                url: url,
                settings: [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: 44100,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                ]
            )
            recorder.delegate = self
            guard recorder.record(forDuration: Self.maximumRecordingDuration) else {
                recorder.deleteRecording()
                throw Phase1ActionError.audioUnavailable
            }
            self.recorder = recorder
            recordingStartedAt = Date()
            isRecording = true
        } catch {
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }

    func stopRecording() -> TimeInterval {
        guard let recorder else { return 0 }
        let duration = recorder.currentTime
        recorder.stop()
        self.recorder = nil
        isRecording = false
        recordingDuration = duration
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return duration
    }

    func cancelRecording() {
        recorder?.stop()
        recorder?.deleteRecording()
        recorder = nil
        isRecording = false
        recordingDuration = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func deactivateRecordingSession() {
        cancelRecording()
    }

    func play(url: URL, identifier: String) throws {
        if case let .playing(active) = playbackState, active == identifier {
            return
        }
        stopPlayback()
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio)
        try session.setActive(true)
        let player = try AVAudioPlayer(contentsOf: url)
        player.delegate = self
        player.prepareToPlay()
        guard player.play() else { throw Phase1ActionError.audioUnavailable }
        self.player = player
        playbackState = .playing(identifier)
    }

    func togglePause() {
        guard let player else { return }
        if player.isPlaying {
            player.pause()
            if case let .playing(identifier) = playbackState {
                playbackState = .paused(identifier)
            }
        } else {
            player.play()
            if case let .paused(identifier) = playbackState {
                playbackState = .playing(identifier)
            }
        }
    }

    func stopPlayback() {
        player?.stop()
        player = nil
        playbackState = .idle
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func showVisualFallback() {
        stopPlayback()
        playbackState = .visualFallback
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        _ = player
        _ = flag
        Task { @MainActor [weak self] in self?.stopPlayback() }
    }

    nonisolated func audioRecorderDidFinishRecording(
        _ recorder: AVAudioRecorder,
        successfully flag: Bool
    ) {
        _ = recorder
        Task { @MainActor [weak self] in
            guard let self, isRecording else { return }
            _ = flag
            // A duration-limited recorder finishing is cancellation, not an
            // implicit save: the user never approved a background finish.
            cancelRecording()
            recordingEndedUnexpectedly?()
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(
        _ recorder: AVAudioRecorder,
        error: (any Error)?
    ) {
        _ = recorder
        _ = error
        Task { @MainActor [weak self] in
            self?.cancelRecording()
            self?.recordingEndedUnexpectedly?()
        }
    }
}
