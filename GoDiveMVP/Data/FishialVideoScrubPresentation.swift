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

    /// Scrub bar current position — includes tenths of a second for sub-second framing.
    nonisolated static func formattedScrubTimestamp(durationSeconds: Double, fraction: Double) -> String {
        let totalSeconds = timeSeconds(durationSeconds: durationSeconds, fraction: fraction)
        guard totalSeconds.isFinite, totalSeconds >= 0 else { return "0:00.0" }

        let wholeSeconds = Int(totalSeconds.rounded(.down))
        let minutes = wholeSeconds / 60
        let seconds = wholeSeconds % 60
        let tenths = Int(((totalSeconds - Double(wholeSeconds)) * 10).rounded(.down))
        return String(format: "%d:%02d.%d", minutes, seconds, min(tenths, 9))
    }

    nonisolated static func formattedDuration(durationSeconds: Double) -> String {
        formattedTimestamp(durationSeconds: durationSeconds, fraction: 1)
    }
}

/// Coalesces rapid scrub frame requests so the preview always chases the latest slider
/// position without queueing a backlog of `AVAssetImageGenerator` work.
///
/// Cancelling the prior Swift task does not stop the underlying frame decode, so the earlier
/// design dropped every intermediate frame and only showed the final one after the finger
/// lifted. Instead we run one generation at a time and, on completion, start the newest
/// fraction requested meanwhile — yielding a live-updating preview during the scrub.
struct FishialVideoScrubFrameRequestCoalescer: Sendable {
    private var isGenerating = false
    private var pendingFraction: Double?

    /// Register a newly requested fraction.
    /// - Returns: The fraction to begin generating now, or `nil` if a generation is already in flight
    ///   (the fraction is stored as the pending request to run next).
    mutating func requestFraction(_ fraction: Double) -> Double? {
        let clamped = FishialVideoScrubPresentation.clampedFraction(fraction)
        if isGenerating {
            pendingFraction = clamped
            return nil
        }
        isGenerating = true
        return clamped
    }

    /// Signal that the in-flight generation finished.
    /// - Returns: The next fraction to generate if one was requested while generating, else `nil`.
    mutating func completeGeneration() -> Double? {
        isGenerating = false
        guard let next = pendingFraction else { return nil }
        pendingFraction = nil
        isGenerating = true
        return next
    }

    /// Reset all coalescing state (e.g. when the preview tears down).
    mutating func reset() {
        isGenerating = false
        pendingFraction = nil
    }
}
