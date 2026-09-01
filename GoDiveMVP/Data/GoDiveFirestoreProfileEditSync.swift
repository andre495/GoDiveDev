import Foundation

/// Gating for Profile → Firebase social-directory edits (name / avatar).
enum GoDiveFirestoreProfileEditSync: Sendable {
    /// Skip while the first signup Firestore write is still waiting on the photo wizard.
    /// After the wizard dismisses, name/avatar edits must sync even if the defer gate is stuck.
    nonisolated static func shouldSyncEdits(
        isDeferredUntilPhotoStep: Bool,
        isPostSignUpSetupVisible: Bool
    ) -> Bool {
        !(isDeferredUntilPhotoStep && isPostSignUpSetupVisible)
    }
}
