import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif

/// Session-scoped PhotoKit warm cache for the Home highlights carousel (max **`carouselLimit`** entries).
///
/// Stores shareable **`AVAsset`** values (each **`AVPlayer`** gets its own **`AVPlayerItem`**) plus hero-sized
/// poster frames. Cleared when the app moves to the background so the next launch re-warms from Photos.
@MainActor
final class HomeMediaHighlightSessionCache {
    static let shared = HomeMediaHighlightSessionCache()

    private var videoAssets: [String: AVAsset] = [:]
    #if canImport(UIKit)
    private var images: [String: UIImage] = [:]
    #endif
    private var accessOrder: [String] = []

    private init() {}

    func containsVideoAsset(localIdentifier: String) -> Bool {
        videoAssets[localIdentifier] != nil
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
        touchAccess(localIdentifier)
        return videoAssets[localIdentifier]
    }

    func storeVideoAsset(_ asset: AVAsset, localIdentifier: String) {
        videoAssets[localIdentifier] = asset
        touchAccess(localIdentifier)
        trimToLimit()
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
        videoAssets.removeAll()
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
            videoAssets.removeValue(forKey: evicted)
            #if canImport(UIKit)
            images = images.filter { !$0.key.hasPrefix("\(evicted)|") }
            #endif
        }
    }
}
