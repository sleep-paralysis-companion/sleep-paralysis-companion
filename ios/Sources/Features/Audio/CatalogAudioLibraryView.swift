import Foundation
import Network
import Observation
import SwiftUI

// swiftlint:disable file_length

nonisolated enum CatalogAudioLibraryLoadState: Equatable, Sendable {
    case loading
    case ready
    case empty
    case failed(String)
}

@MainActor
@Observable
final class CatalogAudioLibraryModel {
    private(set) var loadState: CatalogAudioLibraryLoadState = .loading
    private(set) var assets: [CatalogAudioAsset] = []
    private(set) var metadataByID: [String: AudioCacheMetadata] = [:]
    private(set) var playbackState = CatalogAudioPlaybackState.idle
    private(set) var selectedAlarmAssetID: String?
    private(set) var selectedNotificationAssetID: String?
    private(set) var actionMessage: String?

    private(set) var networkAvailable: Bool

    private let service: any CatalogAudioLibraryServicing
    private let uiTestScenario: String?
    @ObservationIgnored private let audioPlayer: CatalogAudioPlayer
    @ObservationIgnored private var pathMonitor: NWPathMonitor?
    private var hasAttemptedLoad = false

    init(
        service: any CatalogAudioLibraryServicing = UnavailableCatalogAudioService(),
        networkAvailable: Bool = true,
        uiTestScenario: String? = nil
    ) {
        #if DEBUG
            self.service = uiTestScenario.map {
                CatalogAudioLibraryUITestService(scenario: $0)
            } ?? service
        #else
            self.service = service
        #endif
        self.networkAvailable = networkAvailable
        self.uiTestScenario = uiTestScenario
        audioPlayer = CatalogAudioPlayer()
        selectedAlarmAssetID = AlarmSoundSelectionStore.selectedAlarmAssetID()
            ?? SystemAudioAssets.defaultAlarmAssetID
        selectedNotificationAssetID = AlarmSoundSelectionStore.selectedNotificationAssetID()
            ?? SystemAudioAssets.defaultNotificationAssetID

        #if DEBUG
            if let uiTestScenario {
                configureUITestScenario(uiTestScenario)
            } else {
                startNetworkMonitoring()
            }
        #else
            startNetworkMonitoring()
        #endif
    }

    deinit {
        pathMonitor?.cancel()
    }

    var categories: [CatalogAudioCategory] {
        CatalogAudioCategory.allCases
    }

    func loadIfNeeded() async {
        guard !hasAttemptedLoad else { return }
        hasAttemptedLoad = true

        #if DEBUG
            if uiTestScenario != nil { return }
        #endif

        do {
            let manifest = try await service.loadCatalog()
            try CatalogAudioManifestValidator.validate(manifest)
            assets = manifest.assets
            await refreshMetadata()
            loadState = assets.isEmpty ? .empty : .ready
        } catch CatalogAudioBoundaryError.offline {
            loadState = .failed(
                "The curated audio catalog is not available right now. " +
                    "Your personal recordings remain separate and on this device."
            )
        } catch {
            loadState = .failed(
                "The curated audio catalog could not be verified. No unverified audio was made playable."
            )
        }
    }

    func retry() async {
        hasAttemptedLoad = false
        loadState = .loading
        await loadIfNeeded()
    }

    func assets(for category: CatalogAudioCategory) -> [CatalogAudioAsset] {
        assets.filter { $0.category == category }
    }

    func cacheState(for asset: CatalogAudioAsset) -> AudioCacheState {
        if asset.delivery == .bundled {
            guard let resourceName = asset.bundledResourceName,
                  SystemAudioAssets.bundledURL(for: resourceName) != nil
            else {
                return .notAvailable
            }
            if let metadata = metadataByID[asset.id],
               metadata.state == .revoked || metadata.state == .revokedUnavailable
            {
                return metadata.state
            }
            return .availableOffline
        }
        if let metadata = metadataByID[asset.id] {
            return metadata.state
        }
        return asset.delivery == .bundled ? .availableOffline : (networkAvailable ? .availableRemotely : .notAvailable)
    }

