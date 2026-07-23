import Foundation
import CoreGraphics
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Auto-advance rules for the Home featured-media carousel.
enum HomeMediaCarouselPresentation: Sendable {

    /// How long a photo slide stays visible before advancing.
    nonisolated static let photoDisplaySeconds: TimeInterval = 10

    /// Fallback dwell for a video slide when Photos duration is unknown (multi-slide auto-advance).
    nonisolated static var videoDisplayFallbackSeconds: TimeInterval { photoDisplaySeconds }

    /// Home featured muted videos always loop while their pager page is active.
    nonisolated static func shouldLoopCarouselVideo(isPagePlaybackActive: Bool) -> Bool {
        isPagePlaybackActive
    }

    /// Multi-slide carousels still progress after one playthrough (or the photo dwell fallback).
    nonisolated static func videoAutoAdvanceSeconds(
        assetDurationSeconds: Double?,
        slideCount: Int
    ) -> TimeInterval? {
        guard shouldAutoAdvance(slideCount: slideCount) else { return nil }
        if let assetDurationSeconds, assetDurationSeconds > 0 {
            return assetDurationSeconds
        }
        return videoDisplayFallbackSeconds
    }

    /// Bucket size (points) for hero image **`.task`** / session-cache width keys — prevents ±1 pt
    /// geometry jitter from cancelling in-flight PhotoKit progressive loads.
    nonisolated static let imageLoadWidthBucketPoints: CGFloat = 8

    /// Stable container width for carousel image load identity and cache edges.
    nonisolated static func stableImageLoadWidth(_ width: CGFloat) -> CGFloat {
        guard width > 0 else { return 0 }
        let bucket = imageLoadWidthBucketPoints
        return (width / bucket).rounded() * bucket
    }

    nonisolated static func stableImageLoadWidthKey(_ width: CGFloat) -> Int {
        Int(stableImageLoadWidth(width))
    }

    /// Shared height for dive link capsule + tagged species / buddy icon chips (**`HomeMediaCarouselDiveLinkButton`** two-line layout).
    nonisolated static var slideChromeControlHeight: CGFloat {
        #if canImport(UIKit)
        let titleFont = UIFont.preferredFont(forTextStyle: .subheadline)
        let numberFont = UIFont.preferredFont(forTextStyle: .caption2)
        let textStackHeight = ceil(titleFont.lineHeight + numberFont.lineHeight)
        let iconHeight = ceil(titleFont.lineHeight)
        return max(textStackHeight, iconHeight) + 8 * 2
        #else
        return 48
        #endif
    }

    /// Minimum tappable square for fish / buddy icon chips (visual glass circle may stay smaller).
    nonisolated static let taggedOverlayIconTapDimension: CGFloat = 56

    /// Next slide index; wraps from last → first.
    nonisolated static func nextIndex(after current: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return (current + 1) % count
    }

    /// **`TabView`** page count — appends a duplicate first slide so last → first animates forward.
    nonisolated static func loopingPagerSlideCount(slideCount: Int) -> Int {
        slideCount > 1 ? slideCount + 1 : max(slideCount, 0)
    }

    /// Maps pager position to the real highlight index (duplicate last page shows slide **0**).
    nonisolated static func logicalSlideIndex(pagerIndex: Int, slideCount: Int) -> Int {
        guard slideCount > 0 else { return 0 }
        return pagerIndex % slideCount
    }

    /// Auto-advance target — from last real slide, step onto duplicate first instead of wrapping backward.
    nonisolated static func nextLoopingPagerIndex(after pagerIndex: Int, slideCount: Int) -> Int {
        guard slideCount > 1 else { return 0 }
        if pagerIndex == slideCount - 1 {
            return slideCount
        }
        return min(pagerIndex + 1, slideCount)
    }

    /// After landing on the duplicate first page, snap back to index **0** without animation.
    nonisolated static func shouldResetLoopingPagerIndex(pagerIndex: Int, slideCount: Int) -> Bool {
        slideCount > 1 && pagerIndex == slideCount
    }

    /// Programmatic slide-advance animation length (forward wrap onto the duplicate first page).
    nonisolated static let slideAdvanceAnimationSeconds: TimeInterval = 0.35

    /// Delay before the duplicate-first page snaps back to index **0**.
    ///
    /// Must outlast **`slideAdvanceAnimationSeconds`** plus settle time: a non-animated selection
    /// jump issued while the pager is still animating / decelerating desyncs the paged
    /// **`TabView`** (it keeps showing the duplicate last page — which has no next page — while
    /// the binding says **0**), leaving forward swipes on the first item unresponsive until the
    /// next auto-advance resyncs it.
    nonisolated static let loopingPagerResetDelaySeconds: TimeInterval = 0.6

