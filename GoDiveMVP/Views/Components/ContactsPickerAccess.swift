import Contacts
import Foundation

#if canImport(UIKit)
/// Requests Contacts authorization, then runs **`onAuthorized`** so the host can present **`ContactPickerView`**.
enum ContactsPickerAccess {
    @MainActor
    static func presentIfAuthorized(
        onAuthorized: @escaping () -> Void,
        onError: @escaping (String) -> Void
    ) {
        let store = CNContactStore()
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized, .limited:
            onAuthorized()
        case .notDetermined:
            store.requestAccess(for: .contacts) { granted, error in
                Task { @MainActor in
                    if let error {
                        onError(error.localizedDescription)
                        return
                    }
                    if granted {
                        onAuthorized()
                    } else {
                        onError("Allow Contacts access in Settings to pick a contact.")
                    }
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
