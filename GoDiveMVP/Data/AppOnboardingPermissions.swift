import Foundation

/// Contacts + Photos prompts for brand-new accounts (Sign in with Apple first-time profile).
enum AppOnboardingPermissions {

    /// Requests each permission only while still **`.notDetermined`**; no-op under UI tests.
    @MainActor
    static func requestForNewAccount() async {
        guard !GoDiveUITestConfiguration.isActive else { return }

        #if canImport(UIKit)
        await ContactsPickerAccess.requestAccessIfNeeded()
        #endif

        _ = await DiveLibraryMediaAutoAttach.requestPhotoLibraryReadAccess()
    }
}
