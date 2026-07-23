import Foundation
import SwiftData

/// Sendable snapshot of **`SecurityEventRecord`**.
nonisolated struct SecurityEvent: Identifiable, Equatable, Sendable {
    var id: UUID
    var capturedAt: Date
    var kindRaw: String
    var detail: String?
    var appVersion: String
    var osVersion: String
    var ownerProfileID: UUID?
    var sharedToCloudAt: Date?

    init(
        id: UUID = UUID(),
        capturedAt: Date = Date(),
        kindRaw: String,
        detail: String? = nil,
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

    nonisolated var kind: GoDiveSecurityEvent.Kind? {
        GoDiveSecurityEvent.Kind(rawValue: kindRaw)
    }
}

nonisolated enum SecurityEventPresentation: Sendable {
    nonisolated static func kindLabel(_ kindRaw: String) -> String {
        switch GoDiveSecurityEvent.Kind(rawValue: kindRaw) {
        case .authSucceeded: "Signed in"
        case .authFailed: "Sign-in failed"
        case .signOut: "Signed out"
        case .accountDeleted: "Account deleted"
        case .accountDeleteFailed: "Account delete failed"
        case .importRejected: "Import rejected"
        case .cdnChecksumMismatch: "Catalog checksum mismatch"
        case .cdnRefreshFailed: "Catalog refresh failed"
        case .friendAdded: "Friend added"
        case .friendRemoved: "Friend removed"
        case .friendShareSyncFailed: "Friend share sync failed"
        case nil: kindRaw
        }
    }

    nonisolated static func sharedStatusLabel(sharedToCloudAt: Date?) -> String {
        sharedToCloudAt == nil ? "Not sent to developer" : "Sent to developer"
    }

    nonisolated static func exportText(for event: SecurityEvent) -> String {
        var lines: [String] = [
            "GoDive security event",
            "Kind: \(kindLabel(event.kindRaw)) (\(event.kindRaw))",
            "Captured: \(event.capturedAt.formatted(.iso8601))",
            "App version: \(event.appVersion)",
            "OS version: \(event.osVersion)",
        ]
        if let detail = event.detail, !detail.isEmpty {
            lines.append("Detail: \(detail)")
        }
        lines.append("Shared: \(sharedStatusLabel(sharedToCloudAt: event.sharedToCloudAt))")
        return lines.joined(separator: "\n")
    }

    nonisolated static func exportText(for events: [SecurityEvent]) -> String {
        guard !events.isEmpty else { return "No security events recorded." }
        return events
            .map { exportText(for: $0) }
            .joined(separator: "\n\n————————————————\n\n")
    }
}

/// SwiftData-backed security event journal (user store / private CloudKit).
nonisolated struct SecurityEventStore: Sendable {
    let container: ModelContainer
    let maxStoredEvents: Int

    init(container: ModelContainer, maxStoredEvents: Int = 300) {
        self.container = container
        self.maxStoredEvents = maxStoredEvents
    }

    func save(_ event: SecurityEvent) throws {
        let context = ModelContext(container)
        context.insert(SecurityEventRecord(event))
        pruneBeyondCap(context: context, ownerProfileID: event.ownerProfileID)
        try context.save()
    }

    /// Newest first. When **`ownerProfileID`** is set, only that owner’s rows.
    func loadAll(ownerProfileID: UUID?) -> [SecurityEvent] {
        let context = ModelContext(container)
        return (try? context.fetch(sortedDescriptor(ownerProfileID: ownerProfileID)))?.map(\.snapshot) ?? []
    }

    func pendingCloudShare(ownerProfileID: UUID?) -> [SecurityEvent] {
        let context = ModelContext(container)
        let descriptor: FetchDescriptor<SecurityEventRecord>
        if let ownerProfileID {
            descriptor = FetchDescriptor<SecurityEventRecord>(
                predicate: #Predicate {
                    $0.sharedToCloudAt == nil && $0.ownerProfileID == ownerProfileID
                },
                sortBy: [SortDescriptor(\.capturedAt, order: .forward)]
            )
        } else {
            descriptor = FetchDescriptor<SecurityEventRecord>(
                predicate: #Predicate { $0.sharedToCloudAt == nil },
                sortBy: [SortDescriptor(\.capturedAt, order: .forward)]
            )
        }
        return (try? context.fetch(descriptor))?.map(\.snapshot) ?? []
    }

    func markShared(id: UUID, at sharedAt: Date = Date()) {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<SecurityEventRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let record = try? context.fetch(descriptor).first else { return }
        record.sharedToCloudAt = sharedAt
        try? context.save()
    }

    func deleteAll(ownerProfileID: UUID?) {
        let context = ModelContext(container)
        let records = (try? context.fetch(sortedDescriptor(ownerProfileID: ownerProfileID))) ?? []
        for record in records {
            context.delete(record)
        }
        try? context.save()
    }

    private func sortedDescriptor(ownerProfileID: UUID?) -> FetchDescriptor<SecurityEventRecord> {
        if let ownerProfileID {
            return FetchDescriptor<SecurityEventRecord>(
                predicate: #Predicate { $0.ownerProfileID == ownerProfileID },
                sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
            )
        }
        return FetchDescriptor<SecurityEventRecord>(
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
        )
    }

    private func pruneBeyondCap(context: ModelContext, ownerProfileID: UUID?) {
        guard let records = try? context.fetch(sortedDescriptor(ownerProfileID: ownerProfileID)),
              records.count > maxStoredEvents
        else { return }
        for stale in records.dropFirst(maxStoredEvents) {
            context.delete(stale)
        }
    }
}
