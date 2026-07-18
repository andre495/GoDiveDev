import Foundation
import SwiftData

/// Gear linked to a single dive (**`DiveActivity.equipmentList`**). One list per dive.
@Model
final class DiveActivityEquipmentList {

    var id: UUID = UUID()

    /// Denormalized for **`#Predicate`**; kept in sync with **`dive`**.
    var diveActivityID: UUID?

    @Relationship(inverse: \DiveActivity.equipmentList)
    var dive: DiveActivity?

    @Relationship(deleteRule: .cascade)
    var entriesStorage: [DiveEquipmentEntry]? = []
    @Transient
    var entries: [DiveEquipmentEntry] {
        get { entriesStorage ?? [] }
        set { entriesStorage = newValue }
    }

    init(
        id: UUID = UUID(),
        diveActivityID: UUID? = nil,
        dive: DiveActivity? = nil
    ) {
        self.id = id
        self.diveActivityID = diveActivityID
        self.dive = dive
    }
}
