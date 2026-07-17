import CoreGraphics
import MapKit

/// Explore tab: plot catalog **`DiveSite`** rows that have usable coordinates.
enum ExploreCatalogMapPresentation: Sendable {
    struct PlottedSite: Identifiable, Equatable, Sendable {
        let id: UUID
        let siteName: String
        let coordinate: DiveCoordinate
        let selection: ExploreMapSiteSelection
        /// **`true`** when the signed-in diver has logged a dive linked to this site.
        let isVisited: Bool

        nonisolated init(
            id: UUID,
            siteName: String,
            coordinate: DiveCoordinate,
            selection: ExploreMapSiteSelection? = nil,
            isVisited: Bool = false
        ) {
            self.id = id
            self.siteName = siteName
            self.coordinate = coordinate
            self.selection = selection ?? .catalog(id)
            self.isVisited = isVisited
        }

        nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id
                && lhs.siteName == rhs.siteName
                && lhs.coordinate == rhs.coordinate
                && lhs.selection == rhs.selection
                && lhs.isVisited == rhs.isVisited
        }
    }

    nonisolated static func plottableSites(from catalog: [DiveSite]) -> [PlottedSite] {
        catalog.compactMap { site in
            guard let lat = site.latCoords, let lon = site.longCoords else { return nil }
            let coordinate = DiveCoordinate(latitude: lat, longitude: lon)
            guard DiveMapCoordinateResolver.isUsable(coordinate) else { return nil }
            return PlottedSite(
                id: site.id,
                siteName: DiveSiteCatalogMatcher.resolvedCatalogSiteName(for: site) ?? site.siteName,
                coordinate: coordinate,
                selection: .catalog(site.id),
                isVisited: true
            )
        }
    }

    nonisolated static func plottableSites(from userSites: [UserDiveSite]) -> [PlottedSite] {
        userSites.compactMap { site in
            guard let lat = site.latCoords, let lon = site.longCoords else { return nil }
            let coordinate = DiveCoordinate(latitude: lat, longitude: lon)
            guard DiveMapCoordinateResolver.isUsable(coordinate) else { return nil }
            return PlottedSite(
                id: site.id,
                siteName: site.siteName,
                coordinate: coordinate,
                selection: .catalog(site.id),
                isVisited: true
            )
        }
    }

    /// Region that fits all plotted sites with padding; **`nil`** when empty (use default world view).
    nonisolated static func boundingRegion(for sites: [PlottedSite]) -> DiveLocationMapRegionSpec? {
        guard let first = sites.first else { return nil }
        guard sites.count == 1 else {
            var minLat = first.coordinate.latitude
            var maxLat = first.coordinate.latitude
            var minLon = first.coordinate.longitude
            var maxLon = first.coordinate.longitude
            for site in sites.dropFirst() {
                minLat = min(minLat, site.coordinate.latitude)
                maxLat = max(maxLat, site.coordinate.latitude)
                minLon = min(minLon, site.coordinate.longitude)
                maxLon = max(maxLon, site.coordinate.longitude)
            }
            let latDelta = max((maxLat - minLat) * 1.35, 0.04)
            let lonDelta = max((maxLon - minLon) * 1.35, 0.04)
            return DiveLocationMapRegionSpec(
                centerLatitude: (minLat + maxLat) / 2,
                centerLongitude: (minLon + maxLon) / 2,
                latitudeDelta: latDelta,
                longitudeDelta: lonDelta
            )
        }
        return DiveLocationMapRegionSpec(
            centerLatitude: first.coordinate.latitude,
            centerLongitude: first.coordinate.longitude,
            latitudeDelta: DiveLocationMapPresentation.diveSiteLatitudeDelta,
            longitudeDelta: DiveLocationMapPresentation.diveSiteLongitudeDelta
        )
    }

    nonisolated static func region(for sites: [PlottedSite]) -> MKCoordinateRegion? {
        boundingRegion(for: sites)?.mkCoordinateRegion
    }

    /// Cheap fingerprint for map pin sync — avoids sorting thousands of site ids on every map update.
    nonisolated static func sitesChangeSignature(for sites: [PlottedSite]) -> String {
        var hasher = Hasher()
        hasher.combine(sites.count)
        for site in sites {
            hasher.combine(site.id)
            hasher.combine(site.isVisited)
        }
        return "\(sites.count)-\(hasher.finalize())"
    }
}
