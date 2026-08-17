import Foundation

actor CatalogAudioService {
    private let remote: any CatalogAudioRemoteProviding
    private let catalogIndex: any CatalogAudioMetadataIndexing
    private let cache: CatalogAudioCacheCoordinator

    init(
        remote: any CatalogAudioRemoteProviding,
        catalogIndex: any CatalogAudioMetadataIndexing,
        cache: CatalogAudioCacheCoordinator
    ) {
        self.remote = remote
        self.catalogIndex = catalogIndex
        self.cache = cache
    }

    func loadCatalog() async throws -> CatalogAudioManifest {
        let manifest = try await remote.loadManifest()
        try CatalogAudioManifestValidator.validate(manifest)
        for asset in manifest.assets {
            try await catalogIndex.save(asset: asset)
        }
        return manifest
    }

    func state(
        for asset: CatalogAudioAsset,
        networkAvailable: Bool
    ) async throws -> AudioCacheMetadata {
        try await cache.state(for: asset, networkAvailable: networkAvailable)
    }

    func previewURL(for asset: CatalogAudioAsset) async throws -> URL {
        try await cache.beginPreview(for: asset)
    }

    func playbackURL(for asset: CatalogAudioAsset, networkAvailable: Bool) async throws -> URL {
        if let localURL = try await cache.localPlaybackURL(for: asset) {
            return localURL
        }
        guard networkAvailable else {
            throw CatalogAudioBoundaryError.offline
        }
        return try await cache.beginPreview(for: asset)
    }

    func download(
        _ asset: CatalogAudioAsset,
        progress: @escaping @Sendable (CatalogAudioDownloadProgress) async -> Void = { _ in }
    ) async throws -> URL {
        try await cache.download(asset, progress: progress)
    }

    func deleteCachedAudio(_ asset: CatalogAudioAsset) async throws {
        try await cache.deleteCachedAudio(asset)
    }

    func preflightAlarm(_ asset: CatalogAudioAsset) async throws -> URL {
        try await cache.preflightAlarm(asset)
    }
}
