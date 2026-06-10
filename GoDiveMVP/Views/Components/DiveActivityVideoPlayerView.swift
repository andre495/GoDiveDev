import AVFoundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Full-bleed dive video (**`resizeAspectFill`**, same crop behavior as photos).
///
/// **`source`** is either a copied app file or a Photos-library pointer (**`DiveVideoSource`**); a library asset is
/// resolved to an **`AVPlayerItem`** on demand via **`DiveMediaReferenceLoader`** (no exported file). A missing /
/// offline / deleted asset shows the **`missingPlaceholder`**.
struct DiveActivityVideoPlayerView: View {
    let source: DiveVideoSource?
    var isPlaybackActive: Bool = true
    var loopsPlayback: Bool = false
    /// PhotoKit delivery tier for **`.libraryAsset`** sources (overview heroes use **`.homeCarousel`**; default **`.fullQuality`** for specialized flows).
    var libraryVideoQuality: DiveMediaVideoRequestQuality = .fullQuality
    var isPausedByUserHold: Bool = false
    /// Called once when playback reaches the end and **`loopsPlayback`** is **`false`**.
    var onPlaybackFinished: (() -> Void)?
    /// Called when a referenced Photos asset can't be resolved (e.g. deleted) so the owner can prune the row.
    var onAssetMissing: (() -> Void)?

    #if canImport(UIKit)
    @State private var playerItem: AVPlayerItem?
    @State private var resolvedKey: String?
    @State private var isResolving = false
    /// Transient load failure / timeout (asset still present) — show an error with a retry button.
    @State private var loadFailed = false
    /// Bumped by **Retry** to re-run the load **`.task`** without the source changing.
    @State private var reloadToken = 0
    #endif

    var body: some View {
        Group {
            #if canImport(UIKit)
            if let playerItem, let resolvedKey {
                GeometryReader { geometry in
                    DiveActivityFillVideoPlayerRepresentable(
                        playerItem: playerItem,
                        identityKey: resolvedKey,
                        isPlaybackActive: isPlaybackActive,
                        loopsPlayback: loopsPlayback,
                        isPausedByUserHold: isPausedByUserHold,
                        onPlaybackFinished: loopsPlayback ? nil : onPlaybackFinished
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                }
                .accessibilityLabel("Dive video")
            } else if source != nil, isResolving {
                loadingPlaceholder
            } else if loadFailed {
                errorRetryPlaceholder
            } else {
                missingPlaceholder
            }
            #else
            missingPlaceholder
            #endif
        }
        #if canImport(UIKit)
        .task(id: videoLoadTaskID) {
            await resolveSourceIfNeeded()
        }
        #endif
    }

    #if canImport(UIKit)
    /// Re-runs the load **`.task`** when the source changes **or** the user taps **Retry**.
    private var videoLoadTaskID: String {
        "\(source?.identityKey ?? "nil")#\(reloadToken)"
    }

    private func resolveSourceIfNeeded() async {
        guard let source else {
            playerItem = nil
            resolvedKey = nil
            isResolving = false
            loadFailed = false
            return
        }
        if resolvedKey == source.identityKey, playerItem != nil { return }

        isResolving = true
        loadFailed = false
        let resolved = await resolvedItem(for: source)
        // Source may have changed while awaiting; only apply the latest.
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
        switch DiveMediaVideoLoad.classify(
            itemResolved: false,
            isLibraryAsset: source.isLibraryAsset,
            assetStillExists: assetStillExists(for: source)
        ) {
        case .loaded:
            break
        case .assetMissing:
            loadFailed = false
            onAssetMissing?()
        case .retryable:
            loadFailed = true
        }
    }

    private func resolvedItem(for source: DiveVideoSource) async -> AVPlayerItem? {
        switch source {
        case .file(let url):
            return AVPlayerItem(url: url)
        case .libraryAsset(let identifier):
            #if canImport(Photos)
            return await DiveMediaReferenceLoader.playerItem(
                localIdentifier: identifier,
                quality: libraryVideoQuality
            )
            #else
            return nil
            #endif
        }
    }

    /// **`true`** when a library asset is still reachable (distinguishes a deleted original from a transient timeout).
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

    func makeUIView(context: Context) -> DiveActivityFillVideoPlayerUIView {
        let view = DiveActivityFillVideoPlayerUIView()
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
    }

    func configure(
        playerItem: AVPlayerItem,
        identityKey: String,
        isPlaybackActive: Bool,
        loopsPlayback: Bool,
        isPausedByUserHold: Bool,
        onPlaybackFinished: (() -> Void)?
    ) {
        let mediaChanged = currentKey != identityKey
        let shouldRestart = DiveActivityVideoPlaybackPolicy.shouldRestartFromBeginning(
            wasPlaybackActive: lastAppliedPlaybackActive,
            isPlaybackActive: isPlaybackActive,
            mediaURLChanged: mediaChanged
        )

        self.isPlaybackActive = isPlaybackActive
        self.isPausedByUserHold = isPausedByUserHold
        self.loopsPlayback = loopsPlayback
        self.onPlaybackFinished = onPlaybackFinished

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
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        playerLayer.player = nil
        player = nil
        currentKey = identityKey
        DiveMutedVideoAudioSession.activateForMutedPlayback()
        // Always attach a fresh item — a cached **`AVPlayerItem`** must not move between **`AVPlayer`**s.
        let playbackItem = AVPlayerItem(asset: playerItem.asset)
        let newPlayer = AVPlayer(playerItem: playbackItem)
        newPlayer.isMuted = true
        player = newPlayer
        playerLayer.player = newPlayer
        syncPlaybackEndObserver()
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
