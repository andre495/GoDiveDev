import CoreGraphics
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Renders a circular profile photo from a source image and crop gestures (testable off the main actor).
enum ProfilePhotoCropRenderer: Sendable {
    static let defaultOutputPixelSize: CGFloat = 400
    static let minimumGestureScale: CGFloat = 1

    /// Base scale so the image fully covers a square crop viewport (aspect fill).
    static func baseFillScale(imageSize: CGSize, cropDiameter: CGFloat) -> CGFloat {
        guard imageSize.width > 0, imageSize.height > 0, cropDiameter > 0 else { return 1 }
        return max(cropDiameter / imageSize.width, cropDiameter / imageSize.height)
    }

    #if canImport(UIKit)
    /// Circular crop in **`outputPixelSize`** × **`outputPixelSize`** pixels (JPEG).
    static func croppedJPEGData(
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

    static func croppedImage(
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
