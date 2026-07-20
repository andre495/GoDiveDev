import CloudKit
import Foundation

/// Uploads scrubbed security events to the app’s **CloudKit public database** when
/// **Settings → Share diagnostic events** is on (parallel to crash reports).
nonisolated enum SecurityEventCloudUploader {

    nonisolated static let containerIdentifier =
        AppSwiftDataCloudKitCompatibility.iCloudContainerIdentifier
    nonisolated static let recordType = "SecurityEvent"

    static func uploadPendingEvents(
        store: SecurityEventStore,
        ownerProfileID: UUID?
    ) async {
        let pending = store.pendingCloudShare(ownerProfileID: ownerProfileID)
        guard !pending.isEmpty else { return }

        let cloudContainer = CKContainer(identifier: containerIdentifier)
        guard let status = try? await cloudContainer.accountStatus(), status == .available else { return }
        let database = cloudContainer.publicCloudDatabase

        for event in pending {
            do {
                let record = makeRecord(for: event)
                _ = try await database.save(record)
                store.markShared(id: event.id)
            } catch let error as CKError where error.code == .serverRecordChanged {
                store.markShared(id: event.id)
            } catch {
                continue
            }
        }
    }

    /// Public payload — kind/detail already coarse; scrub again at the share boundary.
    nonisolated static func makeRecord(for event: SecurityEvent) -> CKRecord {
        let recordID = CKRecord.ID(recordName: event.id.uuidString)
        let record = CKRecord(recordType: recordType, recordID: recordID)
        record["capturedAt"] = event.capturedAt as NSDate
        record["kind"] = CrashReportPayloadScrubber.scrub(event.kindRaw) as NSString
        if let detail = event.detail {
            record["detail"] = CrashReportPayloadScrubber.scrub(detail) as NSString
        }
        record["appVersion"] = event.appVersion as NSString
        record["osVersion"] = event.osVersion as NSString
        // Never upload ownerProfileID — developer share is anonymized.
        return record
    }
}
