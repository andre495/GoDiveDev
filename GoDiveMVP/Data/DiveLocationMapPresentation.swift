import CoreLocation
import MapKit

/// Map camera / marker rules for the dive overview map (testable without SwiftUI).
enum DiveLocationMapPresentation {
    static let defaultMarkerTitle = "Dive site"

    /// Wide world view when a dive has no stored coordinates.
    static let defaultRegion = DiveLocationMapRegionSpec(
        centerLatitude: 20,
        centerLongitude: 0,
        latitudeDelta: 120,
        longitudeDelta: 120
    )

    /// Local zoom when coordinates are present (~few km). Tighter than a typical “block” default for overview context.
    static let diveSiteLatitudeDelta = 0.05
    static let diveSiteLongitudeDelta = 0.05

    /// Altitude for **`MapCamera`** when centering on a dive site (meters).
    static let diveSiteCameraDistanceMeters: CLLocationDistance = 4_500

    static func regionSpec(for coordinate: DiveCoordinate?) -> DiveLocationMapRegionSpec {
        guard let coordinate, DiveMapCoordinateResolver.isUsable(coordinate) else { return defaultRegion }
        return DiveLocationMapRegionSpec(
            centerLatitude: coordinate.latitude,
            centerLongitude: coordinate.longitude,
            latitudeDelta: diveSiteLatitudeDelta,
            longitudeDelta: diveSiteLongitudeDelta
        )
    }

    static func showsDiveMarker(for coordinate: DiveCoordinate?) -> Bool {
        DiveMapCoordinateResolver.isUsable(coordinate)
    }

    static func markerTitle(siteName: String?, fallback: String) -> String {
        let trimmed = siteName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : trimmed
    }

    /// Shifts the camera center so a pin at **`coordinate`** sits in the middle of the map band between
    /// **`topObstructionHeight`** and **`bottomObstructionHeight`** (both in the same coordinate space as **`layoutHeight`**).
    static func adjustedMapCenter(
        for coordinate: DiveCoordinate,
        layoutHeight: CGFloat,
        bottomObstructionHeight: CGFloat,
        topObstructionHeight: CGFloat
    ) -> CLLocationCoordinate2D {
        let h = max(layoutHeight, 1)
        let bottomFraction = min(max(bottomObstructionHeight / h, 0), 0.92)
        let topFraction = min(max(topObstructionHeight / h, 0), 0.92)

        // Fraction of viewport the camera must move (in “screen space”) so the target sits mid-band:
        // (visibleCenter - fullMapCenter) / H  ==  (bottom - top) / (2H).
        let halfBandShiftFraction = max(0, (bottomFraction - topFraction) / 2)
        guard halfBandShiftFraction > 0.001 else {
            return CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
        let shift = halfBandShiftFraction * diveSiteLatitudeDelta
        return CLLocationCoordinate2D(
            latitude: coordinate.latitude - shift,
            longitude: coordinate.longitude
        )
    }
}
