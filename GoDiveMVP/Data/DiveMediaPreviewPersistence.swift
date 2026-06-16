import CoreGraphics
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Low-res JPEG previews persisted on **`DiveMediaPhoto`** for instant UI while PhotoKit resolves heroes.
enum DiveMediaPreviewPersistence: Sendable {

    /// Stored preview longest edge (logbook thumb / carousel / dive hero placeholder).
    nonisolated static let storedPreviewEdge: CGFloat = 256

    nonisolated static let jpegCompressionQuality: CGFloat = 0.72

    /// Reject runaway blobs if PhotoKit returns an unexpectedly large frame.
    nonisolated static let maxStoredPreviewBytes = 512_000

    nonisolated static func shouldPersistPreview(existingData: Data?) -> Bool {
        guard let existingData, !existingData.isEmpty else { return true }
        return false
    }

    /// **`true`** when the UI should show the offline / missing media affordance (not while loading).
    nonisolated static func showsMissingMediaPlaceholder(
        hasDisplayedImage: Bool,
        loadFinished: Bool
    ) -> Bool {
        !hasDisplayedImage && loadFinished
    }

    #if canImport(UIKit)
    nonisolated static func decodePreviewJPEG(_ data: Data?) -> UIImage? {
        guard let data, !data.isEmpty else { return nil }
        return UIImage(data: data)
    }

    nonisolated static func encodePreviewJPEG(_ image: UIImage) -> Data? {
        let scaled = scaledImage(image, maxPixelEdge: storedPreviewEdge)
        guard let data = scaled.jpegData(compressionQuality: jpegCompressionQuality) else { return nil }
        guard data.count <= maxStoredPreviewBytes else { return nil }
        return data
    }

    nonisolated static func scaledImage(_ image: UIImage, maxPixelEdge: CGFloat) -> UIImage {
        guard maxPixelEdge > 0 else { return image }
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let longest = max(pixelWidth, pixelHeight)
        guard longest > maxPixelEdge, longest > 0 else { return image }

        let scale = maxPixelEdge / longest
        let targetSize = CGSize(width: pixelWidth * scale, height: pixelHeight * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    #endif
}
