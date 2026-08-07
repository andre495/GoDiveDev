import AVFoundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Friend-shared video — poster thumb + streaming **`AVPlayer`** on **`contentURL`**.
///
/// Fullscreen pause / mount contract mirrors **`DiveActivityMediaItemView`** +
/// **`DiveActivityVideoPlayerView`** used by **`LinkedMediaFullscreenView`**:
/// settle delay before mount, unmount when inactive, hold-pause without tearing down.
struct FriendSharedRemoteVideoPlayerView: View {
    let item: FriendSharedMediaPresentation.DisplayItem
    var isPlaybackActive: Bool = true
    /// Center play/pause — keeps the player mounted while pausing in place (Linked fullscreen parity).
    var isPausedByUserHold: Bool = false
    var loopsPlayback: Bool = true
    /// Buddy Feed / hero tiles — start sooner with a smaller buffer (may rebuffer on slow networks).
    var prefersFastPlaybackStart: Bool = false
    /// When true (fullscreen), wait **`videoPlayerMountSettleDelayNanoseconds`** and only mount while active.
    var usesFullscreenMountSettleDelay: Bool = false
    /// Poster aspect for Media hero detent scaling (same path as stills).
    var onDisplayedImageAspectChange: ((CGFloat) -> Void)? = nil

    #if canImport(UIKit)
    @State private var player: AVPlayer?
    @State private var endObserver: NSObjectProtocol?
    @State private var lastAppliedPlaybackActive = false
    @State private var hasCompletedMountSettleDelay = false
    @State private var mountSettleTask: Task<Void, Never>?
    @State private var playbackFlags = FriendSharedRemoteVideoPlaybackFlags()
    #endif

    private var shouldPlay: Bool {
        DiveActivityVideoPlaybackPolicy.shouldPlay(
            isPlaybackActive: isPlaybackActive,
            isPausedByUserHold: isPausedByUserHold
        )
    }

    var body: some View {
        #if canImport(UIKit)
        ZStack {
            FriendSharedMediaImageView(
                item: item,
                fidelity: .thumbnailOnly,
                showsVideoBadge: player == nil,
                onDisplayedImageAspectChange: onDisplayedImageAspectChange
            )

            if let player, shouldDisplayPlayerLayer {
                FriendSharedFillVideoPlayerRepresentable(
                    player: player,
                    shouldPlay: shouldPlay
                )
            }
        }
        .task(id: playbackTaskID) {
            await configurePlayer()
        }
        .onChange(of: isPlaybackActive) { _, isActive in
            playbackFlags.isPlaybackActive = isActive
            if usesFullscreenMountSettleDelay {
                scheduleFullscreenMountSettle(isActive: isActive)
            } else {
                applyPlaybackState(isActive: isActive)
            }
        }
        .onChange(of: isPausedByUserHold) { _, isHeld in
            playbackFlags.isPausedByUserHold = isHeld
            syncPlayPause()
        }
        .onChange(of: loopsPlayback) { _, loops in
            playbackFlags.loopsPlayback = loops
        }
        .onChange(of: hasCompletedMountSettleDelay) { _, completed in
            guard usesFullscreenMountSettleDelay, completed, isPlaybackActive else { return }
            Task { await mountPlayerIfNeeded() }
        }
        .onAppear {
            playbackFlags.isPlaybackActive = isPlaybackActive
            playbackFlags.isPausedByUserHold = isPausedByUserHold
            playbackFlags.loopsPlayback = loopsPlayback
            if usesFullscreenMountSettleDelay {
                scheduleFullscreenMountSettle(isActive: isPlaybackActive)
            }
        }
        .onDisappear {
            cancelMountSettle()
            tearDownPlayer()
        }
        #else
        FriendSharedMediaImageView(item: item, fidelity: .thumbnailOnly)
        #endif
    }

    #if canImport(UIKit)
    private var playbackTaskID: String {
        "\(item.mediaID)|\(loopsPlayback)|\(prefersFastPlaybackStart)|\(usesFullscreenMountSettleDelay)"
    }

    private var shouldDisplayPlayerLayer: Bool {
        if usesFullscreenMountSettleDelay {
            return DiveActivityVideoPlaybackPolicy.shouldMountSettledVideoPlayer(
                isVideoPlaybackActive: isPlaybackActive,
                hasCompletedSettleDelay: hasCompletedMountSettleDelay
            )
        }
        return true
    }

    @MainActor
    private func configurePlayer() async {
        tearDownPlayer()
        guard item.kind == .video else { return }

        if usesFullscreenMountSettleDelay {
            scheduleFullscreenMountSettle(isActive: isPlaybackActive)
            return
        }

        await mountPlayerIfNeeded()
    }

    @MainActor
    private func scheduleFullscreenMountSettle(isActive: Bool) {
        mountSettleTask?.cancel()
        mountSettleTask = nil
        guard isActive else {
            hasCompletedMountSettleDelay = false
            tearDownPlayer()
            return
        }
        hasCompletedMountSettleDelay = false
        mountSettleTask = Task { @MainActor in
            try? await Task.sleep(
                nanoseconds: DiveActivityVideoPlaybackPolicy.videoPlayerMountSettleDelayNanoseconds
            )
            guard !Task.isCancelled else { return }
            hasCompletedMountSettleDelay = true
        }
    }

