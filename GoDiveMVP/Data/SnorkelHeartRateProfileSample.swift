import Foundation

/// Elapsed seconds from session start + heart rate for charting.
struct SnorkelHeartRateProfileSample: Sendable, Equatable {
    var elapsedSeconds: TimeInterval
    var heartRateBPM: Int
}
