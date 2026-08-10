import Foundation
import SwiftData
import SwiftUI

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

    nonisolated static func mediaTagIDsFingerprint(_ tags: [DiveMediaBuddyTag]) -> String {
        tags.map(\.id.uuidString).sorted().joined(separator: ",")
    }
}

/// Scoped **`@Query`** for the self-buddy media tags — keeps Profile off the unscoped tag table.
struct ProfileSelfBuddyMediaTagsObserver: View {
    @Query private var tags: [DiveMediaBuddyTag]
    let onTagsChange: ([DiveMediaBuddyTag]) -> Void

    init(buddyID: UUID, onTagsChange: @escaping ([DiveMediaBuddyTag]) -> Void) {
        self.onTagsChange = onTagsChange
        _tags = Query(
            filter: #Predicate<DiveMediaBuddyTag> { $0.buddyID == buddyID },
            sort: [SortDescriptor(\.id, order: .forward)]
        )
    }

    private var tagIDsFingerprint: String {
        ProfileTaggedMediaPresentation.mediaTagIDsFingerprint(Array(tags))
    }

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onAppear { onTagsChange(Array(tags)) }
            .onChange(of: tagIDsFingerprint) { _, _ in
                onTagsChange(Array(tags))
            }
    }
}
