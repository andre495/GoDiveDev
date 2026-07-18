import Foundation
import SwiftData
#if canImport(Photos)
import Photos
#endif

/// Applies cloud ↔ local Photos identifier mapping onto **`DiveMediaPhoto`** rows.
enum DiveMediaLibraryIdentifierRepair: Sendable {

    /// Ensures **`photosLocalIdentifier`** is usable on this device when a cloud ID is present.
    /// Returns the local identifier to load, or **`nil`** when unresolved.
    @discardableResult
    static func resolveLocalIdentifierIfNeeded(
        for media: DiveMediaPhoto,
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
    static func captureCloudIdentifierIfNeeded(for media: DiveMediaPhoto) -> Bool {
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

/// Launch / idle backfill for Phase 3 cloud identifiers.
enum DiveMediaCloudIdentifierBackfill: Sendable {
    private static let completedCaptureKey = "goDiveMediaCloudIdentifierCaptureBackfillComplete"

    static func backfillIfNeeded(modelContext: ModelContext, batchLimit: Int = 24) {
        #if canImport(Photos)
        captureMissingCloudIdentifiers(modelContext: modelContext, batchLimit: batchLimit)
        resolveStaleLocalIdentifiers(modelContext: modelContext, batchLimit: batchLimit)
        #endif
    }

    #if canImport(Photos)
    private static func captureMissingCloudIdentifiers(modelContext: ModelContext, batchLimit: Int) {
        let all = (try? modelContext.fetch(FetchDescriptor<DiveMediaPhoto>())) ?? []
        var updated = 0
        for media in all where updated < batchLimit {
            if DiveMediaLibraryIdentifierRepair.captureCloudIdentifierIfNeeded(for: media) {
                updated += 1
            }
        }
        if updated > 0 {
            try? modelContext.save()
        }
        if updated > 0 || !UserDefaults.standard.bool(forKey: completedCaptureKey) {
            UserDefaults.standard.set(true, forKey: completedCaptureKey)
        }
    }

    private static func resolveStaleLocalIdentifiers(modelContext: ModelContext, batchLimit: Int) {
        let all = (try? modelContext.fetch(FetchDescriptor<DiveMediaPhoto>())) ?? []
        var updated = 0
        for media in all where updated < batchLimit {
            guard DiveMediaCloudIdentifierStorage.isPresent(media.photosCloudIdentifier) else { continue }
            let localMissing: Bool = {
                guard let local = media.libraryAssetLocalIdentifier else { return true }
                return !DiveMediaReferenceLoader.assetExists(localIdentifier: local)
            }()
            guard localMissing else { continue }
            if DiveMediaLibraryIdentifierRepair.resolveLocalIdentifierIfNeeded(
                for: media,
                modelContext: modelContext
            ) != nil {
                updated += 1
            }
        }
    }
    #endif

    #if DEBUG
    static func resetCompletionFlagForTesting() {
        UserDefaults.standard.removeObject(forKey: completedCaptureKey)
    }
    #endif
}
