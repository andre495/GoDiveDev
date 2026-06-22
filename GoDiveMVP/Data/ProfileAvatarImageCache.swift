import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum ProfileAvatarImageCachePresentation: Sendable {

    /// Stable cache key without hashing the full JPEG payload.
    nonisolated static func cacheKey(for data: Data) -> String {
        guard !data.isEmpty else { return "empty" }
        let prefix = data.prefix(32).map { String(format: "%02x", $0) }.joined()
        let suffix = data.suffix(32).map { String(format: "%02x", $0) }.joined()
        return "\(data.count)|\(prefix)|\(suffix)"
    }
}

#if canImport(UIKit)
/// Decodes profile avatar JPEG/PNG off the main thread and reuses **`UIImage`** instances.
@MainActor
final class ProfileAvatarImageCache {
    static let shared = ProfileAvatarImageCache()

    private var imagesByKey: [String: UIImage] = [:]

    private init() {}

    func image(for data: Data?) async -> UIImage? {
        guard let data, !data.isEmpty else { return nil }
        let key = ProfileAvatarImageCachePresentation.cacheKey(for: data)
        if let cached = imagesByKey[key] {
            return cached
        }
        let decoded = await Task.detached(priority: .userInitiated) {
            UIImage(data: data)
        }.value
        if let decoded {
            imagesByKey[key] = decoded
        }
        return decoded
    }
}
#endif
