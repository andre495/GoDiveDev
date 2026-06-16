import Foundation
import CoreGraphics

/// Auto-advance rules for the Home featured-media carousel.
enum HomeMediaCarouselPresentation: Sendable {

    /// How long a photo slide stays visible before advancing.
    nonisolated static let photoDisplaySeconds: TimeInterval = 10

    /// Next slide index; wraps from last → first.
    nonisolated static func nextIndex(after current: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return (current + 1) % count
    }

    nonisolated static func shouldAutoAdvance(slideCount: Int) -> Bool {
        slideCount > 1
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
