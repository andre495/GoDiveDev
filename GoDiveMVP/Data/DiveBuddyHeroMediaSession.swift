import Foundation

/// Per-buddy random header media for **`ViewDiveBuddyDetails`** — stable for the app session until unstarred or tagged media changes.
@MainActor
enum DiveBuddyHeroMediaSession {

    private static var randomHeroMediaIDByBuddyID: [UUID: UUID] = [:]

    /// Returns the session random pick when still valid, otherwise chooses and stores a new one.
    static func resolvedRandomHeroMediaID(
        buddyID: UUID,
        in photos: [DiveMediaPhoto]
    ) -> UUID? {
        if let existing = randomHeroMediaIDByBuddyID[buddyID],
           photos.contains(where: { $0.id == existing }) {
            return existing
        }
        return pickNewRandomHeroMediaID(buddyID: buddyID, in: photos)
    }

    /// Forces a new random pick (e.g. when the user clears a featured star).
    @discardableResult
    static func pickNewRandomHeroMediaID(
        buddyID: UUID,
        in photos: [DiveMediaPhoto]
    ) -> UUID? {
        let picked = DiveBuddyDetailPresentation.randomHeroTaggedMedia(from: photos)?.id
        if let picked {
            randomHeroMediaIDByBuddyID[buddyID] = picked
        } else {
            randomHeroMediaIDByBuddyID.removeValue(forKey: buddyID)
        }
        return picked
    }

    #if DEBUG
    static func resetForTesting() {
        randomHeroMediaIDByBuddyID.removeAll()
    }
    #endif
}