    nonisolated static func shouldAutoAdvance(slideCount: Int) -> Bool {
        slideCount > 1
    }

    /// After a video finishes: sole-clip carousels restart in place. Multi-slide carousels advance
    /// on a timer while the mute clip **loops** (`shouldLoopCarouselVideo`); this flag is kept for
    /// finishSlide callers that still receive an end event.
    nonisolated static func shouldRestartClipAfterPlaybackFinished(slideCount: Int) -> Bool {
        slideCount <= 1
    }

    /// Home carousel has at most **`carouselLimit`** picks — keep every slide hydrated for the session.
    nonisolated static func keepsAllSlidesLoaded(slideCount: Int) -> Bool {
        slideCount > 0 && slideCount <= HomeMediaHighlightPresentation.carouselLimit
    }

    /// Only the **selected pager page** may drive muted playback — not every page that shares the
    /// same logical slide. The looping carousel duplicates slide **0** as the last pager page; both
    /// would otherwise bind one **`AVPlayer`** to two layers and leave the first item silent / stuck.
    nonisolated static func isPagerPagePlaybackActive(
        pagerIndex: Int,
        selectedPagerIndex: Int
    ) -> Bool {
        pagerIndex == selectedPagerIndex
    }

    /// When the selected page becomes playback-active and a muted player is already cached, remount
    /// so seek / **`readyToPlay`** observation can start playback (first paint often attaches early).
    nonisolated static func shouldRemountCarouselPlayerWhenBecomingActive(
        isBecomingActive: Bool,
        hasPreparedPlayer: Bool
    ) -> Bool {
        isBecomingActive && hasPreparedPlayer
    }

    /// Only the visible slide may auto-advance (ignores stale end-of-playback callbacks).
    nonisolated static func shouldAdvanceFromSlide(
        selectedIndex: Int,
        finishingSlideIndex: Int,
        isPlaybackAllowed: Bool,
        holdsSlideForInteraction: Bool = false
    ) -> Bool {
        isPlaybackAllowed
            && selectedIndex == finishingSlideIndex
            && !holdsSlideForInteraction
    }

    /// Fish overlay or expanded buddy list — keep the current slide playing on loop.
    nonisolated static func holdsSlideForInteraction(
        showsMarineLifeOverlay: Bool,
        hasExpandedBuddyList: Bool
    ) -> Bool {
        showsMarineLifeOverlay || hasExpandedBuddyList
    }

    /// Bump resume token when playback becomes allowed again (return from push, app foreground, carousel remount).
    nonisolated static func shouldBumpPlaybackResumeWhenAllowed(
        wasPlaybackAllowed: Bool,
        isPlaybackAllowed: Bool
    ) -> Bool {
        !wasPlaybackAllowed && isPlaybackAllowed
    }

    /// Dismissing fish / buddy overlays continues the warm stream — never remount the player on overlay close.
    nonisolated static let bumpsPlaybackResumeWhenInteractionHoldEnds = false

    /// PhotoKit identity keys for carousel video slides (Home resume invalidates these after dive overview handoff).
    @MainActor
    static func carouselVideoSourceIdentityKeys(
        highlights: [HomeMediaHighlight],
        mediaByID: [UUID: DiveMediaPhoto]
    ) -> [String] {
        highlights.compactMap { highlight in
            guard let media = mediaByID[highlight.mediaID],
                  media.resolvedMediaKind == .video,
                  let source = media.videoPlaybackSource
            else { return nil }
            return source.identityKey
        }
    }

    nonisolated static let marineLifeOverlayCornerRadius: CGFloat = 0

    nonisolated static func marineLifeOverlaySize(width: CGFloat, height: CGFloat) -> CGSize {
        CGSize(width: max(width, 1), height: max(height, 1))
    }

    /// Fish overlay frame height should match **`HomeMediaCarouselLayout.carouselContentHeight`** so the dimming panel covers the same region as slide media (including top safe-area bleed inside **`PushedHeroBand`**).
    nonisolated static func marineLifeCarouselOverlayFrameHeight(
        heroBandHeight: CGFloat,
        topSafeAreaInset: CGFloat,
        appliesOwnTopSafeAreaBleed: Bool
    ) -> CGFloat {
        appliesOwnTopSafeAreaBleed
            ? heroBandHeight
            : heroBandHeight + topSafeAreaInset
    }

