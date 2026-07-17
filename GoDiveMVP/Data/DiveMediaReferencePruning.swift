import Foundation
import SwiftData
#if canImport(Photos)
import Photos
#endif

/// Removes a **`DiveMediaPhoto`** reference when its underlying Photos asset has been **deleted** — so the dive no
/// longer shows a broken/placeholder item.
///
/// Pruning is intentionally conservative: it only fires under **full** Photos authorization, because under
/// **limited** access a still-existing asset outside the user's selection looks "missing". Transient/offline load
/// failures don't prune (the asset still exists, so **`assetExists`** is **`true`**).
///
/// Phase 3: when a cloud identifier is present, resolve the device-local ID **before** pruning so Device B does not
/// delete a valid pointer that only needs remapping. After CloudKit import / reinstall, batch prune runs so
/// pointers whose originals were deleted from Photos are removed without waiting for a thumbnail load.
enum DiveMediaReferencePruning {

    /// Pure decision gate (testable without PhotoKit): prune only when we can be sure the original is gone.
    /// Prefer **`DiveMediaCloudIdentifierPolicy.shouldPrune`** when a cloud resolve outcome is known.
    nonisolated static func shouldPrune(
        hasIdentifier: Bool,
        hasFullAuthorization: Bool,
        assetExists: Bool
    ) -> Bool {
        DiveMediaCloudIdentifierPolicy.shouldPrune(
            hasLocalIdentifier: hasIdentifier,
            hasCloudIdentifier: false,
            hasFullAuthorization: hasFullAuthorization,
            localAssetExists: assetExists,
            cloudResolve: nil
        )
    }

    #if canImport(Photos)
    /// Deletes the row when its asset is confirmed missing (after cloud resolve when applicable).
    /// Returns **`true`** when it pruned.
    @MainActor
    @discardableResult
    static func pruneIfAssetMissing(_ media: DiveMediaPhoto, modelContext: ModelContext) -> Bool {
        let pruned = evaluateAndPruneIfNeeded(media, modelContext: modelContext)
        if pruned {
            try? modelContext.save()
            DiveActivityMediaStorage.postMediaDidChange()
        }
        return pruned
    }

    /// Scans stored media pointers and removes rows whose Photos originals are gone.
    /// Call after CloudKit import and on launch (full Photos authorization required).
    @discardableResult
    static func pruneMissingLibraryAssets(
        modelContext: ModelContext,
        batchLimit: Int = 64
    ) -> Int {
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized else { return 0 }
        let all = (try? modelContext.fetch(FetchDescriptor<DiveMediaPhoto>())) ?? []
        var pruned = 0
        for media in all where pruned < batchLimit {
            if evaluateAndPruneIfNeeded(media, modelContext: modelContext) {
                pruned += 1
            }
        }
        if pruned > 0 {
            try? modelContext.save()
            DiveActivityMediaStorage.postMediaDidChange()
        }
        return pruned
    }

    /// Core prune decision + delete (no save / notify). Returns **`true`** when the row was deleted.
    private static func evaluateAndPruneIfNeeded(
        _ media: DiveMediaPhoto,
        modelContext: ModelContext
    ) -> Bool {
        let hasFullAuthorization = PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized
        let hasLocal = media.libraryAssetLocalIdentifier != nil
        let hasCloud = DiveMediaCloudIdentifierStorage.isPresent(media.photosCloudIdentifier)

        if let localID = media.libraryAssetLocalIdentifier,
           DiveMediaReferenceLoader.assetExists(localIdentifier: localID) {
            return false
        }

        var cloudResolve: DiveMediaCloudResolveOutcome?
        if hasCloud {
            let outcome = DiveMediaCloudIdentifierResolver.localIdentifier(
                forCloudIdentifierString: media.photosCloudIdentifier
            )
            cloudResolve = outcome
            switch outcome {
            case .resolved(let localID):
                if media.photosLocalIdentifier != localID {
                    media.photosLocalIdentifier = localID
                }
                if DiveMediaReferenceLoader.assetExists(localIdentifier: localID) {
                    return false
                }
            case .ambiguous(let locals):
                if let first = locals.first {
                    media.photosLocalIdentifier = first
                    if DiveMediaReferenceLoader.assetExists(localIdentifier: first) {
                        return false
                    }
                }
            case .notFound, .unavailable, .emptyInput:
                break
            }
        }

        guard DiveMediaCloudIdentifierPolicy.shouldPrune(
            hasLocalIdentifier: hasLocal || media.libraryAssetLocalIdentifier != nil,
            hasCloudIdentifier: hasCloud,
            hasFullAuthorization: hasFullAuthorization,
            localAssetExists: false,
            cloudResolve: cloudResolve
        ) else {
            return false
        }

        modelContext.delete(media)
        return true
    }
    #endif
}
