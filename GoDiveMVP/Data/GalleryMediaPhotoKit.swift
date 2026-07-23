import Foundation
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

/// PhotoKit preview / identifier / prune helpers for dive and snorkel gallery media.
enum GalleryMediaPhotoKit {

    #if canImport(UIKit)
    @MainActor
    static func storedPreviewImage(for media: some PhotoLibraryMediaRow) -> UIImage? {
        if let dive = media as? DiveMediaPhoto {
            return DiveMediaPreviewStorage.storedPreviewImage(for: dive)
        }
        if let snorkel = media as? SnorkelMediaPhoto {
            return SnorkelMediaPreviewStorage.storedPreviewImage(for: snorkel)
        }
        return DiveMediaPreviewPersistence.decodePreviewJPEG(media.previewJPEGData)
    }

    @MainActor
    static func seedSessionCacheIfNeeded(for media: some PhotoLibraryMediaRow) {
        if let dive = media as? DiveMediaPhoto {
            DiveMediaPreviewStorage.seedSessionCacheIfNeeded(for: dive)
        } else if let snorkel = media as? SnorkelMediaPhoto {
            SnorkelMediaPreviewStorage.seedSessionCacheIfNeeded(for: snorkel)
        }
    }

    @MainActor
    static func persistPreview(
        from image: UIImage,
        on media: some PhotoLibraryMediaRow,
        modelContext: ModelContext
    ) {
        if let dive = media as? DiveMediaPhoto {
            DiveMediaPreviewStorage.persistPreview(from: image, on: dive, modelContext: modelContext)
        } else if let snorkel = media as? SnorkelMediaPhoto {
            SnorkelMediaPreviewStorage.persistPreview(from: image, on: snorkel, modelContext: modelContext)
        }
    }
    #endif

    @MainActor
    @discardableResult
    static func resolveLocalIdentifierIfNeeded(
        for media: some PhotoLibraryMediaRow,
        modelContext: ModelContext
    ) -> String? {
        if let dive = media as? DiveMediaPhoto {
            return DiveMediaLibraryIdentifierRepair.resolveLocalIdentifierIfNeeded(
                for: dive,
                modelContext: modelContext
            )
        }
        if let snorkel = media as? SnorkelMediaPhoto {
            return SnorkelMediaLibraryIdentifierRepair.resolveLocalIdentifierIfNeeded(
                for: snorkel,
                modelContext: modelContext
            )
        }
        return media.libraryAssetLocalIdentifier
    }

    @MainActor
    @discardableResult
    static func pruneIfAssetMissing(
        _ media: some PhotoLibraryMediaRow,
        modelContext: ModelContext
    ) -> Bool {
        if let dive = media as? DiveMediaPhoto {
            return DiveMediaReferencePruning.pruneIfAssetMissing(dive, modelContext: modelContext)
        }
        if let snorkel = media as? SnorkelMediaPhoto {
            return SnorkelMediaReferencePruning.pruneIfAssetMissing(snorkel, modelContext: modelContext)
        }
        return false
    }

    @MainActor
    @discardableResult
    static func captureCloudIdentifierIfNeeded(for media: some PhotoLibraryMediaRow) -> Bool {
        if let dive = media as? DiveMediaPhoto {
            return DiveMediaLibraryIdentifierRepair.captureCloudIdentifierIfNeeded(for: dive)
        }
        if let snorkel = media as? SnorkelMediaPhoto {
            return SnorkelMediaLibraryIdentifierRepair.captureCloudIdentifierIfNeeded(for: snorkel)
        }
        return false
    }
}
