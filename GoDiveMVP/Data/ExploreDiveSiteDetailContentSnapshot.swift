import Foundation
import SwiftData

/// Cached dive-site detail pager + hero inputs — built once per content token, not every SwiftUI pass.
struct ExploreDiveSiteDetailContentSnapshot {
    let siteDiveActivities: [DiveActivity]
    let siteDiveRows: [DiveLogbookRowDisplayData]
    let taggedMediaItems: [DiveMediaPhoto]
    let taggedMediaTimeZoneOffsetByID: [UUID: Int?]
    let linkedMediaItems: [TripDetailLinkedMediaItem]
    let siteSightings: [SightingInstance]
    let sightedSpeciesLinks: [DiveSiteMarineLifePresentation.SightedSpeciesLinkData]
    let marineLifeCatalog: [MarineLife]

    static let empty = ExploreDiveSiteDetailContentSnapshot(
        siteDiveActivities: [],
        siteDiveRows: [],
        taggedMediaItems: [],
        taggedMediaTimeZoneOffsetByID: [:],
        linkedMediaItems: [],
        siteSightings: [],
        sightedSpeciesLinks: [],
        marineLifeCatalog: []
    )
}

enum ExploreDiveSiteDetailContentSnapshotBuilder {

    /// Fast path — site-scoped dives + media only (no marine catalog / species links).
    @MainActor
    static func buildLight(
        siteID: UUID,
        siteActivities: [DiveActivity],
        ownerProfileID: UUID?,
        unitSystem: DiveDisplayUnitSystem
    ) -> ExploreDiveSiteDetailContentSnapshot {
        let activitySnapshots = siteActivities.map {
            DiveActivitySightingLinkSnapshot(
                id: $0.id,
                diveSiteID: $0.diveSiteID,
                resolvedSiteName: $0.resolvedSiteName,
                startTime: $0.startTime,
                timeZoneOffsetSeconds: $0.timeZoneOffsetSeconds
            )
        }
        let activityLinks = DiveSiteMarineLifePresentation.siteActivityLinks(
            diveSiteID: siteID,
            ownerProfileID: ownerProfileID,
            activities: activitySnapshots
        )
        let siteDiveRows = FieldGuidePresentation.sightedDiveRowDisplayData(
            activityIDs: activityLinks.map(\.id),
            activities: siteActivities,
            unitSystem: unitSystem
        )
        let linkedMediaItems = ExploreDiveSiteMediaPresentation.linkedMediaItems(from: siteActivities)
        let taggedMediaItems = ExploreDiveSiteMediaPresentation.mediaPhotos(
            siteActivities: siteActivities,
            linkedItems: linkedMediaItems
        )
        let taggedMediaTimeZoneOffsetByID = ExploreDiveSiteMediaPresentation.timeZoneOffsetByMediaID(
            siteActivities: siteActivities,
            linkedItems: linkedMediaItems
        )

        return ExploreDiveSiteDetailContentSnapshot(
            siteDiveActivities: siteActivities,
            siteDiveRows: siteDiveRows,
            taggedMediaItems: taggedMediaItems,
            taggedMediaTimeZoneOffsetByID: taggedMediaTimeZoneOffsetByID,
            linkedMediaItems: linkedMediaItems,
            siteSightings: [],
            sightedSpeciesLinks: [],
            marineLifeCatalog: []
        )
    }

    @MainActor
    static func buildLight(
        site: DiveSite,
        siteActivities: [DiveActivity],
        ownerProfileID: UUID?,
        unitSystem: DiveDisplayUnitSystem
    ) -> ExploreDiveSiteDetailContentSnapshot {
        buildLight(
            siteID: site.id,
            siteActivities: siteActivities,
            ownerProfileID: ownerProfileID,
            unitSystem: unitSystem
        )
    }

    @MainActor
    static func buildLight(
        site: UserDiveSite,
        siteActivities: [DiveActivity],
        ownerProfileID: UUID?,
        unitSystem: DiveDisplayUnitSystem
    ) -> ExploreDiveSiteDetailContentSnapshot {
        buildLight(
            siteID: site.id,
            siteActivities: siteActivities,
            ownerProfileID: ownerProfileID,
            unitSystem: unitSystem
        )
    }

