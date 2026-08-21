import AVFoundation
import Foundation

/// The system-alert representation of one device-local personal recording.
/// The source clip remains in the protected PersonalAudio store; this CAF is
/// only the AlarmKit-compatible copy in Library/Sounds.
nonisolated struct PreparedPersonalAlarmAudio: Equatable, Sendable {
    let clipID: UUID
    let fileName: String
    let url: URL
}

nonisolated enum PersonalAlarmAudioPreparationError: Error, Equatable, Sendable {
    case sourceUnavailable
    case unsupportedSource
    case conversionFailed
    case invalidOutput
    case installFailed
}

/// AVAudioConverter invokes its input block synchronously during `convert`.
/// Keep the callback state in a scoped heap value so Swift 6 does not treat
/// the converter's callback as an unsafe mutable capture.
private struct PersonalAlarmConverterInputState {
    var inputBuffer: AVAudioPCMBuffer
    var reachedEnd = false
    var sourceReadError: Error?

    init(inputBuffer: AVAudioPCMBuffer) {
        self.inputBuffer = inputBuffer
    }
}

/// Stable, pure values shared by the preparation boundary and tests.
nonisolated enum PersonalAlarmAudioContract {
    static let sampleRate: Double = 44_100
    static let channelCount = 1
    static let bitDepth = 16
    static let fileExtension = "caf"

    static func fileName(for clipID: UUID) -> String {
        "SPCPersonalAlarm-\(clipID.uuidString.lowercased()).caf"
    }

    static func isPreparedFileName(_ fileName: String) -> Bool {
        guard fileName == fileName.trimmingCharacters(in: .whitespacesAndNewlines),
              fileName.hasPrefix("SPCPersonalAlarm-"),
              fileName.hasSuffix(".caf")
        else {
            return false
        }
        let uuidText = fileName
            .dropFirst("SPCPersonalAlarm-".count)
            .dropLast(".caf".count)
        return UUID(uuidString: String(uuidText)) != nil
    }
}

