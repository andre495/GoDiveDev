import SwiftUI

/// Photos-style center play/pause — SF Symbol + Liquid Glass circle on fullscreen video.
struct LinkedMediaFullscreenCenterPlaybackControl: View {
    let isPaused: Bool
    let action: () -> Void
    var accessibilityIdentifier: String = "LinkedMedia.Fullscreen.PlaybackToggle"

    private var diameter: CGFloat {
        LinkedMediaFullscreenPresentation.centerPlaybackControlDiameter
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: isPaused ? "play.fill" : "pause.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .offset(x: isPaused ? 2 : 0)
                .frame(width: diameter, height: diameter)
                .appLiquidGlassCircleChrome()
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPaused ? "Play" : "Pause")
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
