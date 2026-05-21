import AVFoundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Full-bleed dive video (**`resizeAspectFill`**, same crop behavior as photos).
struct DiveActivityVideoPlayerView: View {
    let fileURL: URL?

    var body: some View {
        Group {
            #if canImport(UIKit)
            if let fileURL {
                GeometryReader { geometry in
                    DiveActivityFillVideoPlayerRepresentable(fileURL: fileURL)
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

    func makeUIView(context: Context) -> DiveActivityFillVideoPlayerUIView {
        let view = DiveActivityFillVideoPlayerUIView()
        view.play(url: fileURL)
        return view
    }

    func updateUIView(_ uiView: DiveActivityFillVideoPlayerUIView, context: Context) {
        uiView.play(url: fileURL)
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

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        playerLayer.videoGravity = .resizeAspectFill
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func play(url: URL) {
        if currentURL == url {
            player?.play()
            return
        }
        stop()
        currentURL = url
        let newPlayer = AVPlayer(url: url)
        player = newPlayer
        playerLayer.player = newPlayer
        newPlayer.play()
    }

    func stop() {
        player?.pause()
        player = nil
        playerLayer.player = nil
        currentURL = nil
    }
}
#endif
