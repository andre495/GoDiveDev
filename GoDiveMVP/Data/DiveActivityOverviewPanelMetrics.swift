import CoreGraphics

/// Height ratios for the dive overview bottom panel (Strava-style map + sheet).
///
/// Pure **CoreGraphics** math — **`nonisolated`** so **`DiveActivityOverviewDetent`** and tests stay off the main actor (Swift 6).
enum DiveActivityOverviewPanelMetrics: Sendable {
    /// Compact summary strip (~20% of the screen) over the full-bleed map.
    nonisolated static let minimizedHeightFraction: CGFloat = 0.20
    /// Default resting detent (~half screen).
    nonisolated static let mediumHeightFraction: CGFloat = 0.50
    /// Nearly full screen; back button remains above in the parent **`ZStack`**.
    nonisolated static let largeHeightFraction: CGFloat = 0.85

    nonisolated static let allDetents: [CGFloat] = [
        minimizedHeightFraction,
        mediumHeightFraction,
        largeHeightFraction,
    ]

    /// Gap between the embedded grabber row and panel body (matches **`AppTheme.Sheet.contentTopSpacing`**).
    nonisolated static let panelContentTopPadding: CGFloat = 24

    /// Matches **`DiveActivityOverviewEmbeddedPanel`** grabber row **`minHeight`**.
    nonisolated static let embeddedGrabberRowHeight: CGFloat = 28

    /// Progress **0…1** for map stats box reveal between **minimized** and **medium**.
    nonisolated static func mapStatsRevealProgress(heightFraction: CGFloat) -> CGFloat {
        clampedRevealProgress(
            heightFraction: heightFraction,
            startFraction: minimizedHeightFraction,
            endFraction: mediumHeightFraction
        )
    }

    /// Progress **0…1** for editable map details reveal between **medium** and **large**.
    nonisolated static func mapDetailsRevealProgress(heightFraction: CGFloat) -> CGFloat {
        clampedRevealProgress(
            heightFraction: heightFraction,
            startFraction: mediumHeightFraction,
            endFraction: largeHeightFraction
        )
    }

    /// Map stats box visibility — hidden at **minimized** unless the grabber is dragging upward.
    nonisolated static func mapPanelShowsStatsBox(
        restingDetent: DiveActivityOverviewDetent,
        heightFraction: CGFloat
    ) -> Bool {
        restingDetent != .minimized || mapStatsRevealProgress(heightFraction: heightFraction) > 0
    }

    /// Editable map sections + tags — shown at **large** and while dragging **medium → large**.
    nonisolated static func mapPanelShowsDetails(
        restingDetent: DiveActivityOverviewDetent,
        heightFraction: CGFloat
    ) -> Bool {
        restingDetent == .large || mapDetailsRevealProgress(heightFraction: heightFraction) > 0
    }

    /// Stats box layout height while progressively revealing from **minimized**.
    nonisolated static func mapStatsBoxRevealHeight(
        restingDetent: DiveActivityOverviewDetent,
        heightFraction: CGFloat,
        expandedHeight: CGFloat
    ) -> CGFloat {
        if restingDetent != .minimized {
            return expandedHeight
        }
        return expandedHeight * mapStatsRevealProgress(heightFraction: heightFraction)
    }

    /// Opacity for map details while revealing **medium → large** (full at **large**).
    nonisolated static func mapDetailsPresentationOpacity(
        restingDetent: DiveActivityOverviewDetent,
        heightFraction: CGFloat
    ) -> CGFloat {
        restingDetent == .large ? 1 : mapDetailsRevealProgress(heightFraction: heightFraction)
    }

    nonisolated static func clampedRevealProgress(
        heightFraction: CGFloat,
        startFraction: CGFloat,
        endFraction: CGFloat
    ) -> CGFloat {
        guard endFraction > startFraction else { return heightFraction >= endFraction ? 1 : 0 }
        if heightFraction <= startFraction + 0.015 { return 0 }
        if heightFraction >= endFraction - 0.015 { return 1 }
        return min(max((heightFraction - startFraction) / (endFraction - startFraction), 0), 1)
    }

    /// Scroll content **`minHeight`** so the map header + stats box fill the minimized panel body.
    nonisolated static func mapMinimizedPanelScrollContentMinHeight(
        layoutHeight: CGFloat,
        bottomSafeInset: CGFloat
    ) -> CGFloat {
        let panelHeight = DiveActivityOverviewDetent.sheetHeight(
            for: .minimized,
            layoutHeight: layoutHeight,
            bottomSafeInset: bottomSafeInset
        )
        let bodyHeight = panelHeight - embeddedGrabberRowHeight
        return max(0, bodyHeight - panelContentTopPadding - 24)
    }

    /// Scroll offset (pt) past which a **medium** sheet expands to **large** (one-shot, no per-frame resize).
    nonisolated static let scrollExpandTriggerOffset: CGFloat = 32
    nonisolated static let scrollCommitCollapseOffset: CGFloat = -28

