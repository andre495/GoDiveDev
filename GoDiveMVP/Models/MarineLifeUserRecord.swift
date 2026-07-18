import Foundation
import SwiftData

/// Per-user sighting / tagging overlay for one catalog or user-created species UUID.
@Model
final class MarineLifeUserRecord {

    var id: UUID = UUID()

    /// Denormalized for **`#Predicate`** / batch queries; kept in sync with **`owner`**.
    var ownerProfileID: UUID?
    @Relationship
    var owner: UserProfile?

    /// Matches **`MarineLife.uuid`** or **`UserMarineLife.uuid`**.
    var marineLifeUUID: String = ""

    /// User marked this species as seen (in the field guide or on a dive).
    var isSighted: Bool = false

    /// JSON UUID strings — CloudKit rejects stored `[UUID]` (`NSCodableAttributeType`).
    var activitiesSightedOnData: Data?
    /// JSON UUID strings for catalog / user site ids.
    var sitesSightedOnData: Data?
    /// JSON media link strings.
    var userTaggedMediaData: Data?

    /// Dive activities where the user logged this species.
    @Transient
    var activitiesSightedOn: [UUID] {
        get { AppSwiftDataCloudKitArrayStorage.decodeUUIDList(activitiesSightedOnData) }
        set { activitiesSightedOnData = AppSwiftDataCloudKitArrayStorage.encodeUUIDList(newValue) }
    }

    /// Catalog / user **`DiveSite`** / **`UserDiveSite`** ids where the user logged this species.
    @Transient
    var sitesSightedOn: [UUID] {
        get { AppSwiftDataCloudKitArrayStorage.decodeUUIDList(sitesSightedOnData) }
        set { sitesSightedOnData = AppSwiftDataCloudKitArrayStorage.encodeUUIDList(newValue) }
    }

    /// User media URLs where this species is tagged (local paths or future remote links).
    @Transient
    var userTaggedMedia: [String] {
        get { AppSwiftDataCloudKitArrayStorage.decodeStringList(userTaggedMediaData) }
        set { userTaggedMediaData = AppSwiftDataCloudKitArrayStorage.encodeStringList(newValue) }
    }

    init(
        id: UUID = UUID(),
        owner: UserProfile? = nil,
        marineLifeUUID: String = "",
        isSighted: Bool = false,
        activitiesSightedOn: [UUID] = [],
        sitesSightedOn: [UUID] = [],
        userTaggedMedia: [String] = []
    ) {
        self.id = id
        self.owner = owner
        self.ownerProfileID = owner?.id
        self.marineLifeUUID = marineLifeUUID
        self.isSighted = isSighted
        self.activitiesSightedOn = activitiesSightedOn
        self.sitesSightedOn = sitesSightedOn
        self.userTaggedMedia = userTaggedMedia
    }

    func link(marineLifeUUID: String, owner: UserProfile) {
        self.marineLifeUUID = marineLifeUUID
        self.owner = owner
        self.ownerProfileID = owner.id
    }
}
