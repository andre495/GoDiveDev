import Foundation

/// Flattens friend-shared activity media for the friend-profile media page.
enum FriendProfileSharedMediaListPresentation: Sendable {
    nonisolated static let gridAccessibilityIdentifier = "FriendProfile.SharedMedia.Grid"
    nonisolated static let emptyAccessibilityIdentifier = "FriendProfile.SharedMedia.Empty"
    nonisolated static let sectionAccessibilityIdentifier = "FriendProfile.SharedMedia"

    nonisolated static func displayItems(
        from dives: [GoDiveSharedDiveProjectionMapping.FriendVisibleDive]
    ) -> [FriendSharedMediaPresentation.DisplayItem] {
        let orderedDives = dives.sorted { lhs, rhs in
            let left = lhs.startTime ?? lhs.sharedAt ?? .distantPast
            let right = rhs.startTime ?? rhs.sharedAt ?? .distantPast
            if left != right { return left > right }
            return lhs.id > rhs.id
        }
        var seen = Set<String>()
        var items: [FriendSharedMediaPresentation.DisplayItem] = []
        for dive in orderedDives {
            for item in FriendSharedMediaPresentation.orderedDisplayItems(for: dive) {
                guard seen.insert(item.mediaID).inserted else { continue }
                guard item.thumbnailURL != nil || item.contentURL != nil else { continue }
                items.append(item)
            }
        }
        return items
    }

    /// First owning activity for each media id (newest dive wins when ids collide).
    nonisolated static func diveByMediaID(
        from dives: [GoDiveSharedDiveProjectionMapping.FriendVisibleDive]
    ) -> [String: GoDiveSharedDiveProjectionMapping.FriendVisibleDive] {
        let orderedDives = dives.sorted { lhs, rhs in
            let left = lhs.startTime ?? lhs.sharedAt ?? .distantPast
            let right = rhs.startTime ?? rhs.sharedAt ?? .distantPast
            if left != right { return left > right }
            return lhs.id > rhs.id
        }
        var map: [String: GoDiveSharedDiveProjectionMapping.FriendVisibleDive] = [:]
        for dive in orderedDives {
            for item in FriendSharedMediaPresentation.orderedDisplayItems(for: dive) {
                if !map.keys.contains(item.mediaID) {
                    map[item.mediaID] = dive
                }
            }
        }
        return map
    }
}
