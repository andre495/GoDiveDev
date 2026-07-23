import Foundation

#if canImport(Contacts)
import Contacts
#endif

/// Resolves SMS recipients from a linked **`CNContact`** on a **`DiveBuddy`**.
enum DiveBuddyContactSMSPresentation: Sendable {
    nonisolated static func smsRecipients(contactsIdentifier: String?) -> [String] {
        guard let contactsIdentifier else { return [] }
        guard let phone = primaryPhoneNumber(contactsIdentifier: contactsIdentifier) else { return [] }
        return [phone]
    }

    nonisolated static func primaryPhoneNumber(contactsIdentifier: String) -> String? {
        #if canImport(Contacts)
        let store = CNContactStore()
        let keys: [CNKeyDescriptor] = [CNContactPhoneNumbersKey as CNKeyDescriptor]
        guard let contact = try? store.unifiedContact(
            withIdentifier: contactsIdentifier,
            keysToFetch: keys
        ) else {
            return nil
        }
        let numbers = contact.phoneNumbers
        if let mobile = numbers.first(where: { $0.label == CNLabelPhoneNumberMobile }) {
            return sanitizedPhone(mobile.value.stringValue)
        }
        if let iPhone = numbers.first(where: { $0.label == CNLabelPhoneNumberiPhone }) {
            return sanitizedPhone(iPhone.value.stringValue)
        }
        if let first = numbers.first {
            return sanitizedPhone(first.value.stringValue)
        }
        return nil
        #else
        return nil
        #endif
    }

    private nonisolated static func sanitizedPhone(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let digits = trimmed.filter { $0.isNumber || $0 == "+" }
        return digits.isEmpty ? nil : digits
    }
}
