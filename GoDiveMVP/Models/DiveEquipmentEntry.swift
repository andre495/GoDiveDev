import Foundation
import SwiftData

/// One **`EquipmentItem`** on a dive's equipment list.
@Model
final class DiveEquipmentEntry {

    var id: UUID

    /// Denormalized for lookups; kept in sync with **`equipment`**.
    var equipmentItemID: UUID
    /// Denormalized for lookups; kept in sync with **`equipmentList.dive`**.
    var diveActivityID: UUID

    @Relationship(inverse: \DiveActivityEquipmentList.entries)
    var equipmentList: DiveActivityEquipmentList?

    @Relationship(inverse: \EquipmentItem.diveEquipmentEntries)
    var equipment: EquipmentItem?

    init(
        id: UUID = UUID(),
        equipmentItemID: UUID,
        diveActivityID: UUID,
        equipment: EquipmentItem? = nil,
        equipmentList: DiveActivityEquipmentList? = nil
    ) {
        self.id = id
        self.equipmentItemID = equipmentItemID
        self.diveActivityID = diveActivityID
        self.equipment = equipment
        self.equipmentList = equipmentList
    }
}
