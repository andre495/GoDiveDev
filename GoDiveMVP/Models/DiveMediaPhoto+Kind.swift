import Foundation

/// Where a dive video's frames come from. All dive media is currently a Photos-library reference; the **`.file`**
/// case is kept for a self-contained playback URL should a non-Photos source be added later.
enum DiveVideoSource: Equatable, Sendable {
    case file(URL)
    /// Pointer to a Photos asset (**`PHAsset.localIdentifier`**) loaded via PhotoKit.
    case libraryAsset(String)

    /// Stable key for **`.task(id:)`** / player-change detection.
    var identityKey: String {
        switch self {
        case .file(let url): return "file:\(url.absoluteString)"
        case .libraryAsset(let id): return "asset:\(id)"
        }
    }

    /// **`true`** for a Photos-library pointer (vs. a self-contained file URL).
    var isLibraryAsset: Bool {
        switch self {
        case .file: return false
        case .libraryAsset: return true
        }
    }
}

extension DiveMediaPhoto {
    var resolvedMediaKind: DiveMediaKind {
        DiveMediaKind(rawValue: mediaKind) ?? .image
    }

    /// Trimmed **`PHAsset.localIdentifier`**, or **`nil`** when blank.
    var libraryAssetLocalIdentifier: String? {
        let trimmed = photosLocalIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Video playback source: the referenced Photos asset.
    var videoPlaybackSource: DiveVideoSource? {
        guard resolvedMediaKind == .video, let identifier = libraryAssetLocalIdentifier else { return nil }
        return .libraryAsset(identifier)
    }
}
