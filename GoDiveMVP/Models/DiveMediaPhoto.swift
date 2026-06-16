import Foundation
import SwiftData

/// Pointer to a Photos-library asset attached to a dive (**`DiveActivity.mediaPhotos`**).
///
/// GoDive stores the **`PHAsset.localIdentifier`**, lightweight metadata, and a **low-res JPEG preview**
/// (**`previewJPEGData`**) for instant logbook / carousel / dive-hero placeholders. Full frames still load on demand
/// via **`DiveMediaReferenceLoader`**. If the user deletes the original from Photos, the row is pruned
/// (**`DiveMediaReferencePruning`**).
@Model
final class DiveMediaPhoto {

    var id: UUID
    /// Stable ordering within **`DiveActivity.mediaPhotos`** (lower first).
    var sortOrder: Int
    /// **`DiveMediaKind`** raw value (**`image`** / **`video`**).
    var mediaKind: String = DiveMediaKind.image.rawValue
    /// When the photo/video was captured (**`PHAsset.creationDate`**).
    var capturedAt: Date?
    /// **`PHAsset.localIdentifier`** of the referenced Photos asset.
    var photosLocalIdentifier: String = ""
    /// User-confirmed Fishial scientific name for this media item (empty when unset).
    var fishialConfirmedSpeciesName: String = ""
    /// Low-res JPEG poster for instant UI (**`DiveMediaPreviewPersistence`**); full asset still loads from Photos.
    var previewJPEGData: Data?

    /// Denormalized for batch **`delete(model:where:)`**.
    var diveActivityID: UUID?

    @Relationship(inverse: \DiveActivity.mediaPhotos)
    var dive: DiveActivity?

    init(
        id: UUID = UUID(),
        sortOrder: Int = 0,
        mediaKind: DiveMediaKind = .image,
        capturedAt: Date? = nil,
        photosLocalIdentifier: String = "",
        fishialConfirmedSpeciesName: String = "",
        previewJPEGData: Data? = nil,
        dive: DiveActivity? = nil
    ) {
        self.id = id
        self.sortOrder = sortOrder
        self.mediaKind = mediaKind.rawValue
        self.capturedAt = capturedAt
        self.photosLocalIdentifier = photosLocalIdentifier
        self.fishialConfirmedSpeciesName = fishialConfirmedSpeciesName
        self.previewJPEGData = previewJPEGData
        self.diveActivityID = dive?.id
        self.dive = dive
    }

    /// Links this media row to a dive and updates **`diveActivityID`** for batch deletes.
    func link(to dive: DiveActivity) {
        DiveActivityChildRecordLinking.link(self, to: dive)
    }
}
