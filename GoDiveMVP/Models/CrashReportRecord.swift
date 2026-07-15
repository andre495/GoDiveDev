import Foundation
import SwiftData

// MARK: - CrashReportRecord

/// Locally captured crash / abnormal-exit diagnostic (see `CrashReportingService`).
/// Not owned by a `UserProfile` — crashes are device-level and captured before sign-in resolves.
@Model
final class CrashReportRecord {

    var id: UUID
    var capturedAt: Date
    /// `CrashReport.Kind` raw value (**`metricKitCrash`** / **`abnormalExit`**).
    var kindRaw: String
    /// Human-readable one-liner (signal / exception / heuristic explanation).
    var reason: String
    var appVersion: String
    var osVersion: String
    /// Full diagnostic body — MetricKit call-stack JSON or heuristic session details.
    var details: String
    /// When the report was uploaded to the developer's CloudKit database; `nil` = not shared.
    var sharedToCloudAt: Date?

    init(
        id: UUID = UUID(),
        capturedAt: Date = .now,
        kindRaw: String,
        reason: String,
        appVersion: String,
        osVersion: String,
        details: String,
        sharedToCloudAt: Date? = nil
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.kindRaw = kindRaw
        self.reason = reason
        self.appVersion = appVersion
        self.osVersion = osVersion
        self.details = details
        self.sharedToCloudAt = sharedToCloudAt
    }
}

extension CrashReportRecord {
    /// Sendable snapshot for off-main capture, upload, and presentation.
    var snapshot: CrashReport {
        CrashReport(
            id: id,
            capturedAt: capturedAt,
            kind: CrashReport.Kind(rawValue: kindRaw) ?? .metricKitCrash,
            reason: reason,
            appVersion: appVersion,
            osVersion: osVersion,
            details: details,
            sharedToCloudAt: sharedToCloudAt
        )
    }

    convenience init(_ report: CrashReport) {
        self.init(
            id: report.id,
            capturedAt: report.capturedAt,
            kindRaw: report.kind.rawValue,
            reason: report.reason,
            appVersion: report.appVersion,
            osVersion: report.osVersion,
            details: report.details,
            sharedToCloudAt: report.sharedToCloudAt
        )
    }
}
