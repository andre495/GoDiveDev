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
}
