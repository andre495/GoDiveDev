import Foundation
import SwiftData

/// Links imported **`DiveActivity`** rows to catalog **`DiveSite`** rows (exact import **`siteName`** first; GPS only when the dive has no site name).
enum DiveActivitySiteAssociation {
    static func fetchCatalogSites(modelContext: ModelContext) throws -> [DiveSite] {
        try modelContext.fetch(FetchDescriptor<DiveSite>())
    }

    /// Tries to set **`diveSite`** / **`diveSiteID`** when not already linked.
    static func applyBestMatch(to activity: DiveActivity, catalogSites: [DiveSite]) {
        guard activity.diveSite == nil else { return }
        guard !catalogSites.isEmpty else { return }

        if let siteName = trimmedSiteName(activity.siteName) {
            applyNameBasedMatch(to: activity, siteName: siteName, catalogSites: catalogSites)
            return
        }

        if let entry = activity.entryCoordinate,
           DiveMapCoordinateResolver.isUsable(entry),
           let site = DiveSiteCoordinateMatcher.bestMatch(for: entry, in: catalogSites) {
            link(activity, to: site)
        }
    }

    /// Import **`siteName`** → exact catalog name match only (never a different nearby site). Duplicate names disambiguate by GPS within that name set.
    private static func applyNameBasedMatch(
        to activity: DiveActivity,
        siteName: String,
        catalogSites: [DiveSite]
    ) {
        let exactMatches = DiveMapCoordinateResolver.exactMatchingSites(forSiteName: siteName, in: catalogSites)
        guard let site = disambiguateSiteMatches(exactMatches, entryCoordinate: activity.entryCoordinate) else {
            return
        }
        link(activity, to: site)
    }

    private static func disambiguateSiteMatches(
        _ matches: [DiveSite],
        entryCoordinate: DiveCoordinate?
    ) -> DiveSite? {
        switch matches.count {
        case 0:
            return nil
        case 1:
            return matches[0]
        default:
            if let entry = entryCoordinate,
               DiveMapCoordinateResolver.isUsable(entry),
               let nearest = DiveSiteCoordinateMatcher.bestMatch(for: entry, in: matches) {
                return nearest
            }
            return matches[0]
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
            if createSiteForImportNameIfNeeded(
                to: activity,
                catalogSites: &catalogSites,
                modelContext: modelContext
            ) {
                createdSiteCount += 1
            }
        }
        return createdSiteCount
    }

    /// Creates a catalog **`DiveSite`** when the dive has an import **`siteName`** with no exact catalog match.
    @MainActor
    @discardableResult
    static func createSiteForImportNameIfNeeded(
        to activity: DiveActivity,
        catalogSites: inout [DiveSite],
        modelContext: ModelContext
    ) -> Bool {
        guard activity.diveSite == nil else { return false }
        guard let siteName = trimmedSiteName(activity.siteName) else { return false }
        guard DiveMapCoordinateResolver.exactMatchingSites(forSiteName: siteName, in: catalogSites).isEmpty else {
            return false
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
        return true
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
