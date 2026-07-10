import CoreGraphics
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Renders a circular profile photo from a source image and crop gestures (testable off the main actor).
enum ProfilePhotoCropRenderer: Sendable {
    nonisolated static let defaultOutputPixelSize: CGFloat = 400
    nonisolated static let minimumGestureScale: CGFloat = 1

    /// Base scale so the image fully covers a square crop viewport (aspect fill).
    static func baseFillScale(imageSize: CGSize, cropDiameter: CGFloat) -> CGFloat {
        guard imageSize.width > 0, imageSize.height > 0, cropDiameter > 0 else { return 1 }
        return max(cropDiameter / imageSize.width, cropDiameter / imageSize.height)
    }

    static func scaledDrawSize(
        imageSize: CGSize,
        cropDiameter: CGFloat,
        gestureScale: CGFloat
    ) -> CGSize {
        let total = baseFillScale(imageSize: imageSize, cropDiameter: cropDiameter)
            * max(gestureScale, minimumGestureScale)
        return CGSize(width: imageSize.width * total, height: imageSize.height * total)
    }

    /// Keeps the fixed crop circle fully covered by the panned/zoomed image.
    static func clampedOffset(
        _ proposed: CGSize,
        drawSize: CGSize,
        cropDiameter: CGFloat
    ) -> CGSize {
        let radius = cropDiameter / 2
        let minX = radius - drawSize.width / 2
        let maxX = drawSize.width / 2 - radius
        let minY = radius - drawSize.height / 2
        let maxY = drawSize.height / 2 - radius

        func clamp(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
            guard minValue <= maxValue else { return 0 }
            return min(max(value, minValue), maxValue)
        }

        return CGSize(
            width: clamp(proposed.width, min: minX, max: maxX),
            height: clamp(proposed.height, min: minY, max: maxY)
        )
    }

    #if canImport(UIKit)
    /// Circular crop in **`outputPixelSize`** × **`outputPixelSize`** pixels (JPEG).
    nonisolated static func croppedJPEGData(
        from image: UIImage,
        cropDiameter: CGFloat,
        gestureScale: CGFloat,
        offset: CGSize,
        outputPixelSize: CGFloat = defaultOutputPixelSize,
        compressionQuality: CGFloat = 0.85
    ) -> Data? {
        let clampedScale = max(gestureScale, minimumGestureScale)
        let cropped = croppedImage(
            from: image,
            cropDiameter: cropDiameter,
            gestureScale: clampedScale,
            offset: offset,
            outputPixelSize: outputPixelSize
        )
        return cropped?.jpegData(compressionQuality: compressionQuality)
    }

    nonisolated static func croppedImage(
        from image: UIImage,
        cropDiameter: CGFloat,
        gestureScale: CGFloat,
        offset: CGSize,
        outputPixelSize: CGFloat = defaultOutputPixelSize
    ) -> UIImage? {
        let cropSize = CGSize(width: outputPixelSize, height: outputPixelSize)
        let scaleFactor = outputPixelSize / max(cropDiameter, 1)
        let scaledOffset = CGSize(width: offset.width * scaleFactor, height: offset.height * scaleFactor)

        let renderer = UIGraphicsImageRenderer(size: cropSize)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: cropSize)
            context.cgContext.addEllipse(in: rect)
            context.cgContext.clip()

            let imageSize = image.size
            let baseScale = baseFillScale(imageSize: imageSize, cropDiameter: cropDiameter)
            let totalScale = baseScale * gestureScale * scaleFactor
            let drawWidth = imageSize.width * totalScale
            let drawHeight = imageSize.height * totalScale
            let origin = CGPoint(
                x: (cropSize.width - drawWidth) / 2 + scaledOffset.width,
                y: (cropSize.height - drawHeight) / 2 + scaledOffset.height
            )
            image.draw(in: CGRect(origin: origin, size: CGSize(width: drawWidth, height: drawHeight)))
        }
    }
    #endif
}