    func progress(for asset: CatalogAudioAsset) -> Double {
        metadataByID[asset.id]?.progress ?? 0
    }

    func isPlaying(_ asset: CatalogAudioAsset) -> Bool {
        switch playbackState {
        case let .playing(id), let .streaming(id):
            return id == asset.id
        default:
            return false
        }
    }

    func isPaused(_ asset: CatalogAudioAsset) -> Bool {
        if case let .paused(id) = playbackState {
            return id == asset.id
        }
        return false
    }

    func togglePlayback(_ asset: CatalogAudioAsset) async {
        if isPlaying(asset) {
            audioPlayer.pause()
            playbackState = .paused(asset.id)
            return
        }

        if isPaused(asset) {
            audioPlayer.resume()
            playbackState = .playing(asset.id)
            return
        }

        stopPlayback()
        guard canPlay(asset) else {
            actionMessage = "This audio is not available in the current delivery state. " +
                "Download and verify it before playing offline."
            return
        }

        #if DEBUG
            if uiTestScenario != nil {
                playbackState = .playing(asset.id)
                return
            }
        #endif

        do {
            let url = try await service.playbackURL(for: asset, networkAvailable: networkAvailable)
            let isStreaming = cacheState(for: asset) == .availableRemotely
            audioPlayer.play(url: url, assetID: asset.id, streaming: isStreaming)
            playbackState = isStreaming ? .streaming(asset.id) : .playing(asset.id)
        } catch CatalogAudioBoundaryError.offline {
            playbackState = .offlineFallback(asset.id)
            actionMessage = "This preview is unavailable offline because the audio has not been downloaded."
        } catch {
            playbackState = .failed(asset.id, .playerItemFailed)
            actionMessage = "This preview could not be played. The verified local file was not changed."
        }
    }

    func download(_ asset: CatalogAudioAsset) async {
        guard asset.delivery == .downloadable else { return }

        #if DEBUG
            if uiTestScenario != nil {
                await simulateUITestDownload(asset)
                return
            }
        #endif

        setMetadata(for: asset, state: .downloadQueued, progress: 0, failureReason: nil)
        do {
            _ = try await service.download(asset) { [weak self] value in
                await MainActor.run {
                    self?.apply(progress: value)
                }
            }
            setMetadata(for: asset, state: .availableOffline, progress: 1, failureReason: nil)
        } catch let error as CatalogAudioBoundaryError {
            setMetadata(
                for: asset,
                state: .downloadFailed,
                progress: 0,
                failureReason: error.accessibilityReason
            )
        } catch {
            setMetadata(for: asset, state: .downloadFailed, progress: 0, failureReason: "Download failed")
        }
    }

    func removeDownload(_ asset: CatalogAudioAsset) async {
        guard asset.delivery == .downloadable else { return }
        do {
            #if DEBUG
                if uiTestScenario == nil {
                    try await service.deleteCachedAudio(asset)
                }
            #else
                try await service.deleteCachedAudio(asset)
            #endif
            setMetadata(
                for: asset,
                state: networkAvailable ? .availableRemotely : .notAvailable,
                progress: 0,
                failureReason: nil
            )
            actionMessage = "Removed \(asset.title) from offline storage. It can be downloaded again when available."
        } catch {
            actionMessage = "\(asset.title) could not be removed from offline storage."
        }
    }

    func selectAlarm(_ asset: CatalogAudioAsset) async {
        guard asset.category == .morningAlarm else { return }
        guard isLocallyAvailable(asset) else {
            actionMessage = "Download and verify this morning alarm before selecting it. " +
                "The current local fallback remains unchanged."
            return
        }

        do {
            let url = try await service.preflightAlarm(asset)
            selectedAlarmAssetID = asset.id
            AlarmSoundSelectionStore.selectAlarm(
                assetID: asset.id,
                fileName: url.lastPathComponent
            )
            actionMessage = "\(asset.title) is selected for the next alarm schedule."
        } catch {
            actionMessage = "\(asset.title) is not prepared for alarm use. " +
                "The current local fallback remains unchanged."
        }
    }

