import Foundation
import SwiftData

/// Shared-device-safe gate for adopting orphan (`ownerProfileID == nil`) dives/buddies.
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
        buddyOwnerIDs: [UUID?]
    ) -> Decision {
        let hasUnownedDive = diveOwnerIDs.contains { $0 == nil }
        let hasUnownedBuddy = buddyOwnerIDs.contains { $0 == nil }
        guard hasUnownedDive || hasUnownedBuddy else { return .nothingToClaim }

        let otherOwnsDive = diveOwnerIDs.contains { id in
            guard let id else { return false }
            return id != ownerID
        }
        let otherOwnsBuddy = buddyOwnerIDs.contains { id in
            guard let id else { return false }
            return id != ownerID
        }
        if otherOwnsDive || otherOwnsBuddy {
            return .skipOtherOwnersPresent
        }
        return .claim
    }

    nonisolated static func decision(ownerID: UUID, modelContext: ModelContext) throws -> Decision {
        let dives = try modelContext.fetch(FetchDescriptor<DiveActivity>())
        let buddies = try modelContext.fetch(FetchDescriptor<DiveBuddy>())
        return decision(
            ownerID: ownerID,
            diveOwnerIDs: dives.map(\.ownerProfileID),
            buddyOwnerIDs: buddies.map(\.ownerProfileID)
        )
    }

    /// `true` only for **`.claim`** (not when there is nothing to claim).
    nonisolated static func allowsClaim(ownerID: UUID, modelContext: ModelContext) throws -> Bool {
        try decision(ownerID: ownerID, modelContext: modelContext) == .claim
    }
}
