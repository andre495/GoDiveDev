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

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isSynchronous = false

        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: contentMode,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
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

    /// Builds an **`AVPlayerItem`** that streams directly from the Photos library asset (no exported file).
    ///
    /// Bounded by **`timeoutSeconds`**: **`PHImageManager.requestPlayerItem`** can stall for a long time (or never
    /// call back) while pulling an iCloud original, so if it hasn't produced an item by the deadline this resolves to
    /// **`nil`** and the caller can show a retry affordance. (The underlying request can't be cancelled; a late
    /// result is simply ignored.)
    @MainActor
    static func playerItem(
        localIdentifier: String,
        timeoutSeconds: Double = DiveMediaVideoLoad.timeoutSeconds
    ) async -> AVPlayerItem? {
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
    #endif
}

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
