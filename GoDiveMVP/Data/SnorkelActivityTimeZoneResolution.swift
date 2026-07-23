import Foundation
import SwiftData

enum SnorkelActivityTimeZoneResolution {

    static func coordinateForLookup(
        on activity: SnorkelActivity,
        catalogSites: [DiveSite] = []
    ) -> DiveCoordinate? {
        if let matched = DiveActivitySiteAssociation.previewBestMatch(for: activity, catalogSites: catalogSites),
           let catalogCoordinate = DiveMapCoordinateResolver.coordinate(from: matched),
           DiveMapCoordinateResolver.isUsable(catalogCoordinate) {
            return catalogCoordinate
        }
        if let entry = activity.entryCoordinate, DiveMapCoordinateResolver.isUsable(entry) {
            return entry
        }
        if let site = activity.resolvedLinkedSite,
           let coordinate = DiveMapCoordinateResolver.coordinate(from: site),
           DiveMapCoordinateResolver.isUsable(coordinate) {
            return coordinate
        }
        return nil
    }

    @MainActor
    static func resolveMissingOffset(for activity: SnorkelActivity) async {
        await resolveMissingOffset(for: activity, catalogSites: [], resolver: MapKitGeocodingTimeZoneResolver.shared)
    }

    @MainActor
    static func resolveMissingOffset(
        for activity: SnorkelActivity,
        catalogSites: [DiveSite] = [],
        resolver: any GeocodingTimeZoneResolving
    ) async {
        guard activity.timeZoneOffsetSeconds == nil else { return }

        if let matched = DiveActivitySiteAssociation.previewBestMatch(
            for: activity,
            catalogSites: catalogSites
        ),
           let offset = DiveSiteTimeZoneResolution.offsetSeconds(for: matched, at: activity.startTime) {
            activity.timeZoneOffsetSeconds = offset
            return
        }

        guard let coordinate = coordinateForLookup(on: activity, catalogSites: catalogSites) else { return }

        let input = DiveGeographicTimeZoneLookup.CoordinateInput(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        if let timeZone = await resolver.timeZone(for: input) {
            activity.timeZoneOffsetSeconds = timeZone.secondsFromGMT(for: activity.startTime)
            if let diveSiteID = activity.diveSiteID, let modelContext = activity.modelContext {
                if let userSite = try? DiveLinkedSiteResolver.existingUserDiveSite(id: diveSiteID, modelContext: modelContext) {
                    DiveSiteTimeZoneResolution.persist(timeZone, on: userSite, at: activity.startTime)
                } else if let catalogSite = try? DiveLinkedSiteResolver.existingCatalogDiveSite(id: diveSiteID, modelContext: modelContext) {
                    DiveSiteTimeZoneResolution.persist(timeZone, on: catalogSite, at: activity.startTime)
                }
            } else if let matched = DiveActivitySiteAssociation.previewBestMatch(
                for: activity,
                catalogSites: catalogSites
            ) {
                DiveSiteTimeZoneResolution.persist(timeZone, on: matched, at: activity.startTime)
            }
        }
    }
}
