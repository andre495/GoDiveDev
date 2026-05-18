import Foundation
import SwiftData

/// Shared **Garmin .fit** import path: security-scoped read, decode, SwiftData insert + save.
enum FitDiveFileImport {
    /// Prefix on **`importFitData`** / **`importFromSecurityScopedURL`** success **`userMessage`** when a dive was saved.
    static let importSuccessMessagePrefix = "Imported dive"

    /// Reads **`Data`** from **`url`** while the security-scoped resource is active. **`nonisolated`** so UI can read off the main actor after showing the import scrim.
    nonisolated static func readFitFileData(from url: URL) throws -> Data {
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

    @MainActor
    static func importFromSecurityScopedURL(_ url: URL, modelContext: ModelContext) -> DiveFileImportOutcome {
        do {
            let data = try readFitFileData(from: url)
            return importFitData(data, modelContext: modelContext)
        } catch {
            return DiveFileImportOutcome(userMessage: error.localizedDescription, primaryInsertedDiveId: nil)
        }
    }

    @MainActor
    static func importFitData(
        _ data: Data,
        modelContext: ModelContext,
        owner: UserProfile? = nil
    ) -> DiveFileImportOutcome {
        do {
            let activity = try FitDiveFileDecoder.buildDiveActivity(from: data)
            return persistImportedActivity(activity, modelContext: modelContext, owner: owner)
        } catch let fit as FitDecodeError {
            return DiveFileImportOutcome(userMessage: fit.localizedDescription, primaryInsertedDiveId: nil)
        } catch {
            return DiveFileImportOutcome(userMessage: error.localizedDescription, primaryInsertedDiveId: nil)
        }
    }

    /// Duplicate check + SwiftData insert (call after decode so UI can show progress first).
    @MainActor
    static func persistImportedActivity(
        _ activity: DiveActivity,
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
            let stored = try DiveActivityOwnership.activities(forOwnerProfileID: owner.id, modelContext: modelContext)
            let existing = stored.map(DiveActivityDuplicateMatcher.Signature.init)
            let candidate = DiveActivityDuplicateMatcher.Signature(activity)
            if let match = DiveActivityDuplicateMatcher.findDuplicate(for: candidate, among: existing),
               let duplicate = stored.first(where: { $0.id == match.existingId }) {
                return DiveFileImportOutcome(
                    userMessage: DiveActivityDuplicateMatcher.importBlockedMessage(matching: duplicate),
                    primaryInsertedDiveId: nil
                )
            }
            try DiveActivityDiveNumbering.assignNextDiveNumberChainedAfterNewest(for: activity, modelContext: modelContext)
            DiveActivityOwnership.assignOwner(owner, to: activity)
            modelContext.insert(activity)
            try modelContext.save()
            try DiveActivityDiveNumbering.applyAutomaticSequentialRenumberIfNeeded(modelContext: modelContext)
            let msg = "\(importSuccessMessagePrefix) starting \(activity.startTime.formatted(date: .abbreviated, time: .shortened))."
            return DiveFileImportOutcome(userMessage: msg, primaryInsertedDiveId: activity.id)
        } catch {
            return DiveFileImportOutcome(userMessage: error.localizedDescription, primaryInsertedDiveId: nil)
        }
    }
}
