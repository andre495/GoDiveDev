import AVFoundation
import SwiftUI

/// Friend profile hero — remote image or looping muted video from Firebase Storage.
struct FriendProfileRemoteHeroView: View {
    let heroURL: URL?
    let mediaKind: GoDiveProfileHeroMediaKind?
    var shouldAutoPlayVideo: Bool = false

    var body: some View {
        Group {
            if let heroURL, let mediaKind {
                switch mediaKind {
                case .image:
                    remoteImage(url: heroURL)
                case .video:
                    FriendProfileLoopingRemoteVideoView(
                        url: heroURL,
                        isPlaybackActive: shouldAutoPlayVideo
                    )
                }
            } else {
                emptyPlaceholder
            }
        }
        // `scaledToFill` / `AVPlayerLayer` paint past the proposed frame — match Buddy Feed /
        // equipment heroes so remote profile media cannot blow out the blue-sheet seam.
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .compositingGroup()
        .modifier(
            FriendProfileHeroClipModifier(enabled: FriendProfilePresentation.clipsOverflowingHeroMedia)
        )
    }

    @ViewBuilder
    private func remoteImage(url: URL) -> some View {
        GeometryReader { proxy in
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                case .failure:
                    emptyPlaceholder
                default:
                    GoDiveRotateLoadingIndicator()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(AppTheme.Colors.surfaceMuted.opacity(0.35))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private var emptyPlaceholder: some View {
        ZStack {
            AppTheme.Colors.surfaceMuted.opacity(0.35)
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.Colors.secondaryText.opacity(0.55))
        }
    }
}

private struct FriendProfileHeroClipModifier: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.clipped()
        } else {
            content
        }
    }
}

private struct FriendProfileLoopingRemoteVideoView: View {
    let url: URL
    let isPlaybackActive: Bool

    @State private var player: AVPlayer?

    var body: some View {
        FriendProfileRemoteVideoLayer(player: player)
            .onAppear {
                configurePlayerIfNeeded()
                updatePlayback()
            }
            .onDisappear {
                player?.pause()
            }
            .onChange(of: isPlaybackActive) { _, _ in
                updatePlayback()
            }
    }

    private func configurePlayerIfNeeded() {
        guard player == nil else { return }
        DiveMutedVideoAudioSession.activateForMutedPlayback()
        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.isMuted = true
        newPlayer.actionAtItemEnd = .none
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            newPlayer.seek(to: .zero)
            if isPlaybackActive {
                newPlayer.play()
            }
        }
        player = newPlayer
    }

    private func updatePlayback() {
        guard let player else { return }
        if isPlaybackActive {
            player.play()
        } else {
            player.pause()
        }
    }
}

private struct FriendProfileRemoteVideoLayer: UIViewRepresentable {
    let player: AVPlayer?

    func makeUIView(context: Context) -> FriendProfileRemoteVideoUIView {
        FriendProfileRemoteVideoUIView()
    }

    func updateUIView(_ uiView: FriendProfileRemoteVideoUIView, context: Context) {
        uiView.player = player
    }
}

private final class FriendProfileRemoteVideoUIView: UIView {
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

    var player: AVPlayer? {
        didSet {
            playerLayer.player = player
            playerLayer.videoGravity = .resizeAspectFill
        }
    }
}
