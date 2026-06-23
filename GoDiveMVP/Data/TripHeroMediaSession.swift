import Foundation

/// Per-trip random header media for **`TripDetailView`** — stable for the app session until unstarred or trip media changes.
@MainActor
enum TripHeroMediaSession {

    private static var randomHeroMediaIDByTripID: [UUID: UUID] = [:]

    static func resolvedRandomHeroMediaID(
        tripID: UUID,
        in photos: [DiveMediaPhoto]
    ) -> UUID? {
        if let existing = randomHeroMediaIDByTripID[tripID],
           photos.contains(where: { $0.id == existing }) {
            return existing
        }
        return pickNewRandomHeroMediaID(tripID: tripID, in: photos)
    }

    @discardableResult
    static func pickNewRandomHeroMediaID(
        tripID: UUID,
        in photos: [DiveMediaPhoto]
    ) -> UUID? {
        let picked = TripDetailPresentation.randomHeroMedia(from: photos)?.id
        if let picked {
            randomHeroMediaIDByTripID[tripID] = picked
        } else {
            randomHeroMediaIDByTripID.removeValue(forKey: tripID)
        }
        return picked
    }

    #if DEBUG
    static func resetForTesting() {
        randomHeroMediaIDByTripID.removeAll()
    }
    #endif
}
