import Foundation
import SwiftData

enum SnorkelActivityOwnership {
    nonisolated static func assignOwner(_ owner: UserProfile, to activity: SnorkelActivity) {
        activity.owner = owner
        activity.ownerProfileID = owner.id
        for tag in activity.buddies {
            guard let buddy = tag.buddy, buddy.ownerProfileID == nil else { continue }
            DiveBuddyOwnership.assignOwner(owner, to: buddy)
        }
    }

    static func activities(forOwnerProfileID ownerProfileID: UUID, modelContext: ModelContext) throws -> [SnorkelActivity] {
        let ownerID = ownerProfileID
        return try modelContext.fetch(
            FetchDescriptor<SnorkelActivity>(
                predicate: #Predicate<SnorkelActivity> { $0.ownerProfileID == ownerID }
            )
        )
    }

    /// Claims snorkel sessions imported before accounts existed for this profile.
    /// Skips when another profile already owns dives/snorkels/buddies on this device (shared-device safe).
    @discardableResult
    nonisolated static func claimUnownedSnorkels(
        for owner: UserProfile,
        modelContext: ModelContext,
        force: Bool = false
    ) throws -> Int {
        if !force {
            guard try DiveUnownedClaimGate.allowsClaim(ownerID: owner.id, modelContext: modelContext) else {
                return 0
            }
        }
        let orphans = try modelContext.fetch(FetchDescriptor<SnorkelActivity>())
            .filter { $0.ownerProfileID == nil }
        guard !orphans.isEmpty else { return 0 }
        for activity in orphans {
            assignOwner(owner, to: activity)
        }
        try modelContext.save()
        return orphans.count
    }
}
