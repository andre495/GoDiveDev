import Foundation

/// Keeps **`SightingInstance`** denormalized ids in sync when relationships are set.
enum SightingInstanceLinking {

    static func link(
        _ sighting: SightingInstance,
        marineLife: MarineLife,
        dive: DiveActivity,
        diveSite: DiveSite? = nil,
        mediaPhoto: DiveMediaPhoto? = nil
    ) {
        sighting.marineLife = marineLife
        sighting.marineLifeUUID = marineLife.uuid
        sighting.diveActivity = dive
        sighting.diveActivityID = dive.id

        if let diveSite {
            sighting.diveSite = diveSite
            sighting.diveSiteID = diveSite.id
        } else if let linkedSite = dive.diveSite {
            sighting.diveSite = linkedSite
            sighting.diveSiteID = linkedSite.id
        } else {
            sighting.diveSite = nil
            sighting.diveSiteID = dive.diveSiteID
        }

        if let mediaPhoto {
            sighting.mediaPhoto = mediaPhoto
            sighting.mediaPhotoID = mediaPhoto.id
        } else {
            sighting.mediaPhoto = nil
            sighting.mediaPhotoID = nil
        }
    }
}
