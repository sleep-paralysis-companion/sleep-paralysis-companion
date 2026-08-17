@preconcurrency import AVFoundation
import Foundation

@MainActor
final class CatalogAudioPlayer: NSObject {
    private let cache: CatalogAudioCacheCoordinator?
    private var player: AVPlayer?
    private var activeAssetID: String?

    private(set) var state: CatalogAudioPlaybackState = .idle

    init(cache: CatalogAudioCacheCoordinator? = nil) {
        self.cache = cache
        super.init()
        observeAudioSession()
        observePlaybackFailures()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func play(asset: CatalogAudioAsset, networkAvailable: Bool) async {
        guard let cache else {
            state = .failed(asset.id, .playerItemFailed)
            return
        }

        guard !asset.isRevokedOrRetired else {
            state = .failed(asset.id, .routeUnavailable)
            return
        }

        do {
            let localURL = try await cache.localPlaybackURL(for: asset)
            if let localURL {
                try start(url: localURL, assetID: asset.id, streaming: false)
                return
            }
            guard networkAvailable else {
                state = .offlineFallback(asset.id)
                return
            }
            let previewURL = try await cache.beginPreview(for: asset)
            try start(url: previewURL, assetID: asset.id, streaming: true)
        } catch CatalogAudioBoundaryError.offline {
            state = .offlineFallback(asset.id)
        } catch {
            state = .failed(asset.id, .playerItemFailed)
        }
    }

    func play(url: URL, assetID: String, streaming: Bool) {
        do {
            try start(url: url, assetID: assetID, streaming: streaming)
        } catch {
            state = .failed(assetID, .playerItemFailed)
        }
    }

    func pause() {
        guard let player, let activeAssetID else { return }
        player.pause()
        state = .paused(activeAssetID)
    }

    func resume() {
        guard let player, let activeAssetID else { return }
        player.play()
        state = .playing(activeAssetID)
    }

    func stop() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        activeAssetID = nil
        state = .idle
        deactivateAudioSession()
    }

    private func start(url: URL, assetID: String, streaming: Bool) throws {
        stop()
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.allowBluetoothHFP, .allowAirPlay]
            )
            try session.setActive(true)
            let nextPlayer = AVPlayer(url: url)
            player = nextPlayer
            activeAssetID = assetID
            state = streaming ? .streaming(assetID) : .playing(assetID)
            nextPlayer.play()
        } catch {
            player = nil
            activeAssetID = nil
            deactivateAudioSession()
            throw CatalogAudioBoundaryError.playbackFailed
        }
    }

    private func observeAudioSession() {
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(handleInterruptionNotification(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
        center.addObserver(
            self,
            selector: #selector(handleRouteChangeNotification(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    private func observePlaybackFailures() {
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(handlePlaybackFailureNotification(_:)),
            name: .AVPlayerItemFailedToPlayToEndTime,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handlePlaybackFailureNotification(_:)),
            name: .AVPlayerItemPlaybackStalled,
            object: nil
        )
    }

    @objc private func handleInterruptionNotification(_ notification: Notification) {
        let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
        Task { @MainActor [weak self] in
            self?.handleInterruption(typeValue: typeValue)
        }
    }

    @objc private func handleRouteChangeNotification(_ notification: Notification) {
        let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
        Task { @MainActor [weak self] in
            self?.handleRouteChange(reasonValue: reasonValue)
        }
    }

    @objc private func handlePlaybackFailureNotification(_: Notification) {
        Task { @MainActor [weak self] in
            self?.handlePlaybackFailure()
        }
    }

    private func handleInterruption(typeValue: UInt?) {
        guard let typeValue,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue),
              let activeAssetID
        else { return }

        if type == .began {
            player?.pause()
            state = .interrupted(activeAssetID)
        }
        // Resume is intentionally user initiated. The app does not silently
        // restart curated audio after a call, Siri, or another interruption.
    }

    private func handleRouteChange(reasonValue: UInt?) {
        guard let reasonValue,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue),
              reason == .oldDeviceUnavailable,
              let activeAssetID
        else { return }

        player?.pause()
        state = .interrupted(activeAssetID)
    }

    private func handlePlaybackFailure() {
        guard let activeAssetID else { return }
        player?.pause()
        state = .failed(activeAssetID, .playerItemFailed)
        deactivateAudioSession()
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }
}
