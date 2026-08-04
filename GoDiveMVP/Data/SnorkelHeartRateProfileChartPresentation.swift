import CoreGraphics
import Foundation
import SwiftUI

/// Active heart-rate scrub readout (time + BPM).
struct SnorkelHeartRateScrubCallout: Equatable, Sendable {
    let elapsedSeconds: Double
    let heartRateBPM: Int
}

/// Geometry and scrub labels for **`SnorkelHeartRateProfileChart`** (testable off the main actor).
enum SnorkelHeartRateProfileChartPresentation: Sendable {
    nonisolated static func chartMaxElapsed(samples: [SnorkelHeartRateProfileSample]) -> Double {
        max(samples.map(\.elapsedSeconds).max() ?? 0, 0.001)
    }

    nonisolated static func chartMaxBPM(
        samples: [SnorkelHeartRateProfileSample],
        sessionMaxBPMHint: Int? = nil
    ) -> Double {
        let dataMax = Double(samples.map(\.heartRateBPM).max() ?? 0)
        let hint = Double(sessionMaxBPMHint ?? 0)
        return max(dataMax, hint, 120)
    }

    nonisolated static func plotPoint(
        sample: SnorkelHeartRateProfileSample,
        in rect: CGRect,
        maxElapsed: Double,
        maxBPM: Double
    ) -> CGPoint {
        let elapsed = max(maxElapsed, 0.001)
        let bpmScale = max(maxBPM, 0.001)
        let xFrac = sample.elapsedSeconds / elapsed
        let yFrac = Double(sample.heartRateBPM) / bpmScale
        return CGPoint(
            x: rect.minX + CGFloat(xFrac) * rect.width,
            y: rect.maxY - CGFloat(yFrac) * rect.height
        )
    }

    /// Closed region under the BPM polyline down to the plot floor (static deep-water fill).
    nonisolated static func underCurveAreaPath(
        samples: [SnorkelHeartRateProfileSample],
        in rect: CGRect,
        maxElapsed: Double,
        maxBPM: Double
    ) -> Path {
        guard samples.count >= 2,
              let first = samples.first,
              let last = samples.last else {
            return Path()
        }

        var path = Path()
        for (index, sample) in samples.enumerated() {
            let point = plotPoint(
                sample: sample,
                in: rect,
                maxElapsed: maxElapsed,
                maxBPM: maxBPM
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        let lastPoint = plotPoint(
            sample: last,
            in: rect,
            maxElapsed: maxElapsed,
            maxBPM: maxBPM
        )
        let firstPoint = plotPoint(
            sample: first,
            in: rect,
            maxElapsed: maxElapsed,
            maxBPM: maxBPM
        )
        path.addLine(to: CGPoint(x: lastPoint.x, y: rect.maxY))
        path.addLine(to: CGPoint(x: firstPoint.x, y: rect.maxY))
        path.closeSubpath()
        return path
    }

    nonisolated static func indexNearestElapsed(
        samples: [SnorkelHeartRateProfileSample],
        targetElapsed: Double
    ) -> Int {
        guard !samples.isEmpty else { return 0 }
        var bestIndex = 0
        var bestDelta = TimeInterval.greatestFiniteMagnitude
        for (index, sample) in samples.enumerated() {
            let delta = abs(sample.elapsedSeconds - targetElapsed)
            if delta < bestDelta {
                bestDelta = delta
                bestIndex = index
            }
        }
        return bestIndex
    }

    nonisolated static func scrubTimeLabel(elapsedSeconds: Double) -> String {
        DiveDepthProfileChartAxisPresentation.scrubTimeLabel(elapsedSeconds: elapsedSeconds)
    }

    nonisolated static func scrubHeartRateLabel(bpm: Int) -> String {
        "\(max(bpm, 0)) bpm"
    }

    /// Keeps the two-line callout inside the chart; prefers sitting above the scrub point.
    nonisolated static func scrubCalloutPosition(point: CGPoint, in rect: CGRect) -> CGPoint {
        let boxHalfW: CGFloat = 52
        let boxHalfH: CGFloat = 28
        let margin: CGFloat = 6
        let preferredY = point.y - 44
        let yTop = min(preferredY, point.y - margin - boxHalfH)
        let y = max(rect.minY + boxHalfH + margin, yTop)
        let x = min(max(point.x, rect.minX + boxHalfW + margin), rect.maxX - boxHalfW - margin)
        return CGPoint(x: x, y: y)
    }
}
