import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif

/// Session-scoped PhotoKit warm cache for the Home highlights carousel (max **`carouselLimit`** entries).
///
/// Stores hero-sized poster frames. Shareable video **`AVAsset`** values live in
/// **`DiveMediaVideoAssetSessionCache`**. Cleared when the app moves to the background.
@MainActor
final class HomeMediaHighlightSessionCache {
    static let shared = HomeMediaHighlightSessionCache()

    #if canImport(UIKit)
    private var images: [String: UIImage] = [:]
    #endif
    private var accessOrder: [String] = []

    private init() {}

    func containsVideoAsset(localIdentifier: String) -> Bool {
        DiveMediaVideoAssetSessionCache.shared.contains(localIdentifier: localIdentifier)
    }

    #if canImport(UIKit)
    func containsImage(localIdentifier: String, edge: CGFloat) -> Bool {
        image(for: localIdentifier, edge: edge) != nil
    }

    /// Hero frame is cached; videos also require a warmed **`AVAsset`**.
    func isMediaReady(for media: DiveMediaPhoto) -> Bool {
        guard let identifier = media.libraryAssetLocalIdentifier else { return false }
        let edge = HomeMediaHighlightWarmup.preloadImageEdge
        guard containsImage(localIdentifier: identifier, edge: edge) else { return false }
        if media.resolvedMediaKind == .video {
            return containsVideoAsset(localIdentifier: identifier)
        }
        return true
    }

    /// Preview or hero poster frame — enough to show a carousel slide before full warm completes.
    func hasDisplayableImage(for media: DiveMediaPhoto) -> Bool {
        guard let identifier = media.libraryAssetLocalIdentifier else { return false }
        return bestCachedImage(localIdentifier: identifier) != nil
    }

    func bestCachedImage(localIdentifier: String) -> UIImage? {
        let heroEdge = HomeMediaHighlightWarmup.preloadImageEdge
        if let hero = image(for: localIdentifier, edge: heroEdge) {
            return hero
        }
        let previewEdge = HomeMediaHighlightWarmupPresentation.previewImageEdge
        return image(for: localIdentifier, edge: previewEdge)
    }
    #endif

    func videoAsset(for localIdentifier: String) -> AVAsset? {
        DiveMediaVideoAssetSessionCache.shared.videoAsset(for: localIdentifier)
    }

    func storeVideoAsset(_ asset: AVAsset, localIdentifier: String) {
        DiveMediaVideoAssetSessionCache.shared.store(asset, localIdentifier: localIdentifier)
    }

    #if canImport(UIKit)
    func image(for localIdentifier: String, edge: CGFloat) -> UIImage? {
        let key = imageKey(localIdentifier: localIdentifier, edge: edge)
        if images[key] != nil {
            touchAccess(localIdentifier)
        }
        return images[key]
    }

    func storeImage(_ image: UIImage, localIdentifier: String, edge: CGFloat) {
        let key = imageKey(localIdentifier: localIdentifier, edge: edge)
        images[key] = image
        touchAccess(localIdentifier)
        trimToLimit()
    }
    #endif

    func clear() {
        #if canImport(UIKit)
        images.removeAll()
        #endif
        accessOrder.removeAll()
        DiveMediaReferenceLoader.stopCachingImages()
    }

    private func imageKey(localIdentifier: String, edge: CGFloat) -> String {
        "\(localIdentifier)|\(Int(edge))"
    }

    private func touchAccess(_ localIdentifier: String) {
        accessOrder.removeAll { $0 == localIdentifier }
        accessOrder.append(localIdentifier)
    }

    private func trimToLimit() {
        while accessOrder.count > HomeMediaHighlightPresentation.carouselLimit {
            let evicted = accessOrder.removeFirst()
            #if canImport(UIKit)
            images = images.filter { !$0.key.hasPrefix("\(evicted)|") }
            #endif
        }
    }
}
