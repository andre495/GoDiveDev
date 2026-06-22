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
/// PhotoKit loads use **`AppNetworkConnectivitySnapshot`** — when offline, only local previews are requested
/// (**`isNetworkAccessAllowed = false`**). A missing/deleted asset still resolves to **`nil`**.
enum DiveMediaReferenceLoader {

    nonisolated private static var photoKitAllowsNetworkAccess: Bool {
        AppNetworkConnectivityPresentation.photoKitAllowsNetworkAccess(
            isConnected: AppNetworkConnectivitySnapshot.shared.allowsCloudMediaFetch
        )
    }

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

    /// **`PHAsset.duration`** for a library video, or **`nil`** when not a video / missing.
    nonisolated static func videoDurationSeconds(localIdentifier: String) -> Double? {
        guard let phAsset = asset(localIdentifier: localIdentifier),
              phAsset.mediaType == .video else { return nil }
        let duration = phAsset.duration
        guard duration.isFinite, duration > 0 else { return nil }
        return duration
    }
    #endif

    #if canImport(Photos) && canImport(UIKit)
    /// Loads a (thumbnail or full-size) image for the asset. Works for both photo and video assets
    /// (videos return a poster frame). Returns **`nil`** when the original is unavailable.
    ///
    /// PhotoKit work runs off the main actor; cache mutation stays on **`@MainActor`**.
    @MainActor
    static func image(
        localIdentifier: String,
        targetSize: CGSize,
        contentMode: PHImageContentMode = .aspectFill,
        deliveryMode: PHImageRequestOptionsDeliveryMode = .highQualityFormat
    ) async -> UIImage? {
        guard targetSize.width > 0, targetSize.height > 0,
              let phAsset = asset(localIdentifier: localIdentifier) else { return nil }

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

        let inflightKey = cacheKey as String
        if let existing = DiveMediaReferenceImageCache.shared.inflightTask(for: inflightKey) {
            return await existing.value
        }

        let task = Task.detached(priority: .userInitiated) {
            await fetchImageFromPhotoKit(
                asset: phAsset,
                targetSize: targetSize,
                contentMode: contentMode,
                deliveryMode: deliveryMode
            )
        }
        DiveMediaReferenceImageCache.shared.storeInflightTask(task, for: inflightKey)
        let image = await task.value
        DiveMediaReferenceImageCache.shared.removeInflightTask(for: inflightKey)
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

    /// Delivers opportunistic frames (degraded, then final) for in-place sharpening in dive heroes.
    @MainActor
    static func loadImageProgressive(
        localIdentifier: String,
        targetSize: CGSize,
        contentMode: PHImageContentMode = .aspectFill,
        deliveryMode: PHImageRequestOptionsDeliveryMode = .opportunistic,
        onFrame: @escaping @MainActor (_ image: UIImage, _ isFinal: Bool) -> Void
    ) async {
        guard targetSize.width > 0, targetSize.height > 0,
              let phAsset = asset(localIdentifier: localIdentifier) else { return }

        let edge = max(targetSize.width, targetSize.height)
        if let sessionImage = HomeMediaHighlightSessionCache.shared.image(
            for: localIdentifier,
            edge: edge
        ) {
            onFrame(sessionImage, true)
            return
        }

        let cacheKey = DiveMediaReferenceImageCache.shared.key(
            localIdentifier: localIdentifier,
            targetSize: targetSize
        )
        if let cached = DiveMediaReferenceImageCache.shared.image(for: cacheKey) {
            onFrame(cached, true)
            return
        }

        await fetchImageProgressiveFromPhotoKit(
            asset: phAsset,
            targetSize: targetSize,
            contentMode: contentMode,
            deliveryMode: deliveryMode,
            onFrame: { image, isFinal in
                guard let image else { return }
                onFrame(image, isFinal)
                if isFinal {
                    DiveMediaReferenceImageCache.shared.store(image, for: cacheKey)
                    if HomeMediaHighlightWarmup.shouldStoreInSessionCache(edge: edge) {
                        HomeMediaHighlightSessionCache.shared.storeImage(
                            image,
                            localIdentifier: localIdentifier,
                            edge: edge
                        )
                    }
                }
            }
        )
    }

    nonisolated private static func fetchImageProgressiveFromPhotoKit(
        asset: PHAsset,
        targetSize: CGSize,
        contentMode: PHImageContentMode,
        deliveryMode: PHImageRequestOptionsDeliveryMode,
        onFrame: @escaping @MainActor (_ image: UIImage?, _ isFinal: Bool) -> Void
    ) async {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = photoKitAllowsNetworkAccess
        options.deliveryMode = deliveryMode
        options.resizeMode = .fast
        options.isSynchronous = false

        await withCheckedContinuation { continuation in
            let resumeGuard = SingleResumeGuard()
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: contentMode,
                options: options
            ) { image, info in
                if (info?[PHImageCancelledKey] as? Bool) == true {
                    if resumeGuard.claim() {
                        continuation.resume()
                    }
                    return
                }

                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) == true
                Task { @MainActor in
                    onFrame(image, !isDegraded)
                }

                if !isDegraded, resumeGuard.claim() {
                    continuation.resume()
                }
            }
        }
    }

    nonisolated private static func fetchImageFromPhotoKit(
        asset: PHAsset,
        targetSize: CGSize,
        contentMode: PHImageContentMode,
        deliveryMode: PHImageRequestOptionsDeliveryMode
    ) async -> UIImage? {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = photoKitAllowsNetworkAccess
        options.deliveryMode = deliveryMode
        options.resizeMode = .fast
        options.isSynchronous = false

        return await withCheckedContinuation { continuation in
            let resumeGuard = SingleResumeGuard()
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: contentMode,
                options: options
            ) { image, info in
                if (info?[PHImageCancelledKey] as? Bool) == true {
                    if resumeGuard.claim() {
                        continuation.resume(returning: nil)
                    }
                    return
                }

                if deliveryMode == .opportunistic,
                   (info?[PHImageResultIsDegradedKey] as? Bool) == true {
                    return
                }

                if resumeGuard.claim() {
                    continuation.resume(returning: image)
                }
            }
        }
    }

    /// Tells PhotoKit to download/cache hero frames for Home carousel assets before individual requests.
    @MainActor
    static func startCachingImages(localIdentifiers: [String], targetSize: CGSize) {
        stopCachingImages()
        guard targetSize.width > 0, targetSize.height > 0 else { return }
        let assets = localIdentifiers.compactMap { asset(localIdentifier: $0) }
        guard !assets.isEmpty else { return }

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = photoKitAllowsNetworkAccess
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
    /// Request options for playback. Overview heroes use **`.automatic`**; Fishial / export use **`.highQualityFormat`**.
    nonisolated static func makeVideoRequestOptions(
        quality: DiveMediaVideoRequestQuality = .fullQuality
    ) -> PHVideoRequestOptions {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = photoKitAllowsNetworkAccess
        options.deliveryMode = quality.photoKitDeliveryMode
        return options
    }

    /// Builds a fresh **`AVPlayerItem`** — never reuses a cached item (one item per **`AVPlayer`**).
    ///
    /// Uses the session **`AVAsset`** cache when warmed; otherwise loads via **`loadVideoAsset`**.
    @MainActor
    static func playerItem(
        localIdentifier: String,
        timeoutSeconds: Double = DiveMediaVideoLoad.timeoutSeconds,
        quality: DiveMediaVideoRequestQuality = .fullQuality
    ) async -> AVPlayerItem? {
        if let avAsset = DiveMediaVideoAssetSessionCache.shared.videoAsset(
            for: localIdentifier,
            quality: quality
        ) {
            return AVPlayerItem(asset: avAsset)
        }
        guard let avAsset = await loadVideoAsset(
            localIdentifier: localIdentifier,
            timeoutSeconds: timeoutSeconds,
            quality: quality
        ) else {
            return nil
        }
        return AVPlayerItem(asset: avAsset)
    }

    /// Loads an **`AVAsset`** from PhotoKit for session warm-cache (shareable across many **`AVPlayerItem`**s).
    @MainActor
    static func loadVideoAsset(
        localIdentifier: String,
        timeoutSeconds: Double = DiveMediaVideoLoad.timeoutSeconds,
        quality: DiveMediaVideoRequestQuality = .fullQuality
    ) async -> AVAsset? {
        if let cached = DiveMediaVideoAssetSessionCache.shared.videoAsset(
            for: localIdentifier,
            quality: quality
        ) {
            return cached
        }
        guard let phAsset = asset(localIdentifier: localIdentifier) else { return nil }

        let options = makeVideoRequestOptions(quality: quality)
        let avAsset = await requestAVAssetFromPhotoKit(
            asset: phAsset,
            options: options,
            timeoutSeconds: timeoutSeconds
        )
        if let avAsset, quality.cachesInSession {
            DiveMediaVideoAssetSessionCache.shared.store(
                avAsset,
                localIdentifier: localIdentifier,
                quality: quality
            )
        }
        return avAsset
    }

    nonisolated private static func requestAVAssetFromPhotoKit(
        asset: PHAsset,
        options: PHVideoRequestOptions,
        timeoutSeconds: Double
    ) async -> AVAsset? {
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
                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + timeoutSeconds) {
                    if resumeGuard.claim() {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }
    #endif

    /// Drops session warm caches and in-memory PhotoKit image frames (call when app backgrounds).
    @MainActor
    static func clearSessionMediaCaches() {
        DiveMediaScopeCache.shared.clearSessionCachesOnBackground()
    }

    #if canImport(UIKit)
    /// Clears inflight image loads for a library asset when a page scope releases high fidelity.
    @MainActor
    static func releaseCachedImages(forLocalIdentifier localIdentifier: String) {
        DiveMediaReferenceImageCache.shared.removeInflightLoads(matchingPrefix: "\(localIdentifier)|")
    }

    @MainActor
    static func clearInflightImageLoads() {
        DiveMediaReferenceImageCache.shared.removeAll()
    }
    #endif
}

#if canImport(Photos)
/// Thread-safe single-use latch so PhotoKit load handlers resume a continuation exactly once.
private final class SingleResumeGuard: @unchecked Sendable {
    private let lock = NSLock()
    private nonisolated(unsafe) var claimed = false

    nonisolated init() {}

    /// Returns **`true`** for the first caller only; subsequent callers get **`false`**.
    nonisolated func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if claimed { return false }
        claimed = true
        return true
    }
}
#endif

