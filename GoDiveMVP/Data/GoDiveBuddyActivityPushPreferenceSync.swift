import Foundation
import os
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Mirrors the **Buddy activity notifications** toggle to Firestore
/// `users/{uid}/private/notificationPrefs` so `notifyBuddyActivityShared`
/// can filter recipients server-side. Soft-fails when Firebase is unavailable.
enum GoDiveBuddyActivityPushPreferenceSync: Sendable {
    nonisolated private static let log = Logger(
        subsystem: "PrimoSoftware.GoDiveMVP",
        category: "BuddyActivityPushPrefs"
    )

    @MainActor
    static func uploadCurrentPreference(userDefaults: UserDefaults = .standard) async {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }

        let enabled = AppUserSettings.notifyBuddyActivityShares(userDefaults: userDefaults)
        let ref = Firestore.firestore()
            .collection("users")
            .document(uid)
            .collection("private")
            .document(GoDiveBuddyActivityPushPresentation.notificationPrefsDocumentID)
        do {
            try await ref.setData(
                [GoDiveBuddyActivityPushPresentation.buddyActivitySharesEnabledField: enabled],
                merge: true
            )
        } catch {
            log.error("Buddy activity push pref upload failed: \(String(describing: error), privacy: .private)")
        }
        #endif
    }

    /// Pulls the server value into local defaults (e.g. on Settings open) so a
    /// toggle flipped on another device is reflected here.
    @MainActor
    static func pullPreferenceIntoDefaults(userDefaults: UserDefaults = .standard) async {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard GoDiveFirebaseBootstrap.isConfigured else { return }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }

        let ref = Firestore.firestore()
            .collection("users")
            .document(uid)
            .collection("private")
            .document(GoDiveBuddyActivityPushPresentation.notificationPrefsDocumentID)
        guard let snapshot = try? await ref.getDocument(), snapshot.exists else { return }
        guard let enabled = snapshot.data()?[
            GoDiveBuddyActivityPushPresentation.buddyActivitySharesEnabledField
        ] as? Bool else { return }
        userDefaults.set(enabled, forKey: AppUserSettings.notifyBuddyActivitySharesKey)
        #endif
    }
}
