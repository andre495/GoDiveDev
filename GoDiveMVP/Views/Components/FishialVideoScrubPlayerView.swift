import AVFoundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit) && canImport(AVFoundation)
/// Full-bleed paused frame preview for Fishial still selection (exact **`AVAssetImageGenerator`** timing).
struct FishialVideoScrubPlayerView: UIViewRepresentable {
    let avAsset: AVAsset
    let durationSeconds: Double
    let scrubFraction: Double

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
            durationSeconds: durationSeconds
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

        func syncSeek(fraction: Double, durationSeconds: Double) {
            let clamped = FishialVideoScrubPresentation.clampedFraction(fraction)
            if let lastAppliedFraction,
               abs(lastAppliedFraction - clamped) < 0.000_001 {
                return
            }
            lastAppliedFraction = clamped
            playerView?.seek(
                toFraction: clamped,
                durationSeconds: durationSeconds
            )
        }
    }
}

/// Native aspect-fit still preview — extracts the requested frame instead of keyframe-snapped **`AVPlayer`** seeks.
final class FishialVideoScrubPlayerUIView: UIView {
    private let imageView = UIImageView()
    private var imageGenerator: AVAssetImageGenerator?
    private var generationTask: Task<Void, Never>?
    private var coalescer = FishialVideoScrubFrameRequestCoalescer()
    private var durationSeconds: Double = 0
    private var preparedAssetIdentifier: ObjectIdentifier?

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        backgroundColor = .black
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
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
        imageGenerator = DiveMediaFishialFrameExport.makeScrubPreviewImageGenerator(for: asset)
    }

    func seek(toFraction fraction: Double, durationSeconds: Double) {
        guard imageGenerator != nil else { return }
        self.durationSeconds = durationSeconds
        // Coalesce rapid slider ticks: only one decode runs at a time, and the newest
        // requested fraction runs next so the preview updates live while the user scrubs.
        if let fractionToGenerate = coalescer.requestFraction(fraction) {
            startGeneration(fraction: fractionToGenerate)
        }
    }

    private func startGeneration(fraction: Double) {
        guard let imageGenerator else { return }
        let time = DiveMediaFishialFrameExport.cmTime(
            durationSeconds: durationSeconds,
            fraction: fraction
        )
        generationTask = Task { @MainActor in
            defer {
                if let nextFraction = coalescer.completeGeneration() {
                    startGeneration(fraction: nextFraction)
                }
            }
            let cgImage = try? await DiveMediaFishialFrameExport.cgImage(
                from: imageGenerator,
                at: time
            )
            if let cgImage {
                imageView.image = UIImage(cgImage: cgImage)
            }
        }
    }

    func teardown() {
        generationTask?.cancel()
        generationTask = nil
        coalescer.reset()
        imageGenerator = nil
        imageView.image = nil
        preparedAssetIdentifier = nil
        durationSeconds = 0
    }
}
#endif
