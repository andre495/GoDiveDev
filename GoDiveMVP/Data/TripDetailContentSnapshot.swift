import Foundation
import SwiftData

/// Cached trip-detail pager + hero inputs — built once per content token, not on every SwiftUI pass.
struct TripDetailContentSnapshot: Sendable {
    let aggregate: DiveTripAggregate
    let linkedDiveRows: [DiveLogbookRowDisplayData]
    let mapPins: [TripDetailMapPin]
    let marineLifeItems: [TripDetailMarineLifeCarouselItem]
    let mediaPhotos: [DiveMediaPhoto]
    let mediaTimeZoneOffsets: [UUID: Int?]
    let linkedMediaItems: [TripDetailLinkedMediaItem]
    let mediaSightings: [SightingInstance]
    let rosterBuddiesByID: [UUID: DiveBuddy]
    let marineLifeCatalog: [MarineLife]

    static let empty = TripDetailContentSnapshot(
        aggregate: .empty,
        linkedDiveRows: [],
        mapPins: [],
        marineLifeItems: [],
        mediaPhotos: [],
        mediaTimeZoneOffsets: [:],
        linkedMediaItems: [],
        mediaSightings: [],
        rosterBuddiesByID: [:],
        marineLifeCatalog: []
    )
}

enum TripDetailContentSnapshotBuilder: Sendable {

    /// Fast path — trip relationships + owner dives only (no store-wide sightings / marine catalog).
    @MainActor
    static func buildLight(
        trip: DiveTrip,
        ownedDiveActivities: [DiveActivity],
        rosterBuddies: [DiveBuddy],
        unitSystem: DiveDisplayUnitSystem,
        useChronologicalNumbers: Bool
    ) -> TripDetailContentSnapshot {
        let linked = DiveTripPresentation.linkedDiveActivities(for: trip)
        let aggregate = DiveTripAggregateBuilder.build(
            trip: trip,
            marineLifeCatalog: [],
            allSightings: []
        )
        let linkedDiveRows = DiveTripPresentation.linkedDiveRowDisplayData(
            trip: trip,
            unitSystem: unitSystem,
            useChronologicalNumbers: useChronologicalNumbers,
            numberingActivities: ownedDiveActivities
        )
        let catalogSites = catalogSitesForMap(
            plannedSites: trip.plannedSites,
            linkedActivities: linked
        )
        let mapPins = TripDetailMapPresentation.pins(
            plannedSites: trip.plannedSites,
            linkedActivities: linked,
            catalogSites: catalogSites
        )
        let linkedMediaItems = TripDetailMediaPresentation.linkedMediaItems(from: linked)
        let mediaPhotos = TripDetailMediaPresentation.mediaPhotos(
            from: linked,
            itemIDs: linkedMediaItems
        )
        let mediaTimeZoneOffsets = TripDetailMediaPresentation.timeZoneOffsetByMediaID(
            from: linked,
            itemIDs: linkedMediaItems
        )
        let rosterBuddiesByID = Dictionary(uniqueKeysWithValues: rosterBuddies.map { ($0.id, $0) })

        return TripDetailContentSnapshot(
            aggregate: aggregate,
            linkedDiveRows: linkedDiveRows,
            mapPins: mapPins,
            marineLifeItems: [],
            mediaPhotos: mediaPhotos,
            mediaTimeZoneOffsets: mediaTimeZoneOffsets,
            linkedMediaItems: linkedMediaItems,
            mediaSightings: [],
            rosterBuddiesByID: rosterBuddiesByID,
            marineLifeCatalog: []
        )
    }

    /// Enriches marine-life carousel + sighting overlays after the shell is visible.
    @MainActor
    static func enrichMarineLife(
        snapshot: TripDetailContentSnapshot,
        trip: DiveTrip,
        unitSystem: DiveDisplayUnitSystem,
        marineLifeCatalog: [MarineLife],
        modelContext: ModelContext
    ) -> TripDetailContentSnapshot {
        let linked = DiveTripPresentation.linkedDiveActivities(for: trip)
        let linkedDiveIDs = Set(linked.map(\.id))
        guard !linkedDiveIDs.isEmpty else { return snapshot }

        let linkedSightings = (try? MarineLifeSightingRecorder.sightings(
            forDiveActivityIDs: linkedDiveIDs,
            modelContext: modelContext
        )) ?? []
        let aggregate = DiveTripAggregateBuilder.build(
            trip: trip,
            marineLifeCatalog: marineLifeCatalog,
            allSightings: linkedSightings
        )
        let marineLifeItems = TripDetailMarineLifePresentation.carouselItems(
            from: aggregate.marineLife,
            catalog: marineLifeCatalog,
            unitSystem: unitSystem
        )
        let mediaSightings = linkedSightings.filter { sighting in
            sighting.mediaPhotoID != nil
        }

        return TripDetailContentSnapshot(
            aggregate: aggregate,
            linkedDiveRows: snapshot.linkedDiveRows,
            mapPins: snapshot.mapPins,
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
    static func catalogSitesForNavigation(
        trip: DiveTrip,
        linkedActivities: [DiveActivity]
    ) -> [DiveSite] {
        catalogSitesForMap(
            plannedSites: trip.plannedSites,
            linkedActivities: linkedActivities
        )
    }

    @MainActor
    private static func catalogSitesForMap(
        plannedSites: [DiveSite],
        linkedActivities: [DiveActivity]
    ) -> [DiveSite] {
        var byID: [UUID: DiveSite] = [:]
        for site in plannedSites {
            byID[site.id] = site
        }
        for activity in linkedActivities {
            if let site = activity.diveSite {
                byID[site.id] = site
            }
        }
        return Array(byID.values)
    }
}
