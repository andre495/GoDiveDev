import Foundation

/// Gates the first Firestore social-profile write until post-sign-up photo step finishes (new accounts).
enum GoDiveFirestoreProfilePublishGate: Sendable {
    nonisolated static let deferredUpsertDefaultsKey = "godive.firebase.deferSocialProfileUpsert"

    nonisolated static func markDeferredUntilPhotoStep(userDefaults: UserDefaults = .standard) {
        userDefaults.set(true, forKey: deferredUpsertDefaultsKey)
    }

    nonisolated static func clear(userDefaults: UserDefaults = .standard) {
        userDefaults.removeObject(forKey: deferredUpsertDefaultsKey)
    }

    nonisolated static func isDeferredUntilPhotoStep(userDefaults: UserDefaults = .standard) -> Bool {
        userDefaults.bool(forKey: deferredUpsertDefaultsKey)
    }

    /// Defer only while the post-sign-up photo wizard is still on screen.
    /// After the wizard finishes, retry even if the first upsert never cleared the gate
    /// (e.g. avatar Storage upload failed and aborted the directory write).
    nonisolated static func shouldDeferDirectoryUpsert(
        isPostSignUpSetupVisible: Bool,
        userDefaults: UserDefaults = .standard
    ) -> Bool {
        isDeferredUntilPhotoStep(userDefaults: userDefaults) && isPostSignUpSetupVisible
    }
}
