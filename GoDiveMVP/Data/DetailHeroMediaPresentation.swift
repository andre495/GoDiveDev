import Foundation

/// Shared hero media pick + star toggle rules for buddy and trip detail headers.
enum DetailHeroMediaPresentation: Sendable {

    nonisolated static func resolvedHeroMediaPhotoID(
        in photos: [DiveMediaPhoto],
        explicitFeaturedID: UUID?,
        sessionRandomID: UUID?
    ) -> UUID? {
        if let explicitFeaturedID,
           photos.contains(where: { $0.id == explicitFeaturedID }) {
            return explicitFeaturedID
        }
        if let sessionRandomID,
           photos.contains(where: { $0.id == sessionRandomID }) {
            return sessionRandomID
        }
        return photos.first?.id
    }

    nonisolated static func isExplicitlyFeatured(
        mediaID: UUID,
        explicitFeaturedID: UUID?
    ) -> Bool {
        explicitFeaturedID == mediaID
    }

    nonisolated static func toggledFeaturedMediaPhotoID(
        mediaID: UUID,
        explicitFeaturedID: UUID?
    ) -> UUID? {
        isExplicitlyFeatured(mediaID: mediaID, explicitFeaturedID: explicitFeaturedID) ? nil : mediaID
    }
}
