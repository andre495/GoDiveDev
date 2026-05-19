import MapKit
import UIKit

/// Dive map pin only (site name lives on the overview sheet header).
final class DiveSiteMapAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "DiveSitePin"

    private let pinImageView = UIImageView()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        canShowCallout = false
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        nil
    }

    func configure(pinImage: UIImage) {
        pinImageView.image = pinImage
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let pinSize = pinImageView.image?.size ?? .zero
        bounds = CGRect(origin: .zero, size: pinSize)

        pinImageView.frame = CGRect(origin: .zero, size: pinSize)

        // Anchor the geographic coordinate at the bottom of the pin (tip on the map).
        centerOffset = CGPoint(x: 0, y: -pinSize.height / 2)
    }

    private func setupViews() {
        pinImageView.contentMode = .scaleAspectFit
        addSubview(pinImageView)
    }
}
