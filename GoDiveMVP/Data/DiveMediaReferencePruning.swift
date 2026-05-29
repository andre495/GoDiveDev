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
enum DiveMediaReferencePruning {

    /// Pure decision gate (testable without PhotoKit): prune only when we can be sure the original is gone.
    nonisolated static func shouldPrune(
        hasIdentifier: Bool,
        hasFullAuthorization: Bool,
        assetExists: Bool
    ) -> Bool {
        hasIdentifier && hasFullAuthorization && !assetExists
    }

    #if canImport(Photos)
    /// Deletes the row when its asset is confirmed missing. Returns **`true`** when it pruned.
    @MainActor
    @discardableResult
    static func pruneIfAssetMissing(_ media: DiveMediaPhoto, modelContext: ModelContext) -> Bool {
        guard let identifier = media.libraryAssetLocalIdentifier else { return false }
        let hasFullAuthorization = PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized
        let assetExists = DiveMediaReferenceLoader.assetExists(localIdentifier: identifier)
        guard shouldPrune(
            hasIdentifier: true,
            hasFullAuthorization: hasFullAuthorization,
            assetExists: assetExists
        ) else { return false }

        modelContext.delete(media)
        try? modelContext.save()
        DiveActivityMediaStorage.postMediaDidChange()
        return true
    }
    #endif
}
