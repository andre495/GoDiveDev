import Foundation
import SwiftData

// MARK: - SecurityEventRecord

/// Coarse security / diagnostic event for the signed-in diver (OWASP Phase 5+).
/// Lives in the **user** store so private CloudKit can mirror the journal across the user’s devices.
/// Opt-in developer upload uses public CloudKit (**`SecurityEventCloudUploader`**), not SwiftData mirroring.
@Model
final class SecurityEventRecord {

    var id: UUID = UUID()
    var capturedAt: Date = Date()
    /// **`GoDiveSecurityEvent.Kind`** raw value (e.g. `auth.success`).
    var kindRaw: String = ""
    /// Short non-PII token; empty when none.
    var detail: String = ""
    var appVersion: String = ""
    var osVersion: String = ""
    /// Owning **`UserProfile.id`** — required for multi-profile devices + CloudKit restore scoping.
    var ownerProfileID: UUID?
    /// When uploaded to the developer’s public CloudKit database; `nil` = not shared.
    var sharedToCloudAt: Date?

    init(
        id: UUID = UUID(),
        capturedAt: Date = .now,
        kindRaw: String,
        detail: String = "",
        appVersion: String,
        osVersion: String,
        ownerProfileID: UUID? = nil,
        sharedToCloudAt: Date? = nil
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.kindRaw = kindRaw
        self.detail = detail
        self.appVersion = appVersion
        self.osVersion = osVersion
        self.ownerProfileID = ownerProfileID
        self.sharedToCloudAt = sharedToCloudAt
    }
}

extension SecurityEventRecord {
    var snapshot: SecurityEvent {
        SecurityEvent(
            id: id,
            capturedAt: capturedAt,
            kindRaw: kindRaw,
            detail: detail.isEmpty ? nil : detail,
            appVersion: appVersion,
            osVersion: osVersion,
            ownerProfileID: ownerProfileID,
            sharedToCloudAt: sharedToCloudAt
        )
    }

    convenience init(_ event: SecurityEvent) {
        self.init(
            id: event.id,
            capturedAt: event.capturedAt,
            kindRaw: event.kindRaw,
            detail: event.detail ?? "",
            appVersion: event.appVersion,
            osVersion: event.osVersion,
            ownerProfileID: event.ownerProfileID,
            sharedToCloudAt: event.sharedToCloudAt
        )
    }
}
