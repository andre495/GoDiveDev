import Foundation
import SwiftData

/// **UDDF** (e.g. **MacDive** `.uddf` export) import: security-scoped read, decode, SwiftData insert + save.
enum UddfDiveFileImport {

    /// Shown when **one** dive was saved (same wording as **`.fit`** for shared UI).
    static let importSingleSuccessMessagePrefix = FitDiveFileImport.importSuccessMessagePrefix

    /// Reads **`Data`** from **`url`** while the security-scoped resource is active. **`nonisolated`** so UI can read off the main actor after showing the import scrim.
    nonisolated static func readUddfFileData(from url: URL) throws -> Data {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        guard accessed else {
            struct AccessError: LocalizedError {
                var errorDescription: String? { "Could not access the selected file." }
            }
            throw AccessError()
        }
        return try Data(contentsOf: url)
    }

    /// Inserts all dives in **`startTime`** order (required for chained **`diveNumber`**). **`primaryInsertedDiveId`** is the newest dive by **`startTime`** ( **`id`** tie-break) when multiple rows are inserted.
    @MainActor
    static func importUddfData(
        _ data: Data,
        modelContext: ModelContext,
        owner: UserProfile? = nil
    ) -> DiveFileImportOutcome {
        do {
            let activities = try UddfDiveFileDecoder.buildDiveActivities(from: data)
            return persistImportedActivities(activities, modelContext: modelContext, owner: owner)
        } catch let uddf as UddfDecodeError {
            return DiveFileImportOutcome(userMessage: uddf.localizedDescription, primaryInsertedDiveId: nil)
        } catch {
            return DiveFileImportOutcome(userMessage: error.localizedDescription, primaryInsertedDiveId: nil)
        }
    }

    /// Duplicate check + SwiftData insert (call after decode so UI can show progress first).
    @MainActor
    static func persistImportedActivities(
        _ activities: [DiveActivity],
        modelContext: ModelContext,
        owner: UserProfile? = nil
    ) -> DiveFileImportOutcome {
        do {
            guard let owner = owner ?? AccountSession.shared.currentProfile else {
                return DiveFileImportOutcome(
                    userMessage: "Sign in to import dives.",
                    primaryInsertedDiveId: nil
                )
            }
            var existing = try DiveActivityOwnership.activities(forOwnerProfileID: owner.id, modelContext: modelContext)
                .map(DiveActivityDuplicateMatcher.Signature.init)
            var inserted: [DiveActivity] = []
            var skippedDuplicates = 0

            for activity in activities {
                let candidate = DiveActivityDuplicateMatcher.Signature(activity)
                if let match = DiveActivityDuplicateMatcher.findDuplicate(for: candidate, among: existing) {
                    skippedDuplicates += 1
                    _ = match
                    continue
                }
                try DiveActivityDiveNumbering.assignNextDiveNumberChainedAfterNewest(for: activity, modelContext: modelContext)
                DiveActivityOwnership.assignOwner(owner, to: activity)
                modelContext.insert(activity)
                try DiveActivityEquipmentAssociation.applyAutoAdd(
                    to: activity,
                    ownerProfileID: owner.id,
                    modelContext: modelContext
                )
                inserted.append(activity)
                existing.append(candidate)
            }

            if inserted.isEmpty {
                if skippedDuplicates == 1,
                   let only = activities.first,
                   let match = DiveActivityDuplicateMatcher.findDuplicate(
                       for: DiveActivityDuplicateMatcher.Signature(only),
                       among: existing
                   ),
                   let stored = try? modelContext.fetch(FetchDescriptor<DiveActivity>()),
                   let duplicate = stored.first(where: { $0.id == match.existingId }) {
                    return DiveFileImportOutcome(
                        userMessage: DiveActivityDuplicateMatcher.importBlockedMessage(matching: duplicate),
                        primaryInsertedDiveId: nil
                    )
                }
                let msg = skippedDuplicates == 1
                    ? "This dive is already in your log."
                    : "All \(skippedDuplicates) dives in this file are already in your log."
                return DiveFileImportOutcome(userMessage: msg, primaryInsertedDiveId: nil)
            }

            try modelContext.save()
            try DiveActivityDiveNumbering.applyAutomaticSequentialRenumberIfNeeded(modelContext: modelContext)

            let primaryId = primaryInsertedActivity(from: inserted)?.id
            if inserted.count == 1, let only = inserted.first {
                var msg = "\(importSingleSuccessMessagePrefix) starting \(only.startTime.formatted(date: .abbreviated, time: .shortened))."
                if skippedDuplicates > 0 {
                    msg += " Skipped \(skippedDuplicates) duplicate(s)."
                }
                return DiveFileImportOutcome(userMessage: msg, primaryInsertedDiveId: primaryId)
            }
            var msg = "Imported \(inserted.count) dives."
            if skippedDuplicates > 0 {
                msg += " Skipped \(skippedDuplicates) duplicate(s)."
            }
            return DiveFileImportOutcome(userMessage: msg, primaryInsertedDiveId: primaryId)
        } catch {
            return DiveFileImportOutcome(userMessage: error.localizedDescription, primaryInsertedDiveId: nil)
        }
    }

    /// Newest **`startTime`** wins; **`UUID.uuidString`** breaks ties deterministically.
    private static func primaryInsertedActivity(from activities: [DiveActivity]) -> DiveActivity? {
        activities.max { a, b in
            if a.startTime != b.startTime {
                return a.startTime < b.startTime
            }
            return a.id.uuidString < b.id.uuidString
        }
    }
}