    func selectNotification(_ asset: CatalogAudioAsset) async {
        guard asset.category == .notification else { return }
        guard isLocallyAvailable(asset) else {
            actionMessage = "This notification sound must be included with the app or available locally " +
                "before it can be selected."
            return
        }

        guard let resourceName = asset.bundledResourceName else {
            actionMessage = "This notification sound must be bundled before it can be selected."
            return
        }
        do {
            let url = try SystemAudioAssets.preflightNotification(resourceName: resourceName)
            selectedNotificationAssetID = asset.id
            AlarmSoundSelectionStore.selectNotification(
                assetID: asset.id,
                fileName: url.lastPathComponent
            )
            actionMessage = "\(asset.title) is selected for notifications."
        } catch {
            actionMessage = "This notification sound is not available locally."
        }
    }

    func clearActionMessage() {
        actionMessage = nil
    }

    private func refreshMetadata() async {
        var refreshed: [String: AudioCacheMetadata] = [:]
        for asset in assets {
            do {
                refreshed[asset.id] = try await service.state(
                    for: asset,
                    networkAvailable: networkAvailable
                )
            } catch {
                refreshed[asset.id] = metadata(for: asset, state: .notAvailable, failureReason: "catalog_unavailable")
            }
        }
        metadataByID = refreshed
    }

    private func startNetworkMonitoring() {
        let monitor = NWPathMonitor()
        pathMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                await self?.setNetworkAvailability(path.status == .satisfied)
            }
        }
        monitor.start(queue: DispatchQueue(label: "app.sleepcompanion.catalog-audio-network"))
    }

    private func setNetworkAvailability(_ value: Bool) async {
        networkAvailable = value
        guard hasAttemptedLoad, !assets.isEmpty else { return }
        await refreshMetadata()
    }

    private func canPlay(_ asset: CatalogAudioAsset) -> Bool {
        switch cacheState(for: asset) {
        case .availableOffline, .availableRemotely, .streaming, .playing, .paused, .interrupted, .verified:
            return !asset.isRevokedOrRetired
        default:
            return false
        }
    }

    private func isLocallyAvailable(_ asset: CatalogAudioAsset) -> Bool {
        switch cacheState(for: asset) {
        case .availableOffline, .verified:
            return true
        default:
            return false
        }
    }

    private func stopPlayback() {
        audioPlayer.stop()
        playbackState = .idle
    }

    private func apply(progress: CatalogAudioDownloadProgress) {
        guard let current = metadataByID[progress.assetID] else { return }
        metadataByID[progress.assetID] = AudioCacheMetadata(
            assetID: current.assetID,
            catalogVersion: current.catalogVersion,
            state: .downloading,
            relativeFileName: current.relativeFileName,
            verifiedAt: current.verifiedAt,
            byteCount: progress.bytesReceived,
            progress: progress.fractionCompleted,
            failureReason: nil,
            lastAccessedAt: current.lastAccessedAt
        )
    }

    private func setMetadata(
        for asset: CatalogAudioAsset,
        state: AudioCacheState,
        progress: Double,
        failureReason: String?
    ) {
        let current = metadataByID[asset.id]
        metadataByID[asset.id] = AudioCacheMetadata(
            assetID: asset.id,
            catalogVersion: asset.contentVersion,
            state: state,
            relativeFileName: current?.relativeFileName,
            verifiedAt: state == .availableOffline ? Date() : current?.verifiedAt,
            byteCount: state == .availableOffline ? asset.byteCount : (current?.byteCount ?? 0),
            progress: progress,
            failureReason: failureReason,
            lastAccessedAt: current?.lastAccessedAt
        )
    }

    private func metadata(
        for asset: CatalogAudioAsset,
        state: AudioCacheState,
        failureReason: String? = nil
    ) -> AudioCacheMetadata {
        AudioCacheMetadata(
            assetID: asset.id,
            catalogVersion: asset.contentVersion,
            state: state,
            relativeFileName: nil,
            verifiedAt: nil,
            byteCount: 0,
            progress: 0,
            failureReason: failureReason,
            lastAccessedAt: nil
        )
    }

}

