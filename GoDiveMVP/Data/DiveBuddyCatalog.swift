import Foundation
import SwiftData

/// Find-or-create **`DiveBuddy`** rows for the signed-in diver.
enum DiveBuddyCatalog {
    static let maxDisplayNameLength = 80

    static func findOrCreate(
        displayName: String,
        contactsIdentifier: String? = nil,
        profilePhoto: Data? = nil,
        owner: UserProfile?,
        modelContext: ModelContext
    ) -> DiveBuddy {
        let trimmedName = String(displayName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxDisplayNameLength))
        let resolvedName = trimmedName.isEmpty ? "Buddy" : trimmedName

        if let contactsIdentifier,
           let ownerProfileID = owner?.id,
           let existing = try? findByContactsIdentifier(
               contactsIdentifier,
               ownerProfileID: ownerProfileID,
               modelContext: modelContext
           ) {
            applyProfilePhotoIfNeeded(profilePhoto, to: existing)
            if existing.displayName != resolvedName {
                existing.displayName = resolvedName
            }
            return existing
        }

        if let ownerProfileID = owner?.id,
           let existing = try? findByNormalizedName(
               resolvedName,
               ownerProfileID: ownerProfileID,
               modelContext: modelContext
           ),
           contactsIdentifier == nil || existing.contactsIdentifier == nil || existing.contactsIdentifier == contactsIdentifier
        {
            if let contactsIdentifier {
                existing.contactsIdentifier = contactsIdentifier
            }
            applyProfilePhotoIfNeeded(profilePhoto, to: existing)
            return existing
        }

        let buddy = DiveBuddy(
            displayName: resolvedName,
            profilePhoto: profilePhoto,
            contactsIdentifier: contactsIdentifier,
            owner: owner
        )
        modelContext.insert(buddy)
        if let owner {
            DiveBuddyOwnership.assignOwner(owner, to: buddy)
        }
        return buddy
    }

    static func findByContactsIdentifier(
        _ contactsIdentifier: String,
        ownerProfileID: UUID,
        modelContext: ModelContext
    ) throws -> DiveBuddy? {
        let all = try modelContext.fetch(FetchDescriptor<DiveBuddy>())
        return all.first {
            $0.ownerProfileID == ownerProfileID && $0.contactsIdentifier == contactsIdentifier
        }
    }

    static func findByNormalizedName(
        _ displayName: String,
        ownerProfileID: UUID,
        modelContext: ModelContext
    ) throws -> DiveBuddy? {
        let key = normalizedNameKey(displayName)
        let all = try modelContext.fetch(FetchDescriptor<DiveBuddy>())
        return all.first {
            $0.ownerProfileID == ownerProfileID && normalizedNameKey($0.displayName) == key
        }
    }

    nonisolated static func normalizedNameKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func applyProfilePhotoIfNeeded(_ data: Data?, to buddy: DiveBuddy) {
        guard let data, !data.isEmpty else { return }
        buddy.profilePhoto = data
    }
}
