import Foundation
import SwiftData

/// Per-user sighting / tagging overlay for one catalog **`MarineLife`** row.
@Model
final class MarineLifeUserRecord {

    var id: UUID

    /// Denormalized for **`#Predicate`** / batch queries; kept in sync with **`owner`**.
    var ownerProfileID: UUID?
    @Relationship
    var owner: UserProfile?

    /// Matches **`MarineLife.uuid`** (denormalized when the catalog link is missing).
    var marineLifeUUID: String

    @Relationship
    var marineLife: MarineLife?

    /// User marked this species as seen (in the field guide or on a dive).
    var isSighted: Bool

    /// Dive activities where the user logged this species.
    var activitiesSightedOn: [UUID]

    /// Catalog **`DiveSite`** ids where the user logged this species.
    var sitesSightedOn: [UUID]

    /// User media URLs where this species is tagged (local paths or future remote links).
    var userTaggedMedia: [String]

    init(
        id: UUID = UUID(),
        owner: UserProfile? = nil,
        marineLife: MarineLife? = nil,
        isSighted: Bool = false,
        activitiesSightedOn: [UUID] = [],
        sitesSightedOn: [UUID] = [],
        userTaggedMedia: [String] = []
    ) {
        self.id = id
        self.owner = owner
        self.ownerProfileID = owner?.id
        self.marineLife = marineLife
        self.marineLifeUUID = marineLife?.uuid ?? ""
        self.isSighted = isSighted
        self.activitiesSightedOn = activitiesSightedOn
        self.sitesSightedOn = sitesSightedOn
        self.userTaggedMedia = userTaggedMedia
    }

    func link(to marineLife: MarineLife, owner: UserProfile) {
        self.marineLife = marineLife
        self.marineLifeUUID = marineLife.uuid
        self.owner = owner
        self.ownerProfileID = owner.id
    }
}