    /// Compact feature image on the Home fish overlay (smaller than trip media card).
    nonisolated static func marineLifeCarouselOverlayImageHeight(previewHeight: CGFloat) -> CGFloat {
        min(104, max(72, previewHeight * 0.12))
    }

    nonisolated static func marineLifeCarouselOverlayImageMaxWidth(previewWidth: CGFloat) -> CGFloat {
        min(204, max(144, previewWidth * 0.48))
    }

    /// Text row beside the faded feature column (name + italic description).
    nonisolated static let marineLifeCarouselOverlaySpeciesRowHeight: CGFloat = 56

    nonisolated static let marineLifeCarouselOverlaySpeciesCommonNameLineHeight: CGFloat = 20
    nonisolated static let marineLifeCarouselOverlaySpeciesDescriptionLineHeight: CGFloat = 15
    nonisolated static let marineLifeCarouselOverlaySpeciesNameToDescriptionSpacing: CGFloat = 4

    /// Caps italic description lines so copy ends above page dots (reserves up to two common-name lines).
    nonisolated static func marineLifeCarouselOverlaySpeciesDescriptionLineLimit(
        speciesNameTopInset: CGFloat,
        pageIndicatorTopInset: CGFloat,
        reservedCommonNameLineCount: Int = 2
    ) -> Int {
        let reservedNameHeight = CGFloat(max(1, reservedCommonNameLineCount))
            * marineLifeCarouselOverlaySpeciesCommonNameLineHeight
        let availableHeight = pageIndicatorTopInset
            - speciesNameTopInset
            - reservedNameHeight
            - marineLifeCarouselOverlaySpeciesNameToDescriptionSpacing
            - marineLifeCarouselOverlaySpeciesToPageIndicatorSpacing
        guard availableHeight > 0 else { return 1 }
        return max(1, Int(floor(availableHeight / marineLifeCarouselOverlaySpeciesDescriptionLineHeight)))
    }

    /// **`aboutText`** shown under the common name; falls back to **`distinctiveFeatures`** when empty.
    nonisolated static func marineLifeCarouselOverlaySpeciesDescriptionText(
        aboutText: String,
        distinctiveFeatures: String = ""
    ) -> String? {
        let trimmedAbout = aboutText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAbout.isEmpty {
            return trimmedAbout
        }
        let trimmedDistinctive = distinctiveFeatures.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedDistinctive.isEmpty ? nil : trimmedDistinctive
    }

    nonisolated static func marineLifeCarouselOverlayPageHeight(
        previewHeight: CGFloat,
        speciesCount: Int
    ) -> CGFloat {
        _ = previewHeight
        _ = speciesCount
        return marineLifeCarouselOverlaySpeciesRowHeight
    }

    nonisolated static func marineLifeCarouselOverlayContentHeight(previewHeight: CGFloat) -> CGFloat {
        _ = previewHeight
        return marineLifeCarouselOverlaySpeciesRowHeight
    }

    /// Faded feature column spans from the header-aligned top down to the hero band floor.
    nonisolated static func marineLifeCarouselOverlayFeatureImageColumnHeight(
        closeTopInset: CGFloat,
        pageIndicatorTopInset: CGFloat,
        heroBandBottomYFromTop: CGFloat? = nil,
        speciesRowHeight: CGFloat = marineLifeCarouselOverlaySpeciesRowHeight
    ) -> CGFloat {
        let pageIndicatorColumnHeight = max(
            pageIndicatorTopInset
                - closeTopInset
                - marineLifeCarouselOverlaySpeciesToPageIndicatorSpacing
                - marineLifeCarouselOverlayFeatureImageColumnBottomLift,
            speciesRowHeight
        )
        guard let heroBandBottomYFromTop else {
            return pageIndicatorColumnHeight
        }
        let heroBandColumnHeight = max(
            heroBandBottomYFromTop
                - closeTopInset
                - marineLifeCarouselOverlayFeatureImageColumnBottomLift,
            speciesRowHeight
        )
        return max(pageIndicatorColumnHeight, heroBandColumnHeight)
    }

    /// Backward-compatible overload — prefer **`pageIndicatorTopInset`** at call sites.
    nonisolated static func marineLifeCarouselOverlayFeatureImageColumnHeight(
        closeTopInset: CGFloat,
        speciesContentTopInset: CGFloat,
        speciesRowHeight: CGFloat = marineLifeCarouselOverlaySpeciesRowHeight
    ) -> CGFloat {
        max(speciesContentTopInset + speciesRowHeight - closeTopInset, 1)
    }

