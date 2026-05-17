import CoreGraphics

/// Height ratios for the dive overview bottom panel (Strava-style map + sheet).
enum DiveActivityOverviewPanelMetrics {
    /// Compact summary strip (~20% of the screen) over the full-bleed map.
    static let minimizedHeightFraction: CGFloat = 0.20
    /// Default resting detent (~half screen).
    static let mediumHeightFraction: CGFloat = 0.50
    /// Nearly full screen; back button remains above in the parent **`ZStack`**.
    static let largeHeightFraction: CGFloat = 0.85

    static let allDetents: [CGFloat] = [
        minimizedHeightFraction,
        mediumHeightFraction,
        largeHeightFraction,
    ]

    /// Scroll offset (pt) past which a **medium** sheet expands to **large** (one-shot, no per-frame resize).
    static let scrollExpandTriggerOffset: CGFloat = 32
    static let scrollCommitCollapseOffset: CGFloat = -28

    /// Picks the nearest detent after a drag ends.
    static func snappedHeightFraction(
        currentFraction: CGFloat,
        predictedFraction: CGFloat
    ) -> CGFloat {
        let target = predictedFraction
        return allDetents.min(by: { abs($0 - target) < abs($1 - target) }) ?? mediumHeightFraction
    }

    /// Grabber drag snap with one-step transitions at the ends: **minimized ↔ medium ↔ large**.
    /// - **`verticalTranslation`:** drag gesture Y (> 0 finger moved down, < 0 moved up).
    static func snappedHeightFractionAfterDrag(
        currentFraction: CGFloat,
        predictedFraction: CGFloat,
        verticalTranslation: CGFloat
    ) -> CGFloat {
        if isMinimized(currentFraction), verticalTranslation < 0 {
            return mediumHeightFraction
        }
        if isExpanded(currentFraction), verticalTranslation > 0 {
            return mediumHeightFraction
        }
        return snappedHeightFraction(
            currentFraction: currentFraction,
            predictedFraction: predictedFraction
        )
    }

    static func clampedHeightFraction(_ fraction: CGFloat) -> CGFloat {
        min(max(fraction, minimizedHeightFraction), largeHeightFraction)
    }

    /// Visible panel fraction while the grabber is moving (clamped between detents).
    static func heightFractionWhileDragging(
        restingFraction: CGFloat,
        dragTranslation: CGFloat,
        layoutHeight: CGFloat
    ) -> CGFloat {
        guard dragTranslation != 0, layoutHeight > 0 else {
            return restingFraction
        }
        let currentHeight = layoutHeight * restingFraction - dragTranslation
        return clampedHeightFraction(currentHeight / layoutHeight)
    }

    /// Whether scrolling in the panel should snap from **medium** to **large** (not used for continuous layout).
    static func shouldExpandFromScroll(
        restingFraction: CGFloat,
        scrollOffsetY: CGFloat
    ) -> Bool {
        restingFraction <= mediumHeightFraction + 0.02
            && scrollOffsetY >= scrollExpandTriggerOffset
    }

    /// Pull down at the top while **large** → back to **medium** (default).
    static func shouldCollapseToMediumFromScroll(
        restingFraction: CGFloat,
        scrollOffsetY: CGFloat
    ) -> Bool {
        restingFraction >= largeHeightFraction - 0.01
            && scrollOffsetY <= scrollCommitCollapseOffset
    }

    static func isExpanded(_ fraction: CGFloat) -> Bool {
        fraction >= largeHeightFraction - 0.01
    }

    static func isMinimized(_ fraction: CGFloat) -> Bool {
        fraction <= minimizedHeightFraction + 0.02
    }

    /// Next taller detent after **`fraction`**, or **`nil`** if already at **large**.
    static func nextTallerDetent(after fraction: CGFloat) -> CGFloat? {
        guard let index = allDetents.firstIndex(where: { abs($0 - fraction) < 0.03 }) else {
            return allDetents.first { $0 > fraction + 0.02 }
        }
        let nextIndex = index + 1
        guard nextIndex < allDetents.count else { return nil }
        return allDetents[nextIndex]
    }

    /// Next shorter detent after **`fraction`**, or **`nil`** if already at **minimized**.
    static func nextShorterDetent(after fraction: CGFloat) -> CGFloat? {
        guard let index = allDetents.firstIndex(where: { abs($0 - fraction) < 0.03 }) else {
            return allDetents.last { $0 < fraction - 0.02 }
        }
        let previousIndex = index - 1
        guard previousIndex >= 0 else { return nil }
        return allDetents[previousIndex]
    }

    /// Top coverage for map framing: safe area + dive toolbar row (**points**).
    static func mapTopObstructionHeight(
        topSafeInset: CGFloat,
        chromeRowHeight: CGFloat,
        chromeTopPadding: CGFloat
    ) -> CGFloat {
        topSafeInset + chromeTopPadding + chromeRowHeight
    }

    /// VoiceOver label for the current resting detent.
    static func accessibilityDetentDescription(for fraction: CGFloat) -> String {
        if isMinimized(fraction) { return "Minimized" }
        if isExpanded(fraction) { return "Expanded" }
        return "Half height"
    }
}
