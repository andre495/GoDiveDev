import CoreGraphics

/// Height ratios for the dive overview bottom panel (Strava-style map + sheet).
///
/// Pure **CoreGraphics** math — **`nonisolated`** so **`DiveActivityOverviewDetent`** and tests stay off the main actor (Swift 6).
enum DiveActivityOverviewPanelMetrics: Sendable {
    /// Compact summary strip (~20% of the screen) over the full-bleed map.
    nonisolated static let minimizedHeightFraction: CGFloat = 0.20

    /// Reference **large** fraction on **`DiveActivityOverviewSheetLayoutContext.presentationReference`** — matches pushed blue sheet panel height.
    nonisolated static var referenceLargeHeightFraction: CGFloat {
        largeHeightFraction(in: .presentationReference)
    }

    /// Legacy alias — half-screen detent removed; retained for media carousel alignment tests only.
    nonisolated static let mediumHeightFraction: CGFloat = 0.50

    nonisolated static var allDetents: [CGFloat] {
        [minimizedHeightFraction, referenceLargeHeightFraction]
    }

    /// Sheet height for the **large** resting detent — same seam math as **`BlueSheetDetailPage`** on pushed detail.
    nonisolated static func largeSheetHeight(in context: DiveActivityOverviewSheetLayoutContext) -> CGFloat {
        let heroHeight = HomeOverviewLayout.pushedHeroLayoutMetrics(
            geometryHeight: context.layoutHeight,
            screenWidth: context.screenWidth,
            topSafeAreaInset: context.topSafeInset,
            statsPanelContentHeight: HomeOverviewLayout.heroLayoutStatsPanelContentHeight
        ).heroHeight
        return HomeOverviewLayout.sheetSeamYFromScreenBottom(
            pageKind: .buddyDetail,
            geometryHeight: context.layoutHeight,
            heroHeight: heroHeight
        )
    }

    /// Height fraction for the **large** detent at the current layout size.
    nonisolated static func largeHeightFraction(in context: DiveActivityOverviewSheetLayoutContext) -> CGFloat {
        guard context.layoutHeight > 0 else { return referenceLargeHeightFraction }
        let sheetHeight = largeSheetHeight(in: context)
        let fraction = (sheetHeight - context.bottomSafeInset) / context.layoutHeight
        return clampedHeightFraction(fraction, largeRestingFraction: fraction)
    }

    /// Gap between the embedded grabber row and panel body.
    nonisolated static let panelContentTopPadding: CGFloat = 10

    /// Bottom inset on embedded overview panel scroll content (matches **`AppTheme.Spacing.lg`**).
    nonisolated static let panelContentBottomPadding: CGFloat = 24

    /// Extra feather below the pinned fish/buddy chrome height for scroll-under fade.
    nonisolated static let mediaLargeDetentPinnedChromeFadeExtra: CGFloat = 12

    /// Matches **`DiveActivityOverviewEmbeddedPanel`** grabber row **`minHeight`**.
    nonisolated static let embeddedGrabberRowHeight: CGFloat = 28

    /// Progress **0…1** for map stats box reveal between **minimized** and **large**.
    nonisolated static func mapStatsRevealProgress(
        heightFraction: CGFloat,
        largeRestingFraction: CGFloat = referenceLargeHeightFraction
    ) -> CGFloat {
        clampedRevealProgress(
            heightFraction: heightFraction,
            startFraction: minimizedHeightFraction,
            endFraction: largeRestingFraction
        )
    }

    /// Progress **0…1** for editable map details at **large** (binary until content pass realigns).
    nonisolated static func mapDetailsRevealProgress(
        heightFraction: CGFloat,
        largeRestingFraction: CGFloat = referenceLargeHeightFraction
    ) -> CGFloat {
        isLarge(heightFraction, largeRestingFraction: largeRestingFraction) ? 1 : 0
    }