    /// Gradient stop (0–1) where the feature column reaches full opacity — fades to clear above.
    nonisolated static let marineLifeCarouselOverlayFeatureImageFadeOpaqueStop: CGFloat = 0.58

    /// Leading inset for the species row (image + name) — nudges content left of center.
    nonisolated static let marineLifeCarouselOverlaySpeciesContentLeadingInset: CGFloat = 24

    /// Bias species image + name in the visible hero band (legacy — species row now header-aligned).
    nonisolated static let marineLifeCarouselOverlaySpeciesVerticalBias: CGFloat = 0.68

    /// Drops the species common name below the feature image top.
    nonisolated static let marineLifeCarouselOverlaySpeciesNameTopOffsetFromFeatureImageTop: CGFloat = 21

    /// Legacy alias — prefer **`marineLifeCarouselOverlaySpeciesNameTopOffsetFromFeatureImageTop`**.
    nonisolated static let marineLifeCarouselOverlaySpeciesContentDownshift: CGFloat = marineLifeCarouselOverlaySpeciesNameTopOffsetFromFeatureImageTop

    /// Small gap between page-dot bottom and the sheet seam line (before **`marineLifeCarouselOverlayPageIndicatorTopOffsetFromSeamSpacing`**).
    nonisolated static let marineLifeCarouselOverlayPageIndicatorClearanceAboveSeam: CGFloat = AppTheme.Spacing.sm

    /// Tuned on device — positive moves page dots **down** from seam-spaced default.
    nonisolated static let marineLifeCarouselOverlayPageIndicatorTopOffsetFromSeamSpacing: CGFloat = 65

    /// Tuned on device — negative moves the seam **up** (page dots + species stack follow).
    nonisolated static let marineLifeCarouselOverlaySheetSeamYOffsetFromTemplate: CGFloat = -25

    nonisolated static let marineLifeCarouselOverlaySpeciesToPageIndicatorSpacing: CGFloat = 12

    /// Tuned on device — positive shortens the feature column (lifts the image bottom).
    /// Raises the feature column bottom edge without moving text, close, or page dots.
    nonisolated static let marineLifeCarouselOverlayFeatureImageColumnBottomLift: CGFloat = 126

    /// Tuned on device — positive pushes the feature column top down (bottom stays anchored).
    nonisolated static let marineLifeCarouselOverlayFeatureImageColumnTopCrop: CGFloat = 103

    /// Tuned on device — vertical nudge for the whole feature column after top crop.
    nonisolated static let marineLifeCarouselOverlayFeatureImageColumnVerticalOffset: CGFloat = -83

    /// Positive crop pushes the container top down and keeps the bottom anchored.
    nonisolated static func marineLifeCarouselOverlayFeatureImageColumnLayout(
        closeTopInset: CGFloat,
        featureImageColumnHeight: CGFloat,
        topCrop: CGFloat = marineLifeCarouselOverlayFeatureImageColumnTopCrop
    ) -> (topInset: CGFloat, height: CGFloat) {
        let minimumHeight = marineLifeCarouselOverlaySpeciesRowHeight
        let maxCropDown = max(0, featureImageColumnHeight - minimumHeight)
        let clampedTopCrop = min(max(topCrop, -closeTopInset), maxCropDown)
        return (
            topInset: closeTopInset + clampedTopCrop,
            height: max(minimumHeight, featureImageColumnHeight - clampedTopCrop)
        )
    }

    /// Hero band floor inside the carousel overlay — matches **`PushedHeroBand`** bottom / **`BlueSheetHeaderPageLayout`** hero slot.
    nonisolated static func marineLifeCarouselOverlayHeroBandBottomYFromTop(
        heroBandHeight: CGFloat,
        topSafeAreaInset: CGFloat
    ) -> CGFloat {
        topSafeAreaInset + max(heroBandHeight, 0)
    }

    /// **`BlueSheetHeaderPageLayout`** sheet seam — **`heroHeight − panelOverlap`** in carousel bleed coordinates.
    nonisolated static func marineLifeCarouselOverlaySheetSeamYFromTop(
        heroBandHeight: CGFloat,
        topSafeAreaInset: CGFloat,
        panelOverlap: CGFloat = HomeOverviewLayout.panelOverlap
    ) -> CGFloat {
        max(
            marineLifeCarouselOverlayHeroBandBottomYFromTop(
                heroBandHeight: heroBandHeight,
                topSafeAreaInset: topSafeAreaInset
            ) - panelOverlap
                + marineLifeCarouselOverlaySheetSeamYOffsetFromTemplate,
            0
        )
    }

