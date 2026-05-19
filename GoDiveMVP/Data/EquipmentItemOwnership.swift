import Foundation
import SwiftData

/// Associates **`EquipmentItem`** rows with the signed-in **`UserProfile`**.
enum EquipmentItemOwnership {
    static func assignOwner(_ owner: UserProfile, to item: EquipmentItem) {
        item.owner = owner
        item.ownerProfileID = owner.id
    }

    static func items(forOwnerProfileID ownerProfileID: UUID, modelContext: ModelContext) throws -> [EquipmentItem] {
        let all = try modelContext.fetch(FetchDescriptor<EquipmentItem>())
        return all.filter { $0.ownerProfileID == ownerProfileID }
    }
}
