import Foundation

/// Cold-launch session restore policy — keep **`AppLaunchOverlay`** only while the session profile is unresolved.
enum AccountSessionLaunchRestorePresentation: Sendable {
    /// Whether cold restore should poll CloudKit for a profile (up to launch timeout).
    ///
    /// - Already owns activities → no wait (ownership-aware attach is enough).
    /// - Store already has activities → no wait (heal local ownership; do not sit on splash).
    /// - Preferred profile row exists and store is empty → no wait (new / empty account).
    /// - Preferred row missing → wait (reinstall / fresh store expecting CloudKit profile).
    nonisolated static func waitForCloudKitImportOnColdRestore(
        localOwnedActivityCount: Int,
        localPreferredProfileExists: Bool,
        storeActivityCount: Int
    ) -> Bool {
        if localOwnedActivityCount > 0 { return false }
        if storeActivityCount > 0 { return false }
        return !localPreferredProfileExists
    }

    /// Backward-compatible helper used by older tests — prefer the three-argument API.
    nonisolated static func waitForCloudKitImportOnColdRestore(
        localPreferredProfileExists: Bool
    ) -> Bool {
        waitForCloudKitImportOnColdRestore(
            localOwnedActivityCount: 0,
            localPreferredProfileExists: localPreferredProfileExists,
            storeActivityCount: 0
        )
    }
}
