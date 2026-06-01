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
    static func importFromSecurityScopedURL(_ url: URL, modelContext: ModelContext) async -> DiveFileImportOutcome {
        do {
            let data = try readFitFileData(from: url)
            return await importFitData(data, modelContext: modelContext)
        } catch {
            return DiveFileImportOutcome(userMessage: error.localizedDescription, primaryInsertedDiveId: nil)
        }
    }

    @MainActor
    static func importFitData(
        _ data: Data,
        modelContext: ModelContext,
        owner: UserProfile? = nil
    ) async -> DiveFileImportOutcome {
        do {
            let activity = try FitDiveFileDecoder.buildDiveActivity(from: data)
            return await persistImportedActivity(activity, modelContext: modelContext, owner: owner)
        } catch let fit as FitDecodeError {
            return DiveFileImportOutcome(userMessage: fit.localizedDescription, primaryInsertedDiveId: nil)
        } catch {
            return DiveFileImportOutcome(userMessage: error.localizedDescription, primaryInsertedDiveId: nil)
        }
    }

    /// Duplicate check + SwiftData insert (call after decode so UI can show progress first).
    @MainActor
    /// Set **`attachMedia: false`** when the caller drives the Photos auto-attach pass separately
    /// (e.g. to surface an **"Adding Media"** milestone in the import dialog).
    ///
    /// **`createMissingDiveSites`** mirrors the UDDF import option: when **`false`**, the dive still links to an
    /// existing catalog site by name match but no **new** **`DiveSite`** is created for an unmatched import name.
    static func persistImportedActivity(
        _ activity: DiveActivity,
        modelContext: ModelContext,
        owner: UserProfile? = nil,
        attachMedia: Bool = true,
        createMissingDiveSites: Bool = true
    ) async -> DiveFileImportOutcome {
        do {
            guard let owner = owner ?? AccountSession.shared.currentProfile else {
                return DiveFileImportOutcome(
                    userMessage: "Sign in to import dives.",
                    primaryInsertedDiveId: nil
                )
            }
            let stored = try DiveActivityOwnership.activities(forOwnerProfileID: owner.id, modelContext: modelContext)
            let existing = stored.map { DiveActivityDuplicateMatcher.signature(for: $0) }
            let candidate = DiveActivityDuplicateMatcher.signature(for: activity)
            if let match = DiveActivityDuplicateMatcher.findDuplicate(for: candidate, among: existing),
               let duplicate = stored.first(where: { $0.id == match.existingId }) {
                return DiveFileImportOutcome(
                    userMessage: DiveActivityDuplicateMatcher.importBlockedMessage(matching: duplicate),
                    primaryInsertedDiveId: nil
                )
            }
            try DiveActivityDiveNumbering.assignNextDiveNumberChainedAfterNewest(for: activity, modelContext: modelContext)
            DiveActivityOwnership.assignOwner(owner, to: activity)
            var buddyRosterCache = DiveBuddyImportConsolidation.RosterCache()
            DiveBuddyImportConsolidation.prepareForInsert(
                activity,
                owner: owner,
                modelContext: modelContext,
                rosterCache: &buddyRosterCache
            )
            modelContext.insert(activity)
            try DiveActivityEquipmentAssociation.applyAutoAdd(
                to: activity,
                ownerProfileID: owner.id,
                modelContext: modelContext
            )
            var catalogSites = try DiveActivitySiteAssociation.fetchCatalogSites(modelContext: modelContext)
            DiveActivitySiteAssociation.applyBestMatch(to: activity, catalogSites: catalogSites)
            if createMissingDiveSites {
                _ = DiveActivitySiteAssociation.createSiteForImportNameIfNeeded(
                    to: activity,
                    catalogSites: &catalogSites,
                    modelContext: modelContext
                )
            }
            await DiveSiteTimeZoneResolution.ensureResolvedForLinkedActivities(
                [activity],
                resolver: MapKitGeocodingTimeZoneResolver.shared
            )
            await DiveActivityTimeZoneResolution.resolveMissingOffset(for: activity)
            try modelContext.save()
            try DiveActivityDiveNumbering.applyAutomaticSequentialRenumberIfNeeded(modelContext: modelContext)
            if attachMedia {
                await DiveLibraryMediaAutoAttachScheduler.attachAfterDivePersisted(
                    activity,
                    ownerProfileID: owner.id,
                    modelContext: modelContext
                )
            }
            let msg = "\(importSuccessMessagePrefix) starting \(activity.formattedStartDateTime())."
            return DiveFileImportOutcome(userMessage: msg, primaryInsertedDiveId: activity.id)
        } catch {
            return DiveFileImportOutcome(userMessage: error.localizedDescription, primaryInsertedDiveId: nil)
        }
    }
}
