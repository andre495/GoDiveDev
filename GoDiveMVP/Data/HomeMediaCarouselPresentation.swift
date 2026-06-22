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
        return max(textStackHeight, iconHeight) + AppTheme.Spacing.sm * 2
        #else
        return 48
        #endif
    }

    /// Next slide index; wraps from last → first.
    nonisolated static func nextIndex(after current: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return (current + 1) % count
    }

    nonisolated static func shouldAutoAdvance(slideCount: Int) -> Bool {
        slideCount > 1
    }

    /// Home carousel has at most **`carouselLimit`** picks — keep every slide hydrated for the session.
    nonisolated static func keepsAllSlidesLoaded(slideCount: Int) -> Bool {
        slideCount > 0 && slideCount <= HomeMediaHighlightPresentation.carouselLimit
    }

    /// Only the visible slide may auto-advance (ignores stale end-of-playback callbacks).
    nonisolated static func shouldAdvanceFromSlide(
        selectedIndex: Int,
        finishingSlideIndex: Int,
        isPlaybackAllowed: Bool
    ) -> Bool {
        isPlaybackAllowed && selectedIndex == finishingSlideIndex
    }

    nonisolated static let marineLifeOverlayCornerRadius: CGFloat = 0

    nonisolated static func marineLifeOverlaySize(width: CGFloat, height: CGFloat) -> CGSize {
        CGSize(width: max(width, 1), height: max(height, 1))
    }

    /// Scales the feature image for taller Home heroes while staying compact.
    nonisolated static func marineLifeOverlayFeatureImageHeight(previewHeight: CGFloat) -> CGFloat {
        min(168, max(112, previewHeight * 0.24))
    }

    nonisolated static func marineLifeOverlayFeatureImageMaxWidth(previewWidth: CGFloat) -> CGFloat {
        min(240, max(180, previewWidth * 0.58))
    }

    /// Upper-leading **×** sits below the Home **`AppHeader`** (≈30% hero height, at least header clearance).
    nonisolated static func marineLifeOverlayCloseTopInset(
        previewHeight: CGFloat,
        topSafeAreaInset: CGFloat,
        headerOverlayHeight: CGFloat
    ) -> CGFloat {
        let headerClearance = topSafeAreaInset + headerOverlayHeight + AppTheme.Spacing.sm
        let fractionalInset = previewHeight * 0.30
        return max(headerClearance, fractionalInset)
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
