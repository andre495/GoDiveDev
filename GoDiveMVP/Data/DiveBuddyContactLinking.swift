import Contacts
import Foundation
import SwiftData

/// Links an existing **`DiveBuddy`** roster row to a **`CNContact`**.
enum DiveBuddyContactLinking {

    enum LinkError: LocalizedError, Equatable {
        case missingOwner
        case nameMatchesSignedInDiver
        case contactsLinkedToOtherBuddy(displayName: String)

        var errorDescription: String? {
            switch self {
            case .missingOwner:
                return "Sign in to link a contact."
            case .nameMatchesSignedInDiver:
                return "That contact matches your profile name and cannot be added as a dive buddy."
            case .contactsLinkedToOtherBuddy(let displayName):
                return "That contact is already linked to \(displayName)."
            }
        }
    }

    static func apply(
        contact: CNContact,
        to buddy: DiveBuddy,
        owner: UserProfile?,
        modelContext: ModelContext
    ) throws {
        guard let owner else { throw LinkError.missingOwner }

        let name = DiveBuddyContactImport.displayName(from: contact)
        if DiveBuddyCatalog.shouldExcludeBuddyName(name, owner: owner) {
            throw LinkError.nameMatchesSignedInDiver
        }

        let identifier = DiveBuddyContactImport.contactsIdentifier(from: contact)
        if let existing = try DiveBuddyCatalog.findByContactsIdentifier(
            identifier,
            ownerProfileID: owner.id,
            modelContext: modelContext
        ),
           existing.id != buddy.id {
            throw LinkError.contactsLinkedToOtherBuddy(displayName: existing.displayName)
        }

        buddy.contactsIdentifier = identifier
        buddy.displayName = name
        if let photo = DiveBuddyContactImport.profilePhotoData(from: contact) {
            buddy.profilePhoto = photo
        }
    }

    static func refreshFromContacts(_ buddy: DiveBuddy) throws {
        guard let identifier = buddy.contactsIdentifier else { return }
        guard let refreshed = try DiveBuddyContactImport.refreshedValues(contactsIdentifier: identifier) else {
            return
        }
        buddy.displayName = refreshed.displayName
        if let photo = refreshed.profilePhoto {
            buddy.profilePhoto = photo
        }
    }

    static func disconnect(_ buddy: DiveBuddy) {
        buddy.contactsIdentifier = nil
    }
}
