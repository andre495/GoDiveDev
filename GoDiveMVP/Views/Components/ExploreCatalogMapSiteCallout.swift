#if canImport(UIKit)
import UIKit

/// Shared callout chrome for Explore catalog map pins (MapKit accessory + Google info window).
enum ExploreCatalogMapSiteCallout {
    static func makeChevronAccessory() -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "chevron.right")
        configuration.baseForegroundColor = .secondaryLabel
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        let button = UIButton(configuration: configuration)
        button.accessibilityLabel = "View dive site details"
        return button
    }

    static func makeGoogleInfoWindow(siteName: String, maxWidth: CGFloat = 240) -> UIView {
        let container = UIView()
        container.backgroundColor = .systemBackground
        container.layer.cornerRadius = 10
        container.layer.cornerCurve = .continuous
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.18
        container.layer.shadowRadius = 6
        container.layer.shadowOffset = CGSize(width: 0, height: 2)

        let label = UILabel()
        label.text = siteName
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .label
        label.numberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .secondaryLabel
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        chevron.setContentCompressionResistancePriority(.required, for: .horizontal)
        chevron.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(label)
        container.addSubview(chevron)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
            label.trailingAnchor.constraint(lessThanOrEqualTo: chevron.leadingAnchor, constant: -8),
            chevron.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            chevron.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            container.widthAnchor.constraint(equalToConstant: maxWidth),
        ])

        container.accessibilityLabel = siteName
        container.accessibilityHint = "Opens dive site details"
        container.isAccessibilityElement = true

        let size = container.systemLayoutSizeFitting(
            CGSize(width: maxWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        container.frame = CGRect(origin: .zero, size: size)
        return container
    }

    static func makeMapPinImage(isVisited: Bool) -> UIImage? {
        UIImage(systemName: "mappin.circle.fill")?
            .withTintColor(
                ExploreCatalogMapPinAppearance.pinTintColor(isVisited: isVisited),
                renderingMode: .alwaysOriginal
            )
    }
}
#endif
