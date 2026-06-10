import Foundation

/// Resolves offline bundled marine life hero JPEGs shipped under **`Resources/MarineLifePhotos/`**.
enum FieldGuideMarineLifeBundledImagePresentation: Sendable {

    nonisolated static let bundlePhotoSubdirectories = [
        "Resources/MarineLifePhotos",
        "MarineLifePhotos",
    ]

    /// Where catalog UI should load a species photo from (bundled first, then remote URL).
    enum ImageSource: Equatable, Sendable {
        case bundledFile(URL)
        case remote(URL)
        case none
    }

    nonisolated static func imageSource(
        featureImageResourceName: String,
        featureImageURL: String,
        bundle: Bundle = .main
    ) -> ImageSource {
        let resourceName = featureImageResourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !resourceName.isEmpty, let url = bundledPhotoURL(resourceName: resourceName, bundle: bundle) {
            return .bundledFile(url)
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