struct CatalogAudioLibraryView: View {
    private let openPersonalAudio: () -> Void
    @State private var model: CatalogAudioLibraryModel

    init(
        service: any CatalogAudioLibraryServicing = UnavailableCatalogAudioService(),
        openPersonalAudio: @escaping () -> Void = {}
    ) {
        self.openPersonalAudio = openPersonalAudio
        #if DEBUG
            let scenario = ProcessInfo.processInfo.environment["SPC_UI_TEST_CATALOG_SCENARIO"]
        #else
            let scenario: String? = nil
        #endif
        let networkAvailable = scenario != "offline"
        _model = State(
            initialValue: CatalogAudioLibraryModel(
                service: service,
                networkAvailable: networkAvailable,
                uiTestScenario: scenario
            )
        )
    }

    var body: some View {
        NightScreen {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                header
                deliveryLegend

                if let actionMessage = model.actionMessage {
                    NightCard {
                        HStack(alignment: .top, spacing: AppSpacing.compact) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(.cyan)
                                .accessibilityHidden(true)
                            Text(actionMessage)
                                .font(AppTypographyRole.supporting)
                        }
                        Button("Dismiss message") {
                            model.clearActionMessage()
                        }
                        .buttonStyle(AppSecondaryButtonStyle())
                    }
                    .accessibilityIdentifier("catalogAudio.message")
                }

                loadStateContent
                categoryContent
            }
            .accessibilityIdentifier("catalogAudioLibrary")
        }
        .navigationTitle("Audio library")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await model.loadIfNeeded()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.compact) {
            Text("Curated audio")
                .font(AppTypographyRole.hero)
                .accessibilityAddTraits(.isHeader)
            Text(
                "Preview and manage Sleep Paralysis Companion audio. " +
                    "Personal recordings are separate and stay on this device."
            )
            .font(AppTypographyRole.body)
            .foregroundStyle(.white.opacity(0.72))
            Button("Open personal audio", systemImage: "person.crop.circle") {
                openPersonalAudio()
            }
            .buttonStyle(AppSecondaryButtonStyle())
            .accessibilityIdentifier("catalogAudio.openPersonalAudio")
        }
    }

    private var deliveryLegend: some View {
        NightCard {
            VStack(alignment: .leading, spacing: AppSpacing.compact) {
                Text("Delivery states")
                    .font(AppTypographyRole.cardTitle)
                deliveryState(
                    "Included with app",
                    detail: "Available without a network connection.",
                    icon: "shippingbox.fill"
                )
                deliveryState(
                    "Stream preview",
                    detail: "Preview uses the network until a verified download is ready.",
                    icon: "waveform"
                )
                deliveryState(
                    "Downloading",
                    detail: "Partial bytes are not playable or treated as offline.",
                    icon: "arrow.down.circle"
                )
                deliveryState(
                    "Available offline",
                    detail: "A verified local download is ready.",
                    icon: "checkmark.circle.fill"
                )
                deliveryState(
                    "Selected for system use",
                    detail: "Only a locally available sound can be selected.",
                    icon: "alarm.fill"
                )
                deliveryState(
                    "Unavailable",
                    detail: "The app will not pretend this sound is ready.",
                    icon: "exclamationmark.triangle.fill"
                )
            }
        }
        .accessibilityIdentifier("catalogAudio.deliveryLegend")
    }

    private func deliveryState(_ title: String, detail: String, icon: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypographyRole.supporting.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.66))
            }
        } icon: {
            Image(systemName: icon)
                .frame(width: 24)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var loadStateContent: some View {
        switch model.loadState {
        case .loading:
            NightCard {
                HStack(spacing: AppSpacing.compact) {
                    ProgressView()
                    Text("Loading curated audio")
                        .font(AppTypographyRole.body)
                }
            }
            .accessibilityIdentifier("catalogAudio.loading")
        case .empty:
            NightCard {
                Label("No approved curated audio yet", systemImage: "music.note.list")
                    .font(AppTypographyRole.cardTitle)
                Text(
                    "The library will show audio here after its delivery, rights, accessibility, " +
                        "and device-readiness checks are complete."
                )
                    .font(AppTypographyRole.body)
                    .foregroundStyle(.white.opacity(0.68))
            }
            .accessibilityIdentifier("catalogAudio.empty")
        case let .failed(message):
            NightCard {
                Label("Audio library unavailable", systemImage: "exclamationmark.triangle.fill")
                    .font(AppTypographyRole.cardTitle)
                Text(message)
                    .font(AppTypographyRole.body)
                    .foregroundStyle(.white.opacity(0.68))
                Button("Try again", systemImage: "arrow.clockwise") {
                    Task { await model.retry() }
                }
                .buttonStyle(AppPrimaryButtonStyle())
            }
            .accessibilityIdentifier("catalogAudio.error")
        case .ready:
            EmptyView()
        }
    }

    private var categoryContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            ForEach(model.categories, id: \.self) { category in
                VStack(alignment: .leading, spacing: AppSpacing.compact) {
                    Text(category.displayName)
                        .font(AppTypographyRole.sectionTitle)
                        .accessibilityAddTraits(.isHeader)
                    let categoryAssets = model.assets(for: category)
                    if categoryAssets.isEmpty {
                        emptyCategory(category)
                    } else {
                        ForEach(categoryAssets) { asset in
                            CatalogAudioAssetCard(asset: asset, model: model)
                        }
                    }
                }
                .accessibilityIdentifier("catalogAudio.category.\(category.rawValue)")
            }
        }
    }

    private func emptyCategory(_ category: CatalogAudioCategory) -> some View {
        NightCard {
            Label("No verified delivery", systemImage: category.systemImage)
                .font(AppTypographyRole.cardTitle)
            Text(
                "No approved file is available for \(category.displayName). " +
                    "No duration or download size is shown until real delivery metadata exists."
            )
                .font(AppTypographyRole.body)
                .foregroundStyle(.white.opacity(0.68))
        }
        .accessibilityIdentifier("catalogAudio.emptyCategory.\(category.rawValue)")
    }
}

