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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    @ViewBuilder
    private func remoteImage(url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                emptyPlaceholder
            default:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.Colors.surfaceMuted.opacity(0.35))
            }
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

    var player: AVPlayer? {
        didSet {
            playerLayer.player = player
            playerLayer.videoGravity = .resizeAspectFill
        }
    }
}
