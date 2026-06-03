import Foundation
#if canImport(Contacts)
import Contacts
#endif

/// Contacts permission gate for roster auto-link (no UIKit).
enum DiveBuddyContactsAuthorization: Sendable {
    /// **`true`** when the user granted full or limited Contacts access.
    nonisolated static var allowsContactMatching: Bool {
        #if canImport(Contacts)
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized, .limited:
            return true
        default:
            return false
        }
        #else
        return false
        #endif
    }
}