private struct CatalogAudioAssetCard: View {
    let asset: CatalogAudioAsset
    let model: CatalogAudioLibraryModel

    var body: some View {
        NightCard {
            VStack(alignment: .leading, spacing: AppSpacing.compact) {
                HStack(alignment: .top, spacing: AppSpacing.compact) {
                    Label(asset.title, systemImage: asset.category.systemImage)
                        .font(AppTypographyRole.cardTitle)
                    Spacer(minLength: AppSpacing.compact)
                    if isSelected {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.cyan)
                            .accessibilityLabel("Selected for system use")
                    }
                }

                Text(asset.shortDescription)
                    .font(AppTypographyRole.body)
                    .foregroundStyle(.white.opacity(0.72))

                Text(assetMetadata)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.66))
                    .accessibilityIdentifier("catalogAudio.metadata.\(asset.id)")

                statusRow
                actionButtons
            }
        }
        .accessibilityIdentifier("catalogAudio.row.\(asset.category.rawValue)")
    }

    private var assetMetadata: String {
        "\(asset.durationText) · \(asset.byteSizeText)"
    }

    private var isSelected: Bool {
        model.selectedAlarmAssetID == asset.id || model.selectedNotificationAssetID == asset.id
    }

    private var statusRow: some View {
        VStack(alignment: .leading, spacing: AppSpacing.tight) {
            Label(statusText, systemImage: statusIcon)
                .font(AppTypographyRole.supporting.weight(.semibold))
                .accessibilityValue(statusText)
                .accessibilityIdentifier("catalogAudio.status.\(asset.category.rawValue)")
            if isDownloading {
                ProgressView(value: model.progress(for: asset)) {
                    Text("Download progress")
                }
                .progressViewStyle(.linear)
                .accessibilityValue("\(Int(model.progress(for: asset) * 100)) percent")
                .accessibilityIdentifier("catalogAudio.progress.\(asset.category.rawValue)")
            }
            if let failureReason {
                Text(failureReason)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.66))
            }
        }
        .padding(.vertical, AppSpacing.tight)
    }

    private var actionButtons: some View {
        VStack(spacing: AppSpacing.compact) {
            Button(action: { Task { await model.togglePlayback(asset) } }) {
                Label(playbackTitle, systemImage: playbackIcon)
            }
            .buttonStyle(AppSecondaryButtonStyle())
            .accessibilityIdentifier(
                model.isPlaying(asset)
                    ? "catalogAudio.pause.\(asset.category.rawValue)"
                    : "catalogAudio.play.\(asset.category.rawValue)"
            )
            .disabled(!canPlay)

            if canDownload {
                Button(action: { Task { await model.download(asset) } }) {
                    Label("Download for offline", systemImage: "arrow.down.circle")
                }
                .buttonStyle(AppPrimaryButtonStyle())
                .accessibilityIdentifier("catalogAudio.download.\(asset.category.rawValue)")
            } else if isDownloaded {
                Button(action: { Task { await model.removeDownload(asset) } }) {
                    Label("Remove offline download", systemImage: "trash")
                }
                .buttonStyle(AppSecondaryButtonStyle())
                .accessibilityIdentifier("catalogAudio.remove.\(asset.category.rawValue)")
            }

            if asset.category == .morningAlarm {
                Button(action: { Task { await model.selectAlarm(asset) } }) {
                    Label(alarmButtonTitle, systemImage: "alarm")
                }
                .buttonStyle(AppSecondaryButtonStyle())
                .accessibilityIdentifier("catalogAudio.selectAlarm.\(asset.category.rawValue)")
                .disabled(!canSetAlarm)
            }

            if asset.category == .notification {
                Button(action: { Task { await model.selectNotification(asset) } }) {
                    Label(notificationButtonTitle, systemImage: "bell")
                }
                .buttonStyle(AppSecondaryButtonStyle())
                .accessibilityIdentifier("catalogAudio.selectNotification.\(asset.category.rawValue)")
                .disabled(!canSetNotification)
            }
        }
    }

    private var state: AudioCacheState {
        model.cacheState(for: asset)
    }

    private var isDownloaded: Bool {
        state == .availableOffline || state == .verified
    }

    private var isDownloading: Bool {
        state == .downloadQueued || state == .downloading
    }

    private var canDownload: Bool {
        asset.delivery == .downloadable && !isDownloaded && !isDownloading && !asset.isRevokedOrRetired
    }

    private var canPlay: Bool {
        switch state {
        case .availableOffline, .availableRemotely, .streaming, .playing, .paused, .interrupted, .verified:
            true
        default:
            false
        }
    }

    private var canSetAlarm: Bool {
        asset.category == .morningAlarm && isDownloaded
    }

    private var canSetNotification: Bool {
        asset.category == .notification && isDownloaded
    }

    private var statusText: String {
        if model.isPlaying(asset) { return "Playing preview" }
        if model.isPaused(asset) { return "Preview paused" }
        switch state {
        case .notAvailable:
            return model.networkAvailable ? "Unavailable" : "Unavailable offline"
        case .availableRemotely:
            return "Stream preview available"
        case .streaming:
            return "Streaming preview"
        case .downloadQueued:
            return "Preparing download"
        case .downloading:
            return "Downloading · \(Int(model.progress(for: asset) * 100))%"
        case .downloadFailed:
            return "Download failed"
        case .availableOffline, .verified:
            return asset.delivery == .bundled ? "Included with app" : "Available offline"
        case .updateAvailable:
            return "Update available"
        case .playing:
            return "Playing preview"
        case .paused:
            return "Preview paused"
        case .interrupted:
            return "Preview interrupted"
        case .notCached:
            return "Not downloaded"
        case .invalid, .revoked, .revokedUnavailable:
            return "Unavailable"
        }
    }

    private var statusIcon: String {
        switch state {
        case .availableOffline, .verified:
            "checkmark.circle.fill"
        case .availableRemotely, .streaming:
            "waveform"
        case .downloading, .downloadQueued:
            "arrow.down.circle"
        case .downloadFailed, .invalid, .revoked, .revokedUnavailable, .notAvailable:
            "exclamationmark.triangle.fill"
        default:
            "info.circle"
        }
    }

    private var failureReason: String? {
        guard case .downloadFailed = state else { return nil }
        return model.metadataByID[asset.id]?.failureReason?.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private var playbackTitle: String {
        if model.isPlaying(asset) { return "Pause preview" }
        if model.isPaused(asset) { return "Resume preview" }
        return "Play preview"
    }

    private var playbackIcon: String {
        if model.isPlaying(asset) { return "pause.fill" }
        if model.isPaused(asset) { return "play.fill" }
        return "play.fill"
    }

    private var alarmButtonTitle: String {
        model.selectedAlarmAssetID == asset.id
            ? "Selected for alarm"
            : (canSetAlarm ? "Set as alarm" : "Download to set alarm")
    }

    private var notificationButtonTitle: String {
        model.selectedNotificationAssetID == asset.id ? "Selected for notifications" : "Set as notification"
    }
}

