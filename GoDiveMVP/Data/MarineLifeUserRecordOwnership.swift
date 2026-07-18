import Foundation
import SwiftData

/// Resolves and creates **`MarineLifeUserRecord`** rows for the signed-in profile.
enum MarineLifeUserRecordOwnership {

    static func userRecord(
        marineLifeUUID: String,
        ownerProfileID: UUID,
        in records: [MarineLifeUserRecord]
    ) -> MarineLifeUserRecord? {
        records.first {
            $0.marineLifeUUID == marineLifeUUID && $0.ownerProfileID == ownerProfileID
        }
    }

    /// Callable from background **`ModelContext`** / **`@ModelActor`** (e.g. dive delete cleanup).
    nonisolated static func userRecords(
        forOwnerProfileID ownerProfileID: UUID,
        modelContext: ModelContext
    ) throws -> [MarineLifeUserRecord] {
        let descriptor = FetchDescriptor<MarineLifeUserRecord>(
            predicate: #Predicate { $0.ownerProfileID == ownerProfileID }
        )
        return try modelContext.fetch(descriptor)
    }

    @discardableResult
    static func getOrCreate(
        marineLifeUUID: String,
        owner: UserProfile,
        modelContext: ModelContext
    ) throws -> MarineLifeUserRecord {
        let existing = try userRecords(forOwnerProfileID: owner.id, modelContext: modelContext)
        if let match = userRecord(marineLifeUUID: marineLifeUUID, ownerProfileID: owner.id, in: existing) {
            match.link(marineLifeUUID: marineLifeUUID, owner: owner)
            return match
        }

        let record = MarineLifeUserRecord()
        record.link(marineLifeUUID: marineLifeUUID, owner: owner)
        modelContext.insert(record)
        return record
    }

    @discardableResult
    static func getOrCreate(
        for marineLife: MarineLife,
        owner: UserProfile,
        modelContext: ModelContext
    ) throws -> MarineLifeUserRecord {
        try getOrCreate(marineLifeUUID: marineLife.uuid, owner: owner, modelContext: modelContext)
    }

    @discardableResult
    static func getOrCreate(
        for species: UserMarineLife,
        owner: UserProfile,
        modelContext: ModelContext
    ) throws -> MarineLifeUserRecord {
        try getOrCreate(marineLifeUUID: species.uuid, owner: owner, modelContext: modelContext)
    }
}
