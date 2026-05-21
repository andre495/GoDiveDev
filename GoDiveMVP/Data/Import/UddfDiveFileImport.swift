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
        owner: UserProfile? = nil,
        createMissingDiveSites: Bool = false
    ) async -> DiveFileImportOutcome {
        do {
            let activities = try UddfDiveFileDecoder.buildDiveActivities(from: data)
            return await persistImportedActivities(
                activities,
                modelContext: modelContext,
                owner: owner,
                createMissingDiveSites: createMissingDiveSites
            )
        } catch let uddf as UddfDecodeError {
            return DiveFileImportOutcome(userMessage: uddf.localizedDescription, primaryInsertedDiveId: nil)
        } catch {
            return DiveFileImportOutcome(userMessage: error.localizedDescription, primaryInsertedDiveId: nil)
        }
    }

    /// **`imported`** = rows inserted; **`duplicates`** = skipped; **`processed`** = dives handled so far; **`total`** = dives in file.
    typealias ProgressHandler = @MainActor (_ imported: Int, _ duplicates: Int, _ processed: Int, _ total: Int) -> Void

    /// Duplicate check + SwiftData insert (call after decode so UI can show progress first).
    @MainActor
    static func persistImportedActivities(
        _ activities: [DiveActivity],
        modelContext: ModelContext,
        owner: UserProfile? = nil,
        createMissingDiveSites: Bool = false,
        onProgress: ProgressHandler? = nil
    ) async -> DiveFileImportOutcome {
        do {
            guard let owner = owner ?? AccountSession.shared.currentProfile else {
                return DiveFileImportOutcome(
                    userMessage: "Sign in to import dives.",
                    primaryInsertedDiveId: nil,
                    totalInFile: activities.count
                )
            }
            let ownedExisting = try DiveActivityOwnership.activities(forOwnerProfileID: owner.id, modelContext: modelContext)
            var duplicateBaseline = ownedExisting.map(DiveActivityDuplicateMatcher.Signature.init)
            var numberingBaseline = ownedExisting
            let autoAddCandidates = try DiveActivityEquipmentAssociation.autoAddCandidates(
                forOwnerProfileID: owner.id,
                modelContext: modelContext
            )
            var inserted: [DiveActivity] = []
            var skippedDuplicates = 0

            for (index, activity) in activities.enumerated() {
                let candidate = DiveActivityDuplicateMatcher.Signature(activity)
                if let match = DiveActivityDuplicateMatcher.findDuplicate(for: candidate, among: duplicateBaseline) {
                    skippedDuplicates += 1
                    _ = match
                } else {
                    if !activity.diveNumberExplicitlyNone, activity.diveNumber == nil {
                        DiveActivityDiveNumbering.assignNextChainedDiveNumber(
                            to: activity,
                            among: &numberingBaseline
                        )
                    }
                    DiveActivityOwnership.assignOwner(owner, to: activity)
                    modelContext.insert(activity)
                    try DiveActivityEquipmentAssociation.applyAutoAdd(
                        to: activity,
                        candidates: autoAddCandidates,
                        modelContext: modelContext
                    )
                    inserted.append(activity)
                    duplicateBaseline.append(candidate)
                }
                onProgress?(inserted.count, skippedDuplicates, index + 1, activities.count)
                if onProgress != nil {
                    await Task.yield()
                }
            }

            var catalogSites = try DiveActivitySiteAssociation.fetchCatalogSites(modelContext: modelContext)
            let createdDiveSites = DiveActivitySiteAssociation.applySiteLinksForImportedActivities(
                inserted,
                catalogSites: &catalogSites,
                createMissingSites: createMissingDiveSites,
                modelContext: modelContext
            )

            if inserted.isEmpty {
                if skippedDuplicates == 1,
                   let only = activities.first,
                   let match = DiveActivityDuplicateMatcher.findDuplicate(
                       for: DiveActivityDuplicateMatcher.Signature(only),
                       among: duplicateBaseline
                   ),
                   let stored = try? modelContext.fetch(FetchDescriptor<DiveActivity>()),
                   let duplicate = stored.first(where: { $0.id == match.existingId }) {
                    return DiveFileImportOutcome(
                        userMessage: DiveActivityDuplicateMatcher.importBlockedMessage(matching: duplicate),
                        primaryInsertedDiveId: nil,
                        insertedCount: 0,
                        skippedDuplicateCount: skippedDuplicates,
                        totalInFile: activities.count,
                        createdDiveSiteCount: createdDiveSites
                    )
                }
                let msg = skippedDuplicates == 1
                    ? "This dive is already in your log."
                    : "\(skippedDuplicates) duplicate dive\(skippedDuplicates == 1 ? "" : "s") found. None were imported."
                return DiveFileImportOutcome(
                    userMessage: msg,
                    primaryInsertedDiveId: nil,
                    insertedCount: 0,
                    skippedDuplicateCount: skippedDuplicates,
                    totalInFile: activities.count,
                    createdDiveSiteCount: createdDiveSites
                )
            }

            try modelContext.save()
            try DiveActivityDiveNumbering.applyAutomaticSequentialRenumberIfNeeded(modelContext: modelContext)

            let primaryId = primaryInsertedActivity(from: inserted)?.id
            if inserted.count == 1, let only = inserted.first {
                var msg = "\(importSingleSuccessMessagePrefix) starting \(only.startTime.formatted(date: .abbreviated, time: .shortened))."
                if skippedDuplicates > 0 {
                    msg += " Skipped \(skippedDuplicates) duplicate(s)."
                }
                return DiveFileImportOutcome(
                    userMessage: msg,
                    primaryInsertedDiveId: primaryId,
                    insertedCount: inserted.count,
                    skippedDuplicateCount: skippedDuplicates,
                    totalInFile: activities.count,
                    createdDiveSiteCount: createdDiveSites
                )
            }
            var msg = "Imported \(inserted.count) dives."
            if skippedDuplicates > 0 {
                msg += " \(skippedDuplicates) duplicate dive\(skippedDuplicates == 1 ? "" : "s") found."
            }
            return DiveFileImportOutcome(
                userMessage: msg,
                primaryInsertedDiveId: primaryId,
                insertedCount: inserted.count,
                skippedDuplicateCount: skippedDuplicates,
                totalInFile: activities.count,
                createdDiveSiteCount: createdDiveSites
            )
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
