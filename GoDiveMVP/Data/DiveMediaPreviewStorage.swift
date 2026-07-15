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

    /// Decoded stored previews keyed by **`DiveMediaPhoto.id`**. `previewJPEGData` is write-once
    /// (**`shouldPersistPreview`**), so cached decodes never go stale. Without this, every grid
    /// cell body evaluation re-created a `UIImage` from JPEG data on the main actor.
    @MainActor
    private static let decodedPreviewCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 600
        cache.totalCostLimit = 48 * 1_024 * 1_024
        return cache
    }()

    @MainActor
    static func storedPreviewImage(for media: DiveMediaPhoto) -> UIImage? {
        let key = media.id.uuidString as NSString
        if let cached = decodedPreviewCache.object(forKey: key) {
            return cached
        }
        guard let image = DiveMediaPreviewPersistence.decodePreviewJPEG(media.previewJPEGData) else {
            return nil
        }
        let pixelCost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        decodedPreviewCache.setObject(image, forKey: key, cost: max(pixelCost, 1))
        return image
    }

    /// Copies the persisted JPEG into the session warm cache under the **stored-preview** edge so PhotoKit
    /// preview/hero lookups (**480** / hero) are never falsely short-circuited by a soft **256 px** frame.
    @MainActor
    static func seedSessionCacheIfNeeded(for media: DiveMediaPhoto) {
        guard let identifier = media.libraryAssetLocalIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
              !identifier.isEmpty,
              let image = storedPreviewImage(for: media) else { return }

        let softEdge = HomeMediaHighlightWarmupPresentation.storedPreviewSessionEdge
        if HomeMediaHighlightSessionCache.shared.image(for: identifier, edge: softEdge) == nil {
            HomeMediaHighlightSessionCache.shared.storeImage(
                image,
                localIdentifier: identifier,
                edge: softEdge
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
    /// Captures missing JPEGs in parallel so iCloud waits do not serialize across slides.
    @MainActor
    static func ensureStoredPreviews(
        for mediaRows: [DiveMediaPhoto],
        modelContext: ModelContext
    ) async {
        let missing = mediaRows.filter { !hasStoredPreview(for: $0) }
        if !missing.isEmpty {
            await withTaskGroup(of: Void.self) { group in
                for media in missing {
                    group.addTask { @MainActor in
                        await captureAndPersistPreview(for: media, modelContext: modelContext)
                    }
                }
            }
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
