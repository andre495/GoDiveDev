import Foundation

/// Resolves offline bundled marine life hero JPEGs shipped under **`Resources/MarineLifePhotos/`**.
enum FieldGuideMarineLifeBundledImagePresentation: Sendable {

    nonisolated static let bundlePhotoSubdirectories = [
        "Resources/MarineLifePhotos",
        "MarineLifePhotos",
    ]

    /// Where catalog UI should load a species photo from (bundled first, then disk CDN cache, then remote URL).
    enum ImageSource: Equatable, Sendable {
        case bundledFile(URL)
        case cachedFile(URL)
        case remote(URL)
        case none
    }

    nonisolated static func imageSource(
        featureImageResourceName: String,
        featureImageURL: String,
        bundle: Bundle = .main,
        fileManager: FileManager = .default
    ) -> ImageSource {
        let resourceName = featureImageResourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !resourceName.isEmpty, let url = bundledPhotoURL(resourceName: resourceName, bundle: bundle) {
            return .bundledFile(url)
        }
        if !resourceName.isEmpty,
           let cached = CatalogAssetDiskCache.cachedFileURL(
               kind: .photo,
               resourceName: resourceName,
               fileManager: fileManager
           )
        {
            return .cachedFile(cached)
        }

        let remoteString = featureImageURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: remoteString), !remoteString.isEmpty {
            return .remote(url)
        }

        return .none
    }

    nonisolated static func bundledPhotoURL(
        resourceName: String,
        bundle: Bundle = .main
    ) -> URL? {
        let trimmed = resourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        for subdirectory in bundlePhotoSubdirectories {
            if let url = bundle.url(
                forResource: trimmed,
                withExtension: "jpg",
                subdirectory: subdirectory
            ) {
                return url
            }
        }
        if let url = bundle.url(forResource: trimmed, withExtension: "jpg") {
            return url
        }
        return nil
    }
}

extension FieldGuideMarineLifeBundledImagePresentation.ImageSource {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case let (.bundledFile(left), .bundledFile(right)):
            return left == right
        case let (.cachedFile(left), .cachedFile(right)):
            return left == right
        case let (.remote(left), .remote(right)):
            return left == right
        default:
            return false
        }
    }
}