    /// Distance from the overlay bottom to the template sheet seam.
    nonisolated static func marineLifeCarouselOverlaySheetSeamDistanceFromBottom(
        overlayHeight: CGFloat,
        heroBandHeight: CGFloat,
        topSafeAreaInset: CGFloat,
        panelOverlap: CGFloat = HomeOverviewLayout.panelOverlap
    ) -> CGFloat {
        max(
            overlayHeight - marineLifeCarouselOverlaySheetSeamYFromTop(
                heroBandHeight: heroBandHeight,
                topSafeAreaInset: topSafeAreaInset,
                panelOverlap: panelOverlap
            ),
            0
        )
    }

    nonisolated static let marineLifeCarouselOverlayPageIndicatorDotSize: CGFloat = 7
    nonisolated static let marineLifeCarouselOverlayPageIndicatorSpacing: CGFloat = 8

    nonisolated static func marineLifeCarouselOverlayPageIndicatorTopInsetFromTop(
        sheetSeamYFromTop: CGFloat
    ) -> CGFloat {
        max(
            0,
            sheetSeamYFromTop
                - marineLifeCarouselOverlayPageIndicatorClearanceAboveSeam
                - marineLifeCarouselOverlayPageIndicatorDotSize
                + marineLifeCarouselOverlayPageIndicatorTopOffsetFromSeamSpacing
        )
    }

    /// Default top inset before debug override — seam spacing + **`marineLifeCarouselOverlayPageIndicatorTopOffsetFromSeamSpacing`**.
    nonisolated static func marineLifeCarouselOverlayPageIndicatorTopInsetAboveSeam(
        sheetSeamYFromTop: CGFloat
    ) -> CGFloat {
        max(
            0,
            sheetSeamYFromTop
                - marineLifeCarouselOverlayPageIndicatorClearanceAboveSeam
                - marineLifeCarouselOverlayPageIndicatorDotSize
        )
    }

    nonisolated static func marineLifeCarouselOverlayPageIndicatorBottomInset(
        overlayHeight: CGFloat,
        heroBandHeight: CGFloat,
        topSafeAreaInset: CGFloat,
        panelOverlap: CGFloat = HomeOverviewLayout.panelOverlap
    ) -> CGFloat {
        marineLifeCarouselOverlayPageIndicatorBottomInset(
            overlayHeight: overlayHeight,
            sheetSeamYFromTop: marineLifeCarouselOverlaySheetSeamYFromTop(
                heroBandHeight: heroBandHeight,
                topSafeAreaInset: topSafeAreaInset,
                panelOverlap: panelOverlap
            )
        )
    }

    /// Keeps species image + name above page dots and the seam.
    nonisolated static func marineLifeCarouselOverlaySpeciesBottomMargin(
        overlayHeight: CGFloat,
        heroBandHeight: CGFloat,
        topSafeAreaInset: CGFloat,
        panelOverlap: CGFloat = HomeOverviewLayout.panelOverlap
    ) -> CGFloat {
        marineLifeCarouselOverlayPageIndicatorBottomInset(
            overlayHeight: overlayHeight,
            heroBandHeight: heroBandHeight,
            topSafeAreaInset: topSafeAreaInset,
            panelOverlap: panelOverlap
        )
            + marineLifeCarouselOverlayPageIndicatorDotSize
            + marineLifeCarouselOverlaySpeciesToPageIndicatorSpacing
    }

    /// Shifts the overlay **×** (and species image + name) down from header-aligned default.
    nonisolated static let marineLifeCarouselOverlayCloseTopOffsetFromHeaderAlignment: CGFloat = 75

    /// Mirrors **`AppTheme.Layout.appHeaderTopPadding`** for nonisolated layout math.
    nonisolated static let marineLifeOverlayHomeHeaderTopPadding: CGFloat = AppTheme.Spacing.sm

    /// Mirrors **`AppTheme.Layout.appHeaderBottomPadding`** for nonisolated layout math.
    nonisolated static let marineLifeOverlayHomeHeaderBottomPadding: CGFloat = AppTheme.Spacing.md

    /// Mirrors **`AppToolbarIconButtonMetrics.tapDimension`** for nonisolated layout math.
    nonisolated static let marineLifeOverlayCloseButtonTapDimension: CGFloat = 44

