import Foundation
import SwiftData

@Model
final class SnorkelMediaPhoto {

    var id: UUID = UUID()
    var sortOrder: Int = 0
    var mediaKind: String = DiveMediaKind.image.rawValue
    var capturedAt: Date?
    var photosLocalIdentifier: String = ""
    var photosCloudIdentifier: String = ""
    var fishialConfirmedSpeciesName: String = ""
    /// Low-res JPEG poster for instant UI (**`DiveMediaPreviewPersistence`**); full asset still loads from Photos.
    var previewJPEGData: Data?

    /// Denormalized for batch **`delete(model:where:)`**.
    var snorkelActivityID: UUID?

    @Relationship(inverse: \SnorkelActivity.mediaPhotosStorage)
    var snorkelActivity: SnorkelActivity?

    @Relationship
    var mediaBuddyTagsStorage: [DiveMediaBuddyTag]? = []
    @Transient
    var mediaBuddyTags: [DiveMediaBuddyTag] {
        get { mediaBuddyTagsStorage ?? [] }
        set { mediaBuddyTagsStorage = newValue }
    }

    @Relationship
    var marineLifeSightingsStorage: [SightingInstance]? = []
    @Transient
    var marineLifeSightings: [SightingInstance] {
        get { marineLifeSightingsStorage ?? [] }
        set { marineLifeSightingsStorage = newValue }
    }

    init(
        id: UUID = UUID(),
        sortOrder: Int = 0,
        mediaKind: DiveMediaKind = .image,
        capturedAt: Date? = nil,
        photosLocalIdentifier: String = "",
        photosCloudIdentifier: String = "",
        fishialConfirmedSpeciesName: String = "",
        previewJPEGData: Data? = nil,
        snorkelActivity: SnorkelActivity? = nil
    ) {
        self.id = id
        self.sortOrder = sortOrder
        self.mediaKind = mediaKind.rawValue
        self.capturedAt = capturedAt
        self.photosLocalIdentifier = photosLocalIdentifier
        self.photosCloudIdentifier = photosCloudIdentifier
        self.fishialConfirmedSpeciesName = fishialConfirmedSpeciesName
        self.previewJPEGData = previewJPEGData
        self.snorkelActivityID = snorkelActivity?.id
        self.snorkelActivity = snorkelActivity
    }
}
