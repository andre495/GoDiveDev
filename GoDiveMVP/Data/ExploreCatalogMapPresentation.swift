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
    nonisolated static func region(for sites: [PlottedSite]) -> MKCoordinateRegion? {
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
            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            )
            let latDelta = max((maxLat - minLat) * 1.35, 0.04)
            let lonDelta = max((maxLon - minLon) * 1.35, 0.04)
            return MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
            )
        }
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: first.coordinate.latitude,
                longitude: first.coordinate.longitude
            ),
            span: MKCoordinateSpan(
                latitudeDelta: DiveLocationMapPresentation.diveSiteLatitudeDelta,
                longitudeDelta: DiveLocationMapPresentation.diveSiteLongitudeDelta
            )
        )
    }
}
