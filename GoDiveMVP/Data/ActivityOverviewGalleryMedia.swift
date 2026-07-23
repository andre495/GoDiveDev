import Foundation

/// Shared surface for dive and snorkel gallery media (carousel, hero, tagging).
protocol ActivityOverviewGalleryMedia {
    var id: UUID { get }
    var capturedAt: Date? { get }
    var sortOrder: Int { get }
    var previewJPEGData: Data? { get }
    var fishialConfirmedSpeciesName: String { get }
    var photosLocalIdentifier: String { get }
    var mediaKind: String { get }
}

extension ActivityOverviewGalleryMedia {
    var resolvedMediaKind: DiveMediaKind {
        DiveMediaKind(rawValue: mediaKind) ?? .image
    }

    var libraryAssetLocalIdentifier: String? {
        let trimmed = photosLocalIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var resolvedFishialConfirmedSpeciesName: String? {
        let trimmed = fishialConfirmedSpeciesName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var resolvedFishialConfirmedSpeciesNames: [String] {
        guard let stored = resolvedFishialConfirmedSpeciesName else { return [] }
        return FishialConfirmedSpeciesPresentation.parsedScientificNames(from: stored)
    }

    var videoPlaybackSource: DiveVideoSource? {
        guard resolvedMediaKind == .video, let identifier = libraryAssetLocalIdentifier else { return nil }
        return .libraryAsset(identifier)
    }
}

extension DiveMediaPhoto: ActivityOverviewGalleryMedia {}
extension SnorkelMediaPhoto: ActivityOverviewGalleryMedia {}
