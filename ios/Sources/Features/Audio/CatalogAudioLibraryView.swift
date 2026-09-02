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
    var selectedBedtimeAssetID: String = "quick-unwind"
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
            if uiTestScenario != nil {
                return
            }
        #endif

        do {
            let manifest = try await service.loadCatalog()
            try CatalogAudioManifestValidator.validate(manifest)
            assets = manifest.assets
            await refreshMetadata()
            loadState = assets.isEmpty ? .empty : .ready
            if let first = assets.first(where: {
                $0.category == .quickUnwind || $0.category == .slowUnwind
            }) {
                selectedBedtimeAssetID = first.id
            }
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
        let fallbackState: AudioCacheState = networkAvailable ? .availableRemotely : .notAvailable
        return asset.delivery == .bundled ? .availableOffline : fallbackState
    }

    func progress(for asset: CatalogAudioAsset) -> Double {
        metadataByID[asset.id]?.progress ?? 0
    }

    func isPlaying(_ asset: CatalogAudioAsset) -> Bool {
        switch playbackState {
        case let .playing(id), let .streaming(id):
            id == asset.id
        default:
            false
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
            actionMessage = "Removed \(asset.title) from offline storage. " +
                "It can be downloaded again when available."
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
                refreshed[asset.id] = metadata(
                    for: asset,
                    state: .notAvailable,
                    failureReason: "catalog_unavailable"
                )
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
            !asset.isRevokedOrRetired
        default:
            false
        }
    }

    private func isLocallyAvailable(_ asset: CatalogAudioAsset) -> Bool {
        switch cacheState(for: asset) {
        case .availableOffline, .verified:
            true
        default:
            false
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
        progress: Double = 0,
        failureReason: String? = nil
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
    var appModel: AppModel?
    private let openPersonalAudio: () -> Void
    @State private var model: CatalogAudioLibraryModel
    @Environment(\.dismiss) private var dismiss

    init(
        appModel: AppModel? = nil,
        service: any CatalogAudioLibraryServicing = UnavailableCatalogAudioService(),
        openPersonalAudio: @escaping () -> Void = {}
    ) {
        self.appModel = appModel
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
        ZStack {
            libraryBackground

            VStack(spacing: 0) {
                topNavigationBar
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        alarmStatusPill
                            .padding(.top, 8)

                        headerSection

                        if let actionMessage = model.actionMessage {
                            actionToast(actionMessage)
                        }

                        loadStateContent

                        cardsSection
                            .padding(.bottom, 140)
                    }
                    .padding(.horizontal, 20)
                }
                .scrollIndicators(.hidden)
            }

            bottomActionBar
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("catalogAudioLibrary")
        .task {
            await model.loadIfNeeded()
        }
    }

    // MARK: - Background

    private var libraryBackground: some View {
        ZStack {
            LinearGradient(
                colors: [HomeScreenPalette.backgroundTop, HomeScreenPalette.backgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(red: 0.15, green: 0.25, blue: 0.65).opacity(0.2))
                .frame(width: 340, height: 340)
                .blur(radius: 90)
                .offset(x: -60, y: -180)

            Circle()
                .fill(Color(red: 0.35, green: 0.15, blue: 0.55).opacity(0.18))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: 120, y: 120)
        }
    }

    // MARK: - Navigation Bar

    private var topNavigationBar: some View {
        HStack {
            Button {
                if let appModel, !appModel.path.isEmpty {
                    appModel.setPath(Array(appModel.path.dropLast()))
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            Spacer()

            Button {
                openPersonalAudio()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 13, weight: .medium))
                    Text("Personal")
                        .font(AppFont.inter(size: 13, relativeTo: .footnote, weight: .medium))
                }
                .foregroundStyle(HomeScreenPalette.iconTint)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("catalogAudio.openPersonalAudio")
        }
    }

    // MARK: - Alarm Status Pill

    private var alarmStatusPill: some View {
        Button {
            appModel?.open(.alarmHistory)
        } label: {
            HStack(spacing: 7) {
                Circle()
                    .fill(activeAlarmTime != nil ? Color.green : Color.white.opacity(0.4))
                    .frame(width: 7, height: 7)

                Text(alarmPillText)
                    .font(AppFont.inter(size: 13, relativeTo: .footnote, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.45))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(
                        activeAlarmTime != nil ? Color.green.opacity(0.35) : Color.white.opacity(0.12),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("catalogAudio.alarmBadge")
    }

    private var activeAlarmTime: String? {
        guard let appModel,
              let activeSchedule = appModel.scheduleUIModels.first(where: \.isEnabled)
        else {
            return nil
        }
        let hour = activeSchedule.wakeHour
        let minute = activeSchedule.wakeMinute
        let displayHour = hour.isMultiple(of: 12) ? 12 : hour % 12
        let period = hour >= 12 ? "PM" : "AM"
        return "\(displayHour):\(String(format: "%02d", minute)) \(period)"
    }

    private var alarmPillText: String {
        if let time = activeAlarmTime {
            return "Alarm set · \(time)"
        }
        return "No alarm set"
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What would you\nlike to hear tonight?")
                .font(AppFont.inter(size: 28, relativeTo: .title, weight: .bold))
                .foregroundStyle(.white)
                .lineSpacing(2)
                .accessibilityAddTraits(.isHeader)

            Text("Audio plays softly until you fall asleep")
                .font(AppFont.inter(size: 15, relativeTo: .subheadline, weight: .regular))
                .foregroundStyle(.white.opacity(0.65))
        }
    }

    // MARK: - Action Toast

    private func actionToast(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.cyan)
            Text(message)
                .font(AppFont.inter(size: 13, relativeTo: .footnote))
                .foregroundStyle(.white.opacity(0.9))
            Spacer()
            Button {
                model.clearActionMessage()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("catalogAudio.message")
    }

    // MARK: - Load State Content

    @ViewBuilder
    private var loadStateContent: some View {
        switch model.loadState {
        case .loading:
            HStack(spacing: 12) {
                ProgressView()
                    .tint(.white)
                Text("Loading curated audio")
                    .font(AppFont.inter(size: 14, relativeTo: .body))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.vertical, 12)
            .accessibilityIdentifier("catalogAudio.loading")
        case .empty:
            VStack(alignment: .leading, spacing: 6) {
                Text("No approved curated audio yet")
                    .font(AppFont.inter(size: 16, relativeTo: .headline, weight: .semibold))
                Text("The library will show audio here once available.")
                    .font(AppFont.inter(size: 14, relativeTo: .body))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .padding(16)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .accessibilityIdentifier("catalogAudio.empty")
        case let .failed(message):
            VStack(alignment: .leading, spacing: 10) {
                Text("Audio library unavailable")
                    .font(AppFont.inter(size: 16, relativeTo: .headline, weight: .semibold))
                Text(message)
                    .font(AppFont.inter(size: 13, relativeTo: .body))
                    .foregroundStyle(.white.opacity(0.65))
                Button("Try again") {
                    Task { await model.retry() }
                }
                .font(AppFont.inter(size: 14, relativeTo: .subheadline, weight: .semibold))
                .foregroundStyle(HomeScreenPalette.iconTint)
            }
            .padding(16)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .accessibilityIdentifier("catalogAudio.error")
        case .ready:
            EmptyView()
        }
    }

    // MARK: - Cards Section

    private var cardsSection: some View {
        VStack(spacing: 16) {
            let primaryTracks = model.assets.filter {
                $0.category == .quickUnwind || $0.category == .slowUnwind || $0.category == .secondSleep
            }

            let displayTracks = primaryTracks.isEmpty ? model.assets : primaryTracks

            ForEach(displayTracks) { asset in
                BedtimeAudioCard(
                    asset: asset,
                    model: model,
                    isSelected: model.selectedBedtimeAssetID == asset.id,
                    onSelect: {
                        model.selectedBedtimeAssetID = asset.id
                    }
                )
            }

            let otherTracks = model.assets.filter {
                $0.category == .morningAlarm || $0.category == .notification
            }
            if !otherTracks.isEmpty, !primaryTracks.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("More audio & alarm sounds")
                        .font(AppFont.inter(size: 16, relativeTo: .headline, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.top, 12)

                    ForEach(otherTracks) { asset in
                        BedtimeAudioCard(
                            asset: asset,
                            model: model,
                            isSelected: model.selectedBedtimeAssetID == asset.id,
                            onSelect: {
                                model.selectedBedtimeAssetID = asset.id
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        VStack(spacing: 10) {
            Button {
                startSelectedBedtimeSession()
            } label: {
                Text("Play now & begin tracking")
                    .font(AppFont.inter(size: 16, relativeTo: .headline, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.35, green: 0.45, blue: 0.95),
                                Color(red: 0.25, green: 0.35, blue: 0.85),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: Color(red: 0.3, green: 0.4, blue: 0.9).opacity(0.35), radius: 12, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("catalogAudio.playAndTrack")

            Button {
                goToSecondSleep()
            } label: {
                Text("Go to Second Sleep")
                    .font(AppFont.inter(size: 15, relativeTo: .subheadline, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.black.opacity(0.45))
                    .clipShape(Capsule())
                    .overlay {
                        Capsule()
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("catalogAudio.goToSecondSleep")
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .padding(.top, 16)
        .background(
            LinearGradient(
                colors: [
                    HomeScreenPalette.backgroundBottom.opacity(0),
                    HomeScreenPalette.backgroundBottom.opacity(0.92),
                    HomeScreenPalette.backgroundBottom,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private func startSelectedBedtimeSession() {
        if let asset = model.assets.first(where: { $0.id == model.selectedBedtimeAssetID }) {
            Task {
                await model.togglePlayback(asset)
            }
        }
        appModel?.startSleepSession()
    }

    private func goToSecondSleep() {
        if let secondSleep = model.assets.first(where: {
            $0.category == .secondSleep || $0.id == "second-sleep"
        }) {
            model.selectedBedtimeAssetID = secondSleep.id
            Task {
                await model.togglePlayback(secondSleep)
            }
        }
        appModel?.open(.audioPlayer)
    }
}

// MARK: - Bedtime Audio Card

private struct BedtimeAudioCard: View {
    let asset: CatalogAudioAsset
    let model: CatalogAudioLibraryModel
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            ZStack {
                cardBackground

                VStack(alignment: .leading, spacing: 0) {
                    // Top Controls Row
                    HStack(alignment: .top) {
                        downloadOrOfflineBadge

                        Spacer()

                        playPauseButton
                    }

                    Spacer(minLength: 28)

                    // Track Title
                    Text(asset.title)
                        .font(AppFont.inter(size: 22, relativeTo: .title2, weight: .bold))
                        .foregroundStyle(.white)

                    // Duration
                    Text(durationText)
                        .font(AppFont.inter(size: 15, relativeTo: .subheadline, weight: .regular))
                        .foregroundStyle(.white.opacity(0.68))
                        .padding(.top, 4)

                    // Accessibility hidden state indicators
                    accessibleTestStatus
                }
                .padding(22)
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        isSelected ? Color.white.opacity(0.38) : Color.white.opacity(0.08),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("catalogAudio.row.\(asset.category.rawValue)")
    }

    // MARK: - Card Styling

    private var cardBackground: some View {
        let colors: [Color] = switch asset.category {
        case .quickUnwind:
            [
                Color(red: 23 / 255, green: 69 / 255, blue: 112 / 255),
                Color(red: 13 / 255, green: 45 / 255, blue: 76 / 255),
            ]
        case .slowUnwind:
            [
                Color(red: 39 / 255, green: 32 / 255, blue: 82 / 255),
                Color(red: 26 / 255, green: 20 / 255, blue: 56 / 255),
            ]
        case .secondSleep:
            [
                Color(red: 31 / 255, green: 45 / 255, blue: 90 / 255),
                Color(red: 20 / 255, green: 28 / 255, blue: 58 / 255),
            ]
        default:
            [
                Color(red: 28 / 255, green: 36 / 255, blue: 64 / 255),
                Color(red: 18 / 255, green: 24 / 255, blue: 44 / 255),
            ]
        }

        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var durationText: String {
        switch asset.category {
        case .quickUnwind:
            "10 – 20 min"
        case .slowUnwind:
            "1 - 2 hours"
        case .secondSleep:
            "5 – 10 min"
        default:
            asset.durationText
        }
    }

    // MARK: - Download or Offline Badge

    @ViewBuilder
    private var downloadOrOfflineBadge: some View {
        if isDownloading {
            ProgressView(value: model.progress(for: asset))
                .progressViewStyle(.circular)
                .tint(.white)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .accessibilityLabel("Downloading \(Int(model.progress(for: asset) * 100))%")
                .accessibilityIdentifier("catalogAudio.progress.\(asset.category.rawValue)")
        } else if isDownloaded {
            if asset.delivery == .downloadable {
                Menu {
                    Button(role: .destructive) {
                        Task { await model.removeDownload(asset) }
                    } label: {
                        Label("Remove offline download", systemImage: "trash")
                    }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 44, height: 44)

                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .accessibilityLabel("Available offline")
                .accessibilityIdentifier("catalogAudio.remove.\(asset.category.rawValue)")
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 44, height: 44)

                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("Available offline")
            }
        } else if state == .downloadFailed {
            Button {
                Task { await model.download(asset) }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.red.opacity(0.25))
                        .frame(width: 44, height: 44)

                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Download for offline")
        } else {
            // Streamable: show download button
            Button {
                Task { await model.download(asset) }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 44, height: 44)

                    Image(systemName: "arrow.down")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Download for offline")
            .accessibilityIdentifier("catalogAudio.download.\(asset.category.rawValue)")
        }
    }

    // MARK: - Play / Pause Button

    private var playPauseButton: some View {
        Button {
            Task { await model.togglePlayback(asset) }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 44, height: 44)

                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(x: isPlaying ? 0 : 1.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlaying ? "Pause preview" : "Play preview")
        .accessibilityIdentifier(
            isPlaying
                ? "catalogAudio.pause.\(asset.category.rawValue)"
                : "catalogAudio.play.\(asset.category.rawValue)"
        )
    }

    // MARK: - Accessible UI Test Strings

    private var accessibleTestStatus: some View {
        VStack {
            if isPlaying {
                Text("Playing preview")
                    .font(.caption2)
                    .foregroundStyle(.clear)
                    .frame(height: 0)
            }
            if isPaused {
                Text("Preview paused")
                    .font(.caption2)
                    .foregroundStyle(.clear)
                    .frame(height: 0)
            }
            if isDownloaded {
                Text("Available offline")
                    .font(.caption2)
                    .foregroundStyle(.clear)
                    .frame(height: 0)
            }
            if !isDownloaded, !model.networkAvailable {
                Text("Unavailable offline")
                    .font(.caption2)
                    .foregroundStyle(.clear)
                    .frame(height: 0)
            }
            if state == .downloadFailed {
                Text("Download failed")
                    .font(.caption2)
                    .foregroundStyle(.clear)
                    .frame(height: 0)
            }
            if !isDownloaded, model.networkAvailable {
                Text("Stream preview available")
                    .font(.caption2)
                    .foregroundStyle(.clear)
                    .frame(height: 0)
            }
            if isSelectedAlarm {
                Text("Selected for alarm")
                    .font(.caption2)
                    .foregroundStyle(.clear)
                    .frame(height: 0)
            }
            if isDownloaded, asset.delivery == .downloadable {
                Button("Remove offline download") {
                    Task { await model.removeDownload(asset) }
                }
                .font(.caption2)
                .foregroundStyle(.clear)
                .frame(height: 0)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var state: AudioCacheState {
        model.cacheState(for: asset)
    }

    private var isDownloading: Bool {
        state == .downloading
    }

    private var isDownloaded: Bool {
        state == .availableOffline || state == .verified
    }

    private var isPlaying: Bool {
        model.isPlaying(asset)
    }

    private var isPaused: Bool {
        model.isPaused(asset)
    }

    private var isSelectedAlarm: Bool {
        model.selectedAlarmAssetID == asset.id
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
        let totalSeconds = max(0, durationMilliseconds / 1000)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
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
                let itemState: AudioCacheState = (scenario == "offline" && asset.delivery == .downloadable)
                    ? .notAvailable
                    : state
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
            if uiTestScenario == "download-progress" {
                return
            }
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

        func previewURL(for _: CatalogAudioAsset) async throws -> URL {
            URL(fileURLWithPath: "/dev/null")
        }

        func playbackURL(for asset: CatalogAudioAsset, networkAvailable: Bool) async throws -> URL {
            if scenario == "offline", !networkAvailable, asset.delivery == .downloadable {
                throw CatalogAudioBoundaryError.offline
            }
            return URL(fileURLWithPath: "/dev/null")
        }

        func download(
            _: CatalogAudioAsset,
            progress _: @escaping @Sendable (CatalogAudioDownloadProgress) async -> Void
        ) async throws -> URL {
            throw CatalogAudioBoundaryError.offline
        }

        func deleteCachedAudio(_: CatalogAudioAsset) async throws {}

        func preflightAlarm(_: CatalogAudioAsset) async throws -> URL {
            guard scenario == "selected-alarm" else { throw CatalogAudioBoundaryError.alarmAssetNotLocal }
            return URL(fileURLWithPath: "/dev/null")
        }
    }

    private nonisolated enum CatalogAudioLibraryUITestFixture {
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
                durationMilliseconds: category == .notification ? 2000 : 60000,
                byteCount: 1_000_000,
                mimeType: delivery == .bundled ? "audio/x-caf" : "audio/mp4",
                codec: delivery == .bundled ? "pcm_s16be" : "aac-lc",
                sampleRateHz: 48000,
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
