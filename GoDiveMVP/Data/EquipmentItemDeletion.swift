import Foundation
import SwiftData

/// Removes an **`EquipmentItem`** from the store.
enum EquipmentItemDeletion {
    @MainActor
    static func deletePermanently(_ item: EquipmentItem, modelContext: ModelContext) throws {
        let equipmentID = item.id
        try DiveActivityEquipmentAssociation.unlinkAll(from: item, modelContext: modelContext)
        modelContext.delete(item)
        try modelContext.save()
        Task { @MainActor in
            await EquipmentServiceReminderScheduler.cancel(equipmentID: equipmentID)
        }
    }
}
