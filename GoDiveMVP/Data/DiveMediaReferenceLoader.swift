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
            return await existing.value.image
        }

        let task = Task.detached(priority: .userInitiated) {
            await fetchImageFromPhotoKit(
                asset: phAsset,
                targetSize: targetSize,
                contentMode: contentMode,
                deliveryMode: deliveryMode,
                localIdentifier: localIdentifier
            )
        }
        DiveMediaReferenceImageCache.shared.storeInflightTask(task, for: inflightKey)
        let fetched = await task.value
        DiveMediaReferenceImageCache.shared.removeInflightTask(for: inflightKey)
        if let image = fetched.image, DiveMediaStillLoad.shouldCacheFetchedImage(isFinal: fetched.isFinal) {
            DiveMediaReferenceImageCache.shared.store(image, for: cacheKey)
            if HomeMediaHighlightWarmup.shouldStoreInSessionCache(edge: edge) {
                HomeMediaHighlightSessionCache.shared.storeImage(
                    image,
                    localIdentifier: localIdentifier,
                    edge: edge
                )
            }
        }
        return fetched.image
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

            // Degraded frames were already delivered via onFrame; a stalled iCloud final must not
            // keep the caller's task (and its "load finished" state) hung forever. Late finals still
            // flow through onFrame after this resume.
            DispatchQueue.global(qos: .userInitiated).asyncAfter(
                deadline: .now() + DiveMediaStillLoad.requestTimeoutSeconds
            ) {
                if resumeGuard.claim() {
                    continuation.resume()
                }
            }
        }
    }

    nonisolated private static func fetchImageFromPhotoKit(
        asset: PHAsset,
        targetSize: CGSize,
        contentMode: PHImageContentMode,
        deliveryMode: PHImageRequestOptionsDeliveryMode,
        localIdentifier: String
    ) async -> (image: UIImage?, isFinal: Bool) {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = photoKitAllowsNetworkAccess
        options.deliveryMode = deliveryMode
        options.resizeMode = .fast
        options.isSynchronous = false

        return await withCheckedContinuation { continuation in
            let resumeGuard = SingleResumeGuard()
            let degradedFrame = LatestDegradedFrameBox()
            let started = Date()
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: contentMode,
                options: options
            ) { image, info in
                if (info?[PHImageCancelledKey] as? Bool) == true {
                    if resumeGuard.claim() {
                        continuation.resume(returning: (nil, false))
                    }
                    return
                }

                if deliveryMode == .opportunistic,
                   (info?[PHImageResultIsDegradedKey] as? Bool) == true {
                    // Keep the local thumbnail as a fallback in case the iCloud final never arrives.
                    degradedFrame.store(image)
                    return
                }

                if resumeGuard.claim() {
                    continuation.resume(returning: (image, image != nil))
                }
            }

            // A stalled iCloud download must not hang the caller forever — fall back to the degraded frame.
            guard deliveryMode == .opportunistic else { return }
            let timeout = DiveMediaStillLoad.requestTimeoutSeconds
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + timeout) {
                guard resumeGuard.claim() else { return }
                let fallback = DiveMediaStillLoad.timeoutFallbackImage(latestDegraded: degradedFrame.value)
                let elapsed = Date().timeIntervalSince(started)
                Task { @MainActor in
                    HomeMediaCarouselDebug.stillRequestFellBackToDegraded(
                        localIdentifier: localIdentifier,
                        elapsedSeconds: elapsed,
                        hadDegradedFrame: fallback != nil
                    )
                }
                continuation.resume(returning: (fallback, false))
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

    /// Builds a fresh **`AVPlayerItem`**.
    ///
    /// Home / overview (**`.homeCarousel`**) returns PhotoKit’s streaming **`requestPlayerItem`** result
    /// directly — never touches **`.asset`** in the PhotoKit callback (that forces a full iCloud download
    /// and was timing out at ~30 s). Full-quality / export wraps a **`requestAVAsset`** result.
    @MainActor
    static func playerItem(
        localIdentifier: String,
        timeoutSeconds: Double? = nil,
        quality: DiveMediaVideoRequestQuality = .fullQuality
    ) async -> AVPlayerItem? {
        let timeout = timeoutSeconds ?? quality.requestTimeoutSeconds
        if quality.usesPlayerItemRequest {
            return await loadStreamingPlayerItem(
                localIdentifier: localIdentifier,
                timeoutSeconds: timeout,
                quality: quality
            )
        }
        guard let avAsset = await loadVideoAsset(
            localIdentifier: localIdentifier,
            timeoutSeconds: timeout,
            quality: quality
        ) else {
            return nil
        }
        return AVPlayerItem(asset: avAsset)
    }

    /// Streaming playback path — PhotoKit **`AVPlayerItem`** only (no **`.asset`** extraction).
    @MainActor
    private static func loadStreamingPlayerItem(
        localIdentifier: String,
        timeoutSeconds: Double,
        quality: DiveMediaVideoRequestQuality
    ) async -> AVPlayerItem? {
        let inflightKey = "playerItem|\(DiveMediaVideoAssetSessionCache.storageKey(localIdentifier: localIdentifier, quality: quality))"
        if let existing = inflightVideoPlayerItemTasks[inflightKey] {
            return await existing.value
        }
        guard let phAsset = asset(localIdentifier: localIdentifier) else { return nil }

        let options = makeVideoRequestOptions(quality: quality)
        let networkAllowed = options.isNetworkAccessAllowed
        let task = Task<AVPlayerItem?, Never> { @MainActor in
            await DiveMediaVideoPhotoKitGate.withExclusiveAccess {
                await requestPlayerItemFromPhotoKit(
                    asset: phAsset,
                    options: options,
                    timeoutSeconds: timeoutSeconds,
                    localIdentifier: localIdentifier,
                    quality: quality,
                    networkAllowed: networkAllowed
                )
            }
        }
        inflightVideoPlayerItemTasks[inflightKey] = task
        let result = await task.value
        inflightVideoPlayerItemTasks[inflightKey] = nil
        return result
    }

    /// Loads an **`AVAsset`** from PhotoKit for export / Fishial / session warm-cache that needs tracks.
    ///
    /// Do **not** use this for Home carousel playback — use **`playerItem`** (streaming) instead.
    @MainActor
    static func loadVideoAsset(
        localIdentifier: String,
        timeoutSeconds: Double? = nil,
        quality: DiveMediaVideoRequestQuality = .fullQuality
    ) async -> AVAsset? {
        let timeout = timeoutSeconds ?? quality.requestTimeoutSeconds
        if let cached = DiveMediaVideoAssetSessionCache.shared.videoAsset(
            for: localIdentifier,
            quality: quality
        ) {
            return cached
        }
        let inflightKey = DiveMediaVideoAssetSessionCache.storageKey(
            localIdentifier: localIdentifier,
            quality: quality
        )
        if let existing = inflightVideoAssetTasks[inflightKey] {
            return await existing.value
        }

        guard let phAsset = asset(localIdentifier: localIdentifier) else { return nil }

        let options = makeVideoRequestOptions(quality: quality)
        let networkAllowed = options.isNetworkAccessAllowed
        let task = Task<AVAsset?, Never> { @MainActor in
            // One PhotoKit video request at a time — parallel iCloud loads all hit soft timeout together.
            let avAsset = await DiveMediaVideoPhotoKitGate.withExclusiveAccess {
                await requestAVAssetFromPhotoKit(
                    asset: phAsset,
                    options: options,
                    timeoutSeconds: timeout,
                    localIdentifier: localIdentifier,
                    quality: quality,
                    networkAllowed: networkAllowed
                )
            }
            if let avAsset {
                if quality.cachesInSession {
                    DiveMediaVideoAssetSessionCache.shared.store(
                        avAsset,
                        localIdentifier: localIdentifier,
                        quality: quality
                    )
                }
                return avAsset
            }
            // Timeout may have raced a late PhotoKit success that stored into session cache.
            return DiveMediaVideoAssetSessionCache.shared.videoAsset(
                for: localIdentifier,
                quality: quality
            )
        }
        inflightVideoAssetTasks[inflightKey] = task
        let result = await task.value
        inflightVideoAssetTasks[inflightKey] = nil
        return result
    }

    @MainActor
    private static var inflightVideoAssetTasks: [String: Task<AVAsset?, Never>] = [:]
    @MainActor
    private static var inflightVideoPlayerItemTasks: [String: Task<AVPlayerItem?, Never>] = [:]

    nonisolated private static func requestPlayerItemFromPhotoKit(
        asset: PHAsset,
        options: PHVideoRequestOptions,
        timeoutSeconds: Double,
        localIdentifier: String,
        quality: DiveMediaVideoRequestQuality,
        networkAllowed: Bool
    ) async -> AVPlayerItem? {
        let resumeGuard = SingleResumeGuard()
        let started = Date()
        let progressState = VideoRequestProgressState()
        options.progressHandler = { progress, _, _, _ in
            if progress > 0 {
                progressState.noteProgress()
            }
        }

        return await withCheckedContinuation { (continuation: CheckedContinuation<AVPlayerItem?, Never>) in
            _ = PHImageManager.default().requestPlayerItem(
                forVideo: asset,
                options: options
            ) { playerItem, info in
                // Do not read playerItem.asset here — that forces a full download and stalls the callback.
                finishLibraryPlayerItemRequest(
                    playerItem: playerItem,
                    info: info,
                    timedOut: false,
                    started: started,
                    networkAllowed: networkAllowed,
                    localIdentifier: localIdentifier,
                    quality: quality,
                    hasSeenProgress: progressState.hasSeenProgress,
                    resumeGuard: resumeGuard,
                    continuation: continuation
                )
            }

            scheduleLibraryPlayerItemRequestTimeout(
                softTimeoutSeconds: timeoutSeconds,
                hardTimeoutSeconds: quality.requestHardTimeoutSeconds,
                started: started,
                networkAllowed: networkAllowed,
                localIdentifier: localIdentifier,
                quality: quality,
                progressState: progressState,
                resumeGuard: resumeGuard,
                continuation: continuation
            )
        }
    }

    nonisolated private static func requestAVAssetFromPhotoKit(
        asset: PHAsset,
        options: PHVideoRequestOptions,
        timeoutSeconds: Double,
        localIdentifier: String,
        quality: DiveMediaVideoRequestQuality,
        networkAllowed: Bool
    ) async -> AVAsset? {
        let resumeGuard = SingleResumeGuard()
        let started = Date()
        let progressState = VideoRequestProgressState()
        options.progressHandler = { progress, _, _, _ in
            if progress > 0 {
                progressState.noteProgress()
            }
        }

        return await withCheckedContinuation { (continuation: CheckedContinuation<AVAsset?, Never>) in
            _ = PHImageManager.default().requestAVAsset(
                forVideo: asset,
                options: options
            ) { avAsset, _, info in
                finishLibraryVideoRequest(
                    avAsset: avAsset,
                    info: info,
                    timedOut: false,
                    started: started,
                    networkAllowed: networkAllowed,
                    localIdentifier: localIdentifier,
                    quality: quality,
                    hasSeenProgress: progressState.hasSeenProgress,
                    resumeGuard: resumeGuard,
                    continuation: continuation
                )
            }

            scheduleLibraryVideoRequestTimeout(
                softTimeoutSeconds: timeoutSeconds,
                hardTimeoutSeconds: quality.requestHardTimeoutSeconds,
                started: started,
                networkAllowed: networkAllowed,
                localIdentifier: localIdentifier,
                quality: quality,
                progressState: progressState,
                resumeGuard: resumeGuard,
                continuation: continuation
            )
        }
    }

    nonisolated private static func scheduleLibraryPlayerItemRequestTimeout(
        softTimeoutSeconds: Double,
        hardTimeoutSeconds: Double,
        started: Date,
        networkAllowed: Bool,
        localIdentifier: String,
        quality: DiveMediaVideoRequestQuality,
        progressState: VideoRequestProgressState,
        resumeGuard: SingleResumeGuard,
        continuation: CheckedContinuation<AVPlayerItem?, Never>
    ) {
        guard softTimeoutSeconds > 0 else { return }
        Task.detached {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                let elapsed = Date().timeIntervalSince(started)
                guard DiveMediaVideoLoad.shouldFailVideoRequest(
                    elapsedSeconds: elapsed,
                    hasSeenProgress: progressState.hasSeenProgress,
                    softTimeoutSeconds: softTimeoutSeconds,
                    hardTimeoutSeconds: hardTimeoutSeconds
                ) else { continue }

                finishLibraryPlayerItemRequest(
                    playerItem: nil,
                    info: nil,
                    timedOut: true,
                    started: started,
                    networkAllowed: networkAllowed,
                    localIdentifier: localIdentifier,
                    quality: quality,
                    hasSeenProgress: progressState.hasSeenProgress,
                    resumeGuard: resumeGuard,
                    continuation: continuation
                )
                return
            }
        }
    }

    nonisolated private static func finishLibraryPlayerItemRequest(
        playerItem: AVPlayerItem?,
        info: [AnyHashable: Any]?,
        timedOut: Bool,
        started: Date,
        networkAllowed: Bool,
        localIdentifier: String,
        quality: DiveMediaVideoRequestQuality,
        hasSeenProgress: Bool,
        resumeGuard: SingleResumeGuard,
        continuation: CheckedContinuation<AVPlayerItem?, Never>
    ) {
        guard resumeGuard.claim() else { return }

        let elapsed = Date().timeIntervalSince(started)
        if let playerItem {
            Task { @MainActor in
                HomeMediaCarouselDebug.videoAssetRequestSucceeded(
                    localIdentifier: localIdentifier,
                    quality: quality.sessionCacheKeySuffix,
                    elapsedSeconds: elapsed
                )
            }
            continuation.resume(returning: playerItem)
            return
        }

        let isInCloud = info?[PHImageResultIsInCloudKey] as? Bool
        let error = info?[PHImageErrorKey] as? NSError
        let detail = DiveMediaVideoLoad.requestFailureDetail(
            timedOut: timedOut,
            networkAllowed: networkAllowed,
            elapsedSeconds: elapsed,
            isInCloud: isInCloud,
            errorDescription: error?.localizedDescription,
            hasSeenProgress: hasSeenProgress
        )
        Task { @MainActor in
            HomeMediaCarouselDebug.videoAssetRequestFailed(
                localIdentifier: localIdentifier,
                quality: quality.sessionCacheKeySuffix,
                detail: detail
            )
        }
        continuation.resume(returning: nil)
    }

    nonisolated private static func scheduleLibraryVideoRequestTimeout(
        softTimeoutSeconds: Double,
        hardTimeoutSeconds: Double,
        started: Date,
        networkAllowed: Bool,
        localIdentifier: String,
        quality: DiveMediaVideoRequestQuality,
        progressState: VideoRequestProgressState,
        resumeGuard: SingleResumeGuard,
        continuation: CheckedContinuation<AVAsset?, Never>
    ) {
        guard softTimeoutSeconds > 0 else { return }
        Task.detached {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                let elapsed = Date().timeIntervalSince(started)
                guard DiveMediaVideoLoad.shouldFailVideoRequest(
                    elapsedSeconds: elapsed,
                    hasSeenProgress: progressState.hasSeenProgress,
                    softTimeoutSeconds: softTimeoutSeconds,
                    hardTimeoutSeconds: hardTimeoutSeconds
                ) else { continue }

                finishLibraryVideoRequest(
                    avAsset: nil,
                    info: nil,
                    timedOut: true,
                    started: started,
                    networkAllowed: networkAllowed,
                    localIdentifier: localIdentifier,
                    quality: quality,
                    hasSeenProgress: progressState.hasSeenProgress,
                    resumeGuard: resumeGuard,
                    continuation: continuation
                )
                return
            }
        }
    }

    nonisolated private static func finishLibraryVideoRequest(
        avAsset: AVAsset?,
        info: [AnyHashable: Any]?,
        timedOut: Bool,
        started: Date,
        networkAllowed: Bool,
        localIdentifier: String,
        quality: DiveMediaVideoRequestQuality,
        hasSeenProgress: Bool,
        resumeGuard: SingleResumeGuard,
        continuation: CheckedContinuation<AVAsset?, Never>
    ) {
        if let avAsset, quality.cachesInSession {
            // Persist even if this caller already timed out — next coalesce / retry can hit cache.
            Task { @MainActor in
                DiveMediaVideoAssetSessionCache.shared.store(
                    avAsset,
                    localIdentifier: localIdentifier,
                    quality: quality
                )
            }
        }

        guard resumeGuard.claim() else { return }

        if avAsset == nil {
            let elapsed = Date().timeIntervalSince(started)
            let isInCloud = info?[PHImageResultIsInCloudKey] as? Bool
            let error = info?[PHImageErrorKey] as? NSError
            let detail = DiveMediaVideoLoad.requestFailureDetail(
                timedOut: timedOut,
                networkAllowed: networkAllowed,
                elapsedSeconds: elapsed,
                isInCloud: isInCloud,
                errorDescription: error?.localizedDescription,
                hasSeenProgress: hasSeenProgress
            )
            Task { @MainActor in
                HomeMediaCarouselDebug.videoAssetRequestFailed(
                    localIdentifier: localIdentifier,
                    quality: quality.sessionCacheKeySuffix,
                    detail: detail
                )
            }
        }

        continuation.resume(returning: avAsset)
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

/// Latest degraded (local thumbnail) frame delivered by an opportunistic request — timeout fallback.
private final class LatestDegradedFrameBox: @unchecked Sendable {
    private let lock = NSLock()
    #if canImport(UIKit)
    private nonisolated(unsafe) var image: UIImage?

    nonisolated func store(_ image: UIImage?) {
        guard let image else { return }
        lock.lock()
        self.image = image
        lock.unlock()
    }

    nonisolated var value: UIImage? {
        lock.lock()
        defer { lock.unlock() }
        return image
    }
    #endif

    nonisolated init() {}
}

/// Tracks PhotoKit iCloud progress so soft timeouts can wait out an active download.
private final class VideoRequestProgressState: @unchecked Sendable {
    private let lock = NSLock()
    private nonisolated(unsafe) var seenProgress = false

    nonisolated init() {}

    nonisolated func noteProgress() {
        lock.lock()
        seenProgress = true
        lock.unlock()
    }

    nonisolated var hasSeenProgress: Bool {
        lock.lock()
        defer { lock.unlock() }
        return seenProgress
    }
}
#endif

#if canImport(UIKit)
@MainActor
private final class DiveMediaReferenceImageCache {
    typealias FetchTask = Task<(image: UIImage?, isFinal: Bool), Never>

    static let shared = DiveMediaReferenceImageCache()
    private let storage = NSCache<NSString, UIImage>()
    private var inflightLoads: [String: FetchTask] = [:]

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

    func inflightTask(for key: String) -> FetchTask? {
        inflightLoads[key]
    }

    func storeInflightTask(_ task: FetchTask, for key: String) {
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