    /// Enriches species links + tagged-media sighting overlays after the shell is visible.
    @MainActor
    static func enrichMarineLife(
        snapshot: ExploreDiveSiteDetailContentSnapshot,
        siteID: UUID,
        ownerProfileID: UUID?,
        marineLifeCatalog: [MarineLife],
        modelContext: ModelContext
    ) -> ExploreDiveSiteDetailContentSnapshot {
        guard ownerProfileID != nil, !snapshot.siteDiveActivities.isEmpty else { return snapshot }

        let siteSightings = fetchSiteSightings(diveSiteID: siteID, modelContext: modelContext)
        let catalogByUUID = Dictionary(uniqueKeysWithValues: marineLifeCatalog.map {
            ($0.uuid, $0.fieldGuideCatalogSnapshot)
        })
        let ownerDiveActivityIDs = Set(snapshot.siteDiveActivities.map(\.id))
        let sightedSpeciesLinks = DiveSiteMarineLifePresentation.sightedSpeciesLinks(
            diveSiteID: siteID,
            ownerProfileID: ownerProfileID,
            sightings: siteSightings,
            ownerDiveActivityIDs: ownerDiveActivityIDs,
            catalogByUUID: catalogByUUID
        )

        return ExploreDiveSiteDetailContentSnapshot(
            siteDiveActivities: snapshot.siteDiveActivities,
            siteDiveRows: snapshot.siteDiveRows,
            taggedMediaItems: snapshot.taggedMediaItems,
            taggedMediaTimeZoneOffsetByID: snapshot.taggedMediaTimeZoneOffsetByID,
            linkedMediaItems: snapshot.linkedMediaItems,
            siteSightings: siteSightings,
            sightedSpeciesLinks: sightedSpeciesLinks,
            marineLifeCatalog: marineLifeCatalog
        )
    }

    @MainActor
    static func enrichMarineLife(
        snapshot: ExploreDiveSiteDetailContentSnapshot,
        site: DiveSite,
        ownerProfileID: UUID?,
        marineLifeCatalog: [MarineLife],
        modelContext: ModelContext
    ) -> ExploreDiveSiteDetailContentSnapshot {
        enrichMarineLife(
            snapshot: snapshot,
            siteID: site.id,
            ownerProfileID: ownerProfileID,
            marineLifeCatalog: marineLifeCatalog,
            modelContext: modelContext
        )
    }

    @MainActor
    static func enrichMarineLife(
        snapshot: ExploreDiveSiteDetailContentSnapshot,
        site: UserDiveSite,
        ownerProfileID: UUID?,
        marineLifeCatalog: [MarineLife],
        modelContext: ModelContext
    ) -> ExploreDiveSiteDetailContentSnapshot {
        enrichMarineLife(
            snapshot: snapshot,
            siteID: site.id,
            ownerProfileID: ownerProfileID,
            marineLifeCatalog: marineLifeCatalog,
            modelContext: modelContext
        )
    }

    nonisolated static func fetchSiteDiveActivities(
        diveSiteID: UUID,
        ownerProfileID: UUID,
        modelContext: ModelContext
    ) -> [DiveActivity] {
        let descriptor = FetchDescriptor<DiveActivity>(
            predicate: #Predicate<DiveActivity> { activity in
                activity.ownerProfileID == ownerProfileID && activity.diveSiteID == diveSiteID
            },
            sortBy: [
                SortDescriptor(\.startTime, order: .reverse),
                SortDescriptor(\.id, order: .forward),
            ]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    nonisolated static func fetchSiteDiveActivityPersistentIDs(
        diveSiteID: UUID,
        ownerProfileID: UUID,
        container: ModelContainer
    ) async -> [PersistentIdentifier] {
        await Task.detached(priority: .utility) {
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<DiveActivity>(
                predicate: #Predicate<DiveActivity> { activity in
                    activity.ownerProfileID == ownerProfileID && activity.diveSiteID == diveSiteID
                },
                sortBy: [
                    SortDescriptor(\.startTime, order: .reverse),
                    SortDescriptor(\.id, order: .forward),
                ]
            )
            let rows = (try? context.fetch(descriptor)) ?? []
            return rows.map(\.persistentModelID)
        }.value
    }

    @MainActor
    static func bindDiveActivities(
        persistentIDs: [PersistentIdentifier],
        modelContext: ModelContext
    ) -> [DiveActivity] {
        persistentIDs.compactMap { modelContext.model(for: $0) as? DiveActivity }
    }

    @MainActor
    static func fetchSiteDiveActivitiesAsync(
        diveSiteID: UUID,
        ownerProfileID: UUID,
        modelContext: ModelContext
    ) async -> [DiveActivity] {
        let persistentIDs = await fetchSiteDiveActivityPersistentIDs(
            diveSiteID: diveSiteID,
            ownerProfileID: ownerProfileID,
            container: modelContext.container
        )
        guard !Task.isCancelled else { return [] }
        return bindDiveActivities(persistentIDs: persistentIDs, modelContext: modelContext)
    }

    /// Fast first-frame site dives — **`DiveSite`** no longer holds an inverse relationship (UUID-only link),
    /// so this returns empty; **`fetchSiteDiveActivitiesAsync`** populates the real list right after.
    nonisolated static func siteActivitiesFromRelationships(
        site: DiveSite,
        ownerProfileID: UUID?
    ) -> [DiveActivity] {
        []
    }

    nonisolated static func fetchSiteSightings(
        diveSiteID: UUID,
        modelContext: ModelContext
    ) -> [SightingInstance] {
        let descriptor = FetchDescriptor<SightingInstance>(
            predicate: #Predicate<SightingInstance> { $0.diveSiteID == diveSiteID },
            sortBy: [SortDescriptor(\.sightingDateTime, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
