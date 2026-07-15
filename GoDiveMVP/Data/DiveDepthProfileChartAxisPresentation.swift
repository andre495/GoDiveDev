import CoreGraphics
import Foundation

/// Axis ticks and scrub labels for **`DiveDepthProfileOverlayChart`** (testable off the main actor).
enum DiveDepthProfileChartAxisPresentation: Sendable {
    struct Tick: Equatable, Sendable {
        /// Canonical value used for positioning: **elapsed seconds** (time) or **depth meters** (depth).
        let canonicalValue: Double
        let label: String
        /// **0…1** along the axis (time: left→right; depth: surface→max).
        let fraction: Double
    }

    /// Preferred label count for a compact overlay chart (including endpoints when possible).
    nonisolated static let preferredTickCount = 4

    // MARK: - Scrub / display strings

    /// Dive time for scrub callouts and axis ends — e.g. **`12.5 min`**, **`0 min`**.
    nonisolated static func formattedDiveTimeMinutes(elapsedSeconds: Double) -> String {
        let minutes = Swift.max(0, elapsedSeconds) / 60.0
        let roundedToTenth = (minutes * 10).rounded() / 10
        if abs(roundedToTenth - roundedToTenth.rounded()) < 0.001 {
            return "\(Int(roundedToTenth.rounded())) min"
        }
        return String(format: "%.1f min", roundedToTenth)
    }

    nonisolated static func scrubTimeLabel(elapsedSeconds: Double) -> String {
        "Time \(formattedDiveTimeMinutes(elapsedSeconds: elapsedSeconds))"
    }

    nonisolated static func scrubDepthLabel(depthMeters: Double, system: DiveDisplayUnitSystem) -> String {
        "Depth \(DiveQuantityFormatting.depth(meters: depthMeters, system: system))"
    }

    // MARK: - Ticks

    /// Visible-window time ticks: **midpoint** and **end** only (no dive-start **0 min** label).
    nonisolated static func timeTicks(
        viewport: DiveDepthProfileChartViewport,
        targetCount: Int = preferredTickCount
    ) -> [Tick] {
        _ = targetCount
        let start = viewport.elapsedStart
        let end = Swift.max(viewport.elapsedEnd, start + 0.001)
        let span = end - start
        let mid = start + span * 0.5
        return [
            Tick(
                canonicalValue: mid,
                label: formattedDiveTimeMinutes(elapsedSeconds: mid),
                fraction: 0.5
            ),
            Tick(
                canonicalValue: end,
                label: formattedDiveTimeMinutes(elapsedSeconds: end),
                fraction: 1.0
            ),
        ]
    }

    /// Depth ticks from surface (**0**) to **`maxDepthMeters`**, labels in the user’s unit system.
    nonisolated static func depthTicks(
        maxDepthMeters: Double,
        system: DiveDisplayUnitSystem,
        targetCount: Int = preferredTickCount
    ) -> [Tick] {
        let maxDepth = Swift.max(maxDepthMeters, 0.001)
        switch system {
        case .metric:
            let values = niceValues(lowerBound: 0, upperBound: maxDepth, targetCount: targetCount)
            return values.map { meters in
                Tick(
                    canonicalValue: meters,
                    label: axisDepthLabel(meters: meters, system: .metric),
                    fraction: meters / maxDepth
                )
            }
        case .imperial:
            let maxFeet = maxDepth * feetPerMeter
            let feetValues = niceValues(lowerBound: 0, upperBound: maxFeet, targetCount: targetCount)
            return feetValues.map { feet in
                let meters = feet / feetPerMeter
                return Tick(
                    canonicalValue: meters,
                    label: axisDepthLabel(feet: feet),
                    fraction: Swift.min(Swift.max(meters / maxDepth, 0), 1)
                )
            }
        }
    }

    // MARK: - Geometry helpers

    nonisolated static func timeTickPoint(fraction: Double, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + CGFloat(fraction) * rect.width, y: rect.maxY)
    }

    nonisolated static func depthTickPoint(fraction: Double, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX, y: rect.minY + CGFloat(fraction) * rect.height)
    }

    // MARK: - Nice steps

    /// Inclusive nice tick values across **`[lowerBound, upperBound]`**.
    nonisolated static func niceValues(lowerBound: Double, upperBound: Double, targetCount: Int) -> [Double] {
        let lo = Swift.min(lowerBound, upperBound)
        let hi = Swift.max(lowerBound, upperBound)
        let span = hi - lo
        guard span > 0 else { return [lo] }

        let count = Swift.max(targetCount, 2)
        let step = niceStep(range: span, targetCount: count)
        guard step > 0 else { return [lo, hi] }

        var start = (lo / step).rounded(.down) * step
        if start < lo - step * 0.001 {
            start += step
        }

        var values: [Double] = []
        var cursor = start
        let limit = hi + step * 0.001
        while cursor <= limit {
            if cursor >= lo - step * 0.001 {
                values.append(clampTick(cursor, lo: lo, hi: hi))
            }
            cursor += step
            if values.count > 24 { break }
        }
        if values.isEmpty {
            return [lo, hi]
        }
        if values.first.map({ abs($0 - lo) > step * 0.25 }) == true {
            values.insert(lo, at: 0)
        } else {
            values[0] = lo
        }
        if values.last.map({ abs($0 - hi) > step * 0.25 }) == true {
            values.append(hi)
        } else if let lastIndex = values.indices.last {
            values[lastIndex] = hi
        }
        return dedupeAscending(values)
    }

    nonisolated static func niceStep(range: Double, targetCount: Int) -> Double {
        let rough = range / Double(Swift.max(targetCount - 1, 1))
        guard rough > 0 else { return 1 }
        let exponent = floor(log10(rough))
        let magnitude = pow(10.0, exponent)
        let residual = rough / magnitude
        let niceResidual: Double
        if residual <= 1 {
            niceResidual = 1
        } else if residual <= 2 {
            niceResidual = 2
        } else if residual <= 5 {
            niceResidual = 5
        } else {
            niceResidual = 10
        }
        return niceResidual * magnitude
    }

    // MARK: - Private

    private nonisolated static let feetPerMeter = 3.280839895013123

    private nonisolated static func axisDepthLabel(meters: Double, system: DiveDisplayUnitSystem) -> String {
        switch system {
        case .metric:
            if abs(meters - meters.rounded()) < 0.05 {
                return "\(Int(meters.rounded())) m"
            }
            return String(format: "%.1f m", meters)
        case .imperial:
            let feet = meters * feetPerMeter
            return axisDepthLabel(feet: feet)
        }
    }

    private nonisolated static func axisDepthLabel(feet: Double) -> String {
        if abs(feet - feet.rounded()) < 0.05 {
            return "\(Int(feet.rounded())) ft"
        }
        return String(format: "%.0f ft", feet)
    }

    private nonisolated static func clampTick(_ value: Double, lo: Double, hi: Double) -> Double {
        Swift.min(Swift.max(value, lo), hi)
    }

    private nonisolated static func dedupeAscending(_ values: [Double]) -> [Double] {
        guard !values.isEmpty else { return values }
        var result: [Double] = [values[0]]
        for value in values.dropFirst() {
            if abs(value - result[result.count - 1]) > 1e-9 {
                result.append(value)
            }
        }
        return result
    }
}
