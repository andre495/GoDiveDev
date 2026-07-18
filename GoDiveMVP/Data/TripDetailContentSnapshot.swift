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
        let resolvedPlannedSites = resolvedPlannedSites(for: trip)
        let catalogSites = catalogSitesForMap(
            plannedSiteIDs: trip.plannedSiteIDs,
            linkedActivities: linked,
            modelContext: trip.modelContext
        )
        let mapPins = TripDetailMapPresentation.pins(
            plannedSites: resolvedPlannedSites,
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
            plannedSiteIDs: trip.plannedSiteIDs,
            linkedActivities: linkedActivities,
            modelContext: trip.modelContext
        )
    }

    /// Resolves **`trip.plannedSiteIDs`** to catalog/user site snapshots via the trip's attached model context.
    @MainActor
    private static func resolvedPlannedSites(for trip: DiveTrip) -> [DiveLinkedSiteResolver.ResolvedSite] {
        guard let modelContext = trip.modelContext else { return [] }
        return trip.plannedSiteIDs.compactMap {
            try? DiveLinkedSiteResolver.resolve(id: $0, modelContext: modelContext)
        }
    }

    @MainActor
    private static func catalogSitesForMap(
        plannedSiteIDs: [UUID],
        linkedActivities: [DiveActivity],
        modelContext: ModelContext?
    ) -> [DiveSite] {
        var byID: [UUID: DiveSite] = [:]
        if let modelContext {
            for id in plannedSiteIDs {
                if let site = try? DiveLinkedSiteResolver.existingCatalogDiveSite(id: id, modelContext: modelContext) {
                    byID[site.id] = site
                }
            }
        }
        for activity in linkedActivities {
            guard let diveSiteID = activity.diveSiteID, let context = activity.modelContext else { continue }
            if let site = try? DiveLinkedSiteResolver.existingCatalogDiveSite(id: diveSiteID, modelContext: context) {
                byID[site.id] = site
            }
        }
        return Array(byID.values)
    }
}
