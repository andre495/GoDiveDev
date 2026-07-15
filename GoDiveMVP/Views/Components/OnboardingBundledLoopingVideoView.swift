import AVFoundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
/// Muted, looping bundle **`.mov`** for onboarding micro-demos (read-only; no controls).
struct OnboardingBundledLoopingVideoView: View {
  let resourceName: String
  let resourceExtension: String
  var isPlaybackActive: Bool

  var body: some View {
    Group {
      if let url = Bundle.main.url(forResource: resourceName, withExtension: resourceExtension) {
        OnboardingBundledLoopingVideoRepresentable(
          url: url,
          isPlaybackActive: isPlaybackActive
        )
      } else {
        AppTheme.Colors.screenBackgroundGradient
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .clipped()
  }
}

private struct OnboardingBundledLoopingVideoRepresentable: UIViewRepresentable {
  let url: URL
  let isPlaybackActive: Bool

  func makeUIView(context: Context) -> OnboardingBundledLoopingVideoUIView {
    let view = OnboardingBundledLoopingVideoUIView()
    view.configure(url: url, isPlaybackActive: isPlaybackActive)
    return view
  }

  func updateUIView(_ uiView: OnboardingBundledLoopingVideoUIView, context: Context) {
    uiView.configure(url: url, isPlaybackActive: isPlaybackActive)
  }

  static func dismantleUIView(_ uiView: OnboardingBundledLoopingVideoUIView, coordinator: ()) {
    uiView.teardown()
  }
}

private final class OnboardingBundledLoopingVideoUIView: UIView {
  override static var layerClass: AnyClass { AVPlayerLayer.self }

  private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
  private var player: AVPlayer?
  private var endObserver: NSObjectProtocol?
  private var configuredURL: URL?
  private var isPlaybackActive = false

  override init(frame: CGRect) {
    super.init(frame: frame)
    clipsToBounds = true
    playerLayer.videoGravity = .resizeAspectFill
    backgroundColor = .black
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  deinit {
    teardown()
  }

  func configure(url: URL, isPlaybackActive: Bool) {
    let urlChanged = configuredURL != url
    self.isPlaybackActive = isPlaybackActive

    if urlChanged {
      teardownPlayerOnly()
      configuredURL = url
      DiveMutedVideoAudioSession.activateForMutedPlayback()
      let item = AVPlayerItem(url: url)
      let newPlayer = AVPlayer(playerItem: item)
      newPlayer.isMuted = true
      player = newPlayer
      playerLayer.player = newPlayer
      installEndObserver()
    }

    syncPlaybackState()
  }

  func teardown() {
    removeEndObserver()
    player?.pause()
    player?.replaceCurrentItem(with: nil)
    player = nil
    playerLayer.player = nil
    configuredURL = nil
    isPlaybackActive = false
  }

  private func teardownPlayerOnly() {
    removeEndObserver()
    player?.pause()
    player?.replaceCurrentItem(with: nil)
    player = nil
    playerLayer.player = nil
  }

  private func syncPlaybackState() {
    guard let player else { return }
    if isPlaybackActive {
      DiveMutedVideoAudioSession.activateForMutedPlayback()
      player.isMuted = true
      if player.rate == 0 {
        player.play()
      }
    } else {
      player.pause()
      player.seek(to: .zero)
    }
  }

  private func installEndObserver() {
    removeEndObserver()
    guard let item = player?.currentItem else { return }
    endObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: item,
      queue: .main
    ) { [weak self] _ in
      guard let self, self.isPlaybackActive else { return }
      DiveMutedVideoAudioSession.activateForMutedPlayback()
      self.player?.isMuted = true
      self.player?.seek(to: .zero)
      self.player?.play()
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
