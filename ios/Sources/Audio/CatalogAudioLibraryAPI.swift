import Foundation

nonisolated struct CatalogAudioRemoteConfiguration: Equatable, Sendable {
    let manifestURL: URL
    let authorizationURL: URL
    let allowedHosts: Set<String>

    static func load(from bundle: Bundle) -> CatalogAudioRemoteConfiguration? {
        guard let manifestString = bundle.object(
            forInfoDictionaryKey: "SPCAudioCatalogManifestURL"
        ) as? String,
            let authorizationString = bundle.object(
                forInfoDictionaryKey: "SPCAudioCatalogAuthorizationURL"
            ) as? String,
            let manifestURL = URL(string: manifestString),
            let authorizationURL = URL(string: authorizationString),
            let allowedHostsValue = bundle.object(
                forInfoDictionaryKey: "SPCAudioCatalogAllowedHosts"
            ) as? String
        else {
            return nil
        }

        let allowedHosts = Set(
            allowedHostsValue
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
        )
        guard !allowedHosts.isEmpty else { return nil }

        return CatalogAudioRemoteConfiguration(
            manifestURL: manifestURL,
            authorizationURL: authorizationURL,
            allowedHosts: allowedHosts
        )
    }

    func makeRemoteProvider(
        session: URLSession = .shared
    ) throws -> URLSessionCatalogAudioRemoteProvider {
        try URLSessionCatalogAudioRemoteProvider(
            manifestURL: manifestURL,
            authorizationURL: authorizationURL,
            session: session,
            allowedHosts: allowedHosts
        )
    }

    func makeTransfer(
        session: URLSession = .shared
    ) -> URLSessionCatalogAudioTransfer {
        URLSessionCatalogAudioTransfer(
            session: session,
            allowedHosts: allowedHosts
        )
    }
}

nonisolated protocol CatalogAudioLibraryServicing: Sendable {
    func loadCatalog() async throws -> CatalogAudioManifest
    func state(for asset: CatalogAudioAsset, networkAvailable: Bool) async throws -> AudioCacheMetadata
    func previewURL(for asset: CatalogAudioAsset) async throws -> URL
    func playbackURL(for asset: CatalogAudioAsset, networkAvailable: Bool) async throws -> URL
    func download(
        _ asset: CatalogAudioAsset,
        progress: @escaping @Sendable (CatalogAudioDownloadProgress) async -> Void
    ) async throws -> URL
    func deleteCachedAudio(_ asset: CatalogAudioAsset) async throws
    func preflightAlarm(_ asset: CatalogAudioAsset) async throws -> URL
}

extension CatalogAudioService: CatalogAudioLibraryServicing {}

nonisolated struct UnavailableCatalogAudioService: CatalogAudioLibraryServicing {
    func loadCatalog() async throws -> CatalogAudioManifest {
        CatalogAudioManifest.bundled
    }

    func state(for asset: CatalogAudioAsset, networkAvailable: Bool) async throws -> AudioCacheMetadata {
        AudioCacheMetadata(
            assetID: asset.id,
            catalogVersion: asset.contentVersion,
            state: asset.delivery == .bundled ? .availableOffline : .notAvailable,
            relativeFileName: asset.bundledResourceName,
            verifiedAt: nil,
            byteCount: asset.byteCount,
            progress: asset.delivery == .bundled ? 1 : 0,
            failureReason: nil,
            lastAccessedAt: nil
        )
    }

    func previewURL(for asset: CatalogAudioAsset) async throws -> URL {
        if asset.delivery == .bundled,
           let resourceName = asset.bundledResourceName,
           let url = SystemAudioAssets.bundledURL(for: resourceName)
        {
            return url
        }
        throw CatalogAudioBoundaryError.offline
    }

    func playbackURL(for asset: CatalogAudioAsset, networkAvailable _: Bool) async throws -> URL {
        if asset.delivery == .bundled,
           let resourceName = asset.bundledResourceName,
           let url = SystemAudioAssets.bundledURL(for: resourceName)
        {
            return url
        }
        throw CatalogAudioBoundaryError.offline
    }

    func download(
        _: CatalogAudioAsset,
        progress _: @escaping @Sendable (CatalogAudioDownloadProgress) async -> Void
    ) async throws -> URL {
        throw CatalogAudioBoundaryError.offline
    }

    func deleteCachedAudio(_: CatalogAudioAsset) async throws {}

    func preflightAlarm(_ asset: CatalogAudioAsset) async throws -> URL {
        if asset.delivery == .bundled,
           let resourceName = asset.bundledResourceName,
           let url = SystemAudioAssets.bundledURL(for: resourceName)
        {
            return url
        }
        throw CatalogAudioBoundaryError.alarmAssetNotLocal
    }
}
