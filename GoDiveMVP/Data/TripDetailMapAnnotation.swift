import Foundation
import MapKit

/// MapKit annotation for **`TripDetailMapView`** (planned vs completed tint).
final class TripDetailMapAnnotation: NSObject, MKAnnotation {
    let pinID: String
    let kind: TripDetailMapPinKind
    let siteID: UUID?
    dynamic var coordinate: CLLocationCoordinate2D
    var title: String?

    nonisolated init(pin: TripDetailMapPin) {
        pinID = pin.id
        kind = pin.kind
        siteID = pin.siteID
        coordinate = CLLocationCoordinate2D(
            latitude: pin.coordinate.latitude,
            longitude: pin.coordinate.longitude
        )
        title = ExploreCatalogMapMarkerPresentation.displayTitle(for: pin.title)
    }
}
