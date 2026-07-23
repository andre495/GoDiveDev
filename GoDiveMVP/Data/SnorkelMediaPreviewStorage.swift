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

    @MainActor
    static func storedPreviewImage(for media: SnorkelMediaPhoto) -> UIImage? {
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
