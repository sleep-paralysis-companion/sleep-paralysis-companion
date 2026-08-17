import CryptoKit
import Foundation
@testable import SleepParalysisCompanion
import XCTest

final class CatalogAudioBoundaryTests: XCTestCase {
    func testManifestValidationRejectsDuplicateIDsAndWrongLongSessionDelivery() {
        let first = makeAsset(id: "quick-unwind")
        let duplicate = makeAsset(id: "quick-unwind")
        XCTAssertThrowsError(
            try CatalogAudioManifestValidator.validate(
                CatalogAudioManifest(manifestVersion: 1, minimumAppVersion: nil, assets: [first, duplicate])
            )
        ) { error in
            XCTAssertEqual(error as? CatalogAudioBoundaryError, .invalidManifest("duplicate_asset_id"))
        }

        var wrong = makeAsset(id: "wrong-codec")
        wrong = CatalogAudioAsset(
            id: wrong.id,
            contentVersion: wrong.contentVersion,
            manifestVersion: wrong.manifestVersion,
            category: wrong.category,
            title: wrong.title,
            shortDescription: wrong.shortDescription,
            localeIdentifier: wrong.localeIdentifier,
            delivery: wrong.delivery,
            status: wrong.status,
            durationMilliseconds: wrong.durationMilliseconds,
            byteCount: wrong.byteCount,
            mimeType: "audio/mpeg",
            codec: "mp3",
            sampleRateHz: wrong.sampleRateHz,
            channels: wrong.channels,
            sha256: wrong.sha256,
            previewPathID: wrong.previewPathID,
            downloadPathID: wrong.downloadPathID,
            offlineCacheAllowed: wrong.offlineCacheAllowed,
            bundledResourceName: wrong.bundledResourceName,
            minimumAppVersion: wrong.minimumAppVersion,
            minimumCatalogSchema: wrong.minimumCatalogSchema,
            provenanceReference: wrong.provenanceReference,
            rightsReference: wrong.rightsReference,
            approvalReference: wrong.approvalReference
        )
        XCTAssertThrowsError(try CatalogAudioManifestValidator.validate(wrong)) { error in
            XCTAssertEqual(error as? CatalogAudioBoundaryError, .invalidManifest("catalog_codec"))
        }
    }

    func testCacheStateMachineCoversRemoteDownloadOfflineAndPlaybackLifecycle() throws {
        var state = AudioCacheState.notAvailable
        state = try CatalogAudioCacheStateMachine.transition(from: state, on: .catalogAvailable)
        XCTAssertEqual(state, .availableRemotely)
        state = try CatalogAudioCacheStateMachine.transition(from: state, on: .downloadQueued)
        state = try CatalogAudioCacheStateMachine.transition(from: state, on: .downloadStarted)
        state = try CatalogAudioCacheStateMachine.transition(from: state, on: .downloadSucceeded)
        XCTAssertEqual(state, .availableOffline)
        state = try CatalogAudioCacheStateMachine.transition(from: state, on: .playStarted)
        state = try CatalogAudioCacheStateMachine.transition(from: state, on: .interrupted)
        state = try CatalogAudioCacheStateMachine.transition(from: state, on: .resumed)
        state = try CatalogAudioCacheStateMachine.transition(from: state, on: .paused)
        state = try CatalogAudioCacheStateMachine.transition(from: state, on: .playbackStopped)
        XCTAssertEqual(state, .availableOffline)
    }

    func testChecksumFailureQuarantinesPartialBytesAndIndexesDownloadFailure() async throws {
        let asset = makeAsset(id: "checksum-failure")
        let context = makeContext(downloadData: Data("wrong".utf8))
        do {
            _ = try await context.cache.download(asset)
            XCTFail("A checksum mismatch must not become playable")
        } catch let error as CatalogAudioBoundaryError {
            XCTAssertEqual(error, .checksumMismatch)
        }
        let metadata = try await context.index.metadata(assetID: asset.id)
        XCTAssertEqual(metadata?.state, .downloadFailed)
        XCTAssertEqual(metadata?.failureReason, "checksum_failure")
        let localURL = try await context.files.localURL(for: asset)
        XCTAssertNil(localURL)
        let temporaryFileCount = await context.files.temporaryFileCount()
        XCTAssertEqual(temporaryFileCount, 0)
    }

