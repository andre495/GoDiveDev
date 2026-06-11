import AVFoundation
import SwiftUI
#if canImport(Photos)
import Photos
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Full-bleed dive video (**`resizeAspectFill`**, same crop behavior as photos).
///
/// **`source`** is either a copied app file or a Photos-library pointer (**`DiveVideoSource`**); a library asset is
/// resolved to an **`AVPlayerItem`** on demand via **`DiveMediaReferenceLoader`** (no exported file). A missing /
/// offline / deleted asset shows the **`missingPlaceholder`**.
///
/// With **`usesProgressiveFidelity`**, library videos show a poster frame, then preview playback, then silently
/// upgrade to full quality while preserving playback time.
struct DiveActivityVideoPlayerView: View {
    let source: DiveVideoSource?
    var isPlaybackActive: Bool = true
    var loopsPlayback: Bool = false
    /// PhotoKit delivery tier for **`.libraryAsset`** sources (overview heroes use **`.homeCarousel`**; default **`.fullQuality`** for specialized flows).
    var libraryVideoQuality: DiveMediaVideoRequestQuality = .fullQuality
    /// Poster → preview → full stream for dive overview library videos.
    var usesProgressiveFidelity: Bool = false
    /// Screen pixel width for poster sizing when **`usesProgressiveFidelity`** is **`true`**.
    var screenPixelWidth: CGFloat = 0
    /// Parent-supplied poster (e.g. dive hero) shown immediately while preview video resolves.
    var initialPosterImage: UIImage? = nil
    var isPausedByUserHold: Bool = false
    /// Called once when playback reaches the end and **`loopsPlayback`** is **`false`**.
    var onPlaybackFinished: (() -> Void)?
    /// Called when a referenced Photos asset can't be resolved (e.g. deleted) so the owner can prune the row.
    var onAssetMissing: (() -> Void)?

    #if canImport(UIKit)
    @State private var playerItem: AVPlayerItem?
    @State private var resolvedKey: String?
    @State private var posterImage: UIImage?
    @State private var videoFidelity: DiveMediaVideoFidelity = .none
    @State private var isResolving = false
    @State private var isPlayerDisplayReady = false
    @State private var loadFailed = false
    @State private var showsOfflineUnavailable = false
    @State private var reloadToken = 0
    @State private var fullUpgradeTask: Task<Void, Never>?
    #endif

    var body: some View {
        Group {
            #if canImport(UIKit)
            ZStack {
                if let displayedPoster {
                    GeometryReader { geometry in
                        Image(uiImage: displayedPoster)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    }
                } else if source != nil, isResolving, !usesProgressiveFidelity {
                    loadingPlaceholder
                } else if source != nil, isResolving, usesProgressiveFidelity {
                    subtleLoadingPlaceholder
                }

                if let playerItem, let resolvedKey {
                    GeometryReader { geometry in
                        DiveActivityFillVideoPlayerRepresentable(
                            playerItem: playerItem,
                            identityKey: resolvedKey,
                            isPlaybackActive: isPlaybackActive,
                            loopsPlayback: loopsPlayback,
                            isPausedByUserHold: isPausedByUserHold,
                            onPlaybackFinished: loopsPlayback ? nil : onPlaybackFinished,
                            onDisplayReady: {
                                isPlayerDisplayReady = true
                            }
                        )
                        .opacity(isPlayerDisplayReady ? 1 : 0)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                    }
                    .accessibilityLabel("Dive video")
                } else if showsOfflineUnavailable {
                    offlineUnavailablePlaceholder
                } else if loadFailed {
                    errorRetryPlaceholder
                } else if displayedPoster == nil, !isResolving, source == nil {
                    missingPlaceholder
                } else if displayedPoster == nil, !isResolving, playerItem == nil, !loadFailed {
                    missingPlaceholder
                }
            }
            #else
            missingPlaceholder
            #endif
        }
        #if canImport(UIKit)
        .task(id: videoLoadTaskID) {
            await resolveSourceIfNeeded()
        }
        .onChange(of: isPlaybackActive) { _, isActive in
            if isActive {
                if playerItem != nil {
                    isPlayerDisplayReady = true
                }
                scheduleFullQualityUpgradeIfNeeded()
            } else {
                cancelFullQualityUpgrade()
            }
        }
        .onChange(of: isPausedByUserHold) { _, _ in
            scheduleFullQualityUpgradeIfNeeded()
        }
        .onDisappear {
            cancelFullQualityUpgrade()
        }
        #endif
    }

    #if canImport(UIKit)
    private var videoLoadTaskID: String {
        "\(source?.identityKey ?? "nil")#\(reloadToken)#\(usesProgressiveFidelity)"
    }

