import Foundation

extension DiveMediaPhoto {
    var resolvedMediaKind: DiveMediaKind {
        DiveMediaKind(rawValue: mediaKind) ?? .image
    }

    /// Playback URL when **`resolvedMediaKind`** is **`.video`**.
    var videoFileURL: URL? {
        guard resolvedMediaKind == .video else { return nil }
        return DiveMediaFileStore.fileURL(fileName: mediaFileName)
    }
}