/// Prepares personal clips for AlarmKit without ever substituting a bundled
/// or catalog sound. The actor serializes preparation and makes repeated
/// requests idempotent for the same clip UUID.
actor PersonalAlarmAudioPreparer {
    private let fileStore: PersonalAudioFileStore
    private let protection: any ProtectedFileApplying

    init(
        fileStore: PersonalAudioFileStore = PersonalAudioFileStore(),
        protection: any ProtectedFileApplying = SystemProtectedFileApplicator()
    ) {
        self.fileStore = fileStore
        self.protection = protection
    }

    /// Returns the local filename that can be passed to AlarmKit's named
    /// sound configuration. A missing, protected, corrupt, or unsupported
    /// source throws instead of falling back to another audio asset.
    func prepare(
        clip: PersonalAudioClipMetadata
    ) async throws -> PreparedPersonalAlarmAudio {
        guard clip.availability == .ready else {
            throw PersonalAlarmAudioPreparationError.sourceUnavailable
        }

        let sourceURL: URL
        do {
            sourceURL = try await fileStore.existingURL(for: clip)
        } catch {
            throw PersonalAlarmAudioPreparationError.sourceUnavailable
        }

        let soundsDirectory: URL
        do {
            soundsDirectory = try soundsDirectoryURL()
            try protection.applyProtection(to: soundsDirectory, kind: .personalAudio)
        } catch {
            throw PersonalAlarmAudioPreparationError.installFailed
        }

        let fileName = PersonalAlarmAudioContract.fileName(for: clip.id)
        let destination = soundsDirectory.appendingPathComponent(fileName, isDirectory: false)

        if FileManager.default.fileExists(atPath: destination.path) {
            do {
                try SystemAudioAssets.validateAlarmSoundForCatalog(url: destination)
                try protection.applyProtection(to: destination, kind: .personalAudio)
                return PreparedPersonalAlarmAudio(clipID: clip.id, fileName: fileName, url: destination)
            } catch {
                // Only remove this boundary's deterministic output. Other
                // bundled/catalog assets are never touched.
                try? FileManager.default.removeItem(at: destination)
            }
        }

        let temporary = soundsDirectory.appendingPathComponent(
            ".\(UUID().uuidString).\(fileName)",
            isDirectory: false
        )

        do {
            try transcode(sourceURL: sourceURL, to: temporary)
            try protection.applyProtection(to: temporary, kind: .personalAudio)
            try SystemAudioAssets.validateAlarmSoundForCatalog(url: temporary)
            try FileManager.default.moveItem(at: temporary, to: destination)
            try protection.applyProtection(to: destination, kind: .personalAudio)
            try SystemAudioAssets.validateAlarmSoundForCatalog(url: destination)
            return PreparedPersonalAlarmAudio(clipID: clip.id, fileName: fileName, url: destination)
        } catch let error as PersonalAlarmAudioPreparationError {
            try? FileManager.default.removeItem(at: temporary)
            throw error
        } catch let error as SystemAudioAssetError {
            try? FileManager.default.removeItem(at: temporary)
            switch error {
            case .notFound, .unsupportedFormat, .invalidDuration:
                throw PersonalAlarmAudioPreparationError.invalidOutput
            case .installFailed:
                throw PersonalAlarmAudioPreparationError.installFailed
            }
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            throw PersonalAlarmAudioPreparationError.installFailed
        }
    }

    /// Removes only the prepared AlarmKit copy. The source recording and its
    /// metadata stay untouched so deleting a schedule cannot delete audio.
    func removePreparedClip(clipID: UUID) async throws {
        let fileName = PersonalAlarmAudioContract.fileName(for: clipID)
        do {
            let directory = try soundsDirectoryURL()
            let url = directory.appendingPathComponent(fileName, isDirectory: false)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        } catch {
            throw PersonalAlarmAudioPreparationError.installFailed
        }
    }

    private func soundsDirectoryURL() throws -> URL {
        guard let libraryURL = FileManager.default.urls(
            for: .libraryDirectory,
            in: .userDomainMask
        ).first else {
            throw PersonalAlarmAudioPreparationError.installFailed
        }
        let directory = libraryURL.appendingPathComponent("Sounds", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    private func transcode(sourceURL: URL, to destinationURL: URL) throws {
        let source: AVAudioFile
        do {
            source = try AVAudioFile(forReading: sourceURL)
        } catch {
            throw PersonalAlarmAudioPreparationError.sourceUnavailable
        }

        guard source.length > 0,
              let outputFormat = AVAudioFormat(
                  commonFormat: .pcmFormatInt16,
                  sampleRate: PersonalAlarmAudioContract.sampleRate,
                  channels: AVAudioChannelCount(PersonalAlarmAudioContract.channelCount),
                  interleaved: true
              ),
              let converter = AVAudioConverter(
                  from: source.processingFormat,
                  to: outputFormat
              )
        else {
            throw PersonalAlarmAudioPreparationError.unsupportedSource
        }

        let output: AVAudioFile
        do {
            output = try AVAudioFile(
                forWriting: destinationURL,
                settings: outputFormat.settings,
                commonFormat: .pcmFormatInt16,
                interleaved: true
            )
        } catch {
            throw PersonalAlarmAudioPreparationError.conversionFailed
        }

        guard let inputBuffer = AVAudioPCMBuffer(
            pcmFormat: source.processingFormat,
            frameCapacity: 4096
        ),
        let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: 4096
        ) else {
            throw PersonalAlarmAudioPreparationError.conversionFailed
        }

        let inputState = UnsafeMutablePointer<PersonalAlarmConverterInputState>.allocate(capacity: 1)
        inputState.initialize(to: PersonalAlarmConverterInputState(inputBuffer: inputBuffer))
        defer {
            inputState.deinitialize(count: 1)
            inputState.deallocate()
        }

        while true {
            try Task.checkCancellation()
            outputBuffer.frameLength = 0
            var conversionError: NSError?
            let status = converter.convert(to: outputBuffer, error: &conversionError) { _, status in
                if inputState.pointee.reachedEnd {
                    status.pointee = .endOfStream
                    return nil
                }

                do {
                    try source.read(into: inputState.pointee.inputBuffer)
                } catch {
                    inputState.pointee.sourceReadError = error
                    inputState.pointee.reachedEnd = true
                    status.pointee = .endOfStream
                    return nil
                }

                guard inputState.pointee.inputBuffer.frameLength > 0 else {
                    inputState.pointee.reachedEnd = true
                    status.pointee = .endOfStream
                    return nil
                }
                status.pointee = .haveData
                return inputState.pointee.inputBuffer
            }

            if inputState.pointee.sourceReadError != nil {
                throw PersonalAlarmAudioPreparationError.sourceUnavailable
            }
            if conversionError != nil || status == .error {
                throw PersonalAlarmAudioPreparationError.conversionFailed
            }
            if outputBuffer.frameLength > 0 {
                do {
                    try output.write(from: outputBuffer)
                } catch {
                    throw PersonalAlarmAudioPreparationError.conversionFailed
                }
            }
            if status == .endOfStream {
                break
            }
        }
    }
}
