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
/// delete a valid pointer that only needs remapping.
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
                    try? modelContext.save()
                    DiveActivityMediaStorage.postMediaDidChange()
                }
                if DiveMediaReferenceLoader.assetExists(localIdentifier: localID) {
                    return false
                }
            case .ambiguous(let locals):
                if let first = locals.first {
                    media.photosLocalIdentifier = first
                    try? modelContext.save()
                    DiveActivityMediaStorage.postMediaDidChange()
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
        try? modelContext.save()
        DiveActivityMediaStorage.postMediaDidChange()
        return true
    }
    #endif
}
