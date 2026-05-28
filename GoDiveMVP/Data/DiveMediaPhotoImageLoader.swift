import Foundation
#if canImport(UIKit)
import UIKit
import ImageIO

/// Off-main-thread ImageIO thumbnail decode for dive photo **`mediaData`** (no cache; Swift 6 safe).
enum DiveMediaPhotoImageLoader {

    static func thumbnail(from data: Data, maxPixelSize: CGFloat) async -> UIImage? {
        guard !data.isEmpty, maxPixelSize > 0 else { return nil }
        let cgImage = await Task.detached(priority: .userInitiated) {
            Self.decodeCGImage(from: data, maxPixelSize: maxPixelSize)
        }.value
        guard let cgImage else { return nil }
        return await MainActor.run { UIImage(cgImage: cgImage) }
    }

    /// ImageIO decode only — safe to run off the main actor (`CGImage` is not UIKit-isolated).
    private nonisolated static func decodeCGImage(from data: Data, maxPixelSize: CGFloat) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(maxPixelSize)),
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        if let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
            return thumbnail
        }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
#endif