    private func cancelMountSettle() {
        mountSettleTask?.cancel()
        mountSettleTask = nil
        hasCompletedMountSettleDelay = false
    }

    @MainActor
    private func mountPlayerIfNeeded() async {
        guard item.kind == .video else { return }
        if usesFullscreenMountSettleDelay {
            guard shouldDisplayPlayerLayer else { return }
        }
        if player != nil { return }

        let snapshot = AppNetworkConnectivitySnapshot.shared
        let allowsNetwork = AppNetworkConnectivityPresentation.allowsCloudMediaFetch(
            isConnected: snapshot.allowsCloudMediaFetch
        )
        let allowsContent = FriendSharedMediaPresentation.allowsContentDownload(
            isConnected: allowsNetwork,
            usesWiFi: snapshot.usesWiFiInterface,
            wifiOnly: AppUserSettings.downloadFriendMediaOnWiFiOnly(),
            allowsConstrainedNetworkAccess: URLSession.shared.configuration.allowsConstrainedNetworkAccess
        )
        guard allowsContent, item.contentURL != nil else { return }

        let playbackURL = await FriendSharedMediaPresentation.resolvedVideoPlaybackURL(
            for: item.contentURL
        )
        guard let playbackURL else { return }
        if usesFullscreenMountSettleDelay {
            guard shouldDisplayPlayerLayer else { return }
        }

        if playbackURL.isFileURL == false, let contentURL = item.contentURL {
            Task {
                await FriendSharedMediaPresentation.prefetchVideoContentIfNeeded(
                    contentURLString: contentURL,
                    allowsNetworkFetch: allowsContent
                )
            }
        }

        let playerItem = AVPlayerItem(url: playbackURL)
        if prefersFastPlaybackStart {
            playerItem.preferredForwardBufferDuration = 1
        }
        let avPlayer = AVPlayer(playerItem: playerItem)
        avPlayer.isMuted = true
        avPlayer.actionAtItemEnd = .none
        avPlayer.automaticallyWaitsToMinimizeStalling = !prefersFastPlaybackStart
        player = avPlayer
        lastAppliedPlaybackActive = isPlaybackActive
        playbackFlags.isPlaybackActive = isPlaybackActive
        playbackFlags.isPausedByUserHold = isPausedByUserHold
        playbackFlags.loopsPlayback = loopsPlayback
        syncPlayPause()

        let flags = playbackFlags
        if let currentItem = avPlayer.currentItem {
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: currentItem,
                queue: .main
            ) { [weak avPlayer] _ in
                guard let avPlayer else { return }
                if flags.loopsPlayback {
                    avPlayer.seek(to: .zero) { _ in
                        guard DiveActivityVideoPlaybackPolicy.shouldPlay(
                            isPlaybackActive: flags.isPlaybackActive,
                            isPausedByUserHold: flags.isPausedByUserHold
                        ) else { return }
                        avPlayer.play()
                    }
                } else {
                    avPlayer.pause()
                }
            }
        }
    }

    private func applyPlaybackState(isActive: Bool) {
        guard let player else { return }
        if !isActive && lastAppliedPlaybackActive {
            player.pause()
            player.seek(to: .zero)
        }
        lastAppliedPlaybackActive = isActive
        syncPlayPause()
    }

    private func syncPlayPause() {
        guard let player else { return }
        if shouldPlay {
            player.play()
        } else {
            player.pause()
        }
    }

    private func tearDownPlayer() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        player?.pause()
        player = nil
        lastAppliedPlaybackActive = false
    }
    #endif
}

#if canImport(UIKit)
/// Mutable flags for AVPlayer end-observer (avoids stale SwiftUI captures).
private final class FriendSharedRemoteVideoPlaybackFlags: @unchecked Sendable {
    var isPlaybackActive = true
    var isPausedByUserHold = false
    var loopsPlayback = true
}

private struct FriendSharedFillVideoPlayerRepresentable: UIViewRepresentable {
    let player: AVPlayer
    let shouldPlay: Bool

    func makeUIView(context: Context) -> FriendSharedFillVideoPlayerUIView {
        let view = FriendSharedFillVideoPlayerUIView()
        view.configure(player: player, shouldPlay: shouldPlay)
        return view
    }

    func updateUIView(_ uiView: FriendSharedFillVideoPlayerUIView, context: Context) {
        uiView.configure(player: player, shouldPlay: shouldPlay)
    }

    static func dismantleUIView(_ uiView: FriendSharedFillVideoPlayerUIView, coordinator: ()) {
        uiView.stop()
    }
}

private final class FriendSharedFillVideoPlayerUIView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        playerLayer.videoGravity = .resizeAspectFill
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func configure(player: AVPlayer, shouldPlay: Bool) {
        playerLayer.player = player
        if shouldPlay {
            player.play()
        } else {
            player.pause()
        }
    }

    func stop() {
        playerLayer.player?.pause()
        playerLayer.player = nil
    }
}
#endif
