import Foundation
import SwiftData

/// Shared-device-safe gate for adopting orphan (`ownerProfileID == nil`) dives/snorkels/buddies.
enum DiveUnownedClaimGate: Sendable {
    enum Decision: Equatable, Sendable {
        /// No orphan rows — callers may no-op.
        case nothingToClaim
        /// Safe: no other profile already owns dives or buddies on this device.
        case claim
        /// Another profile owns user rows — do not assign orphans to the newly signed-in account.
        case skipOtherOwnersPresent

        nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case (.nothingToClaim, .nothingToClaim), (.claim, .claim), (.skipOtherOwnersPresent, .skipOtherOwnersPresent):
                return true
            default:
                return false
            }
        }
    }

    /// Evaluates whether unowned rows may be claimed for `ownerID`.
    nonisolated static func decision(
        ownerID: UUID,
        diveOwnerIDs: [UUID?],
        snorkelOwnerIDs: [UUID?],
        buddyOwnerIDs: [UUID?]
    ) -> Decision {
        let hasUnownedDive = diveOwnerIDs.contains { $0 == nil }
        let hasUnownedSnorkel = snorkelOwnerIDs.contains { $0 == nil }
        let hasUnownedBuddy = buddyOwnerIDs.contains { $0 == nil }
        guard hasUnownedDive || hasUnownedSnorkel || hasUnownedBuddy else { return .nothingToClaim }

        let otherOwnsDive = diveOwnerIDs.contains { id in
            guard let id else { return false }
            return id != ownerID
        }
        let otherOwnsSnorkel = snorkelOwnerIDs.contains { id in
            guard let id else { return false }
            return id != ownerID
        }
        let otherOwnsBuddy = buddyOwnerIDs.contains { id in
            guard let id else { return false }
            return id != ownerID
        }
        if otherOwnsDive || otherOwnsSnorkel || otherOwnsBuddy {
            return .skipOtherOwnersPresent
        }
        return .claim
    }

    /// Count-only evaluation — avoids materializing every dive/snorkel/buddy on launch.
    nonisolated static func decision(ownerID: UUID, modelContext: ModelContext) throws -> Decision {
        let unownedDiveCount = try modelContext.fetchCount(
            FetchDescriptor<DiveActivity>(predicate: #Predicate { $0.ownerProfileID == nil })
        )
        let unownedSnorkelCount = try modelContext.fetchCount(
            FetchDescriptor<SnorkelActivity>(predicate: #Predicate { $0.ownerProfileID == nil })
        )
        let unownedBuddyCount = try modelContext.fetchCount(
            FetchDescriptor<DiveBuddy>(predicate: #Predicate { $0.ownerProfileID == nil })
        )
        guard unownedDiveCount + unownedSnorkelCount + unownedBuddyCount > 0 else {
            return .nothingToClaim
        }

        let otherDiveCount = try modelContext.fetchCount(
            FetchDescriptor<DiveActivity>(
                predicate: #Predicate { dive in
                    dive.ownerProfileID != nil && dive.ownerProfileID != ownerID
                }
            )
        )
        let otherSnorkelCount = try modelContext.fetchCount(
            FetchDescriptor<SnorkelActivity>(
                predicate: #Predicate { snorkel in
                    snorkel.ownerProfileID != nil && snorkel.ownerProfileID != ownerID
                }
            )
        )
        let otherBuddyCount = try modelContext.fetchCount(
            FetchDescriptor<DiveBuddy>(
                predicate: #Predicate { buddy in
                    buddy.ownerProfileID != nil && buddy.ownerProfileID != ownerID
                }
            )
        )
        if otherDiveCount + otherSnorkelCount + otherBuddyCount > 0 {
            return .skipOtherOwnersPresent
        }
        return .claim
    }

    /// `true` only for **`.claim`** (not when there is nothing to claim).
    nonisolated static func allowsClaim(ownerID: UUID, modelContext: ModelContext) throws -> Bool {
        try decision(ownerID: ownerID, modelContext: modelContext) == .claim
    }
}
