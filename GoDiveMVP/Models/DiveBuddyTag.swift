import Foundation
import SwiftData

/// Buddy tagged on a dive (imported optionally or added in-app).
@Model
final class DiveBuddyTag {

    var id: UUID
    var displayName: String

    @Relationship(inverse: \DiveActivity.buddies)
    var dive: DiveActivity?

    init(id: UUID = UUID(), displayName: String, dive: DiveActivity? = nil) {
        self.id = id
        self.displayName = displayName
        self.dive = dive
    }
}
