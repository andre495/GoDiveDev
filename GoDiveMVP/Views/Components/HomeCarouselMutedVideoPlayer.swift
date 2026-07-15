import AVFoundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
/// Minimal Home carousel video surface — binds a preloaded muted **`AVPlayer`** (PhotoKit streaming item).
struct HomeCarouselMutedVideoPlayer: UIViewRepresentable {
    let player: AVPlayer
    var isPlaybackActive: Bool
    var loopsPlayback: Bool
    var onPlaybackFinished: (() -> Void)?

    func makeUIView(context: Context) -> HomeCarouselMutedVideoPlayerUIView {
        let view = HomeCarouselMutedVideoPlayerUIView()
        view.configure(
            player: player,
            isPlaybackActive: isPlaybackActive,
            loopsPlayback: loopsPlayback,
            onPlaybackFinished: onPlaybackFinished
        )
        return view
    }

    func updateUIView(_ uiView: HomeCarouselMutedVideoPlayerUIView, context: Context) {
        uiView.configure(
            player: player,
            isPlaybackActive: isPlaybackActive,
            loopsPlayback: loopsPlayback,
            onPlaybackFinished: onPlaybackFinished
        )
    }

    static func dismantleUIView(_ uiView: HomeCarouselMutedVideoPlayerUIView, coordinator: ()) {
        uiView.detach()
    }
}

final class HomeCarouselMutedVideoPlayerUIView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    private var player: AVPlayer?
    private var loopsPlayback = false
    private var isPlaybackActive = false
    private var endObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?
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
        statusObservation?.invalidate()
    }

    func configure(
        player: AVPlayer,
        isPlaybackActive: Bool,
        loopsPlayback: Bool,
        onPlaybackFinished: (() -> Void)?
    ) {
        let wasActive = self.isPlaybackActive
        self.loopsPlayback = loopsPlayback
        self.onPlaybackFinished = onPlaybackFinished
        self.isPlaybackActive = isPlaybackActive

        if self.player !== player {
            removeEndObserver()
            statusObservation?.invalidate()
            statusObservation = nil
            self.player?.pause()
            self.player = player
            playerLayer.player = player
            player.isMuted = true
            installEndObserver()
            observeItemStatus(for: player)
        }

        if isPlaybackActive, !wasActive {
            // Seek then play from the completion — `play()` before seek finishes / before
            // `.readyToPlay` is why slide 0 stayed frozen until a swipe remount.
            player.seek(to: .zero) { [weak self] finished in
                guard finished else { return }
                DispatchQueue.main.async {
                    self?.playIfReady(force: true)
                }
            }
        } else {
            playIfReady(force: false)
        }
    }

    func detach() {
        removeEndObserver()
        statusObservation?.invalidate()
        statusObservation = nil
        // Do not pause — Home shares one **`AVPlayer`** per library id across the looping
        // duplicate of slide **0**; pausing here would mute the selected page.
        playerLayer.player = nil
        player = nil
        isPlaybackActive = false
    }

    private func observeItemStatus(for player: AVPlayer) {
        statusObservation?.invalidate()
        statusObservation = player.currentItem?.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self, self.isPlaybackActive, item.status == .readyToPlay else { return }
                self.playIfReady(force: true)
            }
        }
    }

    private func playIfReady(force: Bool) {
        guard let player else { return }
        if isPlaybackActive {
            DiveMutedVideoAudioSession.activateForMutedPlayback()
            player.isMuted = true
            let itemStatus = player.currentItem?.status
            guard itemStatus == .readyToPlay || itemStatus == nil else {
                // Still loading / failed — `.readyToPlay` observer will retry.
                return
            }
            if force || player.rate == 0 {
                player.play()
            }
        } else {
            player.pause()
        }
    }

    private func installEndObserver() {
        removeEndObserver()
        guard let player, let item = player.currentItem else { return }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            if self.loopsPlayback {
                self.player?.seek(to: .zero) { [weak self] finished in
                    guard finished else { return }
                    DispatchQueue.main.async {
                        self?.playIfReady(force: true)
                    }
                }
            } else {
                self.onPlaybackFinished?()
            }
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