    /// Picks the nearest detent after a drag ends.
    nonisolated static func snappedHeightFraction(
        currentFraction: CGFloat,
        predictedFraction: CGFloat
    ) -> CGFloat {
        let target = predictedFraction
        return allDetents.min(by: { abs($0 - target) < abs($1 - target) }) ?? mediumHeightFraction
    }

    /// Grabber drag snap with one-step transitions at the ends: **minimized ↔ medium ↔ large**.
    /// - **`verticalTranslation`:** drag gesture Y (> 0 finger moved down, < 0 moved up).
    nonisolated static func snappedHeightFractionAfterDrag(
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

    nonisolated static func clampedHeightFraction(_ fraction: CGFloat) -> CGFloat {
        min(max(fraction, minimizedHeightFraction), largeHeightFraction)
    }

    /// Visible panel fraction while the grabber is moving (clamped between detents).
    nonisolated static func heightFractionWhileDragging(
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
    nonisolated static func shouldExpandFromScroll(
        restingFraction: CGFloat,
        scrollOffsetY: CGFloat
    ) -> Bool {
        restingFraction <= mediumHeightFraction + 0.02
            && scrollOffsetY >= scrollExpandTriggerOffset
    }

    /// Pull down at the top while **large** → back to **medium** (default).
    nonisolated static func shouldCollapseToMediumFromScroll(
        restingFraction: CGFloat,
        scrollOffsetY: CGFloat
    ) -> Bool {
        restingFraction >= largeHeightFraction - 0.01
            && scrollOffsetY <= scrollCommitCollapseOffset
    }

    nonisolated static func isExpanded(_ fraction: CGFloat) -> Bool {
        fraction >= largeHeightFraction - 0.01
    }

    nonisolated static func isMinimized(_ fraction: CGFloat) -> Bool {
        fraction <= minimizedHeightFraction + 0.02
    }

    /// Next taller detent after **`fraction`**, or **`nil`** if already at **large**.
    nonisolated static func nextTallerDetent(after fraction: CGFloat) -> CGFloat? {
        guard let index = allDetents.firstIndex(where: { abs($0 - fraction) < 0.03 }) else {
            return allDetents.first { $0 > fraction + 0.02 }
        }
        let nextIndex = index + 1
        guard nextIndex < allDetents.count else { return nil }
        return allDetents[nextIndex]
    }

    /// Next shorter detent after **`fraction`**, or **`nil`** if already at **minimized**.
    nonisolated static func nextShorterDetent(after fraction: CGFloat) -> CGFloat? {
        guard let index = allDetents.firstIndex(where: { abs($0 - fraction) < 0.03 }) else {
            return allDetents.last { $0 < fraction - 0.02 }
        }
        let previousIndex = index - 1
        guard previousIndex >= 0 else { return nil }
        return allDetents[previousIndex]
    }

    /// Top coverage for map framing: safe area + dive toolbar row (**points**).
    nonisolated static func mapTopObstructionHeight(
        topSafeInset: CGFloat,
        chromeRowHeight: CGFloat,
        chromeTopPadding: CGFloat
    ) -> CGFloat {
        topSafeInset + chromeTopPadding + chromeRowHeight
    }

    /// Extra space below the back + tab row before the map **info** site-prompt control.
    nonisolated static let mapSitePromptInfoGapBelowChrome: CGFloat = 72

    /// Top padding for **`DiveMapSitePromptInfoButton`** — fully below the tab menu.
    nonisolated static func mapSitePromptInfoButtonTopPadding(
        topSafeInset: CGFloat,
        chromeRowHeight: CGFloat,
        chromeTopPadding: CGFloat
    ) -> CGFloat {
        mapTopObstructionHeight(
            topSafeInset: topSafeInset,
            chromeRowHeight: chromeRowHeight,
            chromeTopPadding: chromeTopPadding
        ) + mapSitePromptInfoGapBelowChrome
    }

    /// Extra top inset before the media carousel at **medium** so it sits at the same on-screen Y as **minimized**.
    nonisolated static func mediaCarouselScreenAlignmentTopInset(layoutHeight: CGFloat) -> CGFloat {
        guard layoutHeight > 0 else { return 0 }
        return layoutHeight * (mediumHeightFraction - minimizedHeightFraction)
    }

    /// Top padding for **Tag marine life** on the media hero — same clearance as the map info control.
    nonisolated static func marineLifeTagButtonTopPadding(
        topSafeInset: CGFloat,
        chromeRowHeight: CGFloat,
        chromeTopPadding: CGFloat
    ) -> CGFloat {
        mapSitePromptInfoButtonTopPadding(
            topSafeInset: topSafeInset,
            chromeRowHeight: chromeRowHeight,
            chromeTopPadding: chromeTopPadding
        )
    }

    /// VoiceOver label for the current resting detent.
    nonisolated static func accessibilityDetentDescription(for fraction: CGFloat) -> String {
        if isMinimized(fraction) { return "Minimized" }
        if isExpanded(fraction) { return "Expanded" }
        return "Half height"
    }
}
