import Foundation

/// Gating for Profile → Firebase social-directory edits (name / avatar).
enum GoDiveFirestoreProfileEditSync: Sendable {
    /// Skip while the first signup Firestore write is still waiting on the photo step.
    nonisolated static func shouldSyncEdits(isDeferredUntilPhotoStep: Bool) -> Bool {
        !isDeferredUntilPhotoStep
    }
}
