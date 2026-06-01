import Foundation
import SwiftData

/// Join row tagging a **`DiveBuddy`** on a **`DiveActivity`**.
@Model
final class DiveBuddyTag {

    var id: UUID

    /// Denormalized for batch **`delete(model:where:)`**.
    var diveActivityID: UUID?

    /// Denormalized for batch deletes / predicates.
    var buddyID: UUID?

    @Relationship(inverse: \DiveActivity.buddies)
    var dive: DiveActivity?

    @Relationship(inverse: \DiveBuddy.diveParticipations)
    var buddy: DiveBuddy?

    /// Migrated from pre–**`DiveBuddy`** tags; cleared after **`DiveBuddyLegacyMigration`**.
    @Attribute(originalName: "displayName")
    var legacyDisplayName: String?

    init(id: UUID = UUID(), buddy: DiveBuddy, dive: DiveActivity? = nil) {
        self.id = id
        self.buddy = buddy
        self.buddyID = buddy.id
        self.diveActivityID = dive?.id
        self.dive = dive
    }

    /// Links this tag to a dive and updates **`diveActivityID`** for batch deletes.
    func link(to dive: DiveActivity) {
        DiveActivityChildRecordLinking.link(self, to: dive)
    }
}

extension DiveBuddyTag {

    /// Resolved label for summaries and legacy rows.
    var displayName: String {
        let fromBuddy = buddy?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !fromBuddy.isEmpty { return fromBuddy }
        let legacy = legacyDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !legacy.isEmpty { return legacy }
        return "Buddy"
    }
}
