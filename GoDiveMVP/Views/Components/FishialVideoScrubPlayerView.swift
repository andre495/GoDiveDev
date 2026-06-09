import AVFoundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit) && canImport(AVFoundation)
/// Full-bleed paused **`AVPlayer`** preview for Fishial still selection (PhotoKit **`AVAsset`**).
struct FishialVideoScrubPlayerView: UIViewRepresentable {
    let avAsset: AVAsset
    let durationSeconds: Double
    let scrubFraction: Double
    let isScrubbing: Bool

    func makeUIView(context: Context) -> FishialVideoScrubPlayerUIView {
        let view = FishialVideoScrubPlayerUIView()
        view.prepare(asset: avAsset)
        context.coordinator.bind(to: view)
        return view
    }

    func updateUIView(_ uiView: FishialVideoScrubPlayerUIView, context: Context) {
        uiView.prepare(asset: avAsset)
        context.coordinator.bind(to: uiView)
        context.coordinator.syncSeek(
            fraction: scrubFraction,
            durationSeconds: durationSeconds,
            isScrubbing: isScrubbing
        )
    }

    static func dismantleUIView(_ uiView: FishialVideoScrubPlayerUIView, coordinator: Coordinator) {
        coordinator.unbind()
        uiView.teardown()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        private weak var playerView: FishialVideoScrubPlayerUIView?
        private var lastAppliedFraction: Double?

        func bind(to view: FishialVideoScrubPlayerUIView) {
            playerView = view
        }

        func unbind() {
            playerView = nil
            lastAppliedFraction = nil
        }

        func syncSeek(fraction: Double, durationSeconds: Double, isScrubbing: Bool) {
            let clamped = FishialVideoScrubPresentation.clampedFraction(fraction)
            let precise = FishialVideoScrubPresentation.usesPrecisePlaybackSeek(isScrubbing: isScrubbing)
            if precise {
                lastAppliedFraction = clamped
                playerView?.seek(
                    toFraction: clamped,
                    durationSeconds: durationSeconds,
                    precise: true
                )
                return
            }
            if let lastAppliedFraction,
               abs(lastAppliedFraction - clamped) < 0.000_1 {
                return
            }
            lastAppliedFraction = clamped
            playerView?.seek(
                toFraction: clamped,
                durationSeconds: durationSeconds,
                precise: false
            )
        }
    }
}

/// Native **`AVPlayerLayer`** preview — seeks in real time while the slider moves.
final class FishialVideoScrubPlayerUIView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    private var player: AVPlayer?
    private var preparedAssetIdentifier: ObjectIdentifier?

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        backgroundColor = .black
        playerLayer.videoGravity = .resizeAspect
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func prepare(asset: AVAsset) {
        let assetID = ObjectIdentifier(asset)
        guard preparedAssetIdentifier != assetID else { return }
        teardown()
        preparedAssetIdentifier = assetID
        DiveMutedVideoAudioSession.activateForMutedPlayback()
        let item = AVPlayerItem(asset: asset)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.isMuted = true
        newPlayer.pause()
        player = newPlayer
        playerLayer.player = newPlayer
    }

    func seek(toFraction fraction: Double, durationSeconds: Double, precise: Bool) {
        guard let player else { return }
        let time = DiveMediaFishialFrameExport.cmTime(
            durationSeconds: durationSeconds,
            fraction: fraction
        )
        let tolerance = precise ? CMTime.zero : CMTime.positiveInfinity
        player.pause()
        player.seek(to: time, toleranceBefore: tolerance, toleranceAfter: tolerance)
    }

    func teardown() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        playerLayer.player = nil
        player = nil
        preparedAssetIdentifier = nil
    }
}
#endif
