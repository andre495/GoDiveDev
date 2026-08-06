import CoreGraphics
import Foundation
import SwiftUI

/// Visual styling helpers for **`DiveDepthProfileOverlayChart`** (testable off the main actor).
enum DiveDepthProfileChartPresentation: Sendable {
    /// Standard labeled axes vs full-bleed minimized hero (no ticks, flush to seam).
    enum ChromeStyle: Sendable {
        case standard
        case edgeToEdge
    }

    /// Depth / heart-rate profile charts always use the **dark** palette (water fill, underfill, accent line)
    /// so light mode matches dark mode exactly — same idea as Media frosted overlays.
    nonisolated static let forcesDarkAppearance = true

    /// Y-axis extends this fraction beyond the deepest sample (e.g. **0.2** → 100 ft max plots to 120 ft).
    nonisolated static let depthAxisExtensionFraction: Double = 0.2

    /// Empty band above **0 m / 0 ft** so the surface line is not flush with the plot top.
    nonisolated static let depthAxisTopBufferFraction: Double = 0.15

    /// Extra headroom on the tank hero **large** detent (edge-to-edge) plot — **30%** total with **`depthAxisTopBufferFraction`**.
    nonisolated static let depthAxisLargeDetentAdditionalTopBufferFraction: Double = 0.15

    /// Landscape hero — non-scrubbable visual margin; profile underfill extends flat, lines stay in the data band.
    nonisolated static let landscapeHorizontalEdgeBufferFraction: CGFloat = 0.07

    /// Opacity for the top stop of the static deep-water underfill (below the depth line).
    nonisolated static let underfillTopOpacity: Double = 0.55
    /// Opacity for the bottom stop of the static deep-water underfill (plot floor).
    nonisolated static let underfillBottomOpacity: Double = 0.94

    nonisolated static func depthAxisTopBufferFraction(
        for chromeStyle: ChromeStyle
    ) -> Double {
        switch chromeStyle {
        case .edgeToEdge:
            return depthAxisTopBufferFraction + depthAxisLargeDetentAdditionalTopBufferFraction
        case .standard:
            return depthAxisTopBufferFraction
        }
    }

    /// Light pressure-line smoothing — blends each interior point toward its neighbors (not a full regression).
    nonisolated static let pressureLineNeighborBlendWeight: Double = 0.28

    /// Gas-line plot uses one averaged sample per interval; scrub still reads every raw point.
    nonisolated static let pressureLineDownsampleIntervalSeconds: Double = 5

    nonisolated static func depthAxisMaximumMeters(
        dataMaxMeters: Double,
        hintMeters: Double = 0
    ) -> Double {
        let dataMax = Swift.max(dataMaxMeters, hintMeters, 0.5)
        return dataMax * (1 + depthAxisExtensionFraction)
    }

    /// **0…1** depth data fraction → plot **y** fraction with top headroom.
    nonisolated static func depthPlotFraction(
        depthMeters: Double,
        axisMaxDepthMeters: Double,
        topBufferFraction: Double = depthAxisTopBufferFraction
    ) -> Double {
        let axisMax = Swift.max(axisMaxDepthMeters, 0.001)
        let depthFraction = Swift.min(Swift.max(depthMeters / axisMax, 0), 1)
        return topBufferFraction + depthFraction * (1 - topBufferFraction)
    }

    nonisolated static func depthPlotY(
        depthMeters: Double,
        axisMaxDepthMeters: Double,
        in rect: CGRect,
        topBufferFraction: Double = depthAxisTopBufferFraction
    ) -> CGFloat {
        rect.minY + CGFloat(
            depthPlotFraction(
                depthMeters: depthMeters,
                axisMaxDepthMeters: axisMaxDepthMeters,
                topBufferFraction: topBufferFraction
            )
        ) * rect.height
    }

    nonisolated static func lightlySmoothedPressureSamples(
        _ samples: [DiveDepthProfilePressureSample],
        neighborBlendWeight: Double = pressureLineNeighborBlendWeight
    ) -> [DiveDepthProfilePressureSample] {
        guard samples.count > 2 else { return samples }
        let blend = Swift.min(Swift.max(neighborBlendWeight, 0), 0.85)
        var result = samples
        for index in 1 ..< samples.count - 1 {
            let previous = samples[index - 1].pressurePSI
            let current = samples[index].pressurePSI
            let next = samples[index + 1].pressurePSI
            let neighborAverage = (previous + next) / 2
            let smoothed = current * (1 - blend) + neighborAverage * blend
            result[index] = DiveDepthProfilePressureSample(
                elapsedSeconds: samples[index].elapsedSeconds,
                pressurePSI: smoothed
            )
        }
        return result
    }

