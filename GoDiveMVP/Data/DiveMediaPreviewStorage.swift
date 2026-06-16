import Foundation
import SwiftData
#if canImport(Photos)
import Photos
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Reads and writes **`DiveMediaPhoto.previewJPEGData`** (instant thumbnails across the app).
enum DiveMediaPreviewStorage {

    #if canImport(UIKit)
    nonisolated static func hasStoredPreview(for media: DiveMediaPhoto) -> Bool {
        guard let data = media.previewJPEGData, !data.isEmpty else { return false }
        return true
    }

    @MainActor
    static func storedPreviewImage(for media: DiveMediaPhoto) -> UIImage? {
        DiveMediaPreviewPersistence.decodePreviewJPEG(media.previewJPEGData)
    }

    /// Copies the persisted JPEG into the session warm cache so PhotoKit loaders and carousel gates see it immediately.
    @MainActor
    static func seedSessionCacheIfNeeded(for media: DiveMediaPhoto) {
        guard let identifier = media.libraryAssetLocalIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
              !identifier.isEmpty,
              let image = storedPreviewImage(for: media) else { return }

        let previewEdge = HomeMediaHighlightWarmupPresentation.previewImageEdge
        if HomeMediaHighlightSessionCache.shared.image(for: identifier, edge: previewEdge) == nil {
            HomeMediaHighlightSessionCache.shared.storeImage(
                image,
                localIdentifier: identifier,
                edge: previewEdge
            )
        }
    }

    @MainActor
    static func seedSessionCache(for mediaRows: [DiveMediaPhoto]) {
        for media in mediaRows {
            seedSessionCacheIfNeeded(for: media)
        }
    }

    @MainActor
    static func persistPreview(
        from image: UIImage,
        on media: DiveMediaPhoto,
        modelContext: ModelContext
    ) {
        guard DiveMediaPreviewPersistence.shouldPersistPreview(existingData: media.previewJPEGData),
              let data = DiveMediaPreviewPersistence.encodePreviewJPEG(image) else { return }
        media.previewJPEGData = data
        try? modelContext.save()
        seedSessionCacheIfNeeded(for: media)
    }

    /// Fast local PhotoKit frame → persisted JPEG (attach, backfill, or hero warm).
    @MainActor
    static func captureAndPersistPreview(
        for media: DiveMediaPhoto,
        modelContext: ModelContext
    ) async {
        guard DiveMediaPreviewPersistence.shouldPersistPreview(existingData: media.previewJPEGData),
              let identifier = media.libraryAssetLocalIdentifier else { return }

        let edge = DiveMediaPreviewPersistence.storedPreviewEdge
        let targetSize = CGSize(width: edge, height: edge)
        guard let image = await DiveMediaReferenceLoader.image(
            localIdentifier: identifier,
            targetSize: targetSize,
            deliveryMode: .fastFormat
        ) else { return }
        persistPreview(from: image, on: media, modelContext: modelContext)
    }

    /// Ensures carousel / hero picks have a persisted preview (priority over global launch backfill).
    @MainActor
    static func ensureStoredPreviews(
        for mediaRows: [DiveMediaPhoto],
        modelContext: ModelContext
    ) async {
        for media in mediaRows where !hasStoredPreview(for: media) {
            await captureAndPersistPreview(for: media, modelContext: modelContext)
        }
        seedSessionCache(for: mediaRows)
    }

    /// Batches preview capture for legacy rows missing **`previewJPEGData`** (launch / maintenance).
    @MainActor
    static func backfillMissingPreviews(
        modelContext: ModelContext,
        batchLimit: Int = 24
    ) async {
        var descriptor = FetchDescriptor<DiveMediaPhoto>(
            predicate: #Predicate<DiveMediaPhoto> { $0.previewJPEGData == nil }
        )
        descriptor.fetchLimit = batchLimit
        guard let rows = try? modelContext.fetch(descriptor), !rows.isEmpty else { return }
        for row in rows where row.libraryAssetLocalIdentifier != nil {
            await captureAndPersistPreview(for: row, modelContext: modelContext)
        }
    }
    #endif
}
