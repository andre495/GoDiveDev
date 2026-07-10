import Foundation
import SwiftData

/// Cached tag-detail pager + hero inputs — built once per content token.
struct ActivityTagDetailContentSnapshot: Sendable {
    let aggregate: DiveTripAggregate
    let linkedDiveRows: [DiveLogbookRowDisplayData]
    let mapPins: [TripDetailMapPin]
    let catalogSites: [DiveSite]
    let marineLifeItems: [TripDetailMarineLifeCarouselItem]
    let mediaPhotos: [DiveMediaPhoto]
    let mediaTimeZoneOffsets: [UUID: Int?]
    let linkedMediaItems: [TripDetailLinkedMediaItem]
    let mediaSightings: [SightingInstance]
    let rosterBuddiesByID: [UUID: DiveBuddy]
    let marineLifeCatalog: [MarineLife]

    static let empty = ActivityTagDetailContentSnapshot(
        aggregate: .empty,
        linkedDiveRows: [],
        mapPins: [],
        catalogSites: [],
        marineLifeItems: [],
        mediaPhotos: [],
        mediaTimeZoneOffsets: [:],
        linkedMediaItems: [],
        mediaSightings: [],
        rosterBuddiesByID: [:],
        marineLifeCatalog: []
    )
}

enum ActivityTagDetailContentSnapshotBuilder: Sendable {

    @MainActor
    static func buildLight(
        tag: ActivityTag,
        ownedDiveActivities: [DiveActivity],
        rosterBuddies: [DiveBuddy],
        unitSystem: DiveDisplayUnitSystem,
        useChronologicalNumbers: Bool,
        ownerProfileID: UUID?
    ) -> ActivityTagDetailContentSnapshot {
        let tagged = ActivityTagDetailPresentation.taggedDives(on: tag)
        let diveSnapshots = DiveTripAggregateBuilder.snapshots(from: tagged)
        let aggregate = DiveTripAggregateBuilder.build(
            linkedDives: diveSnapshots,
            sightings: [],
            plannedSiteNames: [],
            countries: []
        )
        let linkedDiveRows = ActivityTagDetailPresentation.diveRowDisplayData(
            dives: tagged,
            unitSystem: unitSystem,
            useChronologicalNumbers: useChronologicalNumbers,
            ownerProfileID: ownerProfileID,
            numberingActivities: ownedDiveActivities
        )
        let catalogSites = catalogSitesForMap(linkedActivities: tagged)
        let mapPins = TripDetailMapPresentation.pins(
            plannedSites: [],
            linkedActivities: tagged,
            catalogSites: catalogSites
        )
        let linkedMediaItems = TripDetailMediaPresentation.linkedMediaItems(from: tagged)
        let mediaPhotos = TripDetailMediaPresentation.mediaPhotos(
            from: tagged,
            itemIDs: linkedMediaItems
        )
        let mediaTimeZoneOffsets = TripDetailMediaPresentation.timeZoneOffsetByMediaID(
            from: tagged,
            itemIDs: linkedMediaItems
        )
        let rosterBuddiesByID = Dictionary(uniqueKeysWithValues: rosterBuddies.map { ($0.id, $0) })

        return ActivityTagDetailContentSnapshot(
            aggregate: aggregate,
            linkedDiveRows: linkedDiveRows,
            mapPins: mapPins,
            catalogSites: catalogSites,
            marineLifeItems: [],
            mediaPhotos: mediaPhotos,
            mediaTimeZoneOffsets: mediaTimeZoneOffsets,
            linkedMediaItems: linkedMediaItems,
            mediaSightings: [],
            rosterBuddiesByID: rosterBuddiesByID,
            marineLifeCatalog: []
        )
    }

    @MainActor
    static func enrichMarineLife(
        snapshot: ActivityTagDetailContentSnapshot,
        taggedDives: [DiveActivity],
        unitSystem: DiveDisplayUnitSystem,
        marineLifeCatalog: [MarineLife],
        modelContext: ModelContext
    ) -> ActivityTagDetailContentSnapshot {
        let taggedDiveIDs = Set(taggedDives.map(\.id))
        guard !taggedDiveIDs.isEmpty else { return snapshot }

        let linkedSightings = (try? MarineLifeSightingRecorder.sightings(
            forDiveActivityIDs: taggedDiveIDs,
            modelContext: modelContext
        )) ?? []
        let diveSnapshots = DiveTripAggregateBuilder.snapshots(from: taggedDives)
        let sightingSnapshots = DiveTripAggregateBuilder.sightingSnapshots(
            from: linkedSightings,
            marineLifeCatalog: marineLifeCatalog
        )
        let aggregate = DiveTripAggregateBuilder.build(
            linkedDives: diveSnapshots,
            sightings: sightingSnapshots,
            plannedSiteNames: [],
            countries: []
        )
        let marineLifeItems = TripDetailMarineLifePresentation.carouselItems(
            from: aggregate.marineLife,
            catalog: marineLifeCatalog,
            unitSystem: unitSystem
        )
        let mediaSightings = linkedSightings.filter { sighting in
            sighting.mediaPhotoID != nil
        }

        return ActivityTagDetailContentSnapshot(
            aggregate: aggregate,
            linkedDiveRows: snapshot.linkedDiveRows,
            mapPins: snapshot.mapPins,
            catalogSites: snapshot.catalogSites,
            marineLifeItems: marineLifeItems,
            mediaPhotos: snapshot.mediaPhotos,
            mediaTimeZoneOffsets: snapshot.mediaTimeZoneOffsets,
            linkedMediaItems: snapshot.linkedMediaItems,
            mediaSightings: mediaSightings,
            rosterBuddiesByID: snapshot.rosterBuddiesByID,
            marineLifeCatalog: marineLifeCatalog
        )
    }

    @MainActor
    private static func catalogSitesForMap(linkedActivities: [DiveActivity]) -> [DiveSite] {
        var byID: [UUID: DiveSite] = [:]
        for activity in linkedActivities {
            if let site = activity.diveSite {
                byID[site.id] = site
            }
        }
        return Array(byID.values)
    }
}
