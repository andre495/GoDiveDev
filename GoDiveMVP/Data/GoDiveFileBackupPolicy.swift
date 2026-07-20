import Foundation

/// Backup exclusion + documented Data Protection stance (OWASP Phase 4).
enum GoDiveFileBackupPolicy: Sendable {

    /// Crash / CloudKit open dumps under Application Support — exclude from device backups.
    nonisolated static func excludeFromBackup(_ url: URL) {
        var mutable = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? mutable.setResourceValues(values)
    }

    /// Marks the path when it exists (no-op if missing).
    nonisolated static func excludeFromBackupIfExists(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        excludeFromBackup(url)
    }

    /// Marks a SQLite store and its `-shm` / `-wal` sidecars when present.
    nonisolated static func excludeStoreFamilyFromBackup(baseStoreURL: URL) {
        for suffix in ["", "-shm", "-wal"] {
            excludeFromBackupIfExists(URL(fileURLWithPath: baseStoreURL.path + suffix))
        }
    }
}

/// Confirmed Data Protection posture for on-device SwiftData (OWASP Phase 4).
///
/// App container files under Application Support inherit the system default
/// (**Complete Until First User Authentication**). GoDive does **not** lower protection
/// (no `NSFileProtectionNone`). User dive log also syncs via private CloudKit when enabled.
enum GoDiveDataProtectionPolicy: Sendable {
    nonisolated static let documentedContainerClass =
        "NSFileProtectionCompleteUntilFirstUserAuthentication (iOS Application Support default)"

    /// Diagnostics store holds crash rows — keep out of iCloud/computer backups.
    nonisolated static let diagnosticsStoreExcludedFromBackup = true
}
