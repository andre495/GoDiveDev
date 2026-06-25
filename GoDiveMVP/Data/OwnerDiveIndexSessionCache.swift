import Foundation
import SwiftData

/// Reuses owner-wide dive numbering built on Home (or a prior buddy open) so buddy detail
/// does not re-fetch every **`DiveActivity`** on push.
@MainActor
enum OwnerDiveIndexSessionCache {

    private static var byOwnerID: [UUID: DiveBuddyDetailPresentation.OwnerDiveIndex] = [:]

    static func publish(
        activities: [DiveActivity],
        ownerProfileID: UUID
    ) {
        byOwnerID[ownerProfileID] = DiveBuddyDetailPresentation.ownerDiveIndex(from: activities)
    }

    static func publish(
        _ index: DiveBuddyDetailPresentation.OwnerDiveIndex,
        ownerProfileID: UUID
    ) {
        byOwnerID[ownerProfileID] = index
    }

    static func resolve(ownerProfileID: UUID) -> DiveBuddyDetailPresentation.OwnerDiveIndex? {
        byOwnerID[ownerProfileID]
    }

    #if DEBUG
    static func resetForTesting() {
        byOwnerID = [:]
    }
    #endif
}
