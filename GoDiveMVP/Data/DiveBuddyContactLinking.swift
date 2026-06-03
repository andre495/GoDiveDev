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
        try applyResolvedContact(
            contactsIdentifier: DiveBuddyContactImport.contactsIdentifier(from: contact),
            displayName: DiveBuddyContactImport.displayName(from: contact),
            profilePhoto: DiveBuddyContactImport.profilePhotoData(from: contact),
            to: buddy,
            owner: owner,
            modelContext: modelContext
        )
    }

    static func applyIdentifier(
        _ contactsIdentifier: String,
        to buddy: DiveBuddy,
        owner: UserProfile?,
        modelContext: ModelContext,
        contactStore: CNContactStore = CNContactStore()
    ) throws {
        #if canImport(Contacts)
        guard let contact = try fetchContact(contactsIdentifier: contactsIdentifier, store: contactStore) else {
            return
        }
        try apply(contact: contact, to: buddy, owner: owner, modelContext: modelContext)
        #endif
    }

    private static func applyResolvedContact(
        contactsIdentifier: String,
        displayName: String,
        profilePhoto: Data?,
        to buddy: DiveBuddy,
        owner: UserProfile?,
        modelContext: ModelContext
    ) throws {
        guard let owner else { throw LinkError.missingOwner }

        if DiveBuddyCatalog.shouldExcludeBuddyName(displayName, owner: owner) {
            throw LinkError.nameMatchesSignedInDiver
        }

        if let existing = try DiveBuddyCatalog.findByContactsIdentifier(
            contactsIdentifier,
            ownerProfileID: owner.id,
            modelContext: modelContext
        ),
           existing.id != buddy.id {
            throw LinkError.contactsLinkedToOtherBuddy(displayName: existing.displayName)
        }

        buddy.contactsIdentifier = contactsIdentifier
        buddy.displayName = displayName
        if let photo = profilePhoto, !photo.isEmpty {
            buddy.profilePhoto = photo
        }
    }

    #if canImport(Contacts)
    private static func fetchContact(
        contactsIdentifier: String,
        store: CNContactStore
    ) throws -> CNContact? {
        let keys: [CNKeyDescriptor] = [
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactThumbnailImageDataKey as CNKeyDescriptor,
            CNContactImageDataKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
        ]
        return try store.unifiedContact(withIdentifier: contactsIdentifier, keysToFetch: keys)
    }
    #endif

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
