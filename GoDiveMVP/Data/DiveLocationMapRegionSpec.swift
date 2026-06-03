import Foundation
import MapKit

/// Region spec for MapKit — separate file so **`Equatable`** stays **nonisolated** (Swift 6 / Swift Testing **`#expect`**).
struct DiveLocationMapRegionSpec: Equatable, Sendable {
    let centerLatitude: Double
    let centerLongitude: Double
    let latitudeDelta: Double
    let longitudeDelta: Double

    /// Explicit **nonisolated** equality for Swift Testing **`#expect`** (Swift 6 / MapKit file).
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.centerLatitude == rhs.centerLatitude
            && lhs.centerLongitude == rhs.centerLongitude
            && lhs.latitudeDelta == rhs.latitudeDelta
            && lhs.longitudeDelta == rhs.longitudeDelta
    }

    nonisolated var mkCoordinateRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude),
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }
}
