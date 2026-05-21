import Foundation
import SwiftData

/// Photo or video attached to a dive (**`DiveActivity.mediaPhotos`**).
@Model
final class DiveMediaPhoto {

    var id: UUID
    /// Stable ordering within **`DiveActivity.mediaPhotos`** (lower first).
    var sortOrder: Int
    /// **`DiveMediaKind`** raw value (**`image`** / **`video`**).
    var mediaKind: String = DiveMediaKind.image.rawValue
    /// Image bytes when **`mediaKind`** is **`image`**; empty for video rows.
    @Attribute(originalName: "imageData")
    var mediaData: Data = Data()
    /// File name under **`DiveMediaFileStore`** when **`mediaKind`** is **`video`**.
    var mediaFileName: String = ""

    /// Denormalized for batch **`delete(model:where:)`**.
    var diveActivityID: UUID?

    @Relationship(inverse: \DiveActivity.mediaPhotos)
    var dive: DiveActivity?

    init(
        id: UUID = UUID(),
        sortOrder: Int = 0,
        mediaKind: DiveMediaKind = .image,
        mediaData: Data = Data(),
        mediaFileName: String = "",
        dive: DiveActivity? = nil
    ) {
        self.id = id
        self.sortOrder = sortOrder
        self.mediaKind = mediaKind.rawValue
        self.mediaData = mediaData
        self.mediaFileName = mediaFileName
        self.dive = dive
        self.diveActivityID = dive?.id
    }
}
