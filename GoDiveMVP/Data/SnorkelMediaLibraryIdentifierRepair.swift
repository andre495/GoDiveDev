import Foundation
import SwiftData
#if canImport(Photos)
import Photos
#endif

/// Applies cloud ↔ local Photos identifier mapping onto **`SnorkelMediaPhoto`** rows.
enum SnorkelMediaLibraryIdentifierRepair: Sendable {

    /// Ensures **`photosLocalIdentifier`** is usable on this device when a cloud ID is present.
    /// Returns the local identifier to load, or **`nil`** when unresolved.
    @discardableResult
    static func resolveLocalIdentifierIfNeeded(
        for media: SnorkelMediaPhoto,
        modelContext: ModelContext
    ) -> String? {
        #if canImport(Photos)
        if let local = media.libraryAssetLocalIdentifier,
           DiveMediaReferenceLoader.assetExists(localIdentifier: local) {
            return local
        }

        guard DiveMediaCloudIdentifierPolicy.shouldAttemptCloudResolve(
            localAssetExists: false,
            cloudIdentifier: media.photosCloudIdentifier
        ) else {
            return media.libraryAssetLocalIdentifier
        }

        switch DiveMediaCloudIdentifierResolver.localIdentifier(
            forCloudIdentifierString: media.photosCloudIdentifier
        ) {
        case .resolved(let localID):
            if media.photosLocalIdentifier != localID {
                media.photosLocalIdentifier = localID
                try? modelContext.save()
            }
            return localID
        case .ambiguous(let locals):
            if let first = locals.first {
                media.photosLocalIdentifier = first
                try? modelContext.save()
                return first
            }
            return media.libraryAssetLocalIdentifier
        case .notFound, .unavailable, .emptyInput:
            return media.libraryAssetLocalIdentifier
        }
        #else
        return media.libraryAssetLocalIdentifier
        #endif
    }

    /// Fills empty **`photosCloudIdentifier`** from the local Photos asset (best-effort).
    /// Does not save — caller batches **`modelContext.save()`**.
    @discardableResult
    static func captureCloudIdentifierIfNeeded(for media: SnorkelMediaPhoto) -> Bool {
        #if canImport(Photos)
        guard DiveMediaCloudIdentifierPolicy.needsCloudIdentifierCapture(
            localIdentifier: media.photosLocalIdentifier,
            cloudIdentifier: media.photosCloudIdentifier
        ) else {
            return false
        }
        guard let local = media.libraryAssetLocalIdentifier,
              let cloud = DiveMediaCloudIdentifierResolver.cloudIdentifierString(forLocalIdentifier: local)
        else {
            return false
        }
        media.photosCloudIdentifier = cloud
        return true
        #else
        return false
        #endif
    }
}
