import Foundation
import SwiftData

enum SnorkelSightingInstanceCreation {

    struct Draft: Sendable {
        var sightingUUID: String
        var marineLifeUUID: String
        var sightingDateTime: Date
        var snorkelActivityID: UUID
        var diveSiteID: UUID?
        var mediaPhotoID: UUID?
    }

    static func makeDraft(
        marineLifeUUID: String,
        snorkel: SnorkelActivity,
        mediaPhoto: SnorkelMediaPhoto? = nil,
        sightingUUID: String = UUID().uuidString
    ) -> Draft {
        Draft(
            sightingUUID: sightingUUID,
            marineLifeUUID: marineLifeUUID,
            sightingDateTime: SightingInstanceDateTimeResolution.resolvedUTCDateTime(
                diveStartTime: snorkel.startTime,
                mediaCapturedAt: mediaPhoto?.capturedAt
            ),
            snorkelActivityID: snorkel.id,
            diveSiteID: snorkel.diveSiteID,
            mediaPhotoID: mediaPhoto?.id
        )
    }

    @discardableResult
    static func insert(
        draft: Draft,
        snorkel: SnorkelActivity,
        mediaPhoto: SnorkelMediaPhoto? = nil,
        modelContext: ModelContext,
        persistImmediately: Bool = true
    ) throws -> SightingInstance {
        if let existing = try AppSwiftDataLogicalUniqueness.existingSighting(
            sightingUUID: draft.sightingUUID,
            modelContext: modelContext
        ) {
            return existing
        }
        let sighting = SightingInstance(
            sightingUUID: draft.sightingUUID,
            marineLifeUUID: draft.marineLifeUUID,
            sightingDateTime: draft.sightingDateTime,
            snorkelActivity: snorkel,
            diveSiteID: draft.diveSiteID,
            mediaPhoto: nil,
            snorkelMediaPhoto: mediaPhoto
        )
        SightingInstanceLinking.link(
            sighting,
            marineLifeUUID: draft.marineLifeUUID,
            snorkel: snorkel,
            diveSiteID: draft.diveSiteID,
            snorkelMediaPhoto: mediaPhoto
        )
        snorkel.marineLifeSightings.append(sighting)
        mediaPhoto?.marineLifeSightings.append(sighting)
        modelContext.insert(sighting)
        if persistImmediately {
            try modelContext.save()
        }
        return sighting
    }
}