    nonisolated static func marineLifeOverlayHeaderBrandRowHeight() -> CGFloat {
        max(
            AppHeaderBrandRowMetrics.wordmarkLineHeight,
            BlueSheetTopChromePresentation.homeProfileAvatarDiameter
        )
    }

    /// Vertically centers the overlay **×** with the Home **`AppHeader`** profile avatar row.
    nonisolated static func marineLifeOverlayCloseTopInset(
        topSafeAreaInset: CGFloat,
        headerClearance: CGFloat
    ) -> CGFloat {
        _ = headerClearance
        let rowHeight = marineLifeOverlayHeaderBrandRowHeight()
        let profileCenterY = topSafeAreaInset
            + marineLifeOverlayHomeHeaderTopPadding
            + rowHeight / 2
        return max(
            0,
            profileCenterY
                - marineLifeOverlayCloseButtonTapDimension / 2
                + marineLifeCarouselOverlayCloseTopOffsetFromHeaderAlignment
        )
    }

    /// Legacy overload — **`listTopInset`** = status bar + **`headerClearance`**.
    nonisolated static func marineLifeOverlayCloseTopInset(
        previewHeight: CGFloat,
        topSafeAreaInset: CGFloat,
        headerOverlayHeight: CGFloat
    ) -> CGFloat {
        _ = previewHeight
        let headerClearance = max(0, headerOverlayHeight - topSafeAreaInset)
        return marineLifeOverlayCloseTopInset(
            topSafeAreaInset: topSafeAreaInset,
            headerClearance: headerClearance
        )
    }

    /// Species feature image top (**`marineLifeOverlayCloseTopInset`**).
    nonisolated static func marineLifeCarouselOverlaySpeciesContentTopInset(
        closeTopInset: CGFloat
    ) -> CGFloat {
        closeTopInset
    }

    /// Species common name sits below the feature image top.
    nonisolated static func marineLifeCarouselOverlaySpeciesNameTopInset(
        closeTopInset: CGFloat
    ) -> CGFloat {
        closeTopInset + marineLifeCarouselOverlaySpeciesNameTopOffsetFromFeatureImageTop
    }

    /// Legacy hero-band bias helper — prefer **`marineLifeCarouselOverlaySpeciesContentTopInset(closeTopInset:)`**.
    nonisolated static func marineLifeCarouselOverlaySpeciesContentTopInset(
        previewHeight: CGFloat,
        speciesRowHeight: CGFloat,
        topSafeAreaInset: CGFloat,
        headerOverlayHeight: CGFloat,
        heroBandHeight: CGFloat,
        panelOverlap: CGFloat = HomeOverviewLayout.panelOverlap
    ) -> CGFloat {
        _ = previewHeight
        _ = speciesRowHeight
        _ = topSafeAreaInset
        _ = heroBandHeight
        _ = panelOverlap
        return marineLifeCarouselOverlaySpeciesContentTopInset(
            closeTopInset: marineLifeOverlayCloseTopInset(
                previewHeight: previewHeight,
                topSafeAreaInset: topSafeAreaInset,
                headerOverlayHeight: headerOverlayHeight
            )
        )
    }

    /// Home carousel fish overlay — full-bleed frosted dimming so media stays visible underneath.
    nonisolated static let marineLifeCarouselOverlayMediaScrimOpacity: Double = 0.38

    nonisolated static func marineLifeCarouselOverlayProductionSeamYInHeroBand(
        heroBandHeight: CGFloat,
        panelOverlap: CGFloat = HomeOverviewLayout.panelOverlap
    ) -> CGFloat {
        max(
            marineLifeCarouselOverlayTemplateSeamYInHeroBand(
                heroBandHeight: heroBandHeight,
                panelOverlap: panelOverlap
            ) + marineLifeCarouselOverlaySheetSeamYOffsetFromTemplate,
            0
        )
    }

    nonisolated static func marineLifeCarouselOverlayTemplateSeamYInHeroBand(
        heroBandHeight: CGFloat,
        panelOverlap: CGFloat = HomeOverviewLayout.panelOverlap
    ) -> CGFloat {
        max(heroBandHeight - panelOverlap, 0)
    }

    nonisolated static func marineLifeCarouselOverlayClampedSeamYFromTop(
        templateSeamYFromTop: CGFloat,
        proposedSeamYFromTop: CGFloat?,
        minimumSeamY: CGFloat,
        maximumSeamY: CGFloat
    ) -> CGFloat {
        let proposed = proposedSeamYFromTop ?? templateSeamYFromTop
        return min(max(proposed, minimumSeamY), maximumSeamY)
    }

