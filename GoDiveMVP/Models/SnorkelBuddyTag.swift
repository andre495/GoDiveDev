import Foundation
import SwiftData

@Model
final class SnorkelBuddyTag {

    var id: UUID = UUID()
    var snorkelActivityID: UUID?
    var buddyID: UUID?

    @Relationship(inverse: \SnorkelActivity.buddiesStorage)
    var snorkelActivity: SnorkelActivity?

    @Relationship(inverse: \DiveBuddy.snorkelParticipationsStorage)
    var buddy: DiveBuddy?

    var legacyDisplayName: String?

    init(id: UUID = UUID(), buddy: DiveBuddy, snorkelActivity: SnorkelActivity? = nil) {
        self.id = id
        self.buddy = buddy
        self.buddyID = buddy.id
        self.snorkelActivityID = snorkelActivity?.id
        self.snorkelActivity = snorkelActivity
    }

    var displayName: String {
        let fromBuddy = buddy?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !fromBuddy.isEmpty { return fromBuddy }
        let legacy = legacyDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !legacy.isEmpty { return legacy }
        return "Buddy"
    }

    func link(to activity: SnorkelActivity) {
        snorkelActivityID = activity.id
        snorkelActivity = activity
    }
}
