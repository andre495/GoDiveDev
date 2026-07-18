import Foundation
import SwiftData

/// Reusable label the signed-in user can apply to one or more dives.
@Model
final class ActivityTag {

    var id: UUID = UUID()
    /// Display label (trimmed; casing preserved from creation).
    var name: String = ""
    /// Lowercased, collapsed key for deduping per owner (**`ActivityTagStore.normalizedName(from:)`**).
    var normalizedName: String = ""

    var ownerProfileID: UUID?

    @Relationship(inverse: \DiveActivity.activityTagsStorage)
    var divesStorage: [DiveActivity]? = []
    @Transient
    var dives: [DiveActivity] {
        get { divesStorage ?? [] }
        set { divesStorage = newValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        normalizedName: String,
        ownerProfileID: UUID?
    ) {
        self.id = id
        self.name = name
        self.normalizedName = normalizedName
        self.ownerProfileID = ownerProfileID
    }
}
