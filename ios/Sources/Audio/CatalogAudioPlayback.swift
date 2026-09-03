@preconcurrency import AVFoundation
import Foundation

@MainActor
final class CatalogAudioPlayer: NSObject {
    private let cache: CatalogAudioCacheCoordinator?
    private var player: AVPlayer?
    private var activeAssetID: String?
    private var itemStatusObserver: NSKeyValueObservation?
    private var timeControlStatusObserver: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var failureObserver: NSObjectProtocol?

    var playbackStateDidChange: (@MainActor @Sendable (CatalogAudioPlaybackState) -> Void)?

    private(set) var state: CatalogAudioPlaybackState = .idle {
        didSet {
            guard state != oldValue else { return }
            playbackStateDidChange?(state)
        }
    }

    init(cache: CatalogAudioCacheCoordinator? = nil) {
        self.cache = cache
        super.init()
        observeAudioSession()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        itemStatusObserver?.invalidate()
        timeControlStatusObserver?.invalidate()
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        if let failureObserver {
            NotificationCenter.default.removeObserver(failureObserver)
        }
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
        try? AVAudioSession.sharedInstance().setActive(true)
        player.play()
        state = .playing(activeAssetID)
    }

    var currentTime: TimeInterval {
        guard let player else { return 0 }
        let time = player.currentTime().seconds
        return time.isFinite && time >= 0 ? time : 0
    }

    var duration: TimeInterval {
        guard let item = player?.currentItem else { return 0 }
        let seconds = item.duration.seconds
        return seconds.isFinite && seconds > 0 ? seconds : 0
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        let clampedTime = max(0, time)
        let target = CMTime(seconds: clampedTime, preferredTimescale: 600)
        player.seek(to: target)
    }

    func skip(by seconds: TimeInterval) {
        seek(to: currentTime + seconds)
    }

    func stop() {
        cleanCurrentPlayer()
        state = .idle
        deactivateAudioSession()
    }

    private func cleanCurrentPlayer() {
        itemStatusObserver?.invalidate()
        itemStatusObserver = nil
        timeControlStatusObserver?.invalidate()
        timeControlStatusObserver = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        if let failureObserver {
            NotificationCenter.default.removeObserver(failureObserver)
            self.failureObserver = nil
        }
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        activeAssetID = nil
    }

    private func start(url: URL, assetID: String, streaming: Bool) throws {
        cleanCurrentPlayer()
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio)
            try session.setActive(true)
            let item = AVPlayerItem(url: url)
            let nextPlayer = AVPlayer(playerItem: item)
            nextPlayer.automaticallyWaitsToMinimizeStalling = true
            player = nextPlayer
            activeAssetID = assetID
            state = streaming ? .streaming(assetID) : .playing(assetID)
            attachItemObservers(item: item, player: nextPlayer, assetID: assetID)
            nextPlayer.play()
        } catch {
            cleanCurrentPlayer()
            state = .failed(assetID, .playerItemFailed)
            deactivateAudioSession()
            throw CatalogAudioBoundaryError.playbackFailed
        }
    }

    private func attachItemObservers(item: AVPlayerItem, player: AVPlayer, assetID _: String) {
        itemStatusObserver = item.observe(
            \.status,
            options: [.new]
        ) { [weak self] observedItem, _ in
            Task { @MainActor [weak self] in
                guard let self,
                      observedItem == self.player?.currentItem
                else {
                    return
                }
                if observedItem.status == .failed {
                    self.handlePlaybackFailure()
                }
            }
        }

        timeControlStatusObserver = player.observe(
            \.timeControlStatus,
            options: [.new]
        ) { [weak self] observedPlayer, _ in
            Task { @MainActor [weak self] in
                guard let self,
                      observedPlayer == self.player,
                      let activeAssetID = self.activeAssetID
                else {
                    return
                }
                switch observedPlayer.timeControlStatus {
                case .playing:
                    self.state = .playing(activeAssetID)
                case .paused:
                    if case .playing = self.state {
                        self.state = .paused(activeAssetID)
                    }
                case .waitingToPlayAtSpecifiedRate:
                    if case .playing = self.state {
                        self.state = .streaming(activeAssetID)
                    }
                @unknown default:
                    break
                }
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let activeAssetID = self.activeAssetID else {
                    return
                }
                self.player?.seek(to: .zero)
                self.state = .paused(activeAssetID)
            }
        }

        failureObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handlePlaybackFailure()
            }
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
