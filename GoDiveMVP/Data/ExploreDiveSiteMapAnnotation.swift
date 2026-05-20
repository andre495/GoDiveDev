import Foundation
import MapKit

/// MapKit annotation for a catalog **`DiveSite`** on **Explore**.
final class ExploreDiveSiteMapAnnotation: NSObject, MKAnnotation {
    let siteID: UUID
    let siteName: String
    @objc dynamic var coordinate: CLLocationCoordinate2D

    init(site: ExploreCatalogMapPresentation.PlottedSite) {
        self.siteID = site.id
        self.siteName = site.siteName
        self.coordinate = CLLocationCoordinate2D(
            latitude: site.coordinate.latitude,
            longitude: site.coordinate.longitude
        )
        super.init()
    }

    var title: String? { siteName }
}
