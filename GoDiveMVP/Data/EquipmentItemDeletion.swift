import Foundation
import SwiftData

/// Removes an **`EquipmentItem`** from the store.
enum EquipmentItemDeletion {
    @MainActor
    static func deletePermanently(_ item: EquipmentItem, modelContext: ModelContext) throws {
        modelContext.delete(item)
        try modelContext.save()
    }
}
