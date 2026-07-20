import Foundation
import os

/// Local, non-PII security-event log (OWASP Phase 5+).
///
/// - **OSLog:** subsystem **`PrimoSoftware.GoDiveMVP`**, category **`Security`** (Console.app).
/// - **SwiftData:** ring buffer on the **user** store (**`SecurityEventRecord`**) when a signed-in
///   profile id is available — private CloudKit mirrors across the user’s devices.
/// - **Developer share:** opt-in (**`AppUserSettings.shareSecurityEvents`**) → scrubbed public CloudKit.
enum GoDiveSecurityEvent: Sendable {

    enum Kind: String, Sendable, Equatable {
        case authSucceeded = "auth.success"
        case authFailed = "auth.fail"
        case signOut = "signOut"
        case accountDeleted = "accountDelete"
        case accountDeleteFailed = "accountDelete.fail"
        case importRejected = "import.reject"
        case cdnChecksumMismatch = "cdn.checksumFail"
        case cdnRefreshFailed = "cdn.refreshFail"
    }

    private nonisolated static let log = Logger(
        subsystem: "PrimoSoftware.GoDiveMVP",
        category: "Security"
    )

    /// Test hook — when non-`nil`, each record is appended (cleared by tests).
    nonisolated(unsafe) static var testRecorder: [(Kind, String?)]?

    /// - Parameter ownerProfileID: Optional override (e.g. sign-out before Keychain clear).
    /// - Parameter persistToJournal: When **`false`**, OSLog only (e.g. account wipe already cleared the journal).
    nonisolated static func record(
        _ kind: Kind,
        detail: String? = nil,
        ownerProfileID: UUID? = nil,
        persistToJournal: Bool = true
    ) {
        let safeDetail = sanitizedDetail(detail)
        testRecorder?.append((kind, safeDetail))
        if let safeDetail {
            log.notice(
                "security_event kind=\(kind.rawValue, privacy: .public) detail=\(safeDetail, privacy: .public)"
            )
        } else {
            log.notice("security_event kind=\(kind.rawValue, privacy: .public)")
        }
        guard persistToJournal else { return }
        GoDiveSecurityEventJournal.persistIfPossible(
            kind: kind,
            detail: safeDetail,
            ownerProfileID: ownerProfileID
        )
    }

    /// Stable line shape for unit tests (no Logger dependency).
    nonisolated static func formattedLine(kind: Kind, detail: String? = nil) -> String {
        if let detail = sanitizedDetail(detail) {
            return "security_event kind=\(kind.rawValue) detail=\(detail)"
        }
        return "security_event kind=\(kind.rawValue)"
    }

    /// Keeps event details short and scrubbed.
    nonisolated static func sanitizedDetail(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let scrubbed = CrashReportPayloadScrubber.scrub(trimmed)
        let capped = String(scrubbed.prefix(80))
        return capped.isEmpty ? nil : capped
    }
}
