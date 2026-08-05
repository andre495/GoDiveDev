import AVFoundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Friend-shared video hero — poster thumb + streaming **`AVPlayer`** on **`contentURL`**.
struct FriendSharedRemoteVideoPlayerView: View {
    let item: FriendSharedMediaPresentation.DisplayItem
    var isPlaybackActive: Bool = true
    var loopsPlayback: Bool = true
    /// Buddy Feed / hero tiles — start sooner with a smaller buffer (may rebuffer on slow networks).
    var prefersFastPlaybackStart: Bool = false
    /// Poster aspect for Media hero detent scaling (same path as stills).
    var onDisplayedImageAspectChange: ((CGFloat) -> Void)? = nil

    #if canImport(UIKit)
    @State private var player: AVPlayer?
    @State private var endObserver: NSObjectProtocol?
    #endif

    var body: some View {
        #if canImport(UIKit)
        ZStack {
            FriendSharedMediaImageView(
                item: item,
                fidelity: .thumbnailOnly,
                showsVideoBadge: player == nil,
                onDisplayedImageAspectChange: onDisplayedImageAspectChange
            )

            if let player {
                FriendSharedFillVideoPlayerRepresentable(
                    player: player,
                    isPlaybackActive: isPlaybackActive
                )
            }
        }
        .task(id: playbackTaskID) {
            await configurePlayer()
        }
        .onChange(of: isPlaybackActive) { _, isActive in
            guard let player else { return }
            if isActive {
                player.play()
            } else {
                player.pause()
            }
        }
        .onDisappear {
            tearDownPlayer()
        }
        #else
        FriendSharedMediaImageView(item: item, fidelity: .thumbnailOnly)
        #endif
    }

    #if canImport(UIKit)
    private var playbackTaskID: String {
        "\(item.mediaID)|\(loopsPlayback)|\(prefersFastPlaybackStart)"
    }

    @MainActor
    private func configurePlayer() async {
        tearDownPlayer()
        guard item.kind == .video else { return }

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
        if isPlaybackActive {
            avPlayer.play()
        }
        if let currentItem = avPlayer.currentItem {
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: currentItem,
                queue: .main
            ) { [weak avPlayer] _ in
                guard let avPlayer else { return }
                if loopsPlayback {
                    avPlayer.seek(to: .zero)
                    if isPlaybackActive {
                        avPlayer.play()
                    }
                } else {
                    avPlayer.pause()
                }
            }
        }
    }

    private func tearDownPlayer() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        player?.pause()
        player = nil
    }
    #endif
}

#if canImport(UIKit)
private struct FriendSharedFillVideoPlayerRepresentable: UIViewRepresentable {
    let player: AVPlayer
    let isPlaybackActive: Bool

    func makeUIView(context: Context) -> FriendSharedFillVideoPlayerUIView {
        let view = FriendSharedFillVideoPlayerUIView()
        view.configure(player: player, isPlaybackActive: isPlaybackActive)
        return view
    }

    func updateUIView(_ uiView: FriendSharedFillVideoPlayerUIView, context: Context) {
        uiView.configure(player: player, isPlaybackActive: isPlaybackActive)
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

    func configure(player: AVPlayer, isPlaybackActive: Bool) {
        playerLayer.player = player
        if isPlaybackActive {
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
