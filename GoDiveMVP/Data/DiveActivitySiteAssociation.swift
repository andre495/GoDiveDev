import Foundation
import SwiftData

/// Links imported **`DiveActivity`** rows to catalog **`DiveSite`** rows (unique exact **`siteName`** first, then coordinate, then fuzzy name).
enum DiveActivitySiteAssociation {
    static func fetchCatalogSites(modelContext: ModelContext) throws -> [DiveSite] {
        try modelContext.fetch(FetchDescriptor<DiveSite>())
    }

    /// Tries to set **`diveSite`** / **`diveSiteID`** when not already linked.
    static func applyBestMatch(to activity: DiveActivity, catalogSites: [DiveSite]) {
        guard activity.diveSite == nil else { return }
        guard !catalogSites.isEmpty else { return }

        if let site = DiveMapCoordinateResolver.uniquelyMatchingSite(
            forSiteName: activity.siteName,
            in: catalogSites
        ) {
            link(activity, to: site)
            return
        }

        if let entry = activity.entryCoordinate,
           DiveMapCoordinateResolver.isUsable(entry),
           let site = DiveSiteCoordinateMatcher.bestMatch(for: entry, in: catalogSites) {
            link(activity, to: site)
            return
        }

        if let site = DiveMapCoordinateResolver.matchingSite(forSiteName: activity.siteName, in: catalogSites) {
            link(activity, to: site)
        }
    }

    static func link(_ activity: DiveActivity, to site: DiveSite) {
        activity.diveSite = site
        activity.diveSiteID = site.id
    }

    static func unlink(_ activity: DiveActivity) {
        activity.diveSite = nil
        activity.diveSiteID = nil
    }

    /// Links inserted dives to catalog sites; optionally creates **`DiveSite`** rows for unmatched import site names.
    @MainActor
    @discardableResult
    static func applySiteLinksForImportedActivities(
        _ activities: [DiveActivity],
        catalogSites: inout [DiveSite],
        createMissingSites: Bool,
        modelContext: ModelContext
    ) -> Int {
        var createdSiteCount = 0
        for activity in activities {
            applyBestMatch(to: activity, catalogSites: catalogSites)
            guard activity.diveSite == nil else { continue }
            guard createMissingSites else { continue }
            guard let siteName = trimmedSiteName(activity.siteName) else { continue }

            if let existing = DiveMapCoordinateResolver.matchingSite(forSiteName: siteName, in: catalogSites) {
                link(activity, to: existing)
                continue
            }

            let places = DiveImportedLocationParsing.placeFields(fromLocationName: activity.locationName)
            let lat = activity.entryCoordinate.flatMap { DiveMapCoordinateResolver.isUsable($0) ? $0.latitude : nil }
            let lon = activity.entryCoordinate.flatMap { DiveMapCoordinateResolver.isUsable($0) ? $0.longitude : nil }
            let site = DiveSite(
                siteName: siteName,
                country: DiveSiteFormValidation.sanitizedPlaceField(places.country),
                region: DiveSiteFormValidation.sanitizedPlaceField(places.region),
                latCoords: lat,
                longCoords: lon
            )
            modelContext.insert(site)
            catalogSites.append(site)
            link(activity, to: site)
            createdSiteCount += 1
        }
        return createdSiteCount
    }

    private static func trimmedSiteName(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    /// Inserts a catalog **`DiveSite`** and links **`activity`** to it.
    @discardableResult
    static func createSiteAndLink(
        to activity: DiveActivity,
        siteName: String,
        country: String = "",
        region: String = "",
        bodyOfWater: String = "",
        latCoords: Double?,
        longCoords: Double?,
        modelContext: ModelContext
    ) throws -> DiveSite {
        let site = DiveSite(
            siteName: siteName,
            country: DiveSiteFormValidation.sanitizedPlaceField(country),
            region: DiveSiteFormValidation.sanitizedPlaceField(region),
            bodyOfWater: DiveSiteFormValidation.sanitizedPlaceField(bodyOfWater),
            latCoords: latCoords,
            longCoords: longCoords
        )
        modelContext.insert(site)
        link(activity, to: site)
        try modelContext.save()
        return site
    }
}
