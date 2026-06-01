import Contacts
import Foundation

/// Maps **`CNContact`** fields into buddy roster values.
enum DiveBuddyContactImport {

    static func displayName(from contact: CNContact) -> String {
        let composed = CNContactFormatter.string(from: contact, style: .fullName)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !composed.isEmpty {
            return String(composed.prefix(DiveBuddyCatalog.maxDisplayNameLength))
        }
        let given = contact.givenName.trimmingCharacters(in: .whitespacesAndNewlines)
        let family = contact.familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        let combined = [given, family].filter { !$0.isEmpty }.joined(separator: " ")
        if !combined.isEmpty {
            return String(combined.prefix(DiveBuddyCatalog.maxDisplayNameLength))
        }
        return "Buddy"
    }

    static func profilePhotoData(from contact: CNContact) -> Data? {
        if let thumbnail = contact.thumbnailImageData, !thumbnail.isEmpty {
            return thumbnail
        }
        if let full = contact.imageData, !full.isEmpty {
            return full
        }
        return nil
    }

    static func contactsIdentifier(from contact: CNContact) -> String {
        contact.identifier
    }

    /// Re-fetch image + name when the user refreshes from Contacts.
    static func refreshedValues(
        contactsIdentifier: String,
        contactStore: CNContactStore = CNContactStore()
    ) throws -> (displayName: String, profilePhoto: Data?)? {
        let keys: [CNKeyDescriptor] = [
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactThumbnailImageDataKey as CNKeyDescriptor,
            CNContactImageDataKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
        ]
        let contact = try contactStore.unifiedContact(
            withIdentifier: contactsIdentifier,
            keysToFetch: keys
        )
        return (displayName(from: contact), profilePhotoData(from: contact))
    }
}
