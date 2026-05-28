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

    static func userRecords(
        forOwnerProfileID ownerProfileID: UUID,
        modelContext: ModelContext
    ) throws -> [MarineLifeUserRecord] {
        let all = try modelContext.fetch(FetchDescriptor<MarineLifeUserRecord>())
        return all.filter { $0.ownerProfileID == ownerProfileID }
    }

    @discardableResult
    static func getOrCreate(
        for marineLife: MarineLife,
        owner: UserProfile,
        modelContext: ModelContext
    ) throws -> MarineLifeUserRecord {
        let existing = try userRecords(forOwnerProfileID: owner.id, modelContext: modelContext)
        if let match = userRecord(marineLifeUUID: marineLife.uuid, ownerProfileID: owner.id, in: existing) {
            if match.marineLife == nil {
                match.link(to: marineLife, owner: owner)
            }
            return match
        }

        let record = MarineLifeUserRecord()
        record.link(to: marineLife, owner: owner)
        modelContext.insert(record)
        return record
    }
}