    func testInterruptedDownloadLeavesNoPartialFile() async throws {
        let asset = makeAsset(id: "interrupted")
        let context = makeContext(transferError: .interrupted)
        do {
            _ = try await context.cache.download(asset)
            XCTFail("The interrupted transfer should fail")
        } catch let error as CatalogAudioBoundaryError {
            XCTAssertEqual(error, .interrupted)
        }
        let metadata = try await context.index.metadata(assetID: asset.id)
        XCTAssertEqual(metadata?.state, .downloadFailed)
        XCTAssertEqual(metadata?.failureReason, "interrupted")
        let temporaryFileCount = await context.files.temporaryFileCount()
        XCTAssertEqual(temporaryFileCount, 0)
        let localURL = try await context.files.localURL(for: asset)
        XCTAssertNil(localURL)
    }

    func testDuplicateDownloadsDoNotStartASecondTransfer() async throws {
        let asset = makeAsset(id: "duplicate")
        let context = makeContext(transferDelayNanoseconds: 100_000_000)
        let first = Task { try await context.cache.download(asset) }
        try await Task.sleep(for: .milliseconds(10))
        do {
            _ = try await context.cache.download(asset)
            XCTFail("A duplicate request must not start another transfer")
        } catch let error as CatalogAudioBoundaryError {
            XCTAssertEqual(error, .duplicateDownload)
        }
        _ = try await first.value
        let downloadCount = await context.transfer.downloadCount()
        XCTAssertEqual(downloadCount, 1)
    }

    func testDeletionRemovesBytesAndReturnsToNotAvailable() async throws {
        let asset = makeAsset(id: "delete")
        let context = makeContext()
        _ = try await context.cache.download(asset)
        let downloadedURL = try await context.files.localURL(for: asset)
        XCTAssertNotNil(downloadedURL)
        try await context.cache.deleteCachedAudio(asset)
        let deletedURL = try await context.files.localURL(for: asset)
        XCTAssertNil(deletedURL)
        let deletedMetadata = try await context.index.metadata(assetID: asset.id)
        XCTAssertEqual(deletedMetadata?.state, .notAvailable)
    }

    func testOfflineStateDoesNotAttemptRemoteDownload() async throws {
        let asset = makeAsset(id: "offline")
        let context = makeContext()
        let unavailable = try await context.cache.state(for: asset, networkAvailable: false)
        XCTAssertEqual(unavailable.state, .notAvailable)
        let initialAuthorizationCount = await context.remote.authorizationCount()
        XCTAssertEqual(initialAuthorizationCount, 0)

        _ = try await context.cache.download(asset)
        let cached = try await context.cache.state(for: asset, networkAvailable: false)
        XCTAssertEqual(cached.state, .availableOffline)
        let cachedAuthorizationCount = await context.remote.authorizationCount()
        XCTAssertEqual(cachedAuthorizationCount, 1)
    }

    func testAlarmPreflightRequiresVerifiedLocalSystemSound() async throws {
        let base = makeAsset(id: "alarm")
        let asset = CatalogAudioAsset(
            id: base.id,
            contentVersion: base.contentVersion,
            manifestVersion: base.manifestVersion,
            category: .morningAlarm,
            title: "Morning alarm",
            shortDescription: base.shortDescription,
            localeIdentifier: base.localeIdentifier,
            delivery: base.delivery,
            status: base.status,
            durationMilliseconds: base.durationMilliseconds,
            byteCount: base.byteCount,
            mimeType: base.mimeType,
            codec: base.codec,
            sampleRateHz: base.sampleRateHz,
            channels: base.channels,
            sha256: base.sha256,
            previewPathID: base.previewPathID,
            downloadPathID: base.downloadPathID,
            offlineCacheAllowed: base.offlineCacheAllowed,
            bundledResourceName: base.bundledResourceName,
            minimumAppVersion: base.minimumAppVersion,
            minimumCatalogSchema: base.minimumCatalogSchema,
            provenanceReference: base.provenanceReference,
            rightsReference: base.rightsReference,
            approvalReference: base.approvalReference
        )
        let context = makeContext()
        do {
            _ = try await context.cache.preflightAlarm(asset)
            XCTFail("An uncached morning alarm must not be schedulable")
        } catch let error as CatalogAudioBoundaryError {
            XCTAssertEqual(error, .alarmAssetNotLocal)
        }
        _ = try await context.cache.download(asset)
        do {
            _ = try await context.cache.preflightAlarm(asset)
            XCTFail("A downloaded non-CAF asset must not be schedulable")
        } catch let error as CatalogAudioBoundaryError {
            XCTAssertEqual(error, .alarmAssetNotLocal)
        }
    }

