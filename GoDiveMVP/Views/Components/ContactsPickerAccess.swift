import Contacts
import Foundation

#if canImport(UIKit)
/// Requests Contacts authorization, then runs **`onAuthorized`** so the host can present **`ContactPickerView`**.
enum ContactsPickerAccess {
    /// System prompt only when status is **`.notDetermined`** (onboarding / first buddy link).
    @MainActor
    static func requestAccessIfNeeded() async {
        guard CNContactStore.authorizationStatus(for: .contacts) == .notDetermined else { return }
        let store = CNContactStore()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            store.requestAccess(for: .contacts) { _, _ in
                continuation.resume()
            }
        }
    }

    @MainActor
    static func presentIfAuthorized(
        onAuthorized: @escaping () -> Void,
        onError: @escaping (String) -> Void
    ) {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized, .limited:
            onAuthorized()
        case .notDetermined:
            Task { @MainActor in
                await requestAccessIfNeeded()
                if DiveBuddyContactsAuthorization.allowsContactMatching {
                    onAuthorized()
                } else {
                    onError("Allow Contacts access in Settings to pick a contact.")
                }
            }
        case .denied, .restricted:
            onError("Allow Contacts access in Settings to pick a contact.")
        @unknown default:
            onError("Contacts are not available.")
        }
    }
}
#endif