    private var displayedPoster: UIImage? {
        posterImage ?? initialPosterImage
    }

    private func resolveSourceIfNeeded() async {
        cancelFullQualityUpgrade()

        guard let source else {
            resetPlaybackState()
            return
        }

        if usesProgressiveFidelity, case .libraryAsset = source {
            await resolveProgressiveLibraryVideo(source: source)
            return
        }

        if resolvedKey == source.identityKey, playerItem != nil {
            isPlayerDisplayReady = true
            return
        }

        isPlayerDisplayReady = false

        isResolving = true
        loadFailed = false
        showsOfflineUnavailable = false
        posterImage = nil
        videoFidelity = .none
        let resolved = await resolvedItem(for: source, quality: libraryVideoQuality)
        guard source.identityKey == self.source?.identityKey else { return }
        isResolving = false

        if let resolved {
            playerItem = resolved
            resolvedKey = source.identityKey
            loadFailed = false
            return
        }

        playerItem = nil
        resolvedKey = nil
        classifyLoadFailure(for: source)
    }

    private func resolveProgressiveLibraryVideo(source: DiveVideoSource) async {
        guard case .libraryAsset(let identifier) = source else { return }
        if resolvedKey?.hasPrefix(source.identityKey) == true, playerItem != nil {
            isPlayerDisplayReady = true
            scheduleFullQualityUpgradeIfNeeded()
            return
        }

        isResolving = true
        loadFailed = false
        showsOfflineUnavailable = false
        posterImage = initialPosterImage
        videoFidelity = .none
        isPlayerDisplayReady = false

        let posterSize = DiveMediaProgressivePresentation.posterTargetSize(
            screenPixelWidth: max(screenPixelWidth, 1)
        )

        async let posterTask: UIImage? = {
            #if canImport(Photos)
            return await DiveMediaReferenceLoader.image(
                localIdentifier: identifier,
                targetSize: posterSize,
                deliveryMode: .opportunistic
            )
            #else
            return nil
            #endif
        }()

        let previewItem = await resolvedItem(
            for: source,
            quality: DiveActivityMediaPresentation.overviewLibraryVideoQuality
        )

        guard source.identityKey == self.source?.identityKey else { return }

        if let loadedPoster = await posterTask {
            posterImage = loadedPoster
        }
        isResolving = false

        if let previewItem {
            playerItem = previewItem
            resolvedKey = "\(source.identityKey)|preview"
            videoFidelity = .preview
            loadFailed = false
            scheduleFullQualityUpgradeIfNeeded()
            return
        }

        playerItem = nil
        resolvedKey = nil
        classifyLoadFailure(for: source)
    }

    private func scheduleFullQualityUpgradeIfNeeded() {
        guard usesProgressiveFidelity,
              case .libraryAsset(let identifier) = source,
              let baseKey = source?.identityKey,
              DiveMediaProgressivePresentation.shouldUpgradeToFullVideo(
                  isPlaybackActive: isPlaybackActive,
                  isPausedByUserHold: isPausedByUserHold,
                  currentFidelity: videoFidelity,
                  isNetworkAvailable: AppNetworkConnectivitySnapshot.shared.allowsCloudMediaFetch
              ) else {
            return
        }
        guard fullUpgradeTask == nil else { return }

        fullUpgradeTask = Task {
            defer {
                Task { @MainActor in
                    fullUpgradeTask = nil
                }
            }
            let fullItem = await DiveMediaReferenceLoader.playerItem(
                localIdentifier: identifier,
                quality: .fullQuality
            )
            guard !Task.isCancelled,
                  baseKey == self.source?.identityKey,
                  let fullItem else { return }

            playerItem = fullItem
            resolvedKey = "\(baseKey)|full"
            videoFidelity = .full
        }
    }

    private func cancelFullQualityUpgrade() {
        fullUpgradeTask?.cancel()
        fullUpgradeTask = nil
    }

    private func resolvedItem(
        for source: DiveVideoSource,
        quality: DiveMediaVideoRequestQuality
    ) async -> AVPlayerItem? {
        switch source {
        case .file(let url):
            return AVPlayerItem(url: url)
        case .libraryAsset(let identifier):
            #if canImport(Photos)
            return await DiveMediaReferenceLoader.playerItem(
                localIdentifier: identifier,
                quality: quality
            )
            #else
            return nil
            #endif
        }
    }