    nonisolated static func marineLifeCarouselOverlayPageIndicatorBottomInset(
        overlayHeight: CGFloat,
        sheetSeamYFromTop: CGFloat
    ) -> CGFloat {
        let topInset = marineLifeCarouselOverlayPageIndicatorTopInsetFromTop(
            sheetSeamYFromTop: sheetSeamYFromTop
        )
        return max(
            overlayHeight - topInset - marineLifeCarouselOverlayPageIndicatorDotSize,
            marineLifeCarouselOverlayPageIndicatorClearanceAboveSeam
        )
    }

    nonisolated static func marineLifeCarouselOverlaySpeciesBottomMargin(
        overlayHeight: CGFloat,
        sheetSeamYFromTop: CGFloat
    ) -> CGFloat {
        marineLifeCarouselOverlayPageIndicatorBottomInset(
            overlayHeight: overlayHeight,
            sheetSeamYFromTop: sheetSeamYFromTop
        )
            + marineLifeCarouselOverlayPageIndicatorDotSize
            + marineLifeCarouselOverlaySpeciesToPageIndicatorSpacing
    }

    /// Expanded buddy stack shows at most two full avatars; a third may peek with a top fade.
    nonisolated static let taggedBuddyMaxFullVisibleProfiles: Int = 2

    nonisolated static let taggedBuddyThirdProfilePeekHeight: CGFloat = 28

    /// Height of the bottom band that shows up to two fully opaque buddy avatars.
    nonisolated static func taggedBuddyFullZoneHeight(
        avatarDiameter: CGFloat,
        avatarSpacing: CGFloat
    ) -> CGFloat {
        CGFloat(taggedBuddyMaxFullVisibleProfiles) * avatarDiameter
            + CGFloat(taggedBuddyMaxFullVisibleProfiles - 1) * avatarSpacing
    }

    /// Per-row mask for the buddy scroll stack — maps viewport Y onto each avatar circle.
    struct BuddyRowFadeMask: Sendable, Equatable {
        /// Fully transparent band at the top of the avatar (above the viewport edge).
        let transparentTopHeight: CGFloat
        /// Gradient band from transparent → opaque between the viewport top and full-opacity zone.
        let fadeHeight: CGFloat
        /// Fully opaque band at the bottom of the avatar.
        let opaqueBottomHeight: CGFloat
        let isHidden: Bool

        var needsMask: Bool {
            transparentTopHeight > 0.5 || fadeHeight > 0.5
        }

        nonisolated static let hidden = Self(
            transparentTopHeight: 0,
            fadeHeight: 0,
            opaqueBottomHeight: 0,
            isHidden: true
        )
    }

    nonisolated static func buddyRowFadeMask(
        rowMinYInViewport: CGFloat,
        rowMaxYInViewport: CGFloat,
        viewportHeight: CGFloat,
        avatarDiameter: CGFloat,
        avatarSpacing: CGFloat,
        buddyCount: Int
    ) -> BuddyRowFadeMask {
        guard buddyCount > taggedBuddyMaxFullVisibleProfiles else {
            let isHidden = rowMaxYInViewport <= 0 || rowMinYInViewport >= viewportHeight
            return BuddyRowFadeMask(
                transparentTopHeight: 0,
                fadeHeight: 0,
                opaqueBottomHeight: isHidden ? 0 : avatarDiameter,
                isHidden: isHidden
            )
        }

        if rowMaxYInViewport <= 0 || rowMinYInViewport >= viewportHeight {
            return .hidden
        }

        let fullZoneTop = viewportHeight - taggedBuddyFullZoneHeight(
            avatarDiameter: avatarDiameter,
            avatarSpacing: avatarSpacing
        )

        if rowMinYInViewport >= fullZoneTop {
            return BuddyRowFadeMask(
                transparentTopHeight: 0,
                fadeHeight: 0,
                opaqueBottomHeight: avatarDiameter,
                isHidden: false
            )
        }

        let transparentTopHeight = max(0, min(avatarDiameter, -rowMinYInViewport))
        let fadeEndLocalY = min(avatarDiameter, max(0, fullZoneTop - rowMinYInViewport))
        let fadeHeight = max(0, fadeEndLocalY - transparentTopHeight)
        let opaqueBottomHeight = max(0, avatarDiameter - fadeEndLocalY)

        if transparentTopHeight + fadeHeight + opaqueBottomHeight <= 0 {
            return .hidden
        }

        return BuddyRowFadeMask(
            transparentTopHeight: transparentTopHeight,
            fadeHeight: fadeHeight,
            opaqueBottomHeight: opaqueBottomHeight,
            isHidden: false
        )
    }

