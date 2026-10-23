import Foundation
import MapKit

/// Region spec for MapKit — separate file so **`Equatable`** stays **nonisolated** (Swift 6 / Swift Testing **`#expect`**).
struct DiveLocationMapRegionSpec: Equatable, Sendable {
    let centerLatitude: Double
    let centerLongitude: Double
    let latitudeDelta: Double
    let longitudeDelta: Double

    /// Validated region safe for `MKMapView.setRegion`. Clamps center/spans to MapKit limits
    /// and returns the world fallback on NaN, infinity, or zero spans.
    nonisolated var sanitized: DiveLocationMapRegionSpec {
        DiveLocationMapRegionSpec.sanitize(
            centerLatitude: centerLatitude,
            centerLongitude: centerLongitude,
            latitudeDelta: latitudeDelta,
            longitudeDelta: longitudeDelta
        )
    }

    nonisolated static func sanitize(
        centerLatitude: Double,
        centerLongitude: Double,
        latitudeDelta: Double,
        longitudeDelta: Double
    ) -> DiveLocationMapRegionSpec {
        guard centerLatitude.isFinite,
              centerLongitude.isFinite,
              latitudeDelta.isFinite,
              longitudeDelta.isFinite,
              latitudeDelta > 0,
              longitudeDelta > 0
        else {
            return worldFallbackRegion
        }

        let clampedCenterLat = min(max(centerLatitude, -90), 90)
        var clampedCenterLon = centerLongitude.truncatingRemainder(dividingBy: 360)
        if clampedCenterLon > 180 { clampedCenterLon -= 360 }
        if clampedCenterLon < -180 { clampedCenterLon += 360 }

        let maxLatSpan = max(180 - 2 * abs(clampedCenterLat), minimumSpan)
        let clampedLatDelta = min(max(latitudeDelta, minimumSpan), maxLatSpan)
        let clampedLonDelta = min(max(longitudeDelta, minimumSpan), 360)

        return DiveLocationMapRegionSpec(
            centerLatitude: clampedCenterLat,
            centerLongitude: clampedCenterLon,
            latitudeDelta: clampedLatDelta,
            longitudeDelta: clampedLonDelta
        )
    }

    /// World view fallback when input is invalid or spans are too wide.
    nonisolated static let worldFallbackRegion = DiveLocationMapRegionSpec(
        centerLatitude: 20,
        centerLongitude: 0,
        latitudeDelta: 120,
        longitudeDelta: 120
    )

    private static let minimumSpan: Double = 0.01

    /// Explicit **nonisolated** equality for Swift Testing **`#expect`** (Swift 6 / MapKit file).
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.centerLatitude == rhs.centerLatitude
            && lhs.centerLongitude == rhs.centerLongitude
            && lhs.latitudeDelta == rhs.latitudeDelta
            && lhs.longitudeDelta == rhs.longitudeDelta
    }

    nonisolated var mkCoordinateRegion: MKCoordinateRegion {
        let safe = sanitized
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: safe.centerLatitude, longitude: safe.centerLongitude),
            span: MKCoordinateSpan(latitudeDelta: safe.latitudeDelta, longitudeDelta: safe.longitudeDelta)
        )
    }

    nonisolated var mkMapRect: MKMapRect {
        let safe = sanitized
        let north = safe.centerLatitude + safe.latitudeDelta / 2
        let south = safe.centerLatitude - safe.latitudeDelta / 2
        let east = safe.centerLongitude + safe.longitudeDelta / 2
        let west = safe.centerLongitude - safe.longitudeDelta / 2
        let southWest = MKMapPoint(CLLocationCoordinate2D(latitude: south, longitude: west))
        let northEast = MKMapPoint(CLLocationCoordinate2D(latitude: north, longitude: east))
        return MKMapRect(
            x: min(southWest.x, northEast.x),
            y: min(southWest.y, northEast.y),
            width: abs(northEast.x - southWest.x),
            height: abs(northEast.y - southWest.y)
        )
    }
}
