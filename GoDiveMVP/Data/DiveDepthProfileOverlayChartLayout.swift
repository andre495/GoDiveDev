import CoreGraphics
import Foundation

/// Plot geometry for **`DiveDepthProfileOverlayChart`** (testable off the main actor).
enum DiveDepthProfileOverlayChartLayout: Sendable {
    static let insetTop: CGFloat = 10
    static let insetLeading: CGFloat = 8
    static let insetBottom: CGFloat = 10
    static let insetTrailing: CGFloat = 8

    static func plotRect(in size: CGSize) -> CGRect {
        CGRect(
            x: insetLeading,
            y: insetTop,
            width: max(size.width - insetLeading - insetTrailing, 1),
            height: max(size.height - insetTop - insetBottom, 1)
        )
    }

    /// Ending cylinder pressure for the gas line’s **y = 0**; falls back to last sample then minimum PSI.
    static func resolvedPressureBaselinePSI(
        endingPSI: Double?,
        pressureSamples: [DiveDepthProfilePressureSample]
    ) -> Double? {
        if let endingPSI {
            return endingPSI
        }
        if let last = pressureSamples.last {
            return last.pressurePSI
        }
        return pressureSamples.map(\.pressurePSI).min()
    }

    /// Maximum **`pressurePSI - baseline`** across samples (gas line vertical scale).
    static func maxPressureAboveBaseline(
        pressureSamples: [DiveDepthProfilePressureSample],
        baselinePSI: Double
    ) -> Double {
        let deltas = pressureSamples.map { max(0, $0.pressurePSI - baselinePSI) }
        return max(deltas.max() ?? 0, 1)
    }

    static func depthPoint(
        sample: DiveDepthProfileSample,
        in rect: CGRect,
        maxElapsed: Double,
        maxDepth: Double
    ) -> CGPoint {
        depthPoint(
            sample: sample,
            in: rect,
            viewport: DiveDepthProfileChartViewport.full(elapsedMax: maxElapsed),
            maxDepth: maxDepth
        )
    }

    static func depthPoint(
        sample: DiveDepthProfileSample,
        in rect: CGRect,
        viewport: DiveDepthProfileChartViewport,
        maxDepth: Double
    ) -> CGPoint {
        let span = max(viewport.elapsedSpan, 0.001)
        let xFraction = (sample.elapsedSeconds - viewport.elapsedStart) / span
        let x = rect.minX + CGFloat(xFraction) * rect.width
        let y = rect.minY + CGFloat(sample.depthMeters / max(maxDepth, 0.001)) * rect.height
        return CGPoint(x: x, y: y)
    }

    /// **`baselinePSI`** is **y = 0** (bottom); higher remaining pressure plots higher.
    static func pressurePoint(
        sample: DiveDepthProfilePressureSample,
        in rect: CGRect,
        maxElapsed: Double,
        baselinePSI: Double,
        maxPressureAboveBaseline: Double
    ) -> CGPoint {
        pressurePoint(
            sample: sample,
            in: rect,
            viewport: DiveDepthProfileChartViewport.full(elapsedMax: maxElapsed),
            baselinePSI: baselinePSI,
            maxPressureAboveBaseline: maxPressureAboveBaseline
        )
    }

    static func pressurePoint(
        sample: DiveDepthProfilePressureSample,
        in rect: CGRect,
        viewport: DiveDepthProfileChartViewport,
        baselinePSI: Double,
        maxPressureAboveBaseline: Double
    ) -> CGPoint {
        let span = max(viewport.elapsedSpan, 0.001)
        let xFraction = (sample.elapsedSeconds - viewport.elapsedStart) / span
        let x = rect.minX + CGFloat(xFraction) * rect.width
        let aboveBaseline = max(0, sample.pressurePSI - baselinePSI)
        let fraction = aboveBaseline / max(maxPressureAboveBaseline, 0.001)
        let y = rect.maxY - CGFloat(fraction) * rect.height
        return CGPoint(x: x, y: y)
    }

    static func elapsedSeconds(
        atChartX x: CGFloat,
        rectMinX: CGFloat,
        rectWidth: CGFloat,
        viewport: DiveDepthProfileChartViewport
    ) -> Double {
        let maxW = max(rectWidth, 1)
        let clampedX = min(max(x, rectMinX), rectMinX + maxW)
        let fraction = Double((clampedX - rectMinX) / maxW)
        return viewport.elapsedStart + fraction * viewport.elapsedSpan
    }

    static func indexNearestPressure(
        elapsedSeconds: Double,
        in samples: [DiveDepthProfilePressureSample]
    ) -> Int? {
        guard !samples.isEmpty else { return nil }
        var bestIndex = 0
        var bestDelta = abs(samples[0].elapsedSeconds - elapsedSeconds)
        for i in 1 ..< samples.count {
            let delta = abs(samples[i].elapsedSeconds - elapsedSeconds)
            if delta < bestDelta {
                bestDelta = delta
                bestIndex = i
            }
        }
        return bestIndex
    }
}
