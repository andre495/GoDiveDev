import MapKit
import UIKit

/// Dive map pin with coordinate label (site name stays on the overview sheet header).
final class DiveSiteMapAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "DiveSitePin"

    private enum Layout {
        static let pinToLabelSpacing: CGFloat = 4
        static let labelPadding = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        static let labelCornerRadius: CGFloat = 6
    }

    private let pinImageView = UIImageView()
    private let coordinateLabelContainer = UIView()
    private let coordinateLabel = UILabel()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        canShowCallout = false
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        nil
    }

    func configure(pinImage: UIImage, coordinateLabel text: String) {
        pinImageView.image = pinImage
        coordinateLabel.text = text
        accessibilityLabel = "Dive site, \(text)"
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let pinSize = pinImageView.image?.size ?? .zero
        let maxLabelWidth = max(pinSize.width, 160)
        let labelTextSize = coordinateLabel.sizeThatFits(
            CGSize(width: maxLabelWidth, height: .greatestFiniteMagnitude)
        )
        let labelBoxSize = CGSize(
            width: labelTextSize.width + Layout.labelPadding.left + Layout.labelPadding.right,
            height: labelTextSize.height + Layout.labelPadding.top + Layout.labelPadding.bottom
        )
        let totalWidth = max(pinSize.width, labelBoxSize.width)
        let totalHeight = pinSize.height + Layout.pinToLabelSpacing + labelBoxSize.height

        bounds = CGRect(origin: .zero, size: CGSize(width: totalWidth, height: totalHeight))

        pinImageView.frame = CGRect(
            x: (totalWidth - pinSize.width) / 2,
            y: 0,
            width: pinSize.width,
            height: pinSize.height
        )

        coordinateLabelContainer.frame = CGRect(
            x: (totalWidth - labelBoxSize.width) / 2,
            y: pinSize.height + Layout.pinToLabelSpacing,
            width: labelBoxSize.width,
            height: labelBoxSize.height
        )
        coordinateLabel.frame = coordinateLabelContainer.bounds.inset(by: Layout.labelPadding)

        // Anchor the geographic coordinate at the bottom of the pin (tip on the map).
        let pinTipY = pinImageView.frame.maxY
        centerOffset = CGPoint(x: 0, y: pinTipY - bounds.midY)
    }

    private func setupViews() {
        pinImageView.contentMode = .scaleAspectFit
        addSubview(pinImageView)

        coordinateLabelContainer.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.92)
        coordinateLabelContainer.layer.cornerRadius = Layout.labelCornerRadius
        coordinateLabelContainer.layer.cornerCurve = .continuous
        coordinateLabelContainer.clipsToBounds = true
        addSubview(coordinateLabelContainer)

        coordinateLabel.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        coordinateLabel.textColor = .label
        coordinateLabel.textAlignment = .center
        coordinateLabel.numberOfLines = 1
        coordinateLabel.adjustsFontSizeToFitWidth = true
        coordinateLabel.minimumScaleFactor = 0.85
        coordinateLabelContainer.addSubview(coordinateLabel)
    }
}
