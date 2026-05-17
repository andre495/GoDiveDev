import Foundation
import SwiftData

/// One point in a depth-vs-time profile (time from first sample).
struct DiveDepthProfileSample: Equatable, Sendable {
    var elapsedSeconds: Double
    var depthMeters: Double
}

/// Builds elapsed-time series from profile samples (sorted by timestamp).
enum DiveDepthProfileSeries {
    /// `points` must be sorted by **`timestamp`** ascending.
    static func samples(sortedAscending points: [(timestamp: Date, depthMeters: Double)]) -> [DiveDepthProfileSample] {
        guard let first = points.first else { return [] }
        let t0 = first.timestamp
        return points.map {
            DiveDepthProfileSample(
                elapsedSeconds: $0.timestamp.timeIntervalSince(t0),
                depthMeters: $0.depthMeters
            )
        }
    }

    static func samples(fromProfilePoints points: [DiveProfilePoint]) -> [DiveDepthProfileSample] {
        let sorted = points.sorted { $0.timestamp < $1.timestamp }
        let tuples = sorted.map { (timestamp: $0.timestamp, depthMeters: $0.depthMeters) }
        return samples(sortedAscending: tuples)
    }

    /// Elapsed seconds corresponding to **`x`** in chart space (linear map across **`rectWidth`**).
    static func elapsedSeconds(atChartX x: CGFloat, rectMinX: CGFloat, rectWidth: CGFloat, maxElapsed: Double) -> Double {
        let maxW = max(rectWidth, 1)
        let clampedX = min(max(x, rectMinX), rectMinX + maxW)
        return Double((clampedX - rectMinX) / maxW) * maxElapsed
    }

    /// Index of the sample whose **`elapsedSeconds`** is closest to **`targetElapsedSeconds`** (stable on ties: earlier index wins).
    static func indexNearestElapsed(_ targetElapsedSeconds: Double, in samples: [DiveDepthProfileSample]) -> Int {
        guard !samples.isEmpty else { return 0 }
        var bestIndex = 0
        var bestDelta = abs(samples[0].elapsedSeconds - targetElapsedSeconds)
        for i in 1..<samples.count {
            let delta = abs(samples[i].elapsedSeconds - targetElapsedSeconds)
            if delta < bestDelta {
                bestDelta = delta
                bestIndex = i
            }
        }
        return bestIndex
    }
}
