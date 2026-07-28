import CoreGraphics
import Foundation
import SwiftUI

/// Plot geometry for **`DiveDepthProfileOverlayChart`** (testable off the main actor).
enum DiveDepthProfileOverlayChartLayout: Sendable {
    /// Room for depth tick labels left of the plot.
    nonisolated static let insetTop: CGFloat = 12
    nonisolated static let insetLeading: CGFloat = 36
    /// Room for dive-time tick labels under the plot.
    nonisolated static let insetBottom: CGFloat = 22
    nonisolated static let insetTrailing: CGFloat = 10

    nonisolated static func plotRect(
        in size: CGSize,
        chromeStyle: DiveDepthProfileChartPresentation.ChromeStyle = .standard
    ) -> CGRect {
        switch chromeStyle {
        case .standard:
            return CGRect(
                x: insetLeading,
                y: insetTop,
                width: max(size.width - insetLeading - insetTrailing, 1),
                height: max(size.height - insetTop - insetBottom, 1)
            )
        case .edgeToEdge:
            return CGRect(origin: .zero, size: size)
        }
    }

    nonisolated static func plotRect(in size: CGSize) -> CGRect {
        plotRect(in: size, chromeStyle: .standard)
    }

    /// Inner plot band when **`horizontalEdgeBufferFraction`** reserves non-scrubbable side margins.
    nonisolated static func dataPlotRect(
        in rect: CGRect,
        horizontalEdgeBufferFraction: CGFloat
    ) -> CGRect {
        let fraction = min(max(horizontalEdgeBufferFraction, 0), 0.45)
        guard fraction > 0 else { return rect }
        let insetX = rect.width * fraction
        return CGRect(
            x: rect.minX + insetX,
            y: rect.minY,
            width: max(rect.width - insetX * 2, 1),
            height: rect.height
        )
    }

    nonisolated static func isScrubbableChartX(
        _ x: CGFloat,
        in rect: CGRect,
        horizontalEdgeBufferFraction: CGFloat
    ) -> Bool {
        let dataRect = dataPlotRect(in: rect, horizontalEdgeBufferFraction: horizontalEdgeBufferFraction)
        return x >= dataRect.minX && x <= dataRect.maxX
    }

    nonisolated static func chartX(
        forElapsedFraction fraction: Double,
        in rect: CGRect,
        horizontalEdgeBufferFraction: CGFloat
    ) -> CGFloat {
        let dataRect = dataPlotRect(in: rect, horizontalEdgeBufferFraction: horizontalEdgeBufferFraction)
        let clamped = min(max(fraction, 0), 1)
        return dataRect.minX + CGFloat(clamped) * dataRect.width
    }

