import CoreGraphics
import MapKit

/// Explore tab: plot catalog **`DiveSite`** rows that have usable coordinates.
enum ExploreCatalogMapPresentation: Sendable {
    struct PlottedSite: Identifiable, Equatable, Sendable {
        let id: UUID
        let siteName: String
        let coordinate: DiveCoordinate
    }

    nonisolated static func plottableSites(from catalog: [DiveSite]) -> [PlottedSite] {
        catalog.compactMap { site in
            guard let lat = site.latCoords, let lon = site.longCoords else { return nil }
            let coordinate = DiveCoordinate(latitude: lat, longitude: lon)
            guard DiveMapCoordinateResolver.isUsable(coordinate) else { return nil }
            return PlottedSite(id: site.id, siteName: site.siteName, coordinate: coordinate)
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
}
