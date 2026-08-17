import CryptoKit
import Foundation

nonisolated protocol CatalogAudioRemoteProviding: Sendable {
    func loadManifest() async throws -> CatalogAudioManifest
    func authorizedURL(
        for asset: CatalogAudioAsset,
        purpose: CatalogAudioURLPurpose
    ) async throws -> URL
}

nonisolated protocol CatalogAudioCacheIndexing: Sendable {
    func metadata(assetID: String) async throws -> AudioCacheMetadata?
    func save(_ metadata: AudioCacheMetadata) async throws
    func remove(assetID: String) async throws
}

nonisolated protocol CatalogAudioMetadataIndexing: Sendable {
    func save(asset: CatalogAudioAsset) async throws
}

nonisolated protocol CatalogAudioFileStoring: Sendable {
    func temporaryURL(for asset: CatalogAudioAsset) async throws -> URL
    func localURL(for asset: CatalogAudioAsset) async throws -> URL?
    func atomicallyPlace(temporaryURL: URL, for asset: CatalogAudioAsset) async throws -> URL
    func remove(asset: CatalogAudioAsset) async throws
    func removeTemporaryFile(at url: URL) async
    func byteCount(at url: URL) async throws -> Int64
    func sha256(at url: URL) async throws -> String
}

nonisolated protocol CatalogAudioTransferring: Sendable {
    func download(
        from url: URL,
        to temporaryURL: URL,
        assetID: String,
        expectedByteCount: Int64,
        progress: @escaping @Sendable (CatalogAudioDownloadProgress) async -> Void
    ) async throws -> CatalogAudioDownloadedFile
}

nonisolated struct CatalogAudioDownloadedFile: Sendable {
    let temporaryURL: URL
    let byteCount: Int64
}

nonisolated protocol CatalogAudioStorageCapacityChecking: Sendable {
    func ensureCapacity(for asset: CatalogAudioAsset) async throws
}

nonisolated protocol CatalogAudioAlarmPreflighting: Sendable {
    func preflight(asset: CatalogAudioAsset) async throws -> URL
}

actor LocalDatabaseCatalogAudioCacheIndex: CatalogAudioCacheIndexing {
    private let database: LocalDatabase

    init(database: LocalDatabase) {
        self.database = database
    }

    func metadata(assetID: String) async throws -> AudioCacheMetadata? {
        try await database.audioCacheMetadata(assetID: assetID)
    }

    func save(_ metadata: AudioCacheMetadata) async throws {
        try await database.saveAudioCacheMetadata(metadata)
    }

    func remove(assetID: String) async throws {
        try await database.removeAudioCacheMetadata(assetID: assetID)
    }
}

actor LocalDatabaseCatalogAudioMetadataIndex: CatalogAudioMetadataIndexing {
    private let database: LocalDatabase

    init(database: LocalDatabase) {
        self.database = database
    }

    func save(asset: CatalogAudioAsset) async throws {
        try await database.saveAudioCatalogItem(
            AudioCatalogItem(
                id: asset.id,
                version: asset.contentVersion,
                localeIdentifier: asset.localeIdentifier,
                integritySHA256: asset.sha256,
                byteCount: asset.byteCount,
                durationMilliseconds: asset.durationMilliseconds,
                provenanceReference: asset.provenanceReference,
                rightsReference: asset.rightsReference,
                approvalReference: asset.approvalReference
            )
        )
    }
}