    /// Index of the topmost buddy row that peeks when the list is scrolled to the bottom.
    nonisolated static func taggedBuddyPeekProfileIndex(buddyCount: Int) -> Int? {
        guard buddyCount > taggedBuddyMaxFullVisibleProfiles else { return nil }
        return buddyCount - taggedBuddyMaxFullVisibleProfiles - 1
    }

    nonisolated static func taggedBuddyExpandedListHeight(
        buddyCount: Int,
        avatarDiameter: CGFloat,
        avatarSpacing: CGFloat
    ) -> CGFloat {
        guard buddyCount > 0 else { return 0 }
        if buddyCount <= taggedBuddyMaxFullVisibleProfiles {
            return CGFloat(buddyCount) * avatarDiameter
                + CGFloat(max(0, buddyCount - 1)) * avatarSpacing
        }
        return CGFloat(taggedBuddyMaxFullVisibleProfiles) * avatarDiameter
            + CGFloat(taggedBuddyMaxFullVisibleProfiles - 1) * avatarSpacing
            + taggedBuddyThirdProfilePeekHeight
    }

    nonisolated static func taggedBuddyListShowsScrollFade(buddyCount: Int) -> Bool {
        buddyCount > taggedBuddyMaxFullVisibleProfiles
    }

    /// Horizontal fan-out from the trailing buddy icon — **0** is the avatar adjacent to the icon.
    nonisolated static func taggedBuddyHorizontalOffsetX(
        distanceFromIcon: Int,
        avatarDiameter: CGFloat,
        avatarSpacing: CGFloat,
        isExpanded: Bool
    ) -> CGFloat {
        guard isExpanded, distanceFromIcon >= 0 else { return 0 }
        return -CGFloat(distanceFromIcon + 1) * (avatarDiameter + avatarSpacing)
    }

    nonisolated static func taggedBuddyHorizontalRevealDelay(
        distanceFromIcon: Int,
        staggerStep: TimeInterval = 0.055
    ) -> TimeInterval {
        Double(distanceFromIcon) * staggerStep
    }

    /// Total width of all avatars in the horizontal fan (one row, no vertical peek cap).
    nonisolated static func taggedBuddyHorizontalStripWidth(
        buddyCount: Int,
        avatarDiameter: CGFloat,
        avatarSpacing: CGFloat
    ) -> CGFloat {
        guard buddyCount > 0 else { return 0 }
        return CGFloat(buddyCount) * avatarDiameter
            + CGFloat(max(0, buddyCount - 1)) * avatarSpacing
    }

    nonisolated static func taggedSpecies(
        mediaID: UUID,
        sightings: [SightingInstance],
        catalog: [MarineLife]
    ) -> [MarineLife] {
        TripDetailMediaGalleryPresentation.taggedSpecies(
            mediaID: mediaID,
            sightings: sightings,
            catalog: catalog
        )
    }
}

/// Featured carousel dive-site capsule — dark slate on glass in light mode, white in dark.
enum HomeMediaCarouselDiveLinkChromePresentation {
    static var siteTitleForeground: Color { AppTheme.Colors.backButtonForeground }
    static var diveNumberForeground: Color { AppTheme.Colors.secondaryText }

    /// Light impact when the dive title capsule is tapped (skipped under UI tests).
    nonisolated static func shouldPlayOpenDiveHaptic(
        isUITest: Bool = GoDiveUITestConfiguration.isActive
    ) -> Bool {
        !isUITest
    }

    /// Subtitle under the site name — **`#12 · Trip title`** when both are present.
    nonisolated static func diveLinkSubtitle(
        diveNumberLabel: String,
        linkedTripTitle: String?
    ) -> String? {
        let trimmedTrip = linkedTripTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let showsNumber = diveNumberLabel != "-"
        let showsTrip = !trimmedTrip.isEmpty

        switch (showsNumber, showsTrip) {
        case (true, true):
            return "\(diveNumberLabel) · \(trimmedTrip)"
        case (true, false):
            return diveNumberLabel
        case (false, true):
            return trimmedTrip
        case (false, false):
            return nil
        }
    }
}
