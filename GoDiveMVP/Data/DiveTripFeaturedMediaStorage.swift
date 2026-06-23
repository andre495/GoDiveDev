import Foundation
import SwiftData

/// Persists the trip detail hero pick among linked dive media.
enum DiveTripFeaturedMediaStorage {

    static func setFeaturedTripMedia(
        _ mediaID: UUID?,
        on trip: DiveTrip,
        modelContext: ModelContext
    ) throws {
        guard trip.featuredTripMediaPhotoID != mediaID else { return }
        trip.featuredTripMediaPhotoID = mediaID
        try modelContext.save()
    }
}
