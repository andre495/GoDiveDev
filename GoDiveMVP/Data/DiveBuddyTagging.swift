import Foundation
import SwiftData

/// Builds **`DiveBuddyTag`** rows (person + link) for import and fixtures.
enum DiveBuddyTagging {

    static func makeTag(
        displayName: String,
        tagID: UUID = UUID(),
        dive: DiveActivity,
        owner: UserProfile?,
        modelContext: ModelContext
    ) -> DiveBuddyTag? {
        guard !DiveBuddyCatalog.shouldExcludeBuddyName(displayName, owner: owner) else { return nil }
        let buddy = DiveBuddyCatalog.findOrCreate(
            displayName: displayName,
            owner: owner,
            modelContext: modelContext
        )
        let tag = DiveBuddyTag(id: tagID, buddy: buddy, dive: dive)
        modelContext.insert(tag)
        tag.link(to: dive)
        buddy.diveParticipations.append(tag)
        return tag
    }
}
