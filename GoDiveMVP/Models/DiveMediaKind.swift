import Foundation

/// Image vs video for **`DiveMediaPhoto`** rows (persisted as **`mediaKind`** string).
enum DiveMediaKind: String, Codable, Sendable {
    case image
    case video
}
