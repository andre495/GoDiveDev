import Foundation
import SwiftData

/// Links imported **`DiveActivity`** rows to catalog **`DiveSite`** rows (coordinate match first, then name).
enum DiveActivitySiteAssociation {
    static func fetchCatalogSites(modelContext: ModelContext) throws -> [DiveSite] {
        try modelContext.fetch(FetchDescriptor<DiveSite>())
    }

    /// Tries to set **`diveSite`** / **`diveSiteID`** when not already linked.
    static func applyBestMatch(to activity: DiveActivity, catalogSites: [DiveSite]) {
        guard activity.diveSite == nil else { return }
        guard !catalogSites.isEmpty else { return }

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

    /// Inserts a catalog **`DiveSite`** and links **`activity`** to it.
    @discardableResult
    static func createSiteAndLink(
        to activity: DiveActivity,
        siteName: String,
        latCoords: Double?,
        longCoords: Double?,
        modelContext: ModelContext
    ) throws -> DiveSite {
        let site = DiveSite(
            siteName: siteName,
            latCoords: latCoords,
            longCoords: longCoords
        )
        modelContext.insert(site)
        link(activity, to: site)
        try modelContext.save()
        return site
    }
}
