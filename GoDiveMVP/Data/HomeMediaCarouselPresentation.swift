import Foundation
import CoreGraphics
#if canImport(UIKit)
import UIKit
#endif

/// Auto-advance rules for the Home featured-media carousel.
enum HomeMediaCarouselPresentation: Sendable {

    /// How long a photo slide stays visible before advancing.
    nonisolated static let photoDisplaySeconds: TimeInterval = 10

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

    nonisolated static func shouldAutoAdvance(slideCount: Int) -> Bool {
        slideCount > 1
    }

    /// After a video finishes, advance when there are multiple slides; otherwise loop the sole clip.
    nonisolated static func shouldRestartClipAfterPlaybackFinished(slideCount: Int) -> Bool {
        slideCount <= 1
    }

    /// Home carousel has at most **`carouselLimit`** picks — keep every slide hydrated for the session.
    nonisolated static func keepsAllSlidesLoaded(slideCount: Int) -> Bool {
        slideCount > 0 && slideCount <= HomeMediaHighlightPresentation.carouselLimit
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

    /// Compact feature image on the Home fish overlay (smaller than trip media card).
    nonisolated static func marineLifeCarouselOverlayImageHeight(previewHeight: CGFloat) -> CGFloat {
        min(104, max(72, previewHeight * 0.12))
    }

    nonisolated static func marineLifeCarouselOverlayImageMaxWidth(previewWidth: CGFloat) -> CGFloat {
        min(136, max(96, previewWidth * 0.32))
    }

    nonisolated static func marineLifeCarouselOverlayPageHeight(
        previewHeight: CGFloat,
        speciesCount: Int
    ) -> CGFloat {
        let imageHeight = marineLifeCarouselOverlayImageHeight(previewHeight: previewHeight)
        let textBlock: CGFloat = 44
        let pageIndicator: CGFloat = speciesCount > 1 ? 28 : 0
        return imageHeight + 8 + textBlock + pageIndicator
    }

    /// Upper **×** sits just below measured **`AppHeader`** height (carousel shares the screen-top coordinate space).
    nonisolated static func marineLifeOverlayCloseTopInset(
        previewHeight: CGFloat,
        topSafeAreaInset: CGFloat,
        headerOverlayHeight: CGFloat
    ) -> CGFloat {
        let measuredHeader = max(
            headerOverlayHeight,
            topSafeAreaInset + 64
        )
        return measuredHeader + 16
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
