import Foundation

/// Keeps **`SightingInstance`** denormalized ids in sync when relationships are set.
enum SightingInstanceLinking {

    static func link(
        _ sighting: SightingInstance,
        marineLifeUUID: String,
        dive: DiveActivity,
        diveSiteID: UUID? = nil,
        mediaPhoto: DiveMediaPhoto? = nil
    ) {
        sighting.marineLifeUUID = marineLifeUUID
        sighting.diveActivity = dive
        sighting.diveActivityID = dive.id
        sighting.diveSiteID = diveSiteID ?? dive.diveSiteID

        if let mediaPhoto {
            sighting.mediaPhoto = mediaPhoto
            sighting.mediaPhotoID = mediaPhoto.id
        } else {
            sighting.mediaPhoto = nil
            sighting.mediaPhotoID = nil
        }
    }
}
