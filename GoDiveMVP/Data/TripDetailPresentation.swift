import CoreGraphics
import Foundation

/// Trip detail hero chrome — media/map header and featured trip media.
enum TripDetailPresentation: Sendable {

    /// Upcoming / active / past trip detail — same pinned-summary → divider → pager clearance as
    /// equipment, certs, sites, and species (`pushedDetailWithStandardPanelBodySpacing`).
    nonisolated static func blueSheetPageConfiguration(
        accessibilityRootIdentifier: String,
        showsHero: Bool = true
    ) -> BlueSheetDetailPageConfiguration {
        .pushedDetailWithStandardPanelBodySpacing(
            accessibilityRootIdentifier: accessibilityRootIdentifier,
            showsHero: showsHero
        )
    }

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

    /// Default hero mode: planned (not-yet-started) trips with mappable planned sites open on the map.
    /// Otherwise map when pins exist and there is no trip media.
    nonisolated static func prefersMapHero(
        tripHasStarted: Bool,
        plannedSiteCount: Int,
        hasMapPins: Bool,
        hasTripMedia: Bool
    ) -> Bool {
        guard hasMapPins else { return false }
        if !tripHasStarted, plannedSiteCount > 0 {
            return true
        }
        return !hasTripMedia
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
