import Foundation

/// Visible elapsed-time window for the minimized / landscape depth profile chart.
struct DiveDepthProfileChartViewport: Equatable, Sendable {
    var elapsedStart: Double
    var elapsedEnd: Double

    /// Smallest zoom window as a fraction of the full dive duration.
    nonisolated static let minimumVisibleElapsedFraction: Double = 0.04
    /// Smallest zoom window in seconds (short dives).
    nonisolated static let minimumVisibleElapsedSeconds: Double = 20

    nonisolated var elapsedSpan: Double {
        max(elapsedEnd - elapsedStart, 0.001)
    }

    nonisolated static func full(elapsedMax: Double) -> Self {
        let maxElapsed = max(elapsedMax, 0.001)
        return Self(elapsedStart: 0, elapsedEnd: maxElapsed)
    }

    nonisolated func isZoomed(fullElapsedMax: Double) -> Bool {
        elapsedSpan < max(fullElapsedMax, 0.001) * 0.98
    }

    nonisolated func contains(elapsedSeconds: Double) -> Bool {
        elapsedSeconds >= elapsedStart && elapsedSeconds <= elapsedEnd
    }

    /// Zooms the elapsed window around **`anchorFraction`** (**0…1** within the current window).
    nonisolated mutating func zoom(
        scale: Double,
        anchorFraction: Double,
        fullElapsedMax: Double
    ) {
        guard scale > 0, fullElapsedMax > 0 else { return }
        let fullMax = max(fullElapsedMax, 0.001)
        let anchor = elapsedStart + min(max(anchorFraction, 0), 1) * elapsedSpan
        let minSpan = min(
            fullMax * Self.minimumVisibleElapsedFraction,
            Self.minimumVisibleElapsedSeconds
        )
        let newSpan = min(max(elapsedSpan / scale, minSpan), fullMax)
        var newStart = anchor - min(max(anchorFraction, 0), 1) * newSpan
        var newEnd = newStart + newSpan
        if newStart < 0 {
            newStart = 0
            newEnd = newSpan
        }
        if newEnd > fullMax {
            newEnd = fullMax
            newStart = max(0, fullMax - newSpan)
        }
        elapsedStart = newStart
        elapsedEnd = newEnd
    }

    /// Pans by **`elapsedDelta`** seconds (positive → later in the dive).
    nonisolated mutating func pan(elapsedDelta: Double, fullElapsedMax: Double) {
        let fullMax = max(fullElapsedMax, 0.001)
        guard elapsedSpan < fullMax * 0.999 else { return }

        var newStart = elapsedStart + elapsedDelta
        var newEnd = elapsedEnd + elapsedDelta
        if newStart < 0 {
            newEnd -= newStart
            newStart = 0
        }
        if newEnd > fullMax {
            let overflow = newEnd - fullMax
            newStart -= overflow
            newEnd = fullMax
            newStart = max(0, newStart)
        }
        elapsedStart = newStart
        elapsedEnd = newEnd
    }

    nonisolated mutating func reset(fullElapsedMax: Double) {
        self = Self.full(elapsedMax: fullElapsedMax)
    }
}