#if canImport(UIKit)
@MainActor
private final class DiveMediaReferenceImageCache {
    static let shared = DiveMediaReferenceImageCache()
    private let storage = NSCache<NSString, UIImage>()
    private var inflightLoads: [String: Task<UIImage?, Never>] = [:]

    private init() {
        storage.totalCostLimit = 128 * 1_024 * 1_024
        storage.countLimit = 200
    }

    func key(localIdentifier: String, targetSize: CGSize) -> NSString {
        "\(localIdentifier)|\(Int(targetSize.width))x\(Int(targetSize.height))" as NSString
    }

    func image(for key: NSString) -> UIImage? {
        storage.object(forKey: key)
    }

    func store(_ image: UIImage, for key: NSString) {
        storage.setObject(image, forKey: key, cost: Self.storageCost(for: image))
    }

    func inflightTask(for key: String) -> Task<UIImage?, Never>? {
        inflightLoads[key]
    }

    func storeInflightTask(_ task: Task<UIImage?, Never>, for key: String) {
        inflightLoads[key] = task
    }

    func removeInflightTask(for key: String) {
        inflightLoads.removeValue(forKey: key)
    }

    func removeInflightLoads(matchingPrefix prefix: String) {
        inflightLoads = inflightLoads.filter { !$0.key.hasPrefix(prefix) }
    }

    func removeAll() {
        storage.removeAllObjects()
        inflightLoads.removeAll()
    }

    nonisolated static func storageCost(for image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 1 }
        return max(cgImage.bytesPerRow * cgImage.height, 1)
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

