import Foundation
import SwiftData

/// Persists the buddy detail hero pick among tagged dive media.
enum DiveBuddyFeaturedMediaStorage {

    /// Sets (or clears) the starred hero media for **`ViewDiveBuddyDetails`**. Only one id may be starred per buddy.
    static func setFeaturedTaggedMedia(
        _ mediaID: UUID?,
        on buddy: DiveBuddy,
        modelContext: ModelContext
    ) throws {
        guard buddy.featuredTaggedMediaPhotoID != mediaID else { return }
        buddy.featuredTaggedMediaPhotoID = mediaID
        try modelContext.save()
    }
}
