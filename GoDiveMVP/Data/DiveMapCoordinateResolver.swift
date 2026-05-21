import Foundation

/// Resolves the coordinate shown on dive maps (stored GPS, then catalog **`DiveSite`** match).
enum DiveMapCoordinateResolver {
    /// Pure coordinate validation — **`nonisolated`** for map presentation helpers and tests (Swift 6).
    nonisolated static func isUsable(_ coordinate: DiveCoordinate?) -> Bool {
        guard let coordinate else { return false }
        guard (-90 ... 90).contains(coordinate.latitude),
              (-180 ... 180).contains(coordinate.longitude)
        else { return false }
        if abs(coordinate.latitude) < 0.000_001, abs(coordinate.longitude) < 0.000_001 {
            return false
        }
        return true
    }

    static func effectiveCoordinate(
        activityCoordinate: DiveCoordinate?,
        siteName: String?,
        catalogSites: [DiveSite]
    ) -> DiveCoordinate? {
        if isUsable(activityCoordinate) {
            return activityCoordinate
        }
        if let matched = DiveSiteCoordinateMatcher.bestMatch(for: activityCoordinate, in: catalogSites),
           let resolved = coordinate(from: matched) {
            return resolved
        }
        if let byName = coordinate(fromSiteName: siteName, in: catalogSites) {
            return byName
        }
        return nil
    }

    /// Reads **`latCoords`** / **`longCoords`** only — **`nonisolated`** for map prompt drafts and Explore (Swift 6).
    nonisolated static func coordinate(from site: DiveSite) -> DiveCoordinate? {
        guard let lat = site.latCoords, let lon = site.longCoords else { return nil }
        let candidate = DiveCoordinate(latitude: lat, longitude: lon)
        return isUsable(candidate) ? candidate : nil
    }

    static func matchingSite(forSiteName siteName: String?, in sites: [DiveSite]) -> DiveSite? {
        guard let normalized = normalizedSiteName(siteName) else { return nil }

        if let exact = sites.first(where: { normalizedSiteName($0.siteName) == normalized }) {
            return exact
        }

        return sites.first(where: { catalogNameContainsDiveName($0.siteName, diveName: normalized) })
    }

    static func coordinate(fromSiteName siteName: String?, in sites: [DiveSite]) -> DiveCoordinate? {
        guard let site = matchingSite(forSiteName: siteName, in: sites) else { return nil }
        return coordinate(from: site)
    }

    private static func catalogNameContainsDiveName(_ catalogName: String, diveName: String) -> Bool {
        guard let catalog = normalizedSiteName(catalogName) else { return false }
        return catalog.contains(diveName) || diveName.contains(catalog)
    }

    private static func normalizedSiteName(_ name: String?) -> String? {
        guard let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed.lowercased()
    }
}
