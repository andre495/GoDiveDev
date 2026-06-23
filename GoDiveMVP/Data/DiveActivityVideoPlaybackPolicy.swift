import CoreGraphics
import Foundation

/// Rules for dive **Media** hero video playback (testable without AVFoundation).
enum DiveActivityVideoPlaybackPolicy: Sendable {

    /// Finger must stay still this long before hold-to-pause engages.
    nonisolated static let holdPauseMinimumDurationSeconds: TimeInterval = 0.22

    /// Total finger movement beyond this fails the long-press so the pager swipe wins.
    nonisolated static let holdPauseMaximumMovementPoints: CGFloat = 5

    /// Restart from the beginning when a pager item becomes active, its file changes, or playback is stuck at the end.
    ///
    /// Pager / carousel navigation always starts from **0** — cached **`AVPlayer`** instances must not resume mid-clip.
    /// Preview → full fidelity upgrades are **not** treated as a media change.
    nonisolated static func shouldRestartFromBeginning(
        wasPlaybackActive: Bool,
        isPlaybackActive: Bool,
        mediaURLChanged: Bool,
        isAtEnd: Bool = false
    ) -> Bool {
        guard isPlaybackActive else { return false }
        if mediaURLChanged { return true }
        if !wasPlaybackActive { return true }
        if isAtEnd { return true }
        return false
    }

    /// Whether **`identityKey`** denotes a different clip (ignores preview → full upgrades).
    nonisolated static func mediaIdentityChanged(previousKey: String?, nextKey: String) -> Bool {
        guard previousKey != nextKey else { return false }
        if DiveMediaProgressivePresentation.isVideoQualityFidelityUpgrade(
            from: previousKey,
            to: nextKey
        ) {
            return false
        }
        return true
    }

    /// **`true`** when playback should run (not held, and the page/tab allows play).
    nonisolated static func shouldPlay(
        isPlaybackActive: Bool,
        isPausedByUserHold: Bool
    ) -> Bool {
        isPlaybackActive && !isPausedByUserHold
    }
}
