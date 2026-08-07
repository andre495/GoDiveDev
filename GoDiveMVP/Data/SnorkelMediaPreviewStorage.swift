import Foundation
import SwiftData
#if canImport(Photos)
import Photos
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Reads and writes **`SnorkelMediaPhoto.previewJPEGData`** (instant thumbnails across the app).
enum SnorkelMediaPreviewStorage {

    #if canImport(UIKit)
    nonisolated static func hasStoredPreview(for media: SnorkelMediaPhoto) -> Bool {
        guard let data = media.previewJPEGData, !data.isEmpty else { return false }
        return true
    }

    @MainActor
    private static let decodedPreviewCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 300
        cache.totalCostLimit = 24 * 1_024 * 1_024
        return cache
    }()

    /// Cache-only lookup — safe to call from view bodies during scroll.
    @MainActor
    static func cachedStoredPreviewImage(for media: SnorkelMediaPhoto) -> UIImage? {
        decodedPreviewCache.object(forKey: media.id.uuidString as NSString)
    }

    @MainActor
    static func storedPreviewImage(for media: SnorkelMediaPhoto) -> UIImage? {
        if let cached = cachedStoredPreviewImage(for: media) {
            return cached
        }
        guard let image = DiveMediaPreviewPersistence.decodePreviewJPEG(media.previewJPEGData) else {
            return nil
        }
        storeDecodedPreview(image, for: media.id)
        return image
    }

    /// Decodes the stored JPEG off the main actor on cache miss.
    @MainActor
    static func loadStoredPreviewImage(for media: SnorkelMediaPhoto) async -> UIImage? {
        if let cached = cachedStoredPreviewImage(for: media) {
            return cached
        }
        guard let data = media.previewJPEGData, !data.isEmpty else { return nil }
        let mediaID = media.id
        let decoded = await Task.detached(priority: .userInitiated) {
            DiveMediaPreviewPersistence.decodePreviewJPEG(data)
        }.value
        guard let decoded else { return nil }
        storeDecodedPreview(decoded, for: mediaID)
        return decoded
    }

    @MainActor
    private static func storeDecodedPreview(_ image: UIImage, for mediaID: UUID) {
        let key = mediaID.uuidString as NSString
        let pixelCost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        decodedPreviewCache.setObject(image, forKey: key, cost: max(pixelCost, 1))
    }

    @MainActor
    static func seedSessionCacheIfNeeded(for media: SnorkelMediaPhoto) {
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
    static func persistPreview(
        from image: UIImage,
        on media: SnorkelMediaPhoto,
        modelContext: ModelContext
    ) {
        guard DiveMediaPreviewPersistence.shouldPersistPreview(existingData: media.previewJPEGData),
              let data = DiveMediaPreviewPersistence.encodePreviewJPEG(image) else { return }
        media.previewJPEGData = data
        try? modelContext.save()
        seedSessionCacheIfNeeded(for: media)
    }

    @MainActor
    static func captureAndPersistPreview(
        for media: SnorkelMediaPhoto,
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
    #endif
}
