import Foundation
import SwiftData

/// Links **`EquipmentItem`** rows to **`DiveActivity`** via **`DiveActivityEquipmentList`** / **`DiveEquipmentEntry`**.
@MainActor
enum DiveActivityEquipmentAssociation {

    // MARK: - Read

    static func isLinked(equipmentID: UUID, on dive: DiveActivity) -> Bool {
        dive.equipmentList?.entries.contains { $0.equipmentItemID == equipmentID } ?? false
    }

    static func equipmentItemIDs(on dive: DiveActivity) -> [UUID] {
        guard let entries = dive.equipmentList?.entries else { return [] }
        return entries.map(\.equipmentItemID)
    }

    /// Gear currently on this dive’s equipment list (owner-scoped, stable sort).
    static func linkedEquipment(
        on dive: DiveActivity,
        modelContext: ModelContext
    ) throws -> [EquipmentItem] {
        let linkedIDs = Set(equipmentItemIDs(on: dive))
        guard !linkedIDs.isEmpty, let ownerID = dive.ownerProfileID else { return [] }
        return try EquipmentItemOwnership.items(forOwnerProfileID: ownerID, modelContext: modelContext)
            .filter { linkedIDs.contains($0.id) }
            .sorted(by: equipmentSort)
    }

    /// Owner gear that is not **retired** and not already on this dive (picker list).
    static func addableEquipment(
        for dive: DiveActivity,
        ownerProfileID: UUID,
        modelContext: ModelContext
    ) throws -> [EquipmentItem] {
        let linkedIDs = Set(equipmentItemIDs(on: dive))
        return try EquipmentItemOwnership.items(forOwnerProfileID: ownerProfileID, modelContext: modelContext)
            .filter { !$0.isRetired && !linkedIDs.contains($0.id) }
            .sorted(by: equipmentSort)
    }

    /// Owner gear with **`autoAdd`** and not **`isRetired`**, stable sort for import / tests.
    static func autoAddCandidates(
        forOwnerProfileID ownerProfileID: UUID,
        modelContext: ModelContext
    ) throws -> [EquipmentItem] {
        try EquipmentItemOwnership.items(forOwnerProfileID: ownerProfileID, modelContext: modelContext)
            .filter { $0.autoAdd && !$0.isRetired }
            .sorted(by: equipmentSort)
    }

    private static func equipmentSort(_ lhs: EquipmentItem, _ rhs: EquipmentItem) -> Bool {
        let lm = lhs.manufacturer.localizedCaseInsensitiveCompare(rhs.manufacturer)
        if lm != .orderedSame { return lm == .orderedAscending }
        let lmod = lhs.model.localizedCaseInsensitiveCompare(rhs.model)
        if lmod != .orderedSame { return lmod == .orderedAscending }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    // MARK: - Write

    @discardableResult
    static func ensureEquipmentList(
        for dive: DiveActivity,
        modelContext: ModelContext
    ) -> DiveActivityEquipmentList {
        if let existing = dive.equipmentList {
            if existing.diveActivityID != dive.id {
                existing.diveActivityID = dive.id
            }
            return existing
        }
        let list = DiveActivityEquipmentList(diveActivityID: dive.id, dive: dive)
        dive.equipmentList = list
        modelContext.insert(list)
        return list
    }

    static func link(
        _ equipment: EquipmentItem,
        to dive: DiveActivity,
        modelContext: ModelContext
    ) throws {
        guard !isLinked(equipmentID: equipment.id, on: dive) else { return }

        let list = ensureEquipmentList(for: dive, modelContext: modelContext)
        let entry = DiveEquipmentEntry(
            equipmentItemID: equipment.id,
            diveActivityID: dive.id,
            equipment: equipment,
            equipmentList: list
        )
        list.entries.append(entry)
        modelContext.insert(entry)
    }

    static func unlink(
        equipmentID: UUID,
        from dive: DiveActivity,
        modelContext: ModelContext
    ) throws {
        guard let list = dive.equipmentList else { return }
        guard let entry = list.entries.first(where: { $0.equipmentItemID == equipmentID }) else { return }

        list.entries.removeAll { $0.id == entry.id }
        modelContext.delete(entry)
    }

    /// Attaches every **`autoAdd`** item for the dive owner (skips already linked).
    static func applyAutoAdd(
        to dive: DiveActivity,
        ownerProfileID: UUID,
        modelContext: ModelContext
    ) throws {
        let candidates = try autoAddCandidates(forOwnerProfileID: ownerProfileID, modelContext: modelContext)
        try applyAutoAdd(to: dive, candidates: candidates, modelContext: modelContext)
    }

    /// Batch import: reuse one **`autoAddCandidates`** fetch for every dive in the file.
    static func applyAutoAdd(
        to dive: DiveActivity,
        candidates: [EquipmentItem],
        modelContext: ModelContext
    ) throws {
        for item in candidates {
            try link(item, to: dive, modelContext: modelContext)
        }
    }

    /// Removes all list entries before deleting the equipment row.
    static func unlinkAll(
        from equipment: EquipmentItem,
        modelContext: ModelContext
    ) throws {
        let entries = equipment.diveEquipmentEntries
        for entry in entries {
            if let list = entry.equipmentList {
                list.entries.removeAll { $0.id == entry.id }
            }
            modelContext.delete(entry)
        }
    }
}
