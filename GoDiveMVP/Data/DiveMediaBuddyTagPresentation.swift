import Foundation

/// Rows for buddies already tagged on a dive media item.
enum DiveMediaBuddyTagPresentation {

    struct TaggedBuddyRow: Identifiable, Equatable, Sendable {
        var id: UUID { buddyID }
        let buddyID: UUID
        let displayName: String
        let profilePhoto: Data?
    }

    nonisolated static func taggedRows(
        mediaPhotoID: UUID,
        tags: [DiveMediaBuddyTag]
    ) -> [TaggedBuddyRow] {
        var seenBuddyIDs = Set<UUID>()

        return tags
            .filter { $0.mediaPhotoID == mediaPhotoID }
            .compactMap { tag -> TaggedBuddyRow? in
                guard let buddyID = tag.buddyID, !seenBuddyIDs.contains(buddyID) else { return nil }
                seenBuddyIDs.insert(buddyID)
                return TaggedBuddyRow(
                    buddyID: buddyID,
                    displayName: tag.buddy?.displayName ?? "Buddy",
                    profilePhoto: tag.buddy?.profilePhoto
                )
            }
            .sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
    }

    nonisolated static func hasTaggedBuddiesOnMedia(
        mediaPhotoID: UUID,
        tags: [DiveMediaBuddyTag]
    ) -> Bool {
        tags.contains { $0.mediaPhotoID == mediaPhotoID }
    }

    nonisolated static func taggedBuddyIDs(
        mediaPhotoID: UUID,
        tags: [DiveMediaBuddyTag]
    ) -> Set<UUID> {
        Set(
            tags.compactMap { tag in
                guard tag.mediaPhotoID == mediaPhotoID else { return nil }
                return tag.buddyID
            }
        )
    }

    nonisolated static func resolvedTaggedBuddies(
        mediaPhotoID: UUID,
        tags: [DiveMediaBuddyTag]
    ) -> [DiveBuddy] {
        var seenBuddyIDs = Set<UUID>()

        return tags
            .filter { $0.mediaPhotoID == mediaPhotoID }
            .compactMap { tag -> DiveBuddy? in
                guard let buddy = tag.buddy, let buddyID = tag.buddyID else { return nil }
                guard !seenBuddyIDs.contains(buddyID) else { return nil }
                seenBuddyIDs.insert(buddyID)
                return buddy
            }
            .sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
    }
}