private extension CatalogAudioCategory {
    var displayName: String {
        switch self {
        case .morningAlarm: "Morning Alarm"
        case .notification: "Notification"
        case .quickUnwind: "Quick Unwind"
        case .secondSleep: "Second Sleep"
        case .slowUnwind: "Slow Unwind"
        }
    }

    var systemImage: String {
        switch self {
        case .morningAlarm: "alarm.fill"
        case .notification: "bell.fill"
        case .quickUnwind: "wind"
        case .secondSleep: "moon.zzz.fill"
        case .slowUnwind: "waveform.path.ecg"
        }
    }
}

private extension CatalogAudioAsset {
    var durationText: String {
        let totalSeconds = max(0, durationMilliseconds / 1_000)
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m \(seconds)s" }
        return "\(seconds)s"
    }

    var byteSizeText: String {
        ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    }
}

private extension CatalogAudioBoundaryError {
    var accessibilityReason: String {
        switch self {
        case .storageFull: "Not enough storage"
        case .checksumMismatch, .byteCountMismatch: "The downloaded file did not pass integrity checks"
        case .offline: "The network is unavailable"
        case .interrupted, .cancelled: "The download was interrupted"
        default: "Download failed"
        }
    }
}

#if DEBUG
private extension CatalogAudioLibraryModel {
    func configureUITestScenario(_ scenario: String) {
        loadState = switch scenario {
        case "loading": .loading
        case "empty": .empty
        case "error": .failed("The test catalog could not be verified.")
        default: .ready
        }
        guard loadState == .ready else { return }

        assets = CatalogAudioLibraryUITestFixture.assets
        let state: AudioCacheState = switch scenario {
        case "downloaded", "offline", "selected-alarm", "storage-removal": .availableOffline
        case "failed-download": .downloadFailed
        default: .availableRemotely
        }
        metadataByID = Dictionary(uniqueKeysWithValues: assets.map { asset in
            let itemState = scenario == "offline" && asset.delivery == .downloadable ? .notAvailable : state
            return (
                asset.id,
                metadata(
                    for: asset,
                    state: itemState,
                    failureReason: itemState == .downloadFailed ? "storage_full" : nil
                )
            )
        })
        if scenario == "selected-alarm" {
            selectedAlarmAssetID = assets.first(where: { $0.category == .morningAlarm })?.id
        }
    }

