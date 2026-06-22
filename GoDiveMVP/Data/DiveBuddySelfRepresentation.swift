import Foundation
import SwiftData

/// Roster buddy row representing the signed-in diver (for explicit self-tagging on media).
enum DiveBuddySelfRepresentation {
    nonisolated static let pickerRowTitle = "You"

    nonisolated static func resolvedDisplayName(for owner: UserProfile) -> String {
        let trimmed = owner.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? pickerRowTitle : trimmed
    }

    nonisolated static func isSelfBuddy(_ buddy: DiveBuddy, owner: UserProfile?) -> Bool {
        guard let owner else { return false }
        return DiveBuddyNameMatching.isLikelyDiverSelf(
            buddyName: buddy.displayName,
            diverDisplayName: owner.displayName
        )
    }

    /// Existing roster row for the signed-in diver, if any.
    static func existingSelfBuddy(
        owner: UserProfile,
        modelContext: ModelContext
    ) throws -> DiveBuddy? {
        if let fuzzy = try DiveBuddyCatalog.findFuzzyMatch(
            displayName: resolvedDisplayName(for: owner),
            ownerProfileID: owner.id,
            modelContext: modelContext
        ),
           isSelfBuddy(fuzzy, owner: owner) {
            return fuzzy
        }
        if let exact = try DiveBuddyCatalog.findByNormalizedName(
            resolvedDisplayName(for: owner),
            ownerProfileID: owner.id,
            modelContext: modelContext
        ),
           isSelfBuddy(exact, owner: owner) {
            return exact
        }
        return nil
    }

    /// Finds or creates the roster buddy used when the diver tags themself on media.
    @discardableResult
    static func findOrCreateSelfBuddy(
        owner: UserProfile,
        modelContext: ModelContext
    ) throws -> DiveBuddy {
        if let existing = try existingSelfBuddy(owner: owner, modelContext: modelContext) {
            syncProfilePhoto(from: owner, to: existing)
            return existing
        }

        let buddy = DiveBuddy(
            displayName: resolvedDisplayName(for: owner),
            profilePhoto: owner.profilePhoto,
            owner: owner
        )
        modelContext.insert(buddy)
        DiveBuddyOwnership.assignOwner(owner, to: buddy)
        return buddy
    }

    private static func syncProfilePhoto(from owner: UserProfile, to buddy: DiveBuddy) {
        guard let photo = owner.profilePhoto, !photo.isEmpty else { return }
        buddy.profilePhoto = photo
    }
}
