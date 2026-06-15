#if canImport(GoogleMaps)
import GoogleMaps
import UIKit

/// Renders Explore dive-site pins with an optional name label for **`GMSMarker`**.
enum ExploreCatalogGoogleMapMarkerImageFactory {
    struct PinAsset: Sendable {
        let image: UIImage
        /// **`GMSMarker.groundAnchor`** — pin tip sits on the coordinate.
        let groundAnchor: CGPoint
    }

    static func makePinOnlyAsset(tint: UIColor = .systemRed) -> PinAsset {
        let image = GMSMarker.markerImage(with: tint)
        return PinAsset(image: image, groundAnchor: CGPoint(x: 0.5, y: 1.0))
    }

    static func makeLabeledPinAsset(siteName: String, tint: UIColor = .systemRed, scale: CGFloat) -> PinAsset {
        makeLabeledPinAsset(
            labelText: ExploreCatalogMapMarkerPresentation.displayTitle(for: siteName),
            tint: tint,
            scale: scale,
            maxLabelWidth: ExploreCatalogMapMarkerPresentation.labelMaxWidth
        )
    }

    static func makeLabeledPinAsset(labelText: String, tint: UIColor, scale: CGFloat, maxLabelWidth: CGFloat) -> PinAsset {
        let title = labelText
        let pinImage = GMSMarker.markerImage(with: tint)
        let pinSize = pinImage.size

        let labelFont = UIFont.systemFont(
            ofSize: ExploreCatalogMapMarkerPresentation.labelFontSize,
            weight: .semibold
        )
        let labelBounds = (title as NSString).boundingRect(
            with: CGSize(
                width: maxLabelWidth
                    - ExploreCatalogMapMarkerPresentation.labelHorizontalPadding * 2,
                height: .greatestFiniteMagnitude
            ),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: labelFont],
            context: nil
        ).integral

        let labelWidth = min(
            maxLabelWidth,
            labelBounds.width + ExploreCatalogMapMarkerPresentation.labelHorizontalPadding * 2
        )
        let labelHeight = labelBounds.height + ExploreCatalogMapMarkerPresentation.labelVerticalPadding * 2

        let canvasWidth = max(pinSize.width, labelWidth)
        let canvasHeight = pinSize.height
            + ExploreCatalogMapMarkerPresentation.pinToLabelSpacing
            + labelHeight

        let format = UIGraphicsImageRendererFormat()
        format.scale = max(scale, 1)
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: canvasWidth, height: canvasHeight),
            format: format
        )

        let image = renderer.image { _ in
            let pinOrigin = CGPoint(x: (canvasWidth - pinSize.width) * 0.5, y: 0)
            pinImage.draw(in: CGRect(origin: pinOrigin, size: pinSize))

            let labelOrigin = CGPoint(
                x: (canvasWidth - labelWidth) * 0.5,
                y: pinSize.height + ExploreCatalogMapMarkerPresentation.pinToLabelSpacing
            )
            let labelRect = CGRect(x: labelOrigin.x, y: labelOrigin.y, width: labelWidth, height: labelHeight)

            let pillPath = UIBezierPath(roundedRect: labelRect, cornerRadius: 4)
            UIColor.systemBackground.withAlphaComponent(0.92).setFill()
            pillPath.fill()
            UIColor.label.withAlphaComponent(0.18).setStroke()
            pillPath.lineWidth = 0.5
            pillPath.stroke()

            let textRect = labelRect.insetBy(
                dx: ExploreCatalogMapMarkerPresentation.labelHorizontalPadding,
                dy: ExploreCatalogMapMarkerPresentation.labelVerticalPadding
            )
            (title as NSString).draw(
                with: textRect,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [
                    .font: labelFont,
                    .foregroundColor: UIColor.label,
                ],
                context: nil
            )
        }

        let pinTipY = pinSize.height
        let groundAnchor = CGPoint(x: 0.5, y: pinTipY / canvasHeight)
        return PinAsset(image: image, groundAnchor: groundAnchor)
    }
}
#endif
