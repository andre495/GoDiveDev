import Foundation
import SwiftData

/// One point in a depth-vs-time profile (time from first sample).
struct DiveDepthProfileSample: Equatable, Sendable {
    var elapsedSeconds: Double
    var depthMeters: Double
}

/// Remaining cylinder pressure at elapsed time (subset of profile samples with **`tankPressurePSI`**).
struct DiveDepthProfilePressureSample: Equatable, Sendable {
    var elapsedSeconds: Double
    var pressurePSI: Double
}

/// Builds elapsed-time series from profile samples (sorted by timestamp).
enum DiveDepthProfileSeries {
    /// `points` must be sorted by **`timestamp`** ascending.
    nonisolated static func samples(sortedAscending points: [(timestamp: Date, depthMeters: Double)]) -> [DiveDepthProfileSample] {
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
        return samples(fromSortedProfilePoints: sorted)
    }

    /// Caller guarantees **`points`** are sorted by **`timestamp`** ascending.
    static func samples(fromSortedProfilePoints points: [DiveProfilePoint]) -> [DiveDepthProfileSample] {
        let tuples = points.map { (timestamp: $0.timestamp, depthMeters: $0.depthMeters) }
        return samples(sortedAscending: tuples)
    }

    /// Elapsed time + **psi** only where **`DiveProfilePoint.tankPressurePSI`** is set (same time base as depth series).
    static func pressureSamples(fromProfilePoints points: [DiveProfilePoint]) -> [DiveDepthProfilePressureSample] {
        let sorted = points.sorted { $0.timestamp < $1.timestamp }
        return pressureSamples(fromSortedProfilePoints: sorted)
    }

    /// Caller guarantees **`points`** are sorted by **`timestamp`** ascending.
    static func pressureSamples(fromSortedProfilePoints points: [DiveProfilePoint]) -> [DiveDepthProfilePressureSample] {
        guard let first = points.first else { return [] }
        let t0 = first.timestamp
        return points.compactMap { point in
            guard let psi = point.tankPressurePSI else { return nil }
            return DiveDepthProfilePressureSample(
                elapsedSeconds: point.timestamp.timeIntervalSince(t0),
                pressurePSI: psi
            )
        }
    }

    /// Elapsed seconds corresponding to **`x`** in chart space (linear map across **`rectWidth`**).
    nonisolated static func elapsedSeconds(atChartX x: CGFloat, rectMinX: CGFloat, rectWidth: CGFloat, maxElapsed: Double) -> Double {
        let maxW = max(rectWidth, 1)
        let clampedX = min(max(x, rectMinX), rectMinX + maxW)
        return Double((clampedX - rectMinX) / maxW) * maxElapsed
    }

    /// Index of the sample whose **`elapsedSeconds`** is closest to **`targetElapsedSeconds`** (stable on ties: earlier index wins).
    nonisolated static func indexNearestElapsed(_ targetElapsedSeconds: Double, in samples: [DiveDepthProfileSample]) -> Int {
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
