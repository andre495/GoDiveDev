import Foundation
import SwiftData

/// Creates **`DiveBuddy`** roster rows without tagging a dive.
enum DiveBuddyRosterCreation {
    @discardableResult
    static func addBuddy(
        displayName: String,
        profilePhoto: Data? = nil,
        contactsIdentifier: String? = nil,
        owner: UserProfile?,
        modelContext: ModelContext
    ) -> DiveBuddy? {
        guard !DiveBuddyCatalog.shouldExcludeBuddyName(displayName, owner: owner) else { return nil }
        return DiveBuddyCatalog.findOrCreate(
            displayName: displayName,
            contactsIdentifier: contactsIdentifier,
            profilePhoto: profilePhoto,
            owner: owner,
            modelContext: modelContext
        )
    }
}
