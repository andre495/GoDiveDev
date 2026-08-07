import Foundation
#if canImport(ImageIO)
import ImageIO
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Presentation helpers for off-main image decode caches (blob JPEG/PNG and bundled catalog files).
enum GoDiveDecodedImageCachePresentation: Sendable {
    /// Stable cache key without hashing the full payload.
    nonisolated static func cacheKey(for data: Data) -> String {
        guard !data.isEmpty else { return "empty" }
        let prefix = data.prefix(32).map { String(format: "%02x", $0) }.joined()
        let suffix = data.suffix(32).map { String(format: "%02x", $0) }.joined()
        return "\(data.count)|\(prefix)|\(suffix)"
    }

    nonisolated static func cacheKey(fileURL: URL, maxPixelEdge: CGFloat) -> String {
        "file|\(fileURL.path)|\(Int(maxPixelEdge.rounded()))"
    }

    nonisolated static func cacheKey(data: Data, maxPixelEdge: CGFloat) -> String {
        "blob|\(cacheKey(for: data))|\(Int(maxPixelEdge.rounded()))"
    }
}

#if canImport(UIKit)
/// Decodes JPEG/PNG off the main thread with optional ImageIO downsampling; reuses **`UIImage`** instances.
@MainActor
final class GoDiveDecodedImageCache {
    static let shared = GoDiveDecodedImageCache()

    private let imagesByKey = NSCache<NSString, UIImage>()

    private init() {
        imagesByKey.countLimit = 400
        imagesByKey.totalCostLimit = 64 * 1_024 * 1_024
    }

    func image(for data: Data?, maxPixelEdge: CGFloat = 0) async -> UIImage? {
        guard let data, !data.isEmpty else { return nil }
        let key = GoDiveDecodedImageCachePresentation.cacheKey(data: data, maxPixelEdge: maxPixelEdge) as NSString
        if let cached = imagesByKey.object(forKey: key) {
            return cached
        }
        let edge = maxPixelEdge
        let decoded = await Task.detached(priority: .userInitiated) {
            Self.decode(data: data, maxPixelEdge: edge)
        }.value
        if let decoded {
            store(decoded, forKey: key)
        }
        return decoded
    }

    func image(fileURL: URL, maxPixelEdge: CGFloat = 0) async -> UIImage? {
        let key = GoDiveDecodedImageCachePresentation.cacheKey(
            fileURL: fileURL,
            maxPixelEdge: maxPixelEdge
        ) as NSString
        if let cached = imagesByKey.object(forKey: key) {
            return cached
        }
        let edge = maxPixelEdge
        let decoded = await Task.detached(priority: .userInitiated) {
            Self.decode(fileURL: fileURL, maxPixelEdge: edge)
        }.value
        if let decoded {
            store(decoded, forKey: key)
        }
        return decoded
    }

    private func store(_ image: UIImage, forKey key: NSString) {
        let pixelCost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        imagesByKey.setObject(image, forKey: key, cost: max(pixelCost, 1))
    }

    nonisolated private static func decode(data: Data, maxPixelEdge: CGFloat) -> UIImage? {
        #if canImport(ImageIO)
        if maxPixelEdge > 0, let downsampled = downsample(data: data, maxPixelEdge: maxPixelEdge) {
            return downsampled
        }
        #endif
        return UIImage(data: data)
    }

    nonisolated private static func decode(fileURL: URL, maxPixelEdge: CGFloat) -> UIImage? {
        #if canImport(ImageIO)
        if maxPixelEdge > 0, let downsampled = downsample(fileURL: fileURL, maxPixelEdge: maxPixelEdge) {
            return downsampled
        }
        #endif
        if let image = UIImage(contentsOfFile: fileURL.path) {
            return image
        }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    #if canImport(ImageIO)
    nonisolated private static func downsample(data: Data, maxPixelEdge: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return downsample(source: source, maxPixelEdge: maxPixelEdge)
    }

    nonisolated private static func downsample(fileURL: URL, maxPixelEdge: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else { return nil }
        return downsample(source: source, maxPixelEdge: maxPixelEdge)
    }

    nonisolated private static func downsample(source: CGImageSource, maxPixelEdge: CGFloat) -> UIImage? {
        let edge = max(maxPixelEdge.rounded(), 1)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: edge,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
    #endif
}
#endif