    func testStorageFullFailsBeforeTransferAndKeepsNoPlayableBytes() async throws {
        let asset = makeAsset(id: "storage-full")
        let context = makeContext(
            capacityError: .storageFull(requiredBytes: 10, availableBytes: 1)
        )
        do {
            _ = try await context.cache.download(asset)
            XCTFail("Storage pressure must block the transfer")
        } catch let error as CatalogAudioBoundaryError {
            XCTAssertEqual(error, .storageFull(requiredBytes: 10, availableBytes: 1))
        }
        let metadata = try await context.index.metadata(assetID: asset.id)
        XCTAssertEqual(metadata?.state, .downloadFailed)
        XCTAssertEqual(metadata?.failureReason, "storage_full")
        let downloadCount = await context.transfer.downloadCount()
        XCTAssertEqual(downloadCount, 0)
    }

    private func makeAsset(id: String, data: Data = Data("audio".utf8)) -> CatalogAudioAsset {
        CatalogAudioAsset(
            id: id,
            contentVersion: 1,
            manifestVersion: 1,
            category: .quickUnwind,
            title: "Quick unwind",
            shortDescription: "A short catalog preview.",
            localeIdentifier: "en",
            delivery: .downloadable,
            status: .approved,
            durationMilliseconds: 1000,
            byteCount: Int64(data.count),
            mimeType: "audio/mp4",
            codec: "aac-lc",
            sampleRateHz: 44100,
            channels: 2,
            sha256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
            previewPathID: "previews/\(id).m4a",
            downloadPathID: "full/\(id).m4a",
            offlineCacheAllowed: true,
            bundledResourceName: nil,
            minimumAppVersion: nil,
            minimumCatalogSchema: 1,
            provenanceReference: "test-provenance",
            rightsReference: "test-rights",
            approvalReference: "test-approval"
        )
    }

    private func makeContext(
        downloadData: Data = Data("audio".utf8),
        transferError: CatalogAudioBoundaryError? = nil,
        transferDelayNanoseconds: UInt64 = 0,
        capacityError: CatalogAudioBoundaryError? = nil
    ) -> TestContext {
        let index = TestAudioIndex()
        let files = TestAudioFiles()
        let remote = TestAudioRemote()
        let transfer = TestAudioTransfer(
            files: files,
            data: downloadData,
            error: transferError,
            delayNanoseconds: transferDelayNanoseconds
        )
        let cache = CatalogAudioCacheCoordinator(
            remote: remote,
            index: index,
            files: files,
            transfer: transfer,
            capacity: TestAudioCapacity(error: capacityError)
        )
        return TestContext(cache: cache, index: index, files: files, remote: remote, transfer: transfer)
    }
}

private struct TestContext: Sendable {
    let cache: CatalogAudioCacheCoordinator
    let index: TestAudioIndex
    let files: TestAudioFiles
    let remote: TestAudioRemote
    let transfer: TestAudioTransfer
}

private actor TestAudioIndex: CatalogAudioCacheIndexing {
    private var values: [String: AudioCacheMetadata] = [:]

    func metadata(assetID: String) async throws -> AudioCacheMetadata? {
        values[assetID]
    }

    func save(_ metadata: AudioCacheMetadata) async throws {
        values[metadata.assetID] = metadata
    }

    func remove(assetID: String) async throws {
        values[assetID] = nil
    }
}

