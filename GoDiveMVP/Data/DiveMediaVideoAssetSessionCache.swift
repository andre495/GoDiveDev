import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif

/// Session-scoped LRU cache of shareable PhotoKit **`AVAsset`** values for dive video playback app-wide.
///
/// Each **`AVPlayer`** still gets its own **`AVPlayerItem`**. Cleared when the app backgrounds.
@MainActor
final class DiveMediaVideoAssetSessionCache {
    static let shared = DiveMediaVideoAssetSessionCache()

    /// Enough for Home carousel picks plus recently viewed dive / field-guide videos.
    nonisolated static let capacity = 24

    #if canImport(AVFoundation)
    private var assets: [String: AVAsset] = [:]
    #endif
    private var accessOrder: [String] = []

    private init() {}

    func contains(localIdentifier: String) -> Bool {
        #if canImport(AVFoundation)
        assets[localIdentifier] != nil
        #else
        false
        #endif
    }

    #if canImport(AVFoundation)
    func videoAsset(for localIdentifier: String) -> AVAsset? {
        if assets[localIdentifier] != nil {
            touchAccess(localIdentifier)
        }
        return assets[localIdentifier]
    }

    func store(_ asset: AVAsset, localIdentifier: String) {
        assets[localIdentifier] = asset
        touchAccess(localIdentifier)
        trimToLimit()
    }
    #endif

    func clear() {
        #if canImport(AVFoundation)
        assets.removeAll()
        #endif
        accessOrder.removeAll()
    }

    private func touchAccess(_ localIdentifier: String) {
        accessOrder.removeAll { $0 == localIdentifier }
        accessOrder.append(localIdentifier)
    }

    private func trimToLimit() {
        while accessOrder.count > Self.capacity {
            let evicted = accessOrder.removeFirst()
            #if canImport(AVFoundation)
            assets.removeValue(forKey: evicted)
            #endif
        }
    }
}
