import CoreGraphics
import Foundation

/// Trip detail hero chrome — media/map header and featured trip media.
enum TripDetailPresentation: Sendable {

    nonisolated static let heroModeToggleBottomPadding: CGFloat =
        DiveBuddyDetailPresentation.heroModeToggleBottomPadding

    nonisolated static func shouldAutoPlaySelectedVideo(for media: DiveMediaPhoto?) -> Bool {
        DiveBuddyDetailPresentation.shouldAutoPlaySelectedVideo(for: media)
    }

    nonisolated static func randomHeroMedia(from photos: [DiveMediaPhoto]) -> DiveMediaPhoto? {
        DiveBuddyDetailPresentation.randomHeroTaggedMedia(from: photos)
    }

    nonisolated static func resolvedHeroMediaPhotoID(
        in photos: [DiveMediaPhoto],
        explicitFeaturedID: UUID?,
        sessionRandomID: UUID?
    ) -> UUID? {
        DetailHeroMediaPresentation.resolvedHeroMediaPhotoID(
            in: photos,
            explicitFeaturedID: explicitFeaturedID,
            sessionRandomID: sessionRandomID
        )
    }

    /// Hero pick from linked trip media.
    @MainActor
    static func initialHeroMediaPhotoID(
        for trip: DiveTrip,
        photos: [DiveMediaPhoto]
    ) -> UUID? {
        resolvedHeroMediaPhotoID(
            in: photos,
            explicitFeaturedID: trip.featuredTripMediaPhotoID,
            sessionRandomID: TripHeroMediaSession.resolvedRandomHeroMediaID(
                tripID: trip.id,
                in: photos
            )
        )
    }
}