    /// Map stats box visibility — hidden at **minimized** unless the grabber is dragging upward.
    nonisolated static func mapPanelShowsStatsBox(
        restingDetent: DiveActivityOverviewDetent,
        heightFraction: CGFloat,
        largeRestingFraction: CGFloat = referenceLargeHeightFraction
    ) -> Bool {
        restingDetent != .minimized || mapStatsRevealProgress(
            heightFraction: heightFraction,
            largeRestingFraction: largeRestingFraction
        ) > 0
    }

    /// Editable map sections + tags — shown at **large** and while dragging toward **large**.
    nonisolated static func mapPanelShowsDetails(
        restingDetent: DiveActivityOverviewDetent,
        heightFraction: CGFloat,
        largeRestingFraction: CGFloat = referenceLargeHeightFraction
    ) -> Bool {
        restingDetent == .large || mapDetailsRevealProgress(
            heightFraction: heightFraction,
            largeRestingFraction: largeRestingFraction
        ) > 0
    }

    /// Stats box layout height while progressively revealing from **minimized**.
    nonisolated static func mapStatsBoxRevealHeight(
        restingDetent: DiveActivityOverviewDetent,
        heightFraction: CGFloat,
        expandedHeight: CGFloat,
        largeRestingFraction: CGFloat = referenceLargeHeightFraction
    ) -> CGFloat {
        if restingDetent != .minimized {
            return expandedHeight
        }
        return expandedHeight * mapStatsRevealProgress(
            heightFraction: heightFraction,
            largeRestingFraction: largeRestingFraction
        )
    }

