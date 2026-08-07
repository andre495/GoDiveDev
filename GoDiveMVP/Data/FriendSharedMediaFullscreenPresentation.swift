import CoreGraphics
import Foundation

/// Fullscreen friend-shared media — mirrors **`LinkedMediaFullscreenPresentation`** / buddy tagged-media playback.
enum FriendSharedMediaFullscreenPresentation: Sendable {

    nonisolated static let rootAccessibilityIdentifier = "FriendSharedMedia.Fullscreen.Root"
    nonisolated static let closeAccessibilityIdentifier = "FriendSharedMedia.Fullscreen.Close"
    nonisolated static let openActivityAccessibilityIdentifier = "FriendSharedMedia.Fullscreen.OpenActivity"
    nonisolated static let marineLifeAccessibilityIdentifier = "FriendSharedMedia.Fullscreen.MarineLifeTag"
    nonisolated static let buddyAccessibilityIdentifier = "FriendSharedMedia.Fullscreen.BuddyTag"
    nonisolated static let playbackToggleAccessibilityIdentifier = "FriendSharedMedia.Fullscreen.PlaybackToggle"
    nonisolated static let tagOverviewAccessibilityIdentifier = "FriendSharedMedia.Fullscreen.TagOverview"
    nonisolated static let accessibilityContextLabel = "Friend shared"

    nonisolated static func diveNumberLabel(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> String {
        FriendSharedActivityDetailPresentation.diveNumberChip(for: dive) ?? "-"
    }

    nonisolated static func siteDisplayName(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> String {
        FriendSharedActivityDetailPresentation.siteHeaderTitle(for: dive)
    }

    nonisolated static func selectedItem(
        selectedID: String?,
        in items: [FriendSharedMediaPresentation.DisplayItem]
    ) -> FriendSharedMediaPresentation.DisplayItem? {
        if let selectedID,
           let match = items.first(where: { $0.mediaID == selectedID }) {
            return match
        }
        return items.first
    }

    nonisolated static func adjacentMediaID(
        selectedID: String?,
        in items: [FriendSharedMediaPresentation.DisplayItem],
        offset: Int
    ) -> String? {
        guard offset != 0,
              let selected = selectedItem(selectedID: selectedID, in: items),
              let index = items.firstIndex(where: { $0.mediaID == selected.mediaID })
        else { return nil }
        let nextIndex = index + offset
        guard items.indices.contains(nextIndex) else { return nil }
        return items[nextIndex].mediaID
    }

    /// Same format as **`TripDetailMediaGalleryPresentation.mediaPositionLabel`** (`"1 of N"`).
    nonisolated static func mediaPositionLabel(
        selectedID: String?,
        in items: [FriendSharedMediaPresentation.DisplayItem]
    ) -> String? {
        guard let selected = selectedItem(selectedID: selectedID, in: items),
              let index = items.firstIndex(where: { $0.mediaID == selected.mediaID }),
              !items.isEmpty
        else { return nil }
        return "\(index + 1) of \(items.count)"
    }

    nonisolated static func diveNumberLabel(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive?
    ) -> String {
        guard let dive else { return "-" }
        return diveNumberLabel(for: dive)
    }
}
