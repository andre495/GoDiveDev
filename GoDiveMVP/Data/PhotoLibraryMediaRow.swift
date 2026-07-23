import Foundation

/// SwiftData media row backed by a Photos library asset (dive or snorkel).
protocol PhotoLibraryMediaRow: ActivityOverviewGalleryMedia {
    var photosCloudIdentifier: String { get }
    var photosLocalIdentifier: String { get set }
    var previewJPEGData: Data? { get set }
}

extension DiveMediaPhoto: PhotoLibraryMediaRow {}
extension SnorkelMediaPhoto: PhotoLibraryMediaRow {}
