import Foundation
#if canImport(Photos)
import Photos
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif

/// On-demand PhotoKit access for dive media: thumbnails, full images, and video player items are loaded straight
/// from the user's Photos library by **`PHAsset.localIdentifier`** (**`DiveMediaPhoto.libraryAssetLocalIdentifier`**),
/// so the app stores only a pointer instead of duplicating bytes on disk.
///
/// All loads allow iCloud network access; a missing/offline/deleted asset resolves to **`nil`** so callers
/// fall back to a placeholder.
enum DiveMediaReferenceLoader {

    #if canImport(Photos)
    /// Fetches the **`PHAsset`** for a local identifier, or **`nil`** if it no longer exists / access is denied.
    nonisolated static func asset(localIdentifier: String) -> PHAsset? {
        let trimmed = localIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [trimmed], options: nil)
        return result.firstObject
    }

    /// Capture date for ordering reference rows without copying any bytes.
    nonisolated static func creationDate(localIdentifier: String) async -> Date? {
        asset(localIdentifier: localIdentifier)?.creationDate
    }

    /// **`true`** when the Photos asset still exists / is reachable. Used to distinguish a **deleted** original
    /// (prune the reference) from a transient/offline load failure (keep it). Note: under **limited** access this
    /// returns **`false`** for assets outside the user's selection, so pruning is gated on **full** authorization.
    nonisolated static func assetExists(localIdentifier: String) -> Bool {
        asset(localIdentifier: localIdentifier) != nil
    }
    #endif

    #if canImport(Photos) && canImport(UIKit)
    /// Loads a (thumbnail or full-size) image for the asset. Works for both photo and video assets
    /// (videos return a poster frame). Returns **`nil`** when the original is unavailable.
    ///
    /// **`.highQualityFormat`** delivers the handler exactly once, so the continuation resumes a single time.
    @MainActor
    static func image(
        localIdentifier: String,
        targetSize: CGSize,
        contentMode: PHImageContentMode = .aspectFill
    ) async -> UIImage? {
        guard targetSize.width > 0, targetSize.height > 0,
              let asset = asset(localIdentifier: localIdentifier) else { return nil }

        let edge = max(targetSize.width, targetSize.height)
        if let sessionImage = HomeMediaHighlightSessionCache.shared.image(
            for: localIdentifier,
            edge: edge
        ) {
            return sessionImage
        }

        let cacheKey = DiveMediaReferenceImageCache.shared.key(
            localIdentifier: localIdentifier,
            targetSize: targetSize
        )
        if let cached = DiveMediaReferenceImageCache.shared.image(for: cacheKey) {
            return cached
        }

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isSynchronous = false

        let image = await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: contentMode,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
        if let image {
            DiveMediaReferenceImageCache.shared.store(image, for: cacheKey)
            if HomeMediaHighlightWarmup.shouldStoreInSessionCache(edge: edge) {
                HomeMediaHighlightSessionCache.shared.storeImage(
                    image,
                    localIdentifier: localIdentifier,
                    edge: edge
                )
            }
        }
        return image
    }

    /// Tells PhotoKit to download/cache hero frames for Home carousel assets before individual requests.
    @MainActor
    static func startCachingImages(localIdentifiers: [String], targetSize: CGSize) {
        stopCachingImages()
        guard targetSize.width > 0, targetSize.height > 0 else { return }
        let assets = localIdentifiers.compactMap { asset(localIdentifier: $0) }
        guard !assets.isEmpty else { return }

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast

        HomePhotoKitPreheatManager.shared.startCaching(
            assets: assets,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        )
    }

    @MainActor
    static func stopCachingImages() {
        HomePhotoKitPreheatManager.shared.stopCaching()
    }
    #endif

    #if canImport(Photos) && canImport(AVFoundation)
    /// Request options for full-resolution playback. **`.highQualityFormat`** asks PhotoKit for the highest-quality
    /// asset available (downloading the iCloud original when needed) instead of **`.automatic`**, which can hand back
    /// a lower-resolution / transcoded stream to start playback faster.
    nonisolated static func makeVideoRequestOptions() -> PHVideoRequestOptions {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        return options
    }

    /// Builds a fresh **`AVPlayerItem`** — never reuses a cached item (one item per **`AVPlayer`**).
    ///
    /// When **`HomeMediaHighlightSessionCache`** holds a warmed **`AVAsset`**, a new item is created from that asset
    /// for instant carousel playback. Otherwise falls back to **`requestPlayerItem`** (not cached).
    @MainActor
    static func playerItem(
        localIdentifier: String,
        timeoutSeconds: Double = DiveMediaVideoLoad.timeoutSeconds
    ) async -> AVPlayerItem? {
        if let avAsset = HomeMediaHighlightSessionCache.shared.videoAsset(for: localIdentifier) {
            return AVPlayerItem(asset: avAsset)
        }

        guard let asset = asset(localIdentifier: localIdentifier) else { return nil }

        let options = makeVideoRequestOptions()
        let resumeGuard = SingleResumeGuard()

        return await withCheckedContinuation { (continuation: CheckedContinuation<AVPlayerItem?, Never>) in
            PHImageManager.default().requestPlayerItem(
                forVideo: asset,
                options: options
            ) { item, _ in
                if resumeGuard.claim() {
                    continuation.resume(returning: item)
                }
            }

            if timeoutSeconds > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + timeoutSeconds) {
                    if resumeGuard.claim() {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }

    /// Loads an **`AVAsset`** from PhotoKit for session warm-cache (shareable across many **`AVPlayerItem`**s).
    @MainActor
    static func loadVideoAsset(
        localIdentifier: String,
        timeoutSeconds: Double = DiveMediaVideoLoad.timeoutSeconds
    ) async -> AVAsset? {
        guard let asset = asset(localIdentifier: localIdentifier) else { return nil }

        let options = makeVideoRequestOptions()
        let resumeGuard = SingleResumeGuard()

        return await withCheckedContinuation { (continuation: CheckedContinuation<AVAsset?, Never>) in
            PHImageManager.default().requestAVAsset(
                forVideo: asset,
                options: options
            ) { avAsset, _, _ in
                if resumeGuard.claim() {
                    continuation.resume(returning: avAsset)
                }
            }

            if timeoutSeconds > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + timeoutSeconds) {
                    if resumeGuard.claim() {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }
    #endif

    /// Drops Home carousel warm caches and in-memory PhotoKit image frames (call when app backgrounds).
    @MainActor
    static func clearSessionMediaCaches() {
        HomeMediaHighlightSessionCache.shared.clear()
        #if canImport(UIKit)
        DiveMediaReferenceImageCache.shared.removeAll()
        #endif
    }
}

#if canImport(UIKit)
@MainActor
private final class DiveMediaReferenceImageCache {
    static let shared = DiveMediaReferenceImageCache()
    private let storage = NSCache<NSString, UIImage>()

    func key(localIdentifier: String, targetSize: CGSize) -> NSString {
        "\(localIdentifier)|\(Int(targetSize.width))x\(Int(targetSize.height))" as NSString
    }

    func image(for key: NSString) -> UIImage? {
        storage.object(forKey: key)
    }

    func store(_ image: UIImage, for key: NSString) {
        storage.setObject(image, forKey: key)
    }

    func removeAll() {
        storage.removeAllObjects()
    }
}
#endif

#if canImport(Photos) && canImport(UIKit)
@MainActor
private final class HomePhotoKitPreheatManager {
    static let shared = HomePhotoKitPreheatManager()
    private let cachingManager = PHCachingImageManager()
    private var cachedAssets: [PHAsset] = []
    private var cachedTargetSize: CGSize = .zero
    private var cachedOptions: PHImageRequestOptions?

    func startCaching(
        assets: [PHAsset],
        targetSize: CGSize,
        contentMode: PHImageContentMode,
        options: PHImageRequestOptions
    ) {
        stopCaching()
        cachedAssets = assets
        cachedTargetSize = targetSize
        cachedOptions = options
        cachingManager.startCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: contentMode,
            options: options
        )
    }

    func stopCaching() {
        guard !cachedAssets.isEmpty,
              let options = cachedOptions,
              cachedTargetSize.width > 0,
              cachedTargetSize.height > 0 else {
            cachedAssets = []
            cachedTargetSize = .zero
            cachedOptions = nil
            return
        }
        cachingManager.stopCachingImages(
            for: cachedAssets,
            targetSize: cachedTargetSize,
            contentMode: .aspectFill,
            options: options
        )
        cachedAssets = []
        cachedTargetSize = .zero
        cachedOptions = nil
    }
}
#endif

#if canImport(Photos) && canImport(AVFoundation)
/// Thread-safe single-use latch so the player-item load and its timeout race to resume a continuation exactly once.
private final class SingleResumeGuard: @unchecked Sendable {
    private let lock = NSLock()
    private var claimed = false

    /// Returns **`true`** for the first caller only; subsequent callers (the loser of the load/timeout race) get **`false`**.
    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if claimed { return false }
        claimed = true
        return true
    }
}
#endif
