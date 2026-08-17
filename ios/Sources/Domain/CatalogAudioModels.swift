import Foundation

// The state machine and manifest validator enumerate independent delivery rules.
// swiftlint:disable cyclomatic_complexity

nonisolated enum CatalogAudioCategory: String, Codable, CaseIterable, Sendable {
    case morningAlarm = "morning_alarm"
    case notification
    case quickUnwind = "quick_unwind"
    case secondSleep = "second_sleep"
    case slowUnwind = "slow_unwind"
}

nonisolated enum CatalogAudioDelivery: String, Codable, CaseIterable, Sendable {
    case bundled
    case downloadable
}

nonisolated enum CatalogAudioApprovalStatus: String, Codable, CaseIterable, Sendable {
    case approved
    case revoked
    case retired
}

nonisolated enum CatalogAudioURLPurpose: String, Codable, Sendable {
    case preview
    case fullDownload = "full_download"
}

nonisolated struct CatalogAudioAsset: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let contentVersion: Int
    let manifestVersion: Int
    let category: CatalogAudioCategory
    let title: String
    let shortDescription: String
    let localeIdentifier: String
    let delivery: CatalogAudioDelivery
    let status: CatalogAudioApprovalStatus
    let durationMilliseconds: Int64
    let byteCount: Int64
    let mimeType: String
    let codec: String
    let sampleRateHz: Int
    let channels: Int
    let sha256: String
    let previewPathID: String?
    let downloadPathID: String?
    let offlineCacheAllowed: Bool
    let bundledResourceName: String?
    let minimumAppVersion: String?
    let minimumCatalogSchema: Int
    let provenanceReference: String
    let rightsReference: String
    let approvalReference: String

    var isRevokedOrRetired: Bool {
        status == .revoked || status == .retired
    }

    var isMorningAlarm: Bool {
        category == .morningAlarm
    }

    var systemSoundFileName: String? {
        guard category == .morningAlarm else { return nil }
        if let bundledResourceName {
            return bundledResourceName
        }
        return SystemAudioAssets.downloadedAlarmFileName(
            assetID: id,
            version: contentVersion
        )
    }
}

nonisolated struct CatalogAudioManifest: Codable, Equatable, Sendable {
    let manifestVersion: Int
    let minimumAppVersion: String?
    let assets: [CatalogAudioAsset]
}

nonisolated struct CatalogAudioDownloadProgress: Equatable, Sendable {
    let assetID: String
    let bytesReceived: Int64
    let totalBytes: Int64?

    var fractionCompleted: Double {
        guard let totalBytes, totalBytes > 0 else { return 0 }
        return min(max(Double(bytesReceived) / Double(totalBytes), 0), 1)
    }
}

nonisolated enum CatalogAudioCacheEvent: Equatable, Sendable {
    case catalogAvailable
    case previewStarted
    case downloadQueued
    case downloadStarted
    case downloadProgress
    case downloadSucceeded
    case downloadFailed
    case checksumFailed
    case revoked
    case updateDetected
    case playStarted
    case paused
    case resumed
    case interrupted
    case playbackStopped
    case deleted
    case offline
}

nonisolated enum CatalogAudioCacheTransitionError: Error, Equatable, Sendable {
    case invalidTransition(from: AudioCacheState, event: CatalogAudioCacheEvent)
}

nonisolated enum CatalogAudioCacheStateMachine {
    static func transition(
        from state: AudioCacheState,
        on event: CatalogAudioCacheEvent
    ) throws -> AudioCacheState {
        switch (state, event) {
        case (.notAvailable, .catalogAvailable), (.notCached, .catalogAvailable):
            return .availableRemotely
        case (.notAvailable, .offline), (.notCached, .offline):
            return .notAvailable
        case (.availableRemotely, .previewStarted):
            return .streaming
        case (.availableRemotely, .downloadQueued), (.downloadFailed, .downloadQueued),
             (.updateAvailable, .downloadQueued), (.notAvailable, .downloadQueued):
            return .downloadQueued
        case (.downloadQueued, .downloadStarted):
            return .downloading
        case (.downloading, .downloadProgress):
            return .downloading
        case (.downloading, .downloadSucceeded):
            return .availableOffline
        case (.downloading, .downloadFailed), (.downloading, .checksumFailed),
             (.downloading, .interrupted):
            return .downloadFailed
        case (.availableOffline, .updateDetected), (.verified, .updateDetected):
            return .updateAvailable
        case (.availableOffline, .playStarted), (.verified, .playStarted):
            return .playing
        case (.playing, .paused):
            return .paused
        case (.paused, .resumed), (.interrupted, .resumed):
            return .playing
        case (.playing, .interrupted), (.paused, .interrupted):
            return .interrupted
        case (.playing, .playbackStopped), (.paused, .playbackStopped),
             (.interrupted, .playbackStopped):
            return .availableOffline
        case (.availableOffline, .deleted), (.verified, .deleted), (.updateAvailable, .deleted),
             (.downloadFailed, .deleted), (.invalid, .deleted):
            return .availableRemotely
        case (.streaming, .downloadQueued):
            return .downloadQueued
        case (_, .revoked):
            return .revokedUnavailable
        default:
            throw CatalogAudioCacheTransitionError.invalidTransition(from: state, event: event)
        }
    }
}