    func simulateUITestDownload(_ asset: CatalogAudioAsset) async {
        setMetadata(for: asset, state: .downloadQueued, progress: 0, failureReason: nil)
        setMetadata(for: asset, state: .downloading, progress: 0.35, failureReason: nil)
        if uiTestScenario == "download-progress" { return }
        if uiTestScenario == "failed-download" {
            try? await Task.sleep(for: .milliseconds(200))
            setMetadata(for: asset, state: .downloadFailed, progress: 0, failureReason: "storage_full")
            return
        }
        setMetadata(for: asset, state: .availableOffline, progress: 1, failureReason: nil)
    }
}

private struct CatalogAudioLibraryUITestService: CatalogAudioLibraryServicing {
    let scenario: String

    func loadCatalog() async throws -> CatalogAudioManifest {
        CatalogAudioManifest(
            manifestVersion: 1,
            minimumAppVersion: nil,
            assets: CatalogAudioLibraryUITestFixture.assets
        )
    }

    func state(for asset: CatalogAudioAsset, networkAvailable: Bool) async throws -> AudioCacheMetadata {
        AudioCacheMetadata(
            assetID: asset.id,
            catalogVersion: asset.contentVersion,
            state: networkAvailable ? .availableRemotely : .notAvailable,
            relativeFileName: nil,
            verifiedAt: nil,
            byteCount: 0,
            progress: 0,
            failureReason: nil,
            lastAccessedAt: nil
        )
    }

