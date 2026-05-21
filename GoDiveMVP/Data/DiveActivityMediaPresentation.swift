import Foundation

/// Copy and ordering rules for dive **Media** tab items (testable without SwiftUI).
enum DiveActivityMediaPresentation: Sendable {

    nonisolated static let emptyStateMessage = "No media added"

    /// Background gallery is hidden when the overview sheet is **large** (sheet-only chrome).
    nonisolated static func showsBackgroundPhotos(for detent: DiveActivityOverviewDetent) -> Bool {
        detent != .large
    }

    nonisolated static func sortedMedia(on activity: DiveActivity) -> [DiveMediaPhoto] {
        sortedPhotos(on: activity)
    }

    nonisolated static func sortedPhotos(on activity: DiveActivity) -> [DiveMediaPhoto] {
        activity.mediaPhotos.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    nonisolated static func hasDisplayableMedia(on activity: DiveActivity) -> Bool {
        !sortedPhotos(on: activity).isEmpty
    }

    nonisolated static func mediaCountLabel(photoCount: Int) -> String {
        switch photoCount {
        case 0:
            return emptyStateMessage
        case 1:
            return "1 item"
        default:
            return "\(photoCount) items"
        }
    }

    nonisolated static func nextSortOrder(on activity: DiveActivity) -> Int {
        let orders = activity.mediaPhotos.map(\.sortOrder)
        return (orders.max() ?? -1) + 1
    }

    /// Keeps pager selection valid when the photo list changes.
    nonisolated static func resolvedSelectedPhotoID(
        selectedID: UUID?,
        in photos: [DiveMediaPhoto]
    ) -> UUID? {
        guard !photos.isEmpty else { return nil }
        if let selectedID, photos.contains(where: { $0.id == selectedID }) {
            return selectedID
        }
        return photos.first?.id
    }
}