nonisolated enum CatalogAudioPlaybackState: Equatable, Sendable {
    case idle
    case streaming(String)
    case playing(String)
    case paused(String)
    case interrupted(String)
    case failed(String, CatalogAudioPlaybackFailure)
    case offlineFallback(String)
}

nonisolated enum CatalogAudioPlaybackFailure: Error, Equatable, Sendable {
    case unavailableOffline
    case audioSession
    case routeUnavailable
    case playerItemFailed
    case decoder
}

nonisolated enum CatalogAudioBoundaryError: Error, Equatable, Sendable {
    case invalidManifest(String)
    case invalidRemoteURL
    case invalidResponse
    case httpStatus(Int)
    case unsupportedAsset
    case storageFull(requiredBytes: Int64, availableBytes: Int64)
    case duplicateDownload
    case checksumMismatch
    case byteCountMismatch(expected: Int64, actual: Int64)
    case interrupted
    case cancelled
    case offline
    case cacheCorrupt
    case playbackFailed
    case alarmAssetNotLocal
}

nonisolated enum CatalogAudioManifestValidator {
    static func validate(_ manifest: CatalogAudioManifest) throws {
        guard manifest.manifestVersion > 0 else {
            throw CatalogAudioBoundaryError.invalidManifest("manifest_version")
        }

        var identifiers = Set<String>()
        for asset in manifest.assets {
            try validate(asset)
            guard identifiers.insert(asset.id).inserted else {
                throw CatalogAudioBoundaryError.invalidManifest("duplicate_asset_id")
            }
        }
    }

    static func validate(_ asset: CatalogAudioAsset) throws {
        guard !asset.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              asset.id.count <= 128,
              asset.contentVersion > 0,
              asset.manifestVersion > 0,
              !asset.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              asset.durationMilliseconds >= 0,
              asset.byteCount > 0,
              asset.sampleRateHz > 0,
              asset.channels > 0,
              asset.minimumCatalogSchema > 0,
              isSHA256(asset.sha256)
        else {
            throw CatalogAudioBoundaryError.invalidManifest("asset_metadata")
        }

        guard asset.status == .approved || asset.isRevokedOrRetired else {
            throw CatalogAudioBoundaryError.invalidManifest("approval_status")
        }

        switch asset.delivery {
        case .bundled:
            guard asset.bundledResourceName?.isEmpty == false,
                  asset.downloadPathID == nil
            else {
                throw CatalogAudioBoundaryError.invalidManifest("bundled_delivery")
            }
        case .downloadable:
            guard asset.offlineCacheAllowed,
                  validPathID(asset.previewPathID),
                  validPathID(asset.downloadPathID),
                  asset.bundledResourceName == nil
            else {
                throw CatalogAudioBoundaryError.invalidManifest("downloadable_delivery")
            }
        }

        if asset.category == .notification {
            guard asset.delivery == .bundled,
                  asset.mimeType.lowercased() == "audio/x-caf",
                  asset.codec.lowercased().hasPrefix("pcm"),
                  [44100, 48000].contains(asset.sampleRateHz),
                  asset.channels == 1,
                  asset.durationMilliseconds < 30000
            else {
                throw CatalogAudioBoundaryError.invalidManifest("notification_delivery")
            }
        }

        if asset.category == .morningAlarm {
            guard asset.mimeType.lowercased() == "audio/x-caf",
                  asset.codec.lowercased().hasPrefix("pcm"),
                  [44100, 48000].contains(asset.sampleRateHz),
                  asset.channels == 1,
                  asset.systemSoundFileName != nil
            else {
                throw CatalogAudioBoundaryError.invalidManifest("alarm_system_sound_format")
            }
        }

        if [.quickUnwind, .secondSleep, .slowUnwind].contains(asset.category) {
            guard asset.delivery == .downloadable,
                  asset.mimeType.lowercased() == "audio/mp4",
                  asset.codec.lowercased() == "aac-lc"
            else {
                throw CatalogAudioBoundaryError.invalidManifest("catalog_codec")
            }
        }
    }

    private static func isSHA256(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy(\.isHexDigit)
    }

    private static func validPathID(_ value: String?) -> Bool {
        guard let value, !value.isEmpty else { return false }
        let components = value.split(separator: "/", omittingEmptySubsequences: false)
        return !value.hasPrefix("/") && !value.contains("\\") && !components.contains { $0 == ".." }
    }
}

// swiftlint:enable cyclomatic_complexity
