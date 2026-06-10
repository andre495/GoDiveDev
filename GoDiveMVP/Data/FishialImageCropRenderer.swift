import CoreGraphics
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Renders a rectangular still crop from pinch/drag gestures (testable off the main actor).
enum FishialImageCropRenderer: Sendable {
    static let minimumGestureScale: CGFloat = 1

    /// Base scale so the image fully covers the crop viewport (aspect fill).
    static func baseFillScale(imageSize: CGSize, cropSize: CGSize) -> CGFloat {
        guard imageSize.width > 0, imageSize.height > 0,
              cropSize.width > 0, cropSize.height > 0 else { return 1 }
        return max(cropSize.width / imageSize.width, cropSize.height / imageSize.height)
    }

    static func scaledDrawSize(
        imageSize: CGSize,
        cropSize: CGSize,
        gestureScale: CGFloat
    ) -> CGSize {
        let total = baseFillScale(imageSize: imageSize, cropSize: cropSize)
            * max(gestureScale, minimumGestureScale)
        return CGSize(width: imageSize.width * total, height: imageSize.height * total)
    }

    /// Keeps the fixed crop viewport fully covered by the panned/zoomed image.
    static func clampedOffset(
        _ proposed: CGSize,
        drawSize: CGSize,
        cropSize: CGSize
    ) -> CGSize {
        let halfCropWidth = cropSize.width / 2
        let halfCropHeight = cropSize.height / 2
        let minX = halfCropWidth - drawSize.width / 2
        let maxX = drawSize.width / 2 - halfCropWidth
        let minY = halfCropHeight - drawSize.height / 2
        let maxY = drawSize.height / 2 - halfCropHeight

        func clamp(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
            guard minValue <= maxValue else { return 0 }
            return min(max(value, minValue), maxValue)
        }

        return CGSize(
            width: clamp(proposed.width, min: minX, max: maxX),
            height: clamp(proposed.height, min: minY, max: maxY)
        )
    }

    static func outputPixelSize(
        cropSize: CGSize,
        displayScale: CGFloat,
        maxEdge: CGFloat
    ) -> CGSize {
        let pixelWidth = cropSize.width * displayScale
        let pixelHeight = cropSize.height * displayScale
        let maxPixelEdge = max(pixelWidth, pixelHeight, 1)
        let downscale = min(maxEdge / maxPixelEdge, 1)
        return CGSize(width: pixelWidth * downscale, height: pixelHeight * downscale)
    }

    #if canImport(UIKit)
    static func croppedJPEGData(
        from image: UIImage,
        cropSize: CGSize,
        gestureScale: CGFloat,
        offset: CGSize,
        displayScale: CGFloat,
        maxEdge: CGFloat = DiveMediaFishialFrameExport.maxJPEGEdge,
        compressionQuality: CGFloat = DiveMediaFishialFrameExport.jpegCompressionQuality
    ) -> Data? {
        let clampedScale = max(gestureScale, minimumGestureScale)
        let cropped = croppedImage(
            from: image,
            cropSize: cropSize,
            gestureScale: clampedScale,
            offset: offset,
            displayScale: displayScale,
            maxEdge: maxEdge
        )
        return cropped?.jpegData(compressionQuality: compressionQuality)
    }

    static func croppedImage(
        from image: UIImage,
        cropSize: CGSize,
        gestureScale: CGFloat,
        offset: CGSize,
        displayScale: CGFloat,
        maxEdge: CGFloat = DiveMediaFishialFrameExport.maxJPEGEdge
    ) -> UIImage? {
        let outputSize = outputPixelSize(
            cropSize: cropSize,
            displayScale: displayScale,
            maxEdge: maxEdge
        )
        let scaleFactor = outputSize.width / max(cropSize.width, 1)
        let scaledOffset = CGSize(
            width: offset.width * scaleFactor,
            height: offset.height * scaleFactor
        )

        let renderer = UIGraphicsImageRenderer(size: outputSize)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: outputSize)
            context.cgContext.addRect(rect)
            context.cgContext.clip()

            let imageSize = image.size
            let baseScale = baseFillScale(imageSize: imageSize, cropSize: cropSize)
            let totalScale = baseScale * gestureScale * scaleFactor
            let drawWidth = imageSize.width * totalScale
            let drawHeight = imageSize.height * totalScale
            let origin = CGPoint(
                x: (outputSize.width - drawWidth) / 2 + scaledOffset.width,
                y: (outputSize.height - drawHeight) / 2 + scaledOffset.height
            )
            image.draw(in: CGRect(origin: origin, size: CGSize(width: drawWidth, height: drawHeight)))
        }
    }
    #endif
}
