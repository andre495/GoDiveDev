#if canImport(UIKit)
import UIKit

/// Shared callout chrome for Explore catalog map pins (MapKit accessory + Google info window).
enum ExploreCatalogMapSiteCallout {
    /// Tappable MapKit callout row — site name + chevron; wire via **`calloutAccessoryControlTapped`**.
    static func makeMapKitCalloutAccessory(siteName: String, maxWidth: CGFloat = 240) -> UIControl {
        let control = ExploreCatalogMapCalloutControl()
        control.accessibilityLabel = siteName
        control.accessibilityHint = "Opens dive site details"
        control.isAccessibilityElement = true

        let label = UILabel()
        label.text = siteName
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .label
        label.numberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        label.isUserInteractionEnabled = false
        label.translatesAutoresizingMaskIntoConstraints = false

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .secondaryLabel
        chevron.isUserInteractionEnabled = false
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        chevron.setContentCompressionResistancePriority(.required, for: .horizontal)
        chevron.translatesAutoresizingMaskIntoConstraints = false

        control.addSubview(label)
        control.addSubview(chevron)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: control.leadingAnchor, constant: 12),
            label.topAnchor.constraint(equalTo: control.topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: control.bottomAnchor, constant: -10),
            label.trailingAnchor.constraint(lessThanOrEqualTo: chevron.leadingAnchor, constant: -8),
            chevron.trailingAnchor.constraint(equalTo: control.trailingAnchor, constant: -10),
            chevron.centerYAnchor.constraint(equalTo: control.centerYAnchor),
            control.widthAnchor.constraint(equalToConstant: maxWidth),
        ])

        let size = control.systemLayoutSizeFitting(
            CGSize(width: maxWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        control.frame = CGRect(origin: .zero, size: size)
        return control
    }

    static func makeGoogleInfoWindow(
        siteName: String,
        maxWidth: CGFloat = 240,
        onTap: (() -> Void)? = nil
    ) -> UIView {
        let control = makeMapKitCalloutAccessory(siteName: siteName, maxWidth: maxWidth)
        control.backgroundColor = .systemBackground
        control.layer.cornerRadius = 10
        control.layer.cornerCurve = .continuous
        control.layer.shadowColor = UIColor.black.cgColor
        control.layer.shadowOpacity = 0.18
        control.layer.shadowRadius = 6
        control.layer.shadowOffset = CGSize(width: 0, height: 2)

        if let onTap {
            installTapHandler(on: control, handler: onTap)
        }

        return control
    }

    static func makeChevronAccessory() -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "chevron.right")
        configuration.baseForegroundColor = .secondaryLabel
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        let button = UIButton(configuration: configuration)
        button.accessibilityLabel = "View dive site details"
        return button
    }

    static func makeMapPinImage(isVisited: Bool) -> UIImage? {
        UIImage(systemName: "mappin.circle.fill")?
            .withTintColor(
                ExploreCatalogMapPinAppearance.pinTintColor(isVisited: isVisited),
                renderingMode: .alwaysOriginal
            )
    }

    static func makeTripMapPinImage(kind: TripDetailMapPinKind) -> UIImage? {
        UIImage(systemName: "mappin.circle.fill")?
            .withTintColor(
                kind == .planned ? .systemBlue : .systemRed,
                renderingMode: .alwaysOriginal
            )
    }

    private static func installTapHandler(on view: UIView, handler: @escaping () -> Void) {
        let target = UIViewTapTarget(handler: handler)
        objc_setAssociatedObject(
            view,
            &UIViewTapTarget.associatedObjectKey,
            target,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        let recognizer = UITapGestureRecognizer(target: target, action: #selector(UIViewTapTarget.invoke))
        view.addGestureRecognizer(recognizer)
        view.isUserInteractionEnabled = true
    }
}

/// Empty **`UIControl`** subclass so MapKit routes taps through **`calloutAccessoryControlTapped`**.
final class ExploreCatalogMapCalloutControl: UIControl {}

private final class UIViewTapTarget: NSObject {
    nonisolated(unsafe) static var associatedObjectKey: UInt8 = 0

    private let handler: () -> Void

    init(handler: @escaping () -> Void) {
        self.handler = handler
    }

    @objc func invoke() {
        handler()
    }
}
#endif
