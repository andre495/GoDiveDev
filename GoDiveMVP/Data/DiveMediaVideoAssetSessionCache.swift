import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif

/// Session-scoped LRU cache of shareable PhotoKit **`AVAsset`** values for dive video playback app-wide.
///
/// Each **`AVPlayer`** still gets its own **`AVPlayerItem`**. Cleared when the app backgrounds.
/// Home carousel library ids are pinned for the session (see **`setPinnedCarouselLocalIdentifiers`**).
@MainActor
final class DiveMediaVideoAssetSessionCache {
    static let shared = DiveMediaVideoAssetSessionCache()

    /// Enough for Home carousel picks plus recently viewed dive / field-guide videos.
    nonisolated static let capacity = 24

    #if canImport(AVFoundation)
    private var assets: [String: AVAsset] = [:]
    #endif
    private var accessOrder: [String] = []
    private var pinnedStorageKeys: Set<String> = []
    private var scopedFullQualityKeys: [String: Set<DiveMediaRetentionScope>] = [:]

    private init() {}

    /// Keeps preview **`AVAsset`**s for the active Home carousel picks (not evicted by LRU trim).
    func setPinnedCarouselLocalIdentifiers(_ identifiers: [String]) {
        pinnedStorageKeys = Set(
            identifiers
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map {
                    Self.storageKey(
                        localIdentifier: $0,
                        quality: .homeCarousel
                    )
                }
        )
        for key in pinnedStorageKeys {
            touchAccess(key)
        }
    }

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
        pinnedStorageKeys.removeAll()
        scopedFullQualityKeys.removeAll()
    }

    /// Removes assets that are neither carousel-pinned nor page-scope retained.
    func clearUnpinned() {
        #if canImport(AVFoundation)
        let keysToRemove = accessOrder.filter { key in
            !pinnedStorageKeys.contains(key) && isScopedFullQualityKey(key) == false
        }
        for key in keysToRemove {
            assets.removeValue(forKey: key)
        }
        accessOrder = accessOrder.filter { key in
            pinnedStorageKeys.contains(key) || isScopedFullQualityKey(key)
        }
        #endif
    }

    func retainFullQuality(localIdentifier: String, scope: DiveMediaRetentionScope) {
        let key = Self.storageKey(localIdentifier: localIdentifier, quality: .fullQuality)
        scopedFullQualityKeys[key, default: []].insert(scope)
        touchAccess(key)
    }

    func releaseFullQuality(localIdentifier: String, scope: DiveMediaRetentionScope) {
        let key = Self.storageKey(localIdentifier: localIdentifier, quality: .fullQuality)
        scopedFullQualityKeys[key]?.remove(scope)
        if scopedFullQualityKeys[key]?.isEmpty ?? true {
            scopedFullQualityKeys.removeValue(forKey: key)
            if !pinnedStorageKeys.contains(key) {
                #if canImport(AVFoundation)
                assets.removeValue(forKey: key)
                #endif
                accessOrder.removeAll { $0 == key }
            }
        }
    }

    func releasePreviewQuality(localIdentifier: String) {
        let key = Self.storageKey(localIdentifier: localIdentifier, quality: .homeCarousel)
        guard !pinnedStorageKeys.contains(key) else { return }
        scopedFullQualityKeys.removeValue(forKey: key)
        #if canImport(AVFoundation)
        assets.removeValue(forKey: key)
        #endif
        accessOrder.removeAll { $0 == key }
    }

    private func touchAccess(_ key: String) {
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }

    private func trimToLimit() {
        while accessOrder.count > Self.capacity {
            guard let evictIndex = accessOrder.firstIndex(where: { key in
                !pinnedStorageKeys.contains(key) && !isScopedFullQualityKey(key)
            }) else {
                break
            }
            let evicted = accessOrder.remove(at: evictIndex)
            #if canImport(AVFoundation)
            assets.removeValue(forKey: evicted)
            #endif
        }
    }

    private func isScopedFullQualityKey(_ key: String) -> Bool {
        guard let scopes = scopedFullQualityKeys[key] else { return false }
        return !scopes.isEmpty
    }
}
