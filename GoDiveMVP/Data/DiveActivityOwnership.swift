import Foundation
import SwiftData

/// Associates **`DiveActivity`** rows with the signed-in **`UserProfile`**.
enum DiveActivityOwnership {
    static func assignOwner(_ owner: UserProfile, to activity: DiveActivity) {
        activity.owner = owner
        activity.ownerProfileID = owner.id
        for tag in activity.buddies {
            guard let buddy = tag.buddy, buddy.ownerProfileID == nil else { continue }
            DiveBuddyOwnership.assignOwner(owner, to: buddy)
        }
    }

    static func activities(forOwnerProfileID ownerProfileID: UUID, modelContext: ModelContext) throws -> [DiveActivity] {
        let all = try modelContext.fetch(FetchDescriptor<DiveActivity>())
        return all.filter { $0.ownerProfileID == ownerProfileID }
    }

    /// Claims dives imported before accounts existed for this profile.
    static func claimUnownedDives(for owner: UserProfile, modelContext: ModelContext) throws {
        let descriptor = FetchDescriptor<DiveActivity>()
        let all = try modelContext.fetch(descriptor)
        var changed = false
        for activity in all where activity.ownerProfileID == nil {
            assignOwner(owner, to: activity)
            changed = true
        }
        if changed {
            try modelContext.save()
        }
    }
}