private actor TestAudioFiles: CatalogAudioFileStoring {
    private var bytes: [String: Data] = [:]
    private var temporaryFiles: Set<String> = []

    func temporaryURL(for asset: CatalogAudioAsset) async throws -> URL {
        let url = URL(fileURLWithPath: "/tmp/\(asset.id)-\(UUID().uuidString).partial")
        temporaryFiles.insert(url.path)
        return url
    }

    func localURL(for asset: CatalogAudioAsset) async throws -> URL? {
        let url = destinationURL(for: asset)
        return bytes[url.path] == nil ? nil : url
    }

    func atomicallyPlace(temporaryURL: URL, for asset: CatalogAudioAsset) async throws -> URL {
        let destination = destinationURL(for: asset)
        guard let data = bytes[temporaryURL.path] else {
            throw CatalogAudioBoundaryError.cacheCorrupt
        }
        bytes[destination.path] = data
        bytes[temporaryURL.path] = nil
        temporaryFiles.remove(temporaryURL.path)
        return destination
    }

    func remove(asset: CatalogAudioAsset) async throws {
        bytes[destinationURL(for: asset).path] = nil
    }

    func removeTemporaryFile(at url: URL) async {
        bytes[url.path] = nil
        temporaryFiles.remove(url.path)
    }

    func byteCount(at url: URL) async throws -> Int64 {
        guard let data = bytes[url.path] else { throw CatalogAudioBoundaryError.cacheCorrupt }
        return Int64(data.count)
    }

    func sha256(at url: URL) async throws -> String {
        guard let data = bytes[url.path] else { throw CatalogAudioBoundaryError.cacheCorrupt }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    func write(_ data: Data, to url: URL) {
        bytes[url.path] = data
    }

    func temporaryFileCount() -> Int {
        temporaryFiles.count
    }

    private func destinationURL(for asset: CatalogAudioAsset) -> URL {
        URL(fileURLWithPath: "/tmp/\(asset.id)-v\(asset.contentVersion).m4a")
    }
}

private actor TestAudioRemote: CatalogAudioRemoteProviding {
    private var count = 0

    func loadManifest() async throws -> CatalogAudioManifest {
        CatalogAudioManifest(manifestVersion: 1, minimumAppVersion: nil, assets: [])
    }

    func authorizedURL(
        for asset: CatalogAudioAsset,
        purpose: CatalogAudioURLPurpose
    ) async throws -> URL {
        count += 1
        guard let url = URL(string: "https://audio.example.test/\(purpose.rawValue)/\(asset.id)") else {
            throw URLError(.badURL)
        }
        return url
    }

    func authorizationCount() -> Int {
        count
    }
}

private actor TestAudioTransfer: CatalogAudioTransferring {
    private let files: TestAudioFiles
    private let data: Data
    private let error: CatalogAudioBoundaryError?
    private let delayNanoseconds: UInt64
    private var count = 0

    init(
        files: TestAudioFiles,
        data: Data,
        error: CatalogAudioBoundaryError?,
        delayNanoseconds: UInt64
    ) {
        self.files = files
        self.data = data
        self.error = error
        self.delayNanoseconds = delayNanoseconds
    }

    func download(
        from url: URL,
        to temporaryURL: URL,
        assetID: String,
        expectedByteCount: Int64,
        progress: @escaping @Sendable (CatalogAudioDownloadProgress) async -> Void
    ) async throws -> CatalogAudioDownloadedFile {
        _ = url
        _ = expectedByteCount
        count += 1
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        if let error {
            throw error
        }
        await files.write(data, to: temporaryURL)
        await progress(
            CatalogAudioDownloadProgress(
                assetID: assetID,
                bytesReceived: Int64(data.count),
                totalBytes: Int64(data.count)
            )
        )
        return CatalogAudioDownloadedFile(temporaryURL: temporaryURL, byteCount: Int64(data.count))
    }

    func downloadCount() -> Int {
        count
    }
}

private nonisolated struct TestAudioCapacity: CatalogAudioStorageCapacityChecking {
    let error: CatalogAudioBoundaryError?

    init(error: CatalogAudioBoundaryError? = nil) {
        self.error = error
    }

    func ensureCapacity(for asset: CatalogAudioAsset) async throws {
        _ = asset
        if let error {
            throw error
        }
    }
}
