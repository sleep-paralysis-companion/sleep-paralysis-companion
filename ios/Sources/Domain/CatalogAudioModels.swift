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

    init(
        id: String,
        contentVersion: Int,
        manifestVersion: Int,
        category: CatalogAudioCategory,
        title: String,
        shortDescription: String,
        localeIdentifier: String,
        delivery: CatalogAudioDelivery,
        status: CatalogAudioApprovalStatus,
        durationMilliseconds: Int64,
        byteCount: Int64,
        mimeType: String,
        codec: String,
        sampleRateHz: Int,
        channels: Int,
        sha256: String,
        previewPathID: String?,
        downloadPathID: String?,
        offlineCacheAllowed: Bool,
        bundledResourceName: String?,
        minimumAppVersion: String?,
        minimumCatalogSchema: Int,
        provenanceReference: String,
        rightsReference: String,
        approvalReference: String
    ) {
        self.id = id
        self.contentVersion = contentVersion
        self.manifestVersion = manifestVersion
        self.category = category
        self.title = title
        self.shortDescription = shortDescription
        self.localeIdentifier = localeIdentifier
        self.delivery = delivery
        self.status = status
        self.durationMilliseconds = durationMilliseconds
        self.byteCount = byteCount
        self.mimeType = mimeType
        self.codec = codec
        self.sampleRateHz = sampleRateHz
        self.channels = channels
        self.sha256 = sha256
        self.previewPathID = previewPathID
        self.downloadPathID = downloadPathID
        self.offlineCacheAllowed = offlineCacheAllowed
        self.bundledResourceName = bundledResourceName
        self.minimumAppVersion = minimumAppVersion
        self.minimumCatalogSchema = minimumCatalogSchema
        self.provenanceReference = provenanceReference
        self.rightsReference = rightsReference
        self.approvalReference = approvalReference
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case contentVersion
        case contentVersionSnake = "content_version"
        case manifestVersion
        case manifestVersionSnake = "manifest_version"
        case category
        case title
        case shortDescription
        case shortDescriptionSnake = "short_description"
        case localeIdentifier
        case localeIdentifierSnake = "locale_identifier"
        case delivery
        case status
        case durationMilliseconds
        case durationMillisecondsSnake = "duration_milliseconds"
        case byteCount
        case byteCountSnake = "byte_count"
        case mimeType
        case mimeTypeSnake = "mime_type"
        case codec
        case sampleRateHz
        case sampleRateHzSnake = "sample_rate_hz"
        case channels
        case sha256
        case previewPathID
        case previewPathId
        case previewPathIdSnake = "preview_path_id"
        case downloadPathID
        case downloadPathId
        case downloadPathIdSnake = "download_path_id"
        case offlineCacheAllowed
        case offlineCacheAllowedSnake = "offline_cache_allowed"
        case bundledResourceName
        case bundledResourceNameSnake = "bundled_resource_name"
        case minimumAppVersion
        case minimumAppVersionSnake = "minimum_app_version"
        case minimumCatalogSchema
        case minimumCatalogSchemaSnake = "minimum_catalog_schema"
        case provenanceReference
        case provenanceReferenceSnake = "provenance_reference"
        case rightsReference
        case rightsReferenceSnake = "rights_reference"
        case approvalReference
        case approvalReferenceSnake = "approval_reference"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        contentVersion = try container.decodeIfPresent(Int.self, forKey: .contentVersion)
            ?? container.decode(Int.self, forKey: .contentVersionSnake)
        manifestVersion = try container.decodeIfPresent(Int.self, forKey: .manifestVersion)
            ?? container.decode(Int.self, forKey: .manifestVersionSnake)
        category = try container.decode(CatalogAudioCategory.self, forKey: .category)
        title = try container.decode(String.self, forKey: .title)
        shortDescription = try container.decodeIfPresent(String.self, forKey: .shortDescription)
            ?? container.decode(String.self, forKey: .shortDescriptionSnake)
        localeIdentifier = try container.decodeIfPresent(String.self, forKey: .localeIdentifier)
            ?? container.decode(String.self, forKey: .localeIdentifierSnake)
        delivery = try container.decode(CatalogAudioDelivery.self, forKey: .delivery)
        status = try container.decode(CatalogAudioApprovalStatus.self, forKey: .status)
        durationMilliseconds = try container.decodeIfPresent(Int64.self, forKey: .durationMilliseconds)
            ?? container.decode(Int64.self, forKey: .durationMillisecondsSnake)
        byteCount = try container.decodeIfPresent(Int64.self, forKey: .byteCount)
            ?? container.decode(Int64.self, forKey: .byteCountSnake)
        mimeType = try container.decodeIfPresent(String.self, forKey: .mimeType)
            ?? container.decode(String.self, forKey: .mimeTypeSnake)
        codec = try container.decode(String.self, forKey: .codec)
        sampleRateHz = try container.decodeIfPresent(Int.self, forKey: .sampleRateHz)
            ?? container.decode(Int.self, forKey: .sampleRateHzSnake)
        channels = try container.decode(Int.self, forKey: .channels)
        sha256 = try container.decode(String.self, forKey: .sha256)

        previewPathID = try container.decodeIfPresent(String.self, forKey: .previewPathId)
            ?? container.decodeIfPresent(String.self, forKey: .previewPathID)
            ?? container.decodeIfPresent(String.self, forKey: .previewPathIdSnake)

        downloadPathID = try container.decodeIfPresent(String.self, forKey: .downloadPathId)
            ?? container.decodeIfPresent(String.self, forKey: .downloadPathID)
            ?? container.decodeIfPresent(String.self, forKey: .downloadPathIdSnake)

        offlineCacheAllowed = try container.decodeIfPresent(Bool.self, forKey: .offlineCacheAllowed)
            ?? container.decode(Bool.self, forKey: .offlineCacheAllowedSnake)
        bundledResourceName = try container.decodeIfPresent(String.self, forKey: .bundledResourceName)
            ?? container.decodeIfPresent(String.self, forKey: .bundledResourceNameSnake)
        minimumAppVersion = try container.decodeIfPresent(String.self, forKey: .minimumAppVersion)
            ?? container.decodeIfPresent(String.self, forKey: .minimumAppVersionSnake)
        minimumCatalogSchema = try container.decodeIfPresent(Int.self, forKey: .minimumCatalogSchema)
            ?? container.decode(Int.self, forKey: .minimumCatalogSchemaSnake)
        provenanceReference = try container.decodeIfPresent(String.self, forKey: .provenanceReference)
            ?? container.decode(String.self, forKey: .provenanceReferenceSnake)
        rightsReference = try container.decodeIfPresent(String.self, forKey: .rightsReference)
            ?? container.decode(String.self, forKey: .rightsReferenceSnake)
        approvalReference = try container.decodeIfPresent(String.self, forKey: .approvalReference)
            ?? container.decode(String.self, forKey: .approvalReferenceSnake)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(contentVersion, forKey: .contentVersion)
        try container.encode(manifestVersion, forKey: .manifestVersion)
        try container.encode(category, forKey: .category)
        try container.encode(title, forKey: .title)
        try container.encode(shortDescription, forKey: .shortDescription)
        try container.encode(localeIdentifier, forKey: .localeIdentifier)
        try container.encode(delivery, forKey: .delivery)
        try container.encode(status, forKey: .status)
        try container.encode(durationMilliseconds, forKey: .durationMilliseconds)
        try container.encode(byteCount, forKey: .byteCount)
        try container.encode(mimeType, forKey: .mimeType)
        try container.encode(codec, forKey: .codec)
        try container.encode(sampleRateHz, forKey: .sampleRateHz)
        try container.encode(channels, forKey: .channels)
        try container.encode(sha256, forKey: .sha256)
        try container.encodeIfPresent(previewPathID, forKey: .previewPathID)
        try container.encodeIfPresent(downloadPathID, forKey: .downloadPathID)
        try container.encode(offlineCacheAllowed, forKey: .offlineCacheAllowed)
        try container.encodeIfPresent(bundledResourceName, forKey: .bundledResourceName)
        try container.encodeIfPresent(minimumAppVersion, forKey: .minimumAppVersion)
        try container.encode(minimumCatalogSchema, forKey: .minimumCatalogSchema)
        try container.encode(provenanceReference, forKey: .provenanceReference)
        try container.encode(rightsReference, forKey: .rightsReference)
        try container.encode(approvalReference, forKey: .approvalReference)
    }

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

    init(
        manifestVersion: Int,
        minimumAppVersion: String? = nil,
        assets: [CatalogAudioAsset]
    ) {
        self.manifestVersion = manifestVersion
        self.minimumAppVersion = minimumAppVersion
        self.assets = assets
    }

    private enum CodingKeys: String, CodingKey {
        case manifestVersion
        case manifestVersionSnake = "manifest_version"
        case minimumAppVersion
        case minimumAppVersionSnake = "minimum_app_version"
        case assets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        manifestVersion = try container.decodeIfPresent(Int.self, forKey: .manifestVersion)
            ?? container.decode(Int.self, forKey: .manifestVersionSnake)
        minimumAppVersion = try container.decodeIfPresent(String.self, forKey: .minimumAppVersion)
            ?? container.decodeIfPresent(String.self, forKey: .minimumAppVersionSnake)
        assets = try container.decode([CatalogAudioAsset].self, forKey: .assets)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(manifestVersion, forKey: .manifestVersion)
        try container.encodeIfPresent(minimumAppVersion, forKey: .minimumAppVersion)
        try container.encode(assets, forKey: .assets)
    }

    static let bundled = CatalogAudioManifest(
        manifestVersion: 1,
        minimumAppVersion: "1.0.0",
        assets: [
            CatalogAudioAsset(
                id: "felt-dawn",
                contentVersion: 1,
                manifestVersion: 1,
                category: .morningAlarm,
                title: "Felt Dawn",
                shortDescription: "The compact bundled default wake-up sound.",
                localeIdentifier: "en",
                delivery: .bundled,
                status: .approved,
                durationMilliseconds: 30041,
                byteCount: 2_884_207,
                mimeType: "audio/x-caf",
                codec: "pcm_s16le",
                sampleRateHz: 48000,
                channels: 1,
                sha256: "202b416ac3066ef272baa856d30d817e7686412b0fef5b78f5531c252f40d42c",
                previewPathID: nil,
                downloadPathID: nil,
                offlineCacheAllowed: false,
                bundledResourceName: "SPCWakeUpGentleLoop.caf",
                minimumAppVersion: "1.0.0",
                minimumCatalogSchema: 1,
                provenanceReference: "audio-owner-supplied-2026-08-17",
                rightsReference: "owner-authorized-app-store-worldwide-offline-transcode-2026-08-17",
                approvalReference: "audio-product-approval-2026-08-17"
            ),
            CatalogAudioAsset(
                id: "notification",
                contentVersion: 1,
                manifestVersion: 1,
                category: .notification,
                title: "Notification",
                shortDescription: "The bundled short notification sound.",
                localeIdentifier: "en",
                delivery: .bundled,
                status: .approved,
                durationMilliseconds: 2000,
                byteCount: 192_292,
                mimeType: "audio/x-caf",
                codec: "pcm_s16le",
                sampleRateHz: 48000,
                channels: 1,
                sha256: "6359c2edc965029a953c2050230be47381e977c6d3b3d7ce4761dbc332256ed8",
                previewPathID: nil,
                downloadPathID: nil,
                offlineCacheAllowed: false,
                bundledResourceName: "SPCNotification.caf",
                minimumAppVersion: "1.0.0",
                minimumCatalogSchema: 1,
                provenanceReference: "audio-owner-supplied-2026-08-17",
                rightsReference: "owner-authorized-app-store-worldwide-offline-transcode-2026-08-17",
                approvalReference: "audio-product-approval-2026-08-17"
            ),
            CatalogAudioAsset(
                id: "quick-unwind",
                contentVersion: 1,
                manifestVersion: 1,
                category: .quickUnwind,
                title: "Quick Unwind",
                shortDescription: "A short guided reset for settling the body and attention.",
                localeIdentifier: "en",
                delivery: .bundled,
                status: .approved,
                durationMilliseconds: 393_160,
                byteCount: 9_655_675,
                mimeType: "audio/mp4",
                codec: "aac-lc",
                sampleRateHz: 44100,
                channels: 2,
                sha256: "3c2e9fcad44eae60fad8aed98c36352db42a0be828b8ad8f807952e2044f27fd",
                previewPathID: nil,
                downloadPathID: nil,
                offlineCacheAllowed: false,
                bundledResourceName: "spc_catalog_quick-unwind_v1.m4a",
                minimumAppVersion: "1.0.0",
                minimumCatalogSchema: 1,
                provenanceReference: "audio-owner-supplied-2026-08-17",
                rightsReference: "owner-authorized-app-store-worldwide-offline-transcode-2026-08-17",
                approvalReference: "audio-product-approval-2026-08-17"
            ),
            CatalogAudioAsset(
                id: "slow-unwind",
                contentVersion: 1,
                manifestVersion: 1,
                category: .slowUnwind,
                title: "Slow Unwind",
                shortDescription: "The long-form catalog session for a slower transition into rest.",
                localeIdentifier: "en",
                delivery: .bundled,
                status: .approved,
                durationMilliseconds: 5_170_642,
                byteCount: 85_201_262,
                mimeType: "audio/mp4",
                codec: "aac-lc",
                sampleRateHz: 44100,
                channels: 2,
                sha256: "e00421526fda96c132295ae46f2bf2558db26d6aac53a2e04992c23bdbea88fc",
                previewPathID: nil,
                downloadPathID: nil,
                offlineCacheAllowed: false,
                bundledResourceName: "spc_catalog_slow-unwind_v1.m4a",
                minimumAppVersion: "1.0.0",
                minimumCatalogSchema: 1,
                provenanceReference: "audio-owner-supplied-2026-08-17",
                rightsReference: "owner-authorized-app-store-worldwide-offline-transcode-2026-08-17",
                approvalReference: "audio-product-approval-2026-08-17"
            ),
        ]
    )
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
            guard asset.mimeType.lowercased() == "audio/mp4",
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
