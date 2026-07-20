import Foundation
import SwiftData

/// Associates **`DiveBuddy`** rows with the signed-in **`UserProfile`**.
enum DiveBuddyOwnership {
    nonisolated static func assignOwner(_ owner: UserProfile, to buddy: DiveBuddy) {
        buddy.owner = owner
        buddy.ownerProfileID = owner.id
    }

    static func buddies(forOwnerProfileID ownerProfileID: UUID, modelContext: ModelContext) throws -> [DiveBuddy] {
        let ownerID = ownerProfileID
        return try modelContext.fetch(
            FetchDescriptor<DiveBuddy>(
                predicate: #Predicate<DiveBuddy> { $0.ownerProfileID == ownerID }
            )
        )
    }

    /// Claims buddies created on import before sign-in (same pattern as dives).
    /// Skips when another profile already owns dives/buddies on this device (shared-device safe).
    @discardableResult
    nonisolated static func claimUnownedBuddies(
        for owner: UserProfile,
        modelContext: ModelContext,
        force: Bool = false
    ) throws -> Int {
        if !force {
            guard try DiveUnownedClaimGate.allowsClaim(ownerID: owner.id, modelContext: modelContext) else {
                return 0
            }
        }
        let orphans = try modelContext.fetch(FetchDescriptor<DiveBuddy>())
            .filter { $0.ownerProfileID == nil }
        guard !orphans.isEmpty else { return 0 }
        for buddy in orphans {
            assignOwner(owner, to: buddy)
        }
        try modelContext.save()
        return orphans.count
    }
}
