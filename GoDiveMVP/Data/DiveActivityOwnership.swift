import Foundation
import SwiftData

/// Associates **`DiveActivity`** rows with the signed-in **`UserProfile`**.
enum DiveActivityOwnership {
    nonisolated static func assignOwner(_ owner: UserProfile, to activity: DiveActivity) {
        activity.owner = owner
        activity.ownerProfileID = owner.id
        for tag in activity.buddies {
            guard let buddy = tag.buddy, buddy.ownerProfileID == nil else { continue }
            DiveBuddyOwnership.assignOwner(owner, to: buddy)
        }
    }

    static func activities(forOwnerProfileID ownerProfileID: UUID, modelContext: ModelContext) throws -> [DiveActivity] {
        let ownerID = ownerProfileID
        return try modelContext.fetch(
            FetchDescriptor<DiveActivity>(
                predicate: #Predicate<DiveActivity> { $0.ownerProfileID == ownerID }
            )
        )
    }

    /// Claims dives imported before accounts existed for this profile.
    /// Skips when another profile already owns dives/buddies on this device (shared-device safe).
    @discardableResult
    nonisolated static func claimUnownedDives(
        for owner: UserProfile,
        modelContext: ModelContext,
        force: Bool = false
    ) throws -> Int {
        if !force {
            guard try DiveUnownedClaimGate.allowsClaim(ownerID: owner.id, modelContext: modelContext) else {
                return 0
            }
        }
        let orphans = try modelContext.fetch(FetchDescriptor<DiveActivity>())
            .filter { $0.ownerProfileID == nil }
        guard !orphans.isEmpty else { return 0 }
        for activity in orphans {
            assignOwner(owner, to: activity)
        }
        try modelContext.save()
        return orphans.count
    }
}
