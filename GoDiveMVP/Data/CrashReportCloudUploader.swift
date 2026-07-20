import CloudKit
import Foundation

/// Uploads stored crash reports to the app's **CloudKit public database** so the developer can
/// read them in CloudKit Console (Data → Records → `CrashReport`). Runs only when
/// **Settings → Share crash reports** is on and the device has an iCloud account.
///
/// Records are keyed by the report UUID, so re-upload attempts are idempotent — a
/// `serverRecordChanged` collision means the report already made it and is treated as success.
nonisolated enum CrashReportCloudUploader {

    nonisolated static let containerIdentifier =
        AppSwiftDataCloudKitCompatibility.iCloudContainerIdentifier
    nonisolated static let recordType = "CrashReport"

    /// Details bodies (MetricKit stack JSON) can be hundreds of KB; CKRecord fields cap at
    /// ~1 MB total, so anything above this threshold ships as a `CKAsset` file instead.
    nonisolated static let inlineDetailsCharacterLimit = 100_000

    /// Uploads every pending report; marks each shared on success. Failures (offline, no
    /// iCloud account) leave reports pending — retried on next launch / toggle enable.
    static func uploadPendingReports(store: CrashReportStore) async {
        let pending = store.pendingCloudShare()
        guard !pending.isEmpty else { return }

        let cloudContainer = CKContainer(identifier: containerIdentifier)
        guard let status = try? await cloudContainer.accountStatus(), status == .available else { return }
        let database = cloudContainer.publicCloudDatabase

        for report in pending {
            var detailsFileURL: URL?
            defer {
                if let detailsFileURL {
                    try? FileManager.default.removeItem(at: detailsFileURL)
                }
            }

            do {
                let record: CKRecord
                if usesDetailsAsset(for: report) {
                    let fileURL = try writeDetailsTemporaryFile(for: report)
                    detailsFileURL = fileURL
                    record = makeRecord(for: report, detailsAssetFileURL: fileURL)
                } else {
                    record = makeRecord(for: report, detailsAssetFileURL: nil)
                }
                _ = try await database.save(record)
                store.markShared(id: report.id)
            } catch let error as CKError where error.code == .serverRecordChanged {
                store.markShared(id: report.id)
            } catch {
                // Transient (network, quota, container not yet provisioned) — retry later.
                continue
            }
        }
    }

    /// Inline strings keep Console browsing easy; oversized bodies go out as an asset file.
    nonisolated static func usesDetailsAsset(for report: CrashReport) -> Bool {
        report.details.count > inlineDetailsCharacterLimit
    }

    /// CKRecord keyed by the report UUID. `detailsAssetFileURL` non-nil replaces the inline
    /// `details` string with a `CKAsset`. Reason/details are scrubbed for public upload.
    nonisolated static func makeRecord(for report: CrashReport, detailsAssetFileURL: URL?) -> CKRecord {
        let recordID = CKRecord.ID(recordName: report.id.uuidString)
        let record = CKRecord(recordType: recordType, recordID: recordID)
        record["capturedAt"] = report.capturedAt as NSDate
        record["kind"] = report.kind.rawValue as NSString
        record["reason"] = CrashReportPayloadScrubber.scrub(report.reason) as NSString
        record["appVersion"] = report.appVersion as NSString
        record["osVersion"] = report.osVersion as NSString
        if let detailsAssetFileURL {
            record["detailsAsset"] = CKAsset(fileURL: detailsAssetFileURL)
        } else {
            record["details"] = CrashReportPayloadScrubber.scrub(report.details) as NSString
        }
        return record
    }

    private nonisolated static func writeDetailsTemporaryFile(for report: CrashReport) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("CrashReportDetails-\(report.id.uuidString).txt")
        let scrubbed = CrashReportPayloadScrubber.scrub(report.details)
        try Data(scrubbed.utf8).write(to: url, options: .atomic)
        return url
    }
}
