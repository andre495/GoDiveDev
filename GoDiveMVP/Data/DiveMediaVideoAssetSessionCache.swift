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

    nonisolated static func storageKey(
        localIdentifier: String,
        quality: DiveMediaVideoRequestQuality = .fullQuality
    ) -> String {
        "\(localIdentifier)|\(quality.sessionCacheKeySuffix)"
    }

    func contains(
        localIdentifier: String,
        quality: DiveMediaVideoRequestQuality = .fullQuality
    ) -> Bool {
        #if canImport(AVFoundation)
        assets[Self.storageKey(localIdentifier: localIdentifier, quality: quality)] != nil
        #else
        false
        #endif
    }

    #if canImport(AVFoundation)
    func videoAsset(
        for localIdentifier: String,
        quality: DiveMediaVideoRequestQuality = .fullQuality
    ) -> AVAsset? {
        let key = Self.storageKey(localIdentifier: localIdentifier, quality: quality)
        if assets[key] != nil {
            touchAccess(key)
        }
        return assets[key]
    }

    func store(
        _ asset: AVAsset,
        localIdentifier: String,
        quality: DiveMediaVideoRequestQuality = .fullQuality
    ) {
        let key = Self.storageKey(localIdentifier: localIdentifier, quality: quality)
        assets[key] = asset
        touchAccess(key)
        trimToLimit()
    }
    #endif

    func clear() {
        #if canImport(AVFoundation)
        assets.removeAll()
        #endif
        accessOrder.removeAll()
    }

    private func touchAccess(_ key: String) {
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
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
