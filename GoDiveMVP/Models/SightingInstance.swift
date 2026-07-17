import Foundation
import SwiftData

/// One logged sighting of a catalog or user-created species (dive, site, depth, optional tagged media).
///
/// Species and site links are **UUID / ID only** so user and catalog stores can split without
/// cross-configuration SwiftData relationships.
@Model
final class SightingInstance {

    /// Stable id for this sighting (local UUID string today; remote API later).
    /// Uniqueness is app-enforced (`AppSwiftDataLogicalUniqueness`) — CloudKit forbids `@Attribute(.unique)`.
    var sightingUUID: String = ""

    /// Matches **`MarineLife.uuid`** or **`UserMarineLife.uuid`**.
    var marineLifeUUID: String = ""

    /// UTC instant — dive **`startTime`** by default; media **`capturedAt`** when tagged from media.
    var sightingDateTime: Date = Date()

    var diveActivityID: UUID?
    @Relationship(inverse: \DiveActivity.marineLifeSightingsStorage)
    var diveActivity: DiveActivity?

    /// Matches **`DiveSite.id`** or **`UserDiveSite.id`**.
    var diveSiteID: UUID?

    /// Depth at the sighting (**m**); **`nil`** when unknown.
    var sightingDepthMeters: Double?

    var mediaPhotoID: UUID?
    @Relationship(deleteRule: .nullify, inverse: \DiveMediaPhoto.marineLifeSightingsStorage)
    var mediaPhoto: DiveMediaPhoto?

    init(
        sightingUUID: String = UUID().uuidString,
        marineLifeUUID: String,
        sightingDateTime: Date,
        diveActivity: DiveActivity? = nil,
        diveSiteID: UUID? = nil,
        sightingDepthMeters: Double? = nil,
        mediaPhoto: DiveMediaPhoto? = nil
    ) {
        self.sightingUUID = sightingUUID
        self.marineLifeUUID = marineLifeUUID
        self.sightingDateTime = sightingDateTime
        self.diveActivity = diveActivity
        self.diveActivityID = diveActivity?.id
        self.diveSiteID = diveSiteID ?? diveActivity?.diveSiteID
        self.sightingDepthMeters = sightingDepthMeters
        self.mediaPhoto = mediaPhoto
        self.mediaPhotoID = mediaPhoto?.id
    }
}
