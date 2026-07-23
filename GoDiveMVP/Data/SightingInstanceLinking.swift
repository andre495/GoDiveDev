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
        sighting.snorkelActivity = nil
        sighting.snorkelActivityID = nil
        sighting.diveSiteID = diveSiteID ?? dive.diveSiteID

        if let mediaPhoto {
            sighting.mediaPhoto = mediaPhoto
            sighting.mediaPhotoID = mediaPhoto.id
            sighting.snorkelMediaPhoto = nil
            sighting.snorkelMediaPhotoID = nil
        } else {
            sighting.mediaPhoto = nil
            sighting.mediaPhotoID = nil
        }
    }

    static func link(
        _ sighting: SightingInstance,
        marineLifeUUID: String,
        snorkel: SnorkelActivity,
        diveSiteID: UUID? = nil,
        snorkelMediaPhoto: SnorkelMediaPhoto? = nil
    ) {
        sighting.marineLifeUUID = marineLifeUUID
        sighting.snorkelActivity = snorkel
        sighting.snorkelActivityID = snorkel.id
        sighting.diveActivity = nil
        sighting.diveActivityID = nil
        sighting.diveSiteID = diveSiteID ?? snorkel.diveSiteID

        if let snorkelMediaPhoto {
            sighting.snorkelMediaPhoto = snorkelMediaPhoto
            sighting.snorkelMediaPhotoID = snorkelMediaPhoto.id
            sighting.mediaPhotoID = snorkelMediaPhoto.id
            sighting.mediaPhoto = nil
        } else {
            sighting.snorkelMediaPhoto = nil
            sighting.snorkelMediaPhotoID = nil
            sighting.mediaPhoto = nil
            sighting.mediaPhotoID = nil
        }
    }
}
