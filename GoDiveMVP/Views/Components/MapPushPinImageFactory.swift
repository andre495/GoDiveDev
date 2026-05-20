import SwiftUI
import UIKit

/// Renders map push pins for **`MKAnnotationView`**: tip at the **vertical center** of the asset so
/// **`centerOffset`** can stay **`.zero`** (stable while zooming).
enum MapPushPinImageFactory {
    static func makeMapAnnotationPinImage(headColor: Color, scale: CGFloat) -> UIImage {
        let pinW = MapPushPinMetrics.renderedWidth
        let pinH = MapPushPinMetrics.renderedHeight
        let canvasH = MapPushPinMetrics.mapAnnotationImageHeight
        let displayScale = max(scale, 1)

        let pinBitmap = renderPinBitmap(headColor: headColor, scale: displayScale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = displayScale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: pinW, height: canvasH),
            format: format
        )

        return renderer.image { _ in
            pinBitmap.draw(in: CGRect(x: 0, y: 0, width: pinW, height: pinH))
        }
    }

    private static func renderPinBitmap(headColor: Color, scale: CGFloat) -> UIImage {
        let content = MapPushPinView(headColor: headColor)
            .frame(
                width: MapPushPinMetrics.renderedWidth,
                height: MapPushPinMetrics.renderedHeight,
                alignment: .bottom
            )
            .clipped()

        let renderer = ImageRenderer(content: content)
        renderer.scale = scale

        if let rendered = renderer.uiImage, rendered.size.width > 0, rendered.size.height > 0 {
            return rendered
        }

        return UIImage(systemName: "mappin.circle.fill")?
            .withTintColor(UIColor(headColor), renderingMode: .alwaysOriginal) ?? UIImage()
    }
}

/// MapKit places the annotation view **center** on the coordinate.
enum MapAnnotationPinAnchor {
    /// Explore-style pin-only asset: tip is already at the image center — no offset.
    static let pinOnlyCenterOffset = CGPoint.zero

    /// Dive map: coordinate label sits below the pin tip.
    static func centerOffsetForLabelBelowPin(totalViewHeight: CGFloat) -> CGPoint {
        guard totalViewHeight > 0 else { return .zero }
        return CGPoint(
            x: 0,
            y: MapPushPinMetrics.tipYInAnnotationView - totalViewHeight * 0.5
        )
    }
}
