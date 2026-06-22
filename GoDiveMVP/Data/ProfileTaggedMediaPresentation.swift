import Foundation

/// Copy and counts for **Profile → My tagged media**.
enum ProfileTaggedMediaPresentation: Sendable {
    nonisolated static let sectionTitle = "My tagged media"
    nonisolated static let destinationTileTitle = "My tagged media"
    nonisolated static let emptyStateMessage =
        "Photos and videos you tag yourself on from dive media will appear here."

    nonisolated static func mediaCountLabel(_ count: Int) -> String {
        switch count {
        case 0:
            return "No tagged media"
        case 1:
            return "1 photo or video"
        default:
            return "\(count) photos and videos"
        }
    }

    nonisolated static func uniqueTaggedMediaCount(
        tags: [DiveMediaBuddyTag],
        buddyID: UUID,
        ownerDiveActivityIDs: Set<UUID>
    ) -> Int {
        Set(
            tags.compactMap { tag -> UUID? in
                guard tag.buddyID == buddyID,
                      let diveID = tag.diveActivityID,
                      ownerDiveActivityIDs.contains(diveID),
                      let mediaID = tag.mediaPhotoID
                else { return nil }
                return mediaID
            }
        ).count
    }
}