    func previewURL(for asset: CatalogAudioAsset) async throws -> URL {
        URL(fileURLWithPath: "/dev/null")
    }

    func playbackURL(for asset: CatalogAudioAsset, networkAvailable: Bool) async throws -> URL {
        if scenario == "offline", !networkAvailable, asset.delivery == .downloadable {
            throw CatalogAudioBoundaryError.offline
        }
        return URL(fileURLWithPath: "/dev/null")
    }

    func download(
        _ asset: CatalogAudioAsset,
        progress: @escaping @Sendable (CatalogAudioDownloadProgress) async -> Void
    ) async throws -> URL {
        throw CatalogAudioBoundaryError.offline
    }

    func deleteCachedAudio(_ asset: CatalogAudioAsset) async throws {}

    func preflightAlarm(_ asset: CatalogAudioAsset) async throws -> URL {
        guard scenario == "selected-alarm" else { throw CatalogAudioBoundaryError.alarmAssetNotLocal }
        return URL(fileURLWithPath: "/dev/null")
    }
}

private enum CatalogAudioLibraryUITestFixture {
    static let assets: [CatalogAudioAsset] = [
        make(
            id: "ui-morning-alarm",
            category: .morningAlarm,
            title: "Gentle morning alarm",
            description: "A local morning alarm candidate for UI state coverage.",
            delivery: .downloadable
        ),
        make(
            id: "ui-notification",
            category: .notification,
            title: "Soft notification",
            description: "A bundled notification candidate for UI state coverage.",
            delivery: .bundled
        ),
        make(
            id: "ui-quick-unwind",
            category: .quickUnwind,
            title: "Quick Unwind",
            description: "A short curated preview.",
            delivery: .downloadable
        ),
        make(
            id: "ui-second-sleep",
            category: .secondSleep,
            title: "Second Sleep",
            description: "A curated session for a return to rest.",
            delivery: .downloadable
        ),
        make(
            id: "ui-slow-unwind",
            category: .slowUnwind,
            title: "Slow Unwind",
            description: "A longer curated session.",
            delivery: .downloadable
        ),
    ]

    private static func make(
        id: String,
        category: CatalogAudioCategory,
        title: String,
        description: String,
        delivery: CatalogAudioDelivery
    ) -> CatalogAudioAsset {
        CatalogAudioAsset(
            id: id,
            contentVersion: 1,
            manifestVersion: 1,
            category: category,
            title: title,
            shortDescription: description,
            localeIdentifier: "en",
            delivery: delivery,
            status: .approved,
            durationMilliseconds: category == .notification ? 2_000 : 60_000,
            byteCount: 1_000_000,
            mimeType: delivery == .bundled ? "audio/x-caf" : "audio/mp4",
            codec: delivery == .bundled ? "pcm_s16be" : "aac-lc",
            sampleRateHz: 48_000,
            channels: 1,
            sha256: String(repeating: "a", count: 64),
            previewPathID: delivery == .downloadable ? "preview/\(id)" : nil,
            downloadPathID: delivery == .downloadable ? "download/\(id)" : nil,
            offlineCacheAllowed: true,
            bundledResourceName: delivery == .bundled ? "ui-notification.caf" : nil,
            minimumAppVersion: nil,
            minimumCatalogSchema: 1,
            provenanceReference: "ui-test",
            rightsReference: "ui-test",
            approvalReference: "ui-test"
        )
    }
}
#endif

// swiftlint:enable file_length
