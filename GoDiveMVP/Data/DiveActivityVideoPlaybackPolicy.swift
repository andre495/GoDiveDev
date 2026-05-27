import CoreGraphics
import Foundation

/// Rules for dive **Media** hero video playback (testable without AVFoundation).
enum DiveActivityVideoPlaybackPolicy: Sendable {

    /// Finger must stay still this long before hold-to-pause engages.
    nonisolated static let holdPauseMinimumDurationSeconds: TimeInterval = 0.22

    /// Total finger movement beyond this fails the long-press so the pager swipe wins.
    nonisolated static let holdPauseMaximumMovementPoints: CGFloat = 5

    /// Restart from the beginning when a pager item becomes active or its file changes.
    nonisolated static func shouldRestartFromBeginning(
        wasPlaybackActive: Bool,
        isPlaybackActive: Bool,
        mediaURLChanged: Bool
    ) -> Bool {
        isPlaybackActive && (!wasPlaybackActive || mediaURLChanged)
    }

    /// **`true`** when playback should run (not held, and the page/tab allows play).
    nonisolated static func shouldPlay(
        isPlaybackActive: Bool,
        isPausedByUserHold: Bool
    ) -> Bool {
        isPlaybackActive && !isPausedByUserHold
    }
}
