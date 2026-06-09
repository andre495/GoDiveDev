import Foundation

/// Scrub UI copy and time formatting for Fishial video still selection.
enum FishialVideoScrubPresentation: Sendable {

    nonisolated static func clampedFraction(_ fraction: Double) -> Double {
        min(max(fraction, 0), 1)
    }

    nonisolated static func timeSeconds(durationSeconds: Double, fraction: Double) -> Double {
        durationSeconds * clampedFraction(fraction)
    }

    nonisolated static func formattedTimestamp(durationSeconds: Double, fraction: Double) -> String {
        let totalSeconds = timeSeconds(durationSeconds: durationSeconds, fraction: fraction)
        guard totalSeconds.isFinite, totalSeconds >= 0 else { return "0:00" }

        let wholeSeconds = Int(totalSeconds.rounded(.down))
        let minutes = wholeSeconds / 60
        let seconds = wholeSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    nonisolated static func formattedDuration(durationSeconds: Double) -> String {
        formattedTimestamp(durationSeconds: durationSeconds, fraction: 1)
    }

    /// **`AVPlayer`** uses fast approximate seeks while dragging; exact frame on release.
    nonisolated static func usesPrecisePlaybackSeek(isScrubbing: Bool) -> Bool {
        !isScrubbing
    }
}