actor CatalogAudioFileStore: CatalogAudioFileStoring {
    private let rootURL: URL
    private let protection: any ProtectedFileApplying

    init(
        rootURL: URL? = nil,
        protection: any ProtectedFileApplying = SystemProtectedFileApplicator()
    ) {
        let defaultRoot = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        self.rootURL = rootURL ?? defaultRoot
            .appendingPathComponent("SleepParalysisCompanion", isDirectory: true)
            .appendingPathComponent("CatalogAudio", isDirectory: true)
        self.protection = protection
    }

    func temporaryURL(for asset: CatalogAudioAsset) async throws -> URL {
        try ensureDirectories()
        let url = rootURL
            .appendingPathComponent(".partial", isDirectory: true)
            .appendingPathComponent(
                ".\(safeFileStem(for: asset)).\(UUID().uuidString).partial"
            )
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
            throw CatalogAudioBoundaryError.cacheCorrupt
        }
        try protection.applyProtection(to: url, kind: .downloadedAudioCache)
        return url
    }

    func localURL(for asset: CatalogAudioAsset) async throws -> URL? {
        try ensureDirectories()
        let url = destinationURL(for: asset)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func atomicallyPlace(temporaryURL: URL, for asset: CatalogAudioAsset) async throws -> URL {
        try ensureDirectories()
        guard FileManager.default.fileExists(atPath: temporaryURL.path) else {
            throw CatalogAudioBoundaryError.cacheCorrupt
        }
        let destination = destinationURL(for: asset)
        if FileManager.default.fileExists(atPath: destination.path) {
            try? FileManager.default.removeItem(at: temporaryURL)
            try protection.applyProtection(to: destination, kind: .downloadedAudioCache)
            return destination
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        do {
            try protection.applyProtection(to: destination, kind: .downloadedAudioCache)
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
        return destination
    }

    func remove(asset: CatalogAudioAsset) async throws {
        try ensureDirectories()
        let destination = destinationURL(for: asset)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
    }

    func removeDownloadedAudioAndExports() async throws {
        guard FileManager.default.fileExists(atPath: rootURL.path) else { return }
        try FileManager.default.removeItem(at: rootURL)
    }

    func removeTemporaryFile(at url: URL) async {
        try? FileManager.default.removeItem(at: url)
    }

    func byteCount(at url: URL) async throws -> Int64 {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true, let fileSize = values.fileSize, fileSize >= 0 else {
            throw CatalogAudioBoundaryError.cacheCorrupt
        }
        return Int64(fileSize)
    }

    func sha256(at url: URL) async throws -> String {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CatalogAudioBoundaryError.cacheCorrupt
        }
        let handle = try FileHandle(forReadingFrom: url)
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        try handle.close()
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func ensureDirectories() throws {
        let partialURL = rootURL.appendingPathComponent(".partial", isDirectory: true)
        try FileManager.default.createDirectory(
            at: partialURL,
            withIntermediateDirectories: true
        )
        try protection.applyProtection(to: rootURL, kind: .downloadedAudioCache)
        try protection.applyProtection(to: partialURL, kind: .downloadedAudioCache)
    }

    private func destinationURL(for asset: CatalogAudioAsset) -> URL {
        rootURL.appendingPathComponent(
            "\(safeFileStem(for: asset)).\(fileExtension(for: asset))",
            isDirectory: false
        )
    }

    private func fileExtension(for asset: CatalogAudioAsset) -> String {
        asset.mimeType.lowercased() == "audio/x-caf" ? "caf" : "m4a"
    }

    private func safeFileStem(for asset: CatalogAudioAsset) -> String {
        let id = asset.id.replacingOccurrences(of: "[^A-Za-z0-9._-]", with: "_", options: .regularExpression)
        return "\(id)-v\(asset.contentVersion)"
    }
}

nonisolated struct SystemCatalogAudioStorageCapacityChecker: CatalogAudioStorageCapacityChecking {
    private let installationMargin: Int64

    init(installationMargin: Int64 = 1_048_576) {
        self.installationMargin = installationMargin
    }

    func ensureCapacity(for asset: CatalogAudioAsset) async throws {
        let fileManager = FileManager.default
        let cacheURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let values = try cacheURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        let available = Int64(values.volumeAvailableCapacityForImportantUsage ?? 0)
        let required = asset.byteCount + installationMargin
        guard available >= required else {
            throw CatalogAudioBoundaryError.storageFull(
                requiredBytes: required,
                availableBytes: available
            )
        }
    }
}

actor CatalogAudioCacheCoordinator {
    private let remote: any CatalogAudioRemoteProviding
    private let index: any CatalogAudioCacheIndexing
    private let files: any CatalogAudioFileStoring
    private let transfer: any CatalogAudioTransferring
    private let capacity: any CatalogAudioStorageCapacityChecking
    private var activeDownloads = Set<String>()

    init(
        remote: any CatalogAudioRemoteProviding,
        index: any CatalogAudioCacheIndexing,
        files: any CatalogAudioFileStoring,
        transfer: any CatalogAudioTransferring,
        capacity: any CatalogAudioStorageCapacityChecking
    ) {
        self.remote = remote
        self.index = index
        self.files = files
        self.transfer = transfer
        self.capacity = capacity
    }

    func state(
        for asset: CatalogAudioAsset,
        networkAvailable: Bool
    ) async throws -> AudioCacheMetadata {
        if asset.isRevokedOrRetired {
            let value = metadata(for: asset, state: .revokedUnavailable)
            try await index.save(value)
            return value
        }

        if let existing = try await index.metadata(assetID: asset.id) {
            if existing.catalogVersion < asset.contentVersion,
               existing.state == .availableOffline || existing.state == .verified
            {
                let value = replacing(existing, state: .updateAvailable)
                try await index.save(value)
                return value
            }

            if let localURL = try await files.localURL(for: asset),
               existing.catalogVersion == asset.contentVersion,
               existing.state == .availableOffline || existing.state == .verified
            {
                do {
                    guard try await files.byteCount(at: localURL) == asset.byteCount,
                          try await files.sha256(at: localURL).lowercased() == asset.sha256.lowercased()
                    else {
                        throw CatalogAudioBoundaryError.checksumMismatch
                    }
                    let value = replacing(
                        existing,
                        state: .availableOffline,
                        verifiedAt: existing.verifiedAt ?? Date(),
                        lastAccessedAt: Date()
                    )
                    try await index.save(value)
                    return value
                } catch {
                    try await files.remove(asset: asset)
                    let value = replacing(
                        existing,
                        state: .downloadFailed,
                        byteCount: 0,
                        progress: 0,
                        failureReason: "checksum_failure",
                        clearRelativeFileName: true,
                        clearVerifiedAt: true
                    )
                    try await index.save(value)
                    if !networkAvailable {
                        return value
                    }
                }
            }
        }

        let value = metadata(
            for: asset,
            state: networkAvailable ? .availableRemotely : .notAvailable
        )
        try await index.save(value)
        return value
    }

    func beginPreview(for asset: CatalogAudioAsset) async throws -> URL {
        guard !asset.isRevokedOrRetired else {
            throw CatalogAudioBoundaryError.unsupportedAsset
        }
        let url: URL
        if asset.delivery == .bundled {
            guard let bundledResourceName = asset.bundledResourceName,
                  let bundledURL = Bundle.main.url(
                      forResource: bundledResourceName,
                      withExtension: nil
                  )
            else {
                throw CatalogAudioBoundaryError.offline
            }
            url = bundledURL
        } else {
            url = try await remote.authorizedURL(for: asset, purpose: .preview)
            try validateRemoteURL(url)
        }
        if let current = try await index.metadata(assetID: asset.id) {
            try await index.save(replacing(current, state: .streaming))
        } else {
            try await index.save(metadata(for: asset, state: .streaming))
        }
        return url
    }

    func download(
        _ asset: CatalogAudioAsset,
        progress: @escaping @Sendable (CatalogAudioDownloadProgress) async -> Void = { _ in }
    ) async throws -> URL {
        guard asset.delivery == .downloadable,
              asset.offlineCacheAllowed,
              !asset.isRevokedOrRetired
        else {
            throw CatalogAudioBoundaryError.unsupportedAsset
        }

        if activeDownloads.contains(asset.id) {
            throw CatalogAudioBoundaryError.duplicateDownload
        }
        activeDownloads.insert(asset.id)
        defer { activeDownloads.remove(asset.id) }

        if let existing = try await index.metadata(assetID: asset.id),
           existing.catalogVersion == asset.contentVersion,
           existing.state == .availableOffline || existing.state == .verified,
           let localURL = try await files.localURL(for: asset)
        {
            do {
                guard try await files.byteCount(at: localURL) == asset.byteCount,
                      try await files.sha256(at: localURL).lowercased() == asset.sha256.lowercased()
                else {
                    throw CatalogAudioBoundaryError.checksumMismatch
                }
                try await index.save(replacing(existing, state: .availableOffline, lastAccessedAt: Date()))
                return localURL
            } catch {
                try await files.remove(asset: asset)
            }
        }

        do {
            try await capacity.ensureCapacity(for: asset)
        } catch {
            let failed = metadata(for: asset, state: .downloadFailed)
            try? await index.save(
                replacing(
                    failed,
                    failureReason: "storage_full"
                )
            )
            throw error
        }
        let queued = metadata(for: asset, state: .downloadQueued)
        try await index.save(queued)
        let temporaryURL = try await files.temporaryURL(for: asset)
        let downloading = replacing(queued, state: .downloading)
        try await index.save(downloading)

        do {
            let url = try await remote.authorizedURL(for: asset, purpose: .fullDownload)
            try validateRemoteURL(url)
            let downloaded = try await transfer.download(
                from: url,
                to: temporaryURL,
                assetID: asset.id,
                expectedByteCount: asset.byteCount,
                progress: { [weak self] value in
                    await progress(value)
                    await self?.recordProgress(value)
                }
            )
            guard downloaded.byteCount == asset.byteCount else {
                throw CatalogAudioBoundaryError.byteCountMismatch(
                    expected: asset.byteCount,
                    actual: downloaded.byteCount
                )
            }
            guard try await files.byteCount(at: downloaded.temporaryURL) == asset.byteCount,
                  try await files.sha256(at: downloaded.temporaryURL).lowercased() == asset.sha256.lowercased()
            else {
                throw CatalogAudioBoundaryError.checksumMismatch
            }
            let localURL = try await files.atomicallyPlace(
                temporaryURL: downloaded.temporaryURL,
                for: asset
            )
            let complete = replacing(
                downloading,
                state: .availableOffline,
                relativeFileName: localURL.lastPathComponent,
                verifiedAt: Date(),
                byteCount: asset.byteCount,
                progress: 1,
                failureReason: nil,
                lastAccessedAt: Date(),
                clearFailureReason: true
            )
            try await index.save(complete)
            return localURL
        } catch is CancellationError {
            await files.removeTemporaryFile(at: temporaryURL)
            try? await index.save(
                replacing(
                    downloading,
                    state: .downloadFailed,
                    progress: 0,
                    failureReason: "interrupted"
                )
            )
            throw CatalogAudioBoundaryError.interrupted
        } catch {
            await files.removeTemporaryFile(at: temporaryURL)
            let reason = failureReason(for: error)
            try? await index.save(
                replacing(
                    downloading,
                    state: .downloadFailed,
                    progress: 0,
                    failureReason: reason
                )
            )
            throw error
        }
    }

    func deleteCachedAudio(_ asset: CatalogAudioAsset) async throws {
        guard asset.delivery == .downloadable else { return }
        try await files.remove(asset: asset)
        let current = try await index.metadata(assetID: asset.id)
        try await index.save(
            replacing(
                current ?? metadata(for: asset, state: .notAvailable),
                state: .notAvailable,
                byteCount: 0,
                progress: 0,
                failureReason: nil,
                clearRelativeFileName: true,
                clearVerifiedAt: true,
                clearFailureReason: true,
                clearLastAccessedAt: true
            )
        )
    }

    func localPlaybackURL(for asset: CatalogAudioAsset) async throws -> URL? {
        guard let current = try await index.metadata(assetID: asset.id),
              current.catalogVersion == asset.contentVersion,
              current.state == .availableOffline || current.state == .verified,
              let localURL = try await files.localURL(for: asset),
              try await files.byteCount(at: localURL) == asset.byteCount,
              try await files.sha256(at: localURL).lowercased() == asset.sha256.lowercased()
        else {
            return nil
        }
        try await index.save(replacing(current, state: .availableOffline, lastAccessedAt: Date()))
        return localURL
    }

    func preflightAlarm(_ asset: CatalogAudioAsset) async throws -> URL {
        guard asset.category == .morningAlarm,
              asset.status == .approved,
              asset.mimeType.lowercased() == "audio/x-caf",
              asset.codec.lowercased().hasPrefix("pcm"),
              [44100, 48000].contains(asset.sampleRateHz),
              asset.channels == 1,
              asset.systemSoundFileName != nil
        else {
            throw CatalogAudioBoundaryError.alarmAssetNotLocal
        }

        let url: URL
        if asset.delivery == .bundled {
            guard let resourceName = asset.bundledResourceName,
                  let bundledURL = SystemAudioAssets.bundledURL(for: resourceName)
            else {
                throw CatalogAudioBoundaryError.alarmAssetNotLocal
            }
            do {
                try SystemAudioAssets.validateAlarmSoundForCatalog(url: bundledURL)
            } catch {
                throw CatalogAudioBoundaryError.alarmAssetNotLocal
            }
            url = bundledURL
        } else {
            guard let metadata = try await index.metadata(assetID: asset.id),
                  metadata.catalogVersion == asset.contentVersion,
                  metadata.state == .availableOffline || metadata.state == .verified,
                  let localURL = try await files.localURL(for: asset),
                  try await files.byteCount(at: localURL) == asset.byteCount,
                  try await files.sha256(at: localURL).lowercased() == asset.sha256.lowercased()
            else {
                throw CatalogAudioBoundaryError.alarmAssetNotLocal
            }
            guard let systemSoundFileName = asset.systemSoundFileName else {
                throw CatalogAudioBoundaryError.alarmAssetNotLocal
            }
            do {
                url = try SystemAudioAssets.installDownloadedAlarm(
                    from: localURL,
                    assetID: asset.id,
                    version: asset.contentVersion
                )
                guard url.lastPathComponent == systemSoundFileName else {
                    throw SystemAudioAssetError.installFailed
                }
            } catch {
                throw CatalogAudioBoundaryError.alarmAssetNotLocal
            }
        }
        if asset.delivery == .bundled {
            guard try await files.byteCount(at: url) == asset.byteCount,
                  try await files.sha256(at: url).lowercased() == asset.sha256.lowercased()
            else {
                throw CatalogAudioBoundaryError.alarmAssetNotLocal
            }
        }
        return url
    }

    private func recordProgress(_ value: CatalogAudioDownloadProgress) async {
        guard let current = try? await index.metadata(assetID: value.assetID) else { return }
        let progress = value.totalBytes.map { total in
            total > 0 ? min(max(Double(value.bytesReceived) / Double(total), 0), 1) : 0
        } ?? 0
        try? await index.save(replacing(current, progress: progress))
    }

    private func metadata(for asset: CatalogAudioAsset, state: AudioCacheState) -> AudioCacheMetadata {
        AudioCacheMetadata(
            assetID: asset.id,
            catalogVersion: asset.contentVersion,
            state: state,
            relativeFileName: nil,
            verifiedAt: nil,
            byteCount: 0,
            progress: 0,
            failureReason: nil,
            lastAccessedAt: nil
        )
    }

    private func replacing(
        _ value: AudioCacheMetadata,
        state: AudioCacheState? = nil,
        relativeFileName: String? = nil,
        verifiedAt: Date? = nil,
        byteCount: Int64? = nil,
        progress: Double? = nil,
        failureReason: String? = nil,
        lastAccessedAt: Date? = nil,
        clearRelativeFileName: Bool = false,
        clearVerifiedAt: Bool = false,
        clearFailureReason: Bool = false,
        clearLastAccessedAt: Bool = false
    ) -> AudioCacheMetadata {
        AudioCacheMetadata(
            assetID: value.assetID,
            catalogVersion: value.catalogVersion,
            state: state ?? value.state,
            relativeFileName: clearRelativeFileName ? nil : (relativeFileName ?? value.relativeFileName),
            verifiedAt: clearVerifiedAt ? nil : (verifiedAt ?? value.verifiedAt),
            byteCount: byteCount ?? value.byteCount,
            progress: progress ?? value.progress,
            failureReason: clearFailureReason ? nil : (failureReason ?? value.failureReason),
            lastAccessedAt: clearLastAccessedAt ? nil : (lastAccessedAt ?? value.lastAccessedAt)
        )
    }

    private func failureReason(for error: Error) -> String {
        if error is CancellationError {
            return "interrupted"
        }
        guard let error = error as? CatalogAudioBoundaryError else {
            return "download_failed"
        }
        switch error {
        case .checksumMismatch:
            return "checksum_failure"
        case .byteCountMismatch:
            return "byte_count_mismatch"
        case .storageFull:
            return "storage_full"
        case .offline:
            return "offline"
        case .duplicateDownload:
            return "duplicate_download"
        case .interrupted:
            return "interrupted"
        default:
            "download_failed"
        }
    }

    private func validateRemoteURL(_ url: URL) throws {
        guard url.scheme?.lowercased() == "https",
              url.user == nil,
              url.password == nil
        else {
            throw CatalogAudioBoundaryError.invalidRemoteURL
        }
    }
}

extension CatalogAudioCacheCoordinator: CatalogAudioAlarmPreflighting {
    func preflight(asset: CatalogAudioAsset) async throws -> URL {
        try await preflightAlarm(asset)
    }
}

extension CatalogAudioFileStore: ProtectedLocalFilesRemoving {}
