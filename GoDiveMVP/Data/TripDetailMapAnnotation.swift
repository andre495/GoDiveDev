import Foundation
import MapKit

/// MapKit annotation for **`TripDetailMapView`** (planned vs completed tint).
final class TripDetailMapAnnotation: NSObject, MKAnnotation {
    let pinID: String
    let kind: TripDetailMapPinKind
    let siteID: UUID?
    let siteDisplayName: String?
    dynamic var coordinate: CLLocationCoordinate2D
    /// Pin-only callouts use **`detailCalloutAccessoryView`**; suppress the default title row.
    var title: String? { nil }

    nonisolated init(pin: TripDetailMapPin) {
        pinID = pin.id
        kind = pin.kind
        siteID = pin.siteID
        coordinate = CLLocationCoordinate2D(
            latitude: pin.coordinate.latitude,
            longitude: pin.coordinate.longitude
        )
        siteDisplayName = ExploreCatalogMapMarkerPresentation.displayTitle(for: pin.title)
    }
}