    /// Ending cylinder pressure for the gas line’s **y = 0**; falls back to last sample then minimum PSI.
    nonisolated static func resolvedPressureBaselinePSI(
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
    nonisolated static func maxPressureAboveBaseline(
        pressureSamples: [DiveDepthProfilePressureSample],
        baselinePSI: Double
    ) -> Double {
        let deltas = pressureSamples.map { max(0, $0.pressurePSI - baselinePSI) }
        return max(deltas.max() ?? 0, 1)
    }

    nonisolated static func recordedDepthMetersRange(
        in samples: [DiveDepthProfileSample]
    ) -> (min: Double, max: Double) {
        let depths = samples.map(\.depthMeters)
        return (depths.min() ?? 0, depths.max() ?? 0)
    }

    nonisolated static func recordedPressurePSIRange(
        in samples: [DiveDepthProfilePressureSample]
    ) -> (min: Double, max: Double)? {
        let values = samples.map(\.pressurePSI)
        guard let minValue = values.min(), let maxValue = values.max() else { return nil }
        return (minValue, maxValue)
    }

    nonisolated static func depthDataVerticalBand(
        in rect: CGRect,
        minDepthMeters: Double,
        maxDepthMeters: Double,
        axisMaxDepthMeters: Double,
        topBufferFraction: Double = DiveDepthProfileChartPresentation.depthAxisTopBufferFraction
    ) -> (minY: CGFloat, maxY: CGFloat) {
        let minY = DiveDepthProfileChartPresentation.depthPlotY(
            depthMeters: minDepthMeters,
            axisMaxDepthMeters: axisMaxDepthMeters,
            in: rect,
            topBufferFraction: topBufferFraction
        )
        let maxY = DiveDepthProfileChartPresentation.depthPlotY(
            depthMeters: maxDepthMeters,
            axisMaxDepthMeters: axisMaxDepthMeters,
            in: rect,
            topBufferFraction: topBufferFraction
        )
        return (minY, maxY)
    }

    nonisolated static func depthPoint(
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

    nonisolated static func depthPoint(
        sample: DiveDepthProfileSample,
        in rect: CGRect,
        viewport: DiveDepthProfileChartViewport,
        maxDepth: Double,
        topBufferFraction: Double = DiveDepthProfileChartPresentation.depthAxisTopBufferFraction,
        horizontalEdgeBufferFraction: CGFloat = 0
    ) -> CGPoint {
        let span = max(viewport.elapsedSpan, 0.001)
        let xFraction = (sample.elapsedSeconds - viewport.elapsedStart) / span
        let x = chartX(
            forElapsedFraction: xFraction,
            in: rect,
            horizontalEdgeBufferFraction: horizontalEdgeBufferFraction
        )
        let y = DiveDepthProfileChartPresentation.depthPlotY(
            depthMeters: sample.depthMeters,
            axisMaxDepthMeters: maxDepth,
            in: rect,
            topBufferFraction: topBufferFraction
        )
        return CGPoint(x: x, y: y)
    }

    /// Gas line shares the depth axis band: max PSI at min depth **y**, min PSI at max depth **y** (20% buffer below).
    nonisolated static func pressurePoint(
        sample: DiveDepthProfilePressureSample,
        in rect: CGRect,
        maxElapsed: Double,
        minDepthMeters: Double,
        maxDepthMeters: Double,
        axisMaxDepthMeters: Double,
        minPressurePSI: Double,
        maxPressurePSI: Double
    ) -> CGPoint {
        pressurePoint(
            sample: sample,
            in: rect,
            viewport: DiveDepthProfileChartViewport.full(elapsedMax: maxElapsed),
            minDepthMeters: minDepthMeters,
            maxDepthMeters: maxDepthMeters,
            axisMaxDepthMeters: axisMaxDepthMeters,
            minPressurePSI: minPressurePSI,
            maxPressurePSI: maxPressurePSI
        )
    }

    nonisolated static func pressurePoint(
        sample: DiveDepthProfilePressureSample,
        in rect: CGRect,
        viewport: DiveDepthProfileChartViewport,
        minDepthMeters: Double,
        maxDepthMeters: Double,
        axisMaxDepthMeters: Double,
        minPressurePSI: Double,
        maxPressurePSI: Double,
        topBufferFraction: Double = DiveDepthProfileChartPresentation.depthAxisTopBufferFraction,
        horizontalEdgeBufferFraction: CGFloat = 0
    ) -> CGPoint {
        let span = max(viewport.elapsedSpan, 0.001)
        let xFraction = (sample.elapsedSeconds - viewport.elapsedStart) / span
        let x = chartX(
            forElapsedFraction: xFraction,
            in: rect,
            horizontalEdgeBufferFraction: horizontalEdgeBufferFraction
        )
        let band = depthDataVerticalBand(
            in: rect,
            minDepthMeters: minDepthMeters,
            maxDepthMeters: maxDepthMeters,
            axisMaxDepthMeters: axisMaxDepthMeters,
            topBufferFraction: topBufferFraction
        )
        let pressureSpan = max(maxPressurePSI - minPressurePSI, 0.001)
        let normalized = (maxPressurePSI - sample.pressurePSI) / pressureSpan
        let clamped = min(1, max(0, normalized))
        let y = band.minY + CGFloat(clamped) * (band.maxY - band.minY)
        return CGPoint(x: x, y: y)
    }

    /// Legacy baseline scale — retained for tests; prefer depth-aligned **`pressurePoint`** above.
    nonisolated static func pressurePoint(
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

    nonisolated static func pressurePoint(
        sample: DiveDepthProfilePressureSample,
        in rect: CGRect,
        viewport: DiveDepthProfileChartViewport,
        baselinePSI: Double,
        maxPressureAboveBaseline: Double,
        horizontalEdgeBufferFraction: CGFloat = 0
    ) -> CGPoint {
        let span = max(viewport.elapsedSpan, 0.001)
        let xFraction = (sample.elapsedSeconds - viewport.elapsedStart) / span
        let x = chartX(
            forElapsedFraction: xFraction,
            in: rect,
            horizontalEdgeBufferFraction: horizontalEdgeBufferFraction
        )
        let aboveBaseline = max(0, sample.pressurePSI - baselinePSI)
        let fraction = aboveBaseline / max(maxPressureAboveBaseline, 0.001)
        let y = rect.maxY - CGFloat(fraction) * rect.height
        return CGPoint(x: x, y: y)
    }

    nonisolated static func elapsedSeconds(
        atChartX x: CGFloat,
        rectMinX: CGFloat,
        rectWidth: CGFloat,
        viewport: DiveDepthProfileChartViewport
    ) -> Double {
        elapsedSeconds(
            atChartX: x,
            in: CGRect(x: rectMinX, y: 0, width: rectWidth, height: 1),
            viewport: viewport
        ) ?? viewport.elapsedStart
    }

    nonisolated static func elapsedSeconds(
        atChartX x: CGFloat,
        in rect: CGRect,
        viewport: DiveDepthProfileChartViewport,
        horizontalEdgeBufferFraction: CGFloat = 0
    ) -> Double? {
        guard isScrubbableChartX(x, in: rect, horizontalEdgeBufferFraction: horizontalEdgeBufferFraction) else {
            return nil
        }
        let dataRect = dataPlotRect(in: rect, horizontalEdgeBufferFraction: horizontalEdgeBufferFraction)
        let fraction = Double((x - dataRect.minX) / max(dataRect.width, 1))
        return viewport.elapsedStart + fraction * viewport.elapsedSpan
    }

    nonisolated static func tracedProfilePath(
        points: [CGPoint],
        in rect: CGRect,
        horizontalEdgeBufferFraction: CGFloat,
        extendsIntoHorizontalBuffers: Bool = false
    ) -> Path {
        guard !points.isEmpty else { return Path() }
        var path = Path()
        if horizontalEdgeBufferFraction > 0,
           extendsIntoHorizontalBuffers,
           let first = points.first {
            path.move(to: CGPoint(x: rect.minX, y: first.y))
            if points.count == 1 {
                path.addLine(to: CGPoint(x: rect.maxX, y: first.y))
            } else {
                path.addLine(to: first)
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
                if let last = points.last {
                    path.addLine(to: CGPoint(x: rect.maxX, y: last.y))
                }
            }
        } else {
            for (index, point) in points.enumerated() {
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
        }
        return path
    }

    /// Samples must be sorted by **`elapsedSeconds`** ascending.
    nonisolated static func indexNearestPressure(
        elapsedSeconds: Double,
        in samples: [DiveDepthProfilePressureSample]
    ) -> Int? {
        guard !samples.isEmpty else { return nil }
        if samples.count == 1 { return 0 }
        if elapsedSeconds <= samples[0].elapsedSeconds { return 0 }
        if elapsedSeconds >= samples[samples.count - 1].elapsedSeconds { return samples.count - 1 }

        var low = 0
        var high = samples.count - 1
        while low + 1 < high {
            let mid = (low + high) / 2
            if samples[mid].elapsedSeconds <= elapsedSeconds {
                low = mid
            } else {
                high = mid
            }
        }
        let lowDelta = abs(samples[low].elapsedSeconds - elapsedSeconds)
        let highDelta = abs(samples[high].elapsedSeconds - elapsedSeconds)
        return highDelta < lowDelta ? high : low
    }
}