    /// Opacity for map details while revealing toward **large** (full at **large**).
    nonisolated static func mapDetailsPresentationOpacity(
        restingDetent: DiveActivityOverviewDetent,
        heightFraction: CGFloat,
        largeRestingFraction: CGFloat = referenceLargeHeightFraction
    ) -> CGFloat {
        restingDetent == .large
            ? 1
            : mapDetailsRevealProgress(
                heightFraction: heightFraction,
                largeRestingFraction: largeRestingFraction
            )
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

    /// Scroll offset (pt) past which a compact sheet expands to **large** (one-shot, no per-frame resize).
    nonisolated static let scrollExpandTriggerOffset: CGFloat = 32
    nonisolated static let scrollCommitCollapseOffset: CGFloat = -28

    /// Picks the nearest detent after a drag ends.
    nonisolated static func snappedHeightFraction(
        currentFraction: CGFloat,
        predictedFraction: CGFloat,
        largeRestingFraction: CGFloat = referenceLargeHeightFraction
    ) -> CGFloat {
        let target = predictedFraction
        return allDetents(largeRestingFraction: largeRestingFraction)
            .min(by: { abs($0 - target) < abs($1 - target) }) ?? largeRestingFraction
    }

    /// Grabber drag snap — **minimized ↔ large** only.
    nonisolated static func snappedHeightFractionAfterDrag(
        currentFraction: CGFloat,
        predictedFraction: CGFloat,
        verticalTranslation: CGFloat,
        largeRestingFraction: CGFloat = referenceLargeHeightFraction
    ) -> CGFloat {
        if isMinimized(currentFraction), verticalTranslation < 0 {
            return largeRestingFraction
        }
        if isLarge(currentFraction, largeRestingFraction: largeRestingFraction), verticalTranslation > 0 {
            return minimizedHeightFraction
        }
        return snappedHeightFraction(
            currentFraction: currentFraction,
            predictedFraction: predictedFraction,
            largeRestingFraction: largeRestingFraction
        )
    }

    nonisolated static func allDetents(largeRestingFraction: CGFloat) -> [CGFloat] {
        [minimizedHeightFraction, largeRestingFraction]
    }

    nonisolated static func clampedHeightFraction(
        _ fraction: CGFloat,
        largeRestingFraction: CGFloat = referenceLargeHeightFraction
    ) -> CGFloat {
        min(max(fraction, minimizedHeightFraction), largeRestingFraction)
    }

    /// Visible panel fraction while the grabber is moving (clamped between detents).
    nonisolated static func heightFractionWhileDragging(
        restingFraction: CGFloat,
        dragTranslation: CGFloat,
        layoutHeight: CGFloat,
        largeRestingFraction: CGFloat = referenceLargeHeightFraction
    ) -> CGFloat {
        guard dragTranslation != 0, layoutHeight > 0 else {
            return restingFraction
        }
        let currentHeight = layoutHeight * restingFraction - dragTranslation
        return clampedHeightFraction(
            currentHeight / layoutHeight,
            largeRestingFraction: largeRestingFraction
        )
    }

    /// Whether scrolling in the panel should snap from compact to **large**.
    nonisolated static func shouldExpandFromScroll(
        restingFraction: CGFloat,
        scrollOffsetY: CGFloat,
        largeRestingFraction: CGFloat = referenceLargeHeightFraction
    ) -> Bool {
        !isLarge(restingFraction, largeRestingFraction: largeRestingFraction)
            && scrollOffsetY >= scrollExpandTriggerOffset
    }

    /// Pull down at the top while **large** → back to **minimized**.
    nonisolated static func shouldCollapseFromScroll(
        restingFraction: CGFloat,
        scrollOffsetY: CGFloat,
        largeRestingFraction: CGFloat = referenceLargeHeightFraction
    ) -> Bool {
        isLarge(restingFraction, largeRestingFraction: largeRestingFraction)
            && scrollOffsetY <= scrollCommitCollapseOffset
    }

    /// Back-compat alias while call sites migrate.
    nonisolated static func shouldCollapseToMediumFromScroll(
        restingFraction: CGFloat,
        scrollOffsetY: CGFloat
    ) -> Bool {
        shouldCollapseFromScroll(restingFraction: restingFraction, scrollOffsetY: scrollOffsetY)
    }

    nonisolated static func isLarge(
        _ fraction: CGFloat,
        largeRestingFraction: CGFloat = referenceLargeHeightFraction
    ) -> Bool {
        fraction >= largeRestingFraction - 0.02
    }

    /// Back-compat — **large** resting detent.
    nonisolated static func isExpanded(_ fraction: CGFloat) -> Bool {
        isLarge(fraction)
    }

    nonisolated static func isMinimized(_ fraction: CGFloat) -> Bool {
        fraction <= minimizedHeightFraction + 0.02
    }

    /// Next taller detent after **`fraction`**, or **`nil`** if already at **large**.
    nonisolated static func nextTallerDetent(
        after fraction: CGFloat,
        largeRestingFraction: CGFloat = referenceLargeHeightFraction
    ) -> CGFloat? {
        guard !isLarge(fraction, largeRestingFraction: largeRestingFraction) else { return nil }
        return largeRestingFraction
    }

    /// Next shorter detent after **`fraction`**, or **`nil`** if already at **minimized**.
    nonisolated static func nextShorterDetent(
        after fraction: CGFloat,
        largeRestingFraction: CGFloat = referenceLargeHeightFraction
    ) -> CGFloat? {
        guard !isMinimized(fraction) else { return nil }
        return minimizedHeightFraction
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

    /// Height of the sheet band above the minimized carousel slot for a resting detent.
    nonisolated static func mediaCarouselScreenAlignmentTopInset(
        layoutHeight: CGFloat,
        detent: DiveActivityOverviewDetent,
        layoutContext: DiveActivityOverviewSheetLayoutContext
    ) -> CGFloat {
        guard layoutHeight > 0 else { return 0 }
        let detentFraction = detent.resolvedHeightFraction(in: layoutContext)
        return layoutHeight * (detentFraction - minimizedHeightFraction)
    }

    /// Back-compat — **large** alignment math in tests.
    nonisolated static func mediaCarouselExpandedRegionHeight(layoutHeight: CGFloat) -> CGFloat {
        mediaCarouselScreenAlignmentTopInset(
            layoutHeight: layoutHeight,
            detent: .large,
            layoutContext: .presentationReference
        )
    }

    nonisolated static func mediaCarouselScreenAlignmentTopInset(
        layoutHeight: CGFloat,
        detent: DiveActivityOverviewDetent
    ) -> CGFloat {
        mediaCarouselScreenAlignmentTopInset(
            layoutHeight: layoutHeight,
            detent: detent,
            layoutContext: .presentationReference
        )
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
        return "Expanded"
    }
}