    private func classifyLoadFailure(for source: DiveVideoSource) {
        switch DiveMediaVideoLoad.classify(
            itemResolved: false,
            isLibraryAsset: source.isLibraryAsset,
            assetStillExists: assetStillExists(for: source),
            isNetworkAvailable: AppNetworkConnectivitySnapshot.shared.allowsCloudMediaFetch
        ) {
        case .loaded:
            break
        case .assetMissing:
            loadFailed = false
            showsOfflineUnavailable = false
            onAssetMissing?()
        case .retryable:
            showsOfflineUnavailable = false
            loadFailed = true
        case .offlineUnavailable:
            loadFailed = false
            showsOfflineUnavailable = displayedPoster == nil
        }
    }

    private func resetPlaybackState() {
        playerItem = nil
        resolvedKey = nil
        posterImage = nil
        videoFidelity = .none
        isResolving = false
        loadFailed = false
        showsOfflineUnavailable = false
        isPlayerDisplayReady = false
    }

    private func assetStillExists(for source: DiveVideoSource) -> Bool {
        switch source {
        case .file:
            return true
        case .libraryAsset(let identifier):
            #if canImport(Photos)
            return DiveMediaReferenceLoader.assetExists(localIdentifier: identifier)
            #else
            return false
            #endif
        }
    }

    private func retryLoading() {
        loadFailed = false
        isResolving = true
        reloadToken += 1
    }

    private var loadingPlaceholder: some View {
        ZStack {
            AppTheme.Colors.surfaceMuted.opacity(0.5)
            ProgressView()
        }
    }

    private var subtleLoadingPlaceholder: some View {
        Color.clear
    }

    private var offlineUnavailablePlaceholder: some View {
        ZStack {
            AppTheme.Colors.surfaceMuted.opacity(0.5)
            OfflineMediaUnavailableIndicator()
        }
    }

    private var errorRetryPlaceholder: some View {
        ZStack {
            AppTheme.Colors.surfaceMuted.opacity(0.5)
            VStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title)
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
                Text("Couldn't load video")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text("It may still be downloading from iCloud.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                Button(action: retryLoading) {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.vertical, AppTheme.Spacing.sm)
                        .background { Capsule().fill(AppTheme.Colors.accent) }
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
                .accessibilityIdentifier("DiveActivity.Video.Retry")
            }
            .padding(AppTheme.Spacing.lg)
        }
    }
    #endif

    private var missingPlaceholder: some View {
        ZStack {
            AppTheme.Colors.surfaceMuted.opacity(0.5)
            Image(systemName: "video.slash")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.Colors.tabUnselected)
        }
    }
}

#if canImport(UIKit)
/// **`AVPlayerLayer`** with **`videoGravity = .resizeAspectFill`** (no letterboxing).
private struct DiveActivityFillVideoPlayerRepresentable: UIViewRepresentable {
    let playerItem: AVPlayerItem
    let identityKey: String
    let isPlaybackActive: Bool
    let loopsPlayback: Bool
    let isPausedByUserHold: Bool
    let onPlaybackFinished: (() -> Void)?
    let onDisplayReady: (() -> Void)?

    func makeUIView(context: Context) -> DiveActivityFillVideoPlayerUIView {
        let view = DiveActivityFillVideoPlayerUIView()
        view.onDisplayReady = onDisplayReady
        view.configure(
            playerItem: playerItem,
            identityKey: identityKey,
            isPlaybackActive: isPlaybackActive,
            loopsPlayback: loopsPlayback,
            isPausedByUserHold: isPausedByUserHold,
            onPlaybackFinished: onPlaybackFinished
        )
        return view
    }

    func updateUIView(_ uiView: DiveActivityFillVideoPlayerUIView, context: Context) {
        uiView.onDisplayReady = onDisplayReady
        uiView.configure(
            playerItem: playerItem,
            identityKey: identityKey,
            isPlaybackActive: isPlaybackActive,
            loopsPlayback: loopsPlayback,
            isPausedByUserHold: isPausedByUserHold,
            onPlaybackFinished: onPlaybackFinished
        )
    }

    static func dismantleUIView(_ uiView: DiveActivityFillVideoPlayerUIView, coordinator: ()) {
        uiView.stop()
    }
}

