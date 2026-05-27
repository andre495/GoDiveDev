import AVFoundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Full-bleed dive video (**`resizeAspectFill`**, same crop behavior as photos).
struct DiveActivityVideoPlayerView: View {
    let fileURL: URL?
    var isPlaybackActive: Bool = true
    var loopsPlayback: Bool = false
    var isPausedByUserHold: Bool = false

    var body: some View {
        Group {
            #if canImport(UIKit)
            if let fileURL {
                GeometryReader { geometry in
                    DiveActivityFillVideoPlayerRepresentable(
                        fileURL: fileURL,
                        isPlaybackActive: isPlaybackActive,
                        loopsPlayback: loopsPlayback,
                        isPausedByUserHold: isPausedByUserHold
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                }
                .accessibilityLabel("Dive video")
            } else {
                missingPlaceholder
            }
            #else
            missingPlaceholder
            #endif
        }
    }

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
    let fileURL: URL
    let isPlaybackActive: Bool
    let loopsPlayback: Bool
    let isPausedByUserHold: Bool

    func makeUIView(context: Context) -> DiveActivityFillVideoPlayerUIView {
        let view = DiveActivityFillVideoPlayerUIView()
        view.configure(
            url: fileURL,
            isPlaybackActive: isPlaybackActive,
            loopsPlayback: loopsPlayback,
            isPausedByUserHold: isPausedByUserHold
        )
        return view
    }

    func updateUIView(_ uiView: DiveActivityFillVideoPlayerUIView, context: Context) {
        uiView.configure(
            url: fileURL,
            isPlaybackActive: isPlaybackActive,
            loopsPlayback: loopsPlayback,
            isPausedByUserHold: isPausedByUserHold
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
    private var currentURL: URL?
    private var loopsPlayback = false
    private var isPlaybackActive = false
    private var isPausedByUserHold = false
    private var lastAppliedPlaybackActive = false
    private var endObserver: NSObjectProtocol?

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
        url: URL,
        isPlaybackActive: Bool,
        loopsPlayback: Bool,
        isPausedByUserHold: Bool
    ) {
        let mediaURLChanged = currentURL != url
        let shouldRestart = DiveActivityVideoPlaybackPolicy.shouldRestartFromBeginning(
            wasPlaybackActive: lastAppliedPlaybackActive,
            isPlaybackActive: isPlaybackActive,
            mediaURLChanged: mediaURLChanged
        )

        self.isPlaybackActive = isPlaybackActive
        self.isPausedByUserHold = isPausedByUserHold

        if mediaURLChanged {
            loadPlayer(url: url)
        }
        setLooping(loopsPlayback)

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
        currentURL = nil
        loopsPlayback = false
        isPlaybackActive = false
        isPausedByUserHold = false
        lastAppliedPlaybackActive = false
    }

    private func loadPlayer(url: URL) {
        removeEndObserver()
        player?.pause()
        currentURL = url
        DiveMutedVideoAudioSession.activateForMutedPlayback()
        let newPlayer = AVPlayer(url: url)
        newPlayer.isMuted = true
        player = newPlayer
        playerLayer.player = newPlayer
    }

    private func setLooping(_ enabled: Bool) {
        guard loopsPlayback != enabled else { return }
        loopsPlayback = enabled
        removeEndObserver()
        guard loopsPlayback, let item = player?.currentItem else { return }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self, let player = self.player else { return }
            player.seek(to: .zero) { [weak self] _ in
                guard let self, DiveActivityVideoPlaybackPolicy.shouldPlay(
                    isPlaybackActive: self.isPlaybackActive,
                    isPausedByUserHold: self.isPausedByUserHold
                ) else { return }
                player.play()
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