    /// Averages pressure into fixed-width time buckets, then light neighbor smoothing — display only.
    nonisolated static func downsampledPressureSamplesForLine(
        _ samples: [DiveDepthProfilePressureSample],
        intervalSeconds: Double = pressureLineDownsampleIntervalSeconds
    ) -> [DiveDepthProfilePressureSample] {
        guard samples.count >= 2, intervalSeconds > 0 else { return samples }

        let first = samples[0]
        let last = samples[samples.count - 1]
        if last.elapsedSeconds - first.elapsedSeconds < intervalSeconds {
            return lightlySmoothedPressureSamples(samples)
        }

        var result: [DiveDepthProfilePressureSample] = [first]
        var bucketEnd = first.elapsedSeconds + intervalSeconds

        while bucketEnd < last.elapsedSeconds {
            let bucketStart = bucketEnd - intervalSeconds
            let inBucket = samples.filter {
                $0.elapsedSeconds >= bucketStart && $0.elapsedSeconds < bucketEnd
            }
            if !inBucket.isEmpty {
                let averagePSI = inBucket.map(\.pressurePSI).reduce(0, +) / Double(inBucket.count)
                result.append(
                    DiveDepthProfilePressureSample(
                        elapsedSeconds: bucketStart + intervalSeconds / 2,
                        pressurePSI: averagePSI
                    )
                )
            }
            bucketEnd += intervalSeconds
        }

        if result.last?.elapsedSeconds != last.elapsedSeconds
            || result.last?.pressurePSI != last.pressurePSI {
            result.append(last)
        }

        return lightlySmoothedPressureSamples(result)
    }

    nonisolated static func depthProfileLinePath(
        samples: [DiveDepthProfileSample],
        in rect: CGRect,
        viewport: DiveDepthProfileChartViewport,
        axisMaxDepthMeters: Double,
        topBufferFraction: Double = depthAxisTopBufferFraction,
        horizontalEdgeBufferFraction: CGFloat = 0
    ) -> Path {
        let points = samples.map { sample in
            DiveDepthProfileOverlayChartLayout.depthPoint(
                sample: sample,
                in: rect,
                viewport: viewport,
                maxDepth: axisMaxDepthMeters,
                topBufferFraction: topBufferFraction,
                horizontalEdgeBufferFraction: horizontalEdgeBufferFraction
            )
        }
        return DiveDepthProfileOverlayChartLayout.tracedProfilePath(
            points: points,
            in: rect,
            horizontalEdgeBufferFraction: horizontalEdgeBufferFraction,
            extendsIntoHorizontalBuffers: false
        )
    }

    /// Top boundary for static underfill — flat extensions into side buffers when present.
    nonisolated static func depthProfileUnderfillBoundaryPath(
        samples: [DiveDepthProfileSample],
        in rect: CGRect,
        viewport: DiveDepthProfileChartViewport,
        axisMaxDepthMeters: Double,
        topBufferFraction: Double = depthAxisTopBufferFraction,
        horizontalEdgeBufferFraction: CGFloat = 0
    ) -> Path {
        let points = samples.map { sample in
            DiveDepthProfileOverlayChartLayout.depthPoint(
                sample: sample,
                in: rect,
                viewport: viewport,
                maxDepth: axisMaxDepthMeters,
                topBufferFraction: topBufferFraction,
                horizontalEdgeBufferFraction: horizontalEdgeBufferFraction
            )
        }
        return DiveDepthProfileOverlayChartLayout.tracedProfilePath(
            points: points,
            in: rect,
            horizontalEdgeBufferFraction: horizontalEdgeBufferFraction,
            extendsIntoHorizontalBuffers: true
        )
    }

    /// Closed region above the depth polyline up to the plot ceiling (shimmer + bubbles).
    nonisolated static func depthProfileAreaPath(
        samples: [DiveDepthProfileSample],
        in rect: CGRect,
        viewport: DiveDepthProfileChartViewport,
        axisMaxDepthMeters: Double,
        topBufferFraction: Double = depthAxisTopBufferFraction,
        horizontalEdgeBufferFraction: CGFloat = 0
    ) -> Path {
        guard samples.count >= 2,
              let first = samples.first,
              let last = samples.last else {
            return Path()
        }

        var path = depthProfileLinePath(
            samples: samples,
            in: rect,
            viewport: viewport,
            axisMaxDepthMeters: axisMaxDepthMeters,
            topBufferFraction: topBufferFraction,
            horizontalEdgeBufferFraction: horizontalEdgeBufferFraction
        )
        let lastPoint = DiveDepthProfileOverlayChartLayout.depthPoint(
            sample: last,
            in: rect,
            viewport: viewport,
            maxDepth: axisMaxDepthMeters,
            topBufferFraction: topBufferFraction,
            horizontalEdgeBufferFraction: horizontalEdgeBufferFraction
        )
        let firstPoint = DiveDepthProfileOverlayChartLayout.depthPoint(
            sample: first,
            in: rect,
            viewport: viewport,
            maxDepth: axisMaxDepthMeters,
            topBufferFraction: topBufferFraction,
            horizontalEdgeBufferFraction: horizontalEdgeBufferFraction
        )
        path.addLine(to: CGPoint(x: lastPoint.x, y: rect.minY))
        path.addLine(to: CGPoint(x: firstPoint.x, y: rect.minY))
        path.closeSubpath()
        return path
    }

    /// Closed region under the depth polyline down to the plot floor (static deep-water fill).
    nonisolated static func depthProfileUnderCurveAreaPath(
        samples: [DiveDepthProfileSample],
        in rect: CGRect,
        viewport: DiveDepthProfileChartViewport,
        axisMaxDepthMeters: Double,
        topBufferFraction: Double = depthAxisTopBufferFraction,
        horizontalEdgeBufferFraction: CGFloat = 0
    ) -> Path {
        guard samples.count >= 2 else {
            return Path()
        }

        var path = depthProfileUnderfillBoundaryPath(
            samples: samples,
            in: rect,
            viewport: viewport,
            axisMaxDepthMeters: axisMaxDepthMeters,
            topBufferFraction: topBufferFraction,
            horizontalEdgeBufferFraction: horizontalEdgeBufferFraction
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