private final class DiveActivityFillVideoPlayerUIView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    private var player: AVPlayer?
    private var currentKey: String?
    private var loopsPlayback = false
    private var isPlaybackActive = false
    private var isPausedByUserHold = false
    private var lastAppliedPlaybackActive = false
    private var endObserver: NSObjectProtocol?
    private var onPlaybackFinished: (() -> Void)?
    var onDisplayReady: (() -> Void)?
    private var displayReadyObservation: NSKeyValueObservation?

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        playerLayer.videoGravity = .resizeAspectFill
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        removeEndObserver()
        displayReadyObservation?.invalidate()
    }

    func configure(
        playerItem: AVPlayerItem,
        identityKey: String,
        isPlaybackActive: Bool,
        loopsPlayback: Bool,
        isPausedByUserHold: Bool,
        onPlaybackFinished: (() -> Void)?
    ) {
        self.isPlaybackActive = isPlaybackActive
        self.isPausedByUserHold = isPausedByUserHold
        self.loopsPlayback = loopsPlayback
        self.onPlaybackFinished = onPlaybackFinished

        let isQualityUpgrade = currentKey?.hasSuffix("|preview") == true
            && identityKey.hasSuffix("|full")
        if isQualityUpgrade, player != nil {
            upgradePlayerItem(playerItem, identityKey: identityKey)
            lastAppliedPlaybackActive = isPlaybackActive
            return
        }

        let mediaChanged = currentKey != identityKey
        let shouldRestart = DiveActivityVideoPlaybackPolicy.shouldRestartFromBeginning(
            wasPlaybackActive: lastAppliedPlaybackActive,
            isPlaybackActive: isPlaybackActive,
            mediaURLChanged: mediaChanged
        )

        if mediaChanged {
            loadPlayer(playerItem: playerItem, identityKey: identityKey)
        }
        syncPlaybackEndObserver()

        if shouldRestart {
            restartFromBeginning()
        } else {
            syncPlaybackState()
        }

        lastAppliedPlaybackActive = isPlaybackActive
    }

    func stop() {
        removeEndObserver()
        displayReadyObservation?.invalidate()
        displayReadyObservation = nil
        player?.pause()
        player = nil
        playerLayer.player = nil
        currentKey = nil
        loopsPlayback = false
        isPlaybackActive = false
        isPausedByUserHold = false
        lastAppliedPlaybackActive = false
    }

    private func loadPlayer(playerItem: AVPlayerItem, identityKey: String) {
        removeEndObserver()
        displayReadyObservation?.invalidate()
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        playerLayer.player = nil
        player = nil
        currentKey = identityKey
        DiveMutedVideoAudioSession.activateForMutedPlayback()
        let playbackItem = AVPlayerItem(asset: playerItem.asset)
        let newPlayer = AVPlayer(playerItem: playbackItem)
        newPlayer.isMuted = true
        player = newPlayer
        playerLayer.player = newPlayer
        observeDisplayReady()
        syncPlaybackEndObserver()
    }

    private func upgradePlayerItem(_ playerItem: AVPlayerItem, identityKey: String) {
        guard let player else { return }
        let preservedTime = player.currentTime()
        let shouldResume = DiveActivityVideoPlaybackPolicy.shouldPlay(
            isPlaybackActive: isPlaybackActive,
            isPausedByUserHold: isPausedByUserHold
        )
        removeEndObserver()
        let playbackItem = AVPlayerItem(asset: playerItem.asset)
        player.replaceCurrentItem(with: playbackItem)
        currentKey = identityKey
        observeDisplayReady()
        syncPlaybackEndObserver()
        player.seek(to: preservedTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            guard let self else { return }
            if shouldResume {
                self.player?.play()
            } else {
                self.player?.pause()
            }
        }
    }

    private func observeDisplayReady() {
        displayReadyObservation?.invalidate()
        if playerLayer.isReadyForDisplay {
            onDisplayReady?()
        }
        displayReadyObservation = playerLayer.observe(\.isReadyForDisplay, options: [.new]) { [weak self] layer, _ in
            guard layer.isReadyForDisplay else { return }
            DispatchQueue.main.async {
                self?.onDisplayReady?()
            }
        }
    }

    private func syncPlaybackEndObserver() {
        removeEndObserver()
        guard loopsPlayback || onPlaybackFinished != nil,
              let item = player?.currentItem else { return }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            if self.loopsPlayback, let player = self.player {
                player.seek(to: .zero) { [weak self] _ in
                    guard let self, DiveActivityVideoPlaybackPolicy.shouldPlay(
                        isPlaybackActive: self.isPlaybackActive,
                        isPausedByUserHold: self.isPausedByUserHold
                    ) else { return }
                    player.play()
                }
            } else {
                self.onPlaybackFinished?()
            }
        }
    }

    private func restartFromBeginning() {
        guard player != nil else { return }
        player?.seek(to: .zero) { [weak self] _ in
            self?.syncPlaybackState()
        }
    }

    private func syncPlaybackState() {
        guard player != nil else { return }
        if DiveActivityVideoPlaybackPolicy.shouldPlay(
            isPlaybackActive: isPlaybackActive,
            isPausedByUserHold: isPausedByUserHold
        ) {
            player?.play()
        } else {
            player?.pause()
        }
    }

    private func removeEndObserver() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }
}
#endif
