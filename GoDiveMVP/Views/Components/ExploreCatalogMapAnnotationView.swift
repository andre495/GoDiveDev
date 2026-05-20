import MapKit
import UIKit

/// Explore map annotation — red pin only (details in sheet on tap).
final class ExploreCatalogMapAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "ExploreCatalogPin"

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        canShowCallout = false
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        nil
    }

    func configure(pinImage: UIImage, accessibilityTitle: String) {
        image = pinImage
        bounds = CGRect(origin: .zero, size: pinImage.size)
        centerOffset = MapAnnotationPinAnchor.pinOnlyCenterOffset
        accessibilityLabel = accessibilityTitle
    }
}
