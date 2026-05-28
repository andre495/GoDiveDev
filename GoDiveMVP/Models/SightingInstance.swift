import Foundation
import SwiftData

/// One logged sighting of a catalog **`MarineLife`** species (dive, site, depth, optional tagged media).
@Model
final class SightingInstance {

    /// Stable id for this sighting (local UUID string today; remote API later).
    @Attribute(.unique) var sightingUUID: String

    /// Matches **`MarineLife.uuid`** (denormalized for queries when the catalog link is missing).
    var marineLifeUUID: String
    @Relationship(inverse: \MarineLife.sightingInstances)
    var marineLife: MarineLife?

    /// UTC instant — dive **`startTime`** by default; media **`capturedAt`** when tagged from media.
    var sightingDateTime: Date

    var diveActivityID: UUID?
    @Relationship(inverse: \DiveActivity.marineLifeSightings)
    var diveActivity: DiveActivity?

    var diveSiteID: UUID?
    @Relationship(deleteRule: .nullify)
    var diveSite: DiveSite?

    /// Depth at the sighting (**m**); **`nil`** when unknown.
    var sightingDepthMeters: Double?

    var mediaPhotoID: UUID?
    @Relationship
    var mediaPhoto: DiveMediaPhoto?

    init(
        sightingUUID: String = UUID().uuidString,
        marineLifeUUID: String,
        sightingDateTime: Date,
        marineLife: MarineLife? = nil,
        diveActivity: DiveActivity? = nil,
        diveSite: DiveSite? = nil,
        sightingDepthMeters: Double? = nil,
        mediaPhoto: DiveMediaPhoto? = nil
    ) {
        self.sightingUUID = sightingUUID
        self.marineLifeUUID = marineLifeUUID
        self.sightingDateTime = sightingDateTime
        self.marineLife = marineLife
        self.diveActivity = diveActivity
        self.diveActivityID = diveActivity?.id
        self.diveSite = diveSite
        self.diveSiteID = diveSite?.id ?? diveActivity?.diveSiteID
        self.sightingDepthMeters = sightingDepthMeters
        self.mediaPhoto = mediaPhoto
        self.mediaPhotoID = mediaPhoto?.id
    }
}
