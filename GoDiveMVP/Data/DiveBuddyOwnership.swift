import Foundation
import SwiftData

/// Associates **`DiveBuddy`** rows with the signed-in **`UserProfile`**.
enum DiveBuddyOwnership {
    static func assignOwner(_ owner: UserProfile, to buddy: DiveBuddy) {
        buddy.owner = owner
        buddy.ownerProfileID = owner.id
    }

    static func buddies(forOwnerProfileID ownerProfileID: UUID, modelContext: ModelContext) throws -> [DiveBuddy] {
        let all = try modelContext.fetch(FetchDescriptor<DiveBuddy>())
        return all.filter { $0.ownerProfileID == ownerProfileID }
    }

    /// Claims buddies created on import before sign-in (same pattern as dives).
    static func claimUnownedBuddies(for owner: UserProfile, modelContext: ModelContext) throws {
        let all = try modelContext.fetch(FetchDescriptor<DiveBuddy>())
        var changed = false
        for buddy in all where buddy.ownerProfileID == nil {
            assignOwner(owner, to: buddy)
            changed = true
        }
        if changed {
            try modelContext.save()
        }
    }
}
