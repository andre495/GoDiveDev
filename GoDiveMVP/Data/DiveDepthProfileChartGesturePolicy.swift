import CoreGraphics
import Foundation

/// Thresholds for separating two-finger pan from pinch-to-zoom on the tank profile chart.
enum DiveDepthProfileChartGesturePolicy: Sendable {
    /// Minimum fractional scale change (e.g. **0.03** → **3%**) before applying a zoom step.
    nonisolated static let minimumPinchScaleDeltaToApply: Double = 0.03

    /// Horizontal travel before pan can take priority over pinch drift.
    nonisolated static let panIntentTranslationThreshold: CGFloat = 10

    /// Horizontal movement must exceed vertical movement by this factor to count as pan intent.
    nonisolated static let panHorizontalDominanceRatio: CGFloat = 1.25

    /// Total pinch scale drift below this (since touch down) still allows pan intent to win.
    nonisolated static let panIntentMaximumCumulativeScaleChange: Double = 0.07

    nonisolated static func shouldApplyPinchZoom(scaleDeltaSinceLastApply: Double) -> Bool {
        abs(scaleDeltaSinceLastApply - 1) >= minimumPinchScaleDeltaToApply
    }

    /// Returns **`true`** when a two-finger drag is clearly horizontal panning, not pinching.
    nonisolated static func prefersPanOverPinch(
        horizontalTranslation: CGFloat,
        verticalTranslation: CGFloat,
        cumulativeScaleChange: Double
    ) -> Bool {
        let absHorizontal = abs(horizontalTranslation)
        let absVertical = abs(verticalTranslation)
        guard absHorizontal >= panIntentTranslationThreshold else { return false }
        guard absHorizontal > absVertical * panHorizontalDominanceRatio else { return false }
        return abs(cumulativeScaleChange) <= panIntentMaximumCumulativeScaleChange
    }
}
