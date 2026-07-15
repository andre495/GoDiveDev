import Foundation
import SwiftData

/// One captured crash / abnormal-exit record — a Sendable snapshot of `CrashReportRecord`.
/// `nonisolated` — built on MetricKit's background queue and detached tasks.
nonisolated struct CrashReport: Identifiable, Equatable, Sendable {
    nonisolated enum Kind: String, Sendable {
        /// MetricKit `MXCrashDiagnostic` delivered by the system (usually on the next launch).
        case metricKitCrash
        /// Previous session ended while foregrounded without a clean background transition.
        case abnormalExit
    }

    var id: UUID
    var capturedAt: Date
    var kind: Kind
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
        capturedAt: Date = Date(),
        kind: Kind,
        reason: String,
        appVersion: String,
        osVersion: String,
        details: String,
        sharedToCloudAt: Date? = nil
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.kind = kind
        self.reason = reason
        self.appVersion = appVersion
        self.osVersion = osVersion
        self.details = details
        self.sharedToCloudAt = sharedToCloudAt
    }
}

nonisolated enum CrashReportPresentation: Sendable {
    nonisolated static func kindLabel(_ kind: CrashReport.Kind) -> String {
        switch kind {
        case .metricKitCrash: "Crash"
        case .abnormalExit: "Abnormal exit"
        }
    }

    /// List-row status caption for the CloudKit share state.
    nonisolated static func sharedStatusLabel(sharedToCloudAt: Date?) -> String {
        sharedToCloudAt == nil ? "Not sent to developer" : "Sent to developer"
    }

    /// BSD signal number → name for crash summaries (unknown numbers fall back to `signal N`).
    nonisolated static func signalName(_ signal: Int?) -> String? {
        guard let signal else { return nil }
        let names: [Int: String] = [
            1: "SIGHUP", 2: "SIGINT", 3: "SIGQUIT", 4: "SIGILL", 5: "SIGTRAP",
            6: "SIGABRT", 8: "SIGFPE", 9: "SIGKILL", 10: "SIGBUS", 11: "SIGSEGV",
            12: "SIGSYS", 13: "SIGPIPE",
        ]
        return names[signal] ?? "signal \(signal)"
    }

    /// Mach exception type → name (unknown numbers fall back to `exception N`).
    nonisolated static func machExceptionName(_ exceptionType: Int?) -> String? {
        guard let exceptionType else { return nil }
        let names: [Int: String] = [
            1: "EXC_BAD_ACCESS", 2: "EXC_BAD_INSTRUCTION", 3: "EXC_ARITHMETIC",
            5: "EXC_SOFTWARE", 6: "EXC_BREAKPOINT", 10: "EXC_CRASH",
            11: "EXC_RESOURCE", 12: "EXC_GUARD",
        ]
        return names[exceptionType] ?? "exception \(exceptionType)"
    }

    /// Reason line for a MetricKit crash from its numeric fields + optional termination reason.
    nonisolated static func metricKitReasonLine(
        exceptionType: Int?,
        signal: Int?,
        terminationReason: String?
    ) -> String {
        var parts: [String] = []
        if let name = machExceptionName(exceptionType) { parts.append(name) }
        if let name = signalName(signal) { parts.append(name) }
        if let terminationReason, !terminationReason.isEmpty { parts.append(terminationReason) }
        return parts.isEmpty ? "Crash (no diagnostic detail)" : parts.joined(separator: " · ")
    }

    /// Shareable plain-text body for one report.
    nonisolated static func exportText(for report: CrashReport) -> String {
        """
        GoDive \(kindLabel(report.kind))
        Captured: \(report.capturedAt.formatted(.iso8601))
        App version: \(report.appVersion)
        OS version: \(report.osVersion)
        Reason: \(report.reason)

        \(report.details)
        """
    }

    /// Shareable plain-text body for the full report list (newest first).
    nonisolated static func exportText(for reports: [CrashReport]) -> String {
        guard !reports.isEmpty else { return "No crash reports recorded." }
        return reports
            .map { exportText(for: $0) }
            .joined(separator: "\n\n————————————————\n\n")
    }
}

/// SwiftData-backed crash report storage. Each method opens its own `ModelContext` on the
/// caller's thread, so this is safe from MetricKit's background queue and detached tasks.
nonisolated struct CrashReportStore: Sendable {
    let container: ModelContainer
    let maxStoredReports: Int

    init(container: ModelContainer, maxStoredReports: Int = 20) {
        self.container = container
        self.maxStoredReports = maxStoredReports
    }

    func save(_ report: CrashReport) throws {
        let context = ModelContext(container)
        context.insert(CrashReportRecord(report))
        pruneBeyondCap(context: context)
        try context.save()
    }

    /// All stored reports, newest first.
    func loadAll() -> [CrashReport] {
        let context = ModelContext(container)
        return (try? context.fetch(sortedDescriptor()))?.map(\.snapshot) ?? []
    }

    /// Reports not yet uploaded to CloudKit, oldest first (upload in capture order).
    func pendingCloudShare() -> [CrashReport] {
        let descriptor = FetchDescriptor<CrashReportRecord>(
            predicate: #Predicate { $0.sharedToCloudAt == nil },
            sortBy: [SortDescriptor(\.capturedAt, order: .forward)]
        )
        let context = ModelContext(container)
        return (try? context.fetch(descriptor))?.map(\.snapshot) ?? []
    }

    func markShared(id: UUID, at sharedAt: Date = Date()) {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<CrashReportRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let record = try? context.fetch(descriptor).first else { return }
        record.sharedToCloudAt = sharedAt
        try? context.save()
    }

    func deleteAll() {
        let context = ModelContext(container)
        try? context.delete(model: CrashReportRecord.self)
        try? context.save()
    }

    private func sortedDescriptor() -> FetchDescriptor<CrashReportRecord> {
        FetchDescriptor<CrashReportRecord>(sortBy: [SortDescriptor(\.capturedAt, order: .reverse)])
    }

    /// Keeps only the newest `maxStoredReports` rows. The fetch sees the pending insert
    /// (`includePendingChanges` defaults on), so the new report counts toward the cap.
    private func pruneBeyondCap(context: ModelContext) {
        guard let records = try? context.fetch(sortedDescriptor()),
              records.count > maxStoredReports else { return }
        for stale in records.dropFirst(maxStoredReports) {
            context.delete(stale)
        }
    }
}
