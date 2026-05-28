import Foundation
#if canImport(Photos)
import Photos
#endif

/// Loads a **`PHAsset`** into the same payloads used by the dive media picker.
enum DiveLibraryMediaAssetLoader: Sendable {

    enum LoadError: Error, Sendable {
        case photosUnavailable
        case unsupportedMediaType
        case missingImageData
        case missingVideoExport
    }

    #if canImport(Photos)
    @MainActor
    static func load(from asset: PHAsset) async throws -> LoadedDiveMedia {
        let localIdentifier = asset.localIdentifier
        switch asset.mediaType {
        case .image:
            let data = try await requestImageData(for: asset)
            let capturedAt = await DiveMediaCaptureDateExtraction.resolveImageCaptureDate(
                data: data,
                photosLocalIdentifier: localIdentifier
            )
            return LoadedDiveMedia(
                payload: .image(data),
                capturedAt: capturedAt ?? asset.creationDate
            )
        case .video:
            let url = try await exportVideoToTemporaryFile(asset: asset)
            let capturedAt = await DiveMediaCaptureDateExtraction.resolveVideoCaptureDate(
                fileURL: url,
                photosLocalIdentifier: localIdentifier
            )
            return LoadedDiveMedia(
                payload: .video(url),
                capturedAt: capturedAt ?? asset.creationDate
            )
        default:
            throw LoadError.unsupportedMediaType
        }
    }

    @MainActor
    private static func requestImageData(for asset: PHAsset) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.version = .current

            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let data else {
                    continuation.resume(throwing: LoadError.missingImageData)
                    return
                }
                continuation.resume(returning: data)
            }
        }
    }

    @MainActor
    private static func exportVideoToTemporaryFile(asset: PHAsset) async throws -> URL {
        let resources = PHAssetResource.assetResources(for: asset)
        guard let videoResource = resources.first(where: { $0.type == .video || $0.type == .fullSizeVideo }) else {
            throw LoadError.missingVideoExport
        }
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        return try await withCheckedThrowingContinuation { continuation in
            PHAssetResourceManager.default().writeData(for: videoResource, toFile: destination, options: nil) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: destination)
                }
            }
        }
    }
    #else
    @MainActor
    static func load(from asset: Any) async throws -> LoadedDiveMedia {
        _ = asset
        throw LoadError.photosUnavailable
    }
    #endif
}
