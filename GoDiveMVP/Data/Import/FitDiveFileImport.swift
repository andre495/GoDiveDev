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
        return try DiveFileImportLimits.readCappedFileData(from: url, kind: .fit)
    }

    @MainActor
    static func importFromSecurityScopedURL(_ url: URL, modelContext: ModelContext) async -> DiveFileImportOutcome {
        do {
            let data = try readFitFileData(from: url)
            return await importFitData(data, modelContext: modelContext)
        } catch {
            GoDiveUserFacingError.recordImportRejection(error)
            return DiveFileImportOutcome(
                userMessage: GoDiveUserFacingError.importUserMessage(for: error),
                primaryInsertedDiveId: nil
            )
        }
    }

    @MainActor
    static func importFitData(
        _ data: Data,
        modelContext: ModelContext,
        owner: UserProfile? = nil,
        createMissingDiveSites: Bool = true,
        attachMedia: Bool = true
    ) async -> DiveFileImportOutcome {
        // Decode first so empty / invalid files surface format errors even before sign-in checks.
        let activity: DiveActivity
        do {
            activity = try FitDiveFileDecoder.buildDiveActivity(from: data)
        } catch let fit as FitDecodeError {
            GoDiveUserFacingError.recordImportRejection(fit)
            return DiveFileImportOutcome(
                userMessage: GoDiveUserFacingError.importUserMessage(for: fit),
                primaryInsertedDiveId: nil
            )
        } catch {
            GoDiveUserFacingError.recordImportRejection(error)
            return DiveFileImportOutcome(
                userMessage: GoDiveUserFacingError.importUserMessage(for: error),
                primaryInsertedDiveId: nil
            )
        }

        guard let owner = owner ?? AccountSession.shared.currentProfile else {
            return DiveFileImportOutcome(
                userMessage: "Sign in to import dives.",
                primaryInsertedDiveId: nil
            )
        }
        return await persistImportedActivity(
            activity,
            modelContext: modelContext,
            owner: owner,
            attachMedia: attachMedia,
            createMissingDiveSites: createMissingDiveSites
        )
    }

    /// Duplicate check + SwiftData insert (call after decode so UI can show progress first).
    @MainActor
    /// Set **`attachMedia: false`** when the caller drives the Photos auto-attach pass separately
    /// (e.g. to surface an **"Adding Media"** milestone in the import dialog).
    ///
    /// **`createMissingDiveSites`**: when **`false`**, skips creating a **local-only** site for unmatched import names.
    /// OpenDiveMap reference matching still runs and can link or create an enriched catalog site.
    static func persistImportedActivity(
        _ activity: DiveActivity,
        modelContext: ModelContext,
        owner: UserProfile? = nil,
        attachMedia: Bool = true,
        createMissingDiveSites: Bool = true
    ) async -> DiveFileImportOutcome {
        do {
            return try await DiveFileImportAutosaveScope.withAutosaveDisabled(modelContext: modelContext) {
                try await persistImportedActivityWhileAutosaveDisabled(
                    activity,
                    modelContext: modelContext,
                    owner: owner,
                    attachMedia: attachMedia,
                    createMissingDiveSites: createMissingDiveSites
                )
            }
        } catch {
            modelContext.rollback()
            GoDiveUserFacingError.recordImportRejection(error)
            return DiveFileImportOutcome(
                userMessage: GoDiveUserFacingError.importUserMessage(for: error),
                primaryInsertedDiveId: nil
            )
        }
    }

    @MainActor
    private static func persistImportedActivityWhileAutosaveDisabled(
        _ activity: DiveActivity,
        modelContext: ModelContext,
        owner: UserProfile?,
        attachMedia: Bool,
        createMissingDiveSites: Bool
    ) async throws -> DiveFileImportOutcome {
        do {
            guard let owner = owner ?? AccountSession.shared.currentProfile else {
                return DiveFileImportOutcome(
                    userMessage: "Sign in to import dives.",
                    primaryInsertedDiveId: nil
                )
            }
            if let interrupted = DiveFileImportInterruption.rollbackIfNeededBeforeSave(modelContext: modelContext) {
                return interrupted
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
            let importedBuddyIDs = Set(activity.buddies.compactMap(\.buddyID))
            modelContext.insert(activity)
            DiveProfilePointStore.insertStagedPointsAndSyncTrack(for: activity, into: modelContext)
            try DiveActivityEquipmentAssociation.applyAutoAdd(
                to: activity,
                ownerProfileID: owner.id,
                modelContext: modelContext
            )
            var catalogSites = try DiveActivitySiteAssociation.fetchCatalogSites(modelContext: modelContext)
            DiveActivitySiteAssociation.applyBestMatch(
                to: activity,
                catalogSites: catalogSites,
                modelContext: modelContext
            )
            let matchIndex = DiveSiteReferenceCatalog.bundledMatchIndex()
            _ = DiveActivitySiteAssociation.applyOpenDiveMapSiteLinkIfNeeded(
                to: activity,
                catalogSites: &catalogSites,
                modelContext: modelContext,
                matchIndex: matchIndex,
                createSiteWhenMissing: true
            )
            if createMissingDiveSites, activity.diveSiteID == nil {
                _ = DiveActivitySiteAssociation.createSiteForImportNameIfNeeded(
                    to: activity,
                    catalogSites: &catalogSites,
                    modelContext: modelContext
                )
            }
            DiveActivityDiverWeightDefaults.applyInheritedDefaults(to: activity)
            await DiveSiteTimeZoneResolution.ensureResolvedForLinkedActivities(
                [activity],
                resolver: MapKitGeocodingTimeZoneResolver.shared
            )
            await DiveActivityTimeZoneResolution.resolveMissingOffset(for: activity)
            await ActivityWeatherImportCapture.captureForDive(activity, catalogSites: catalogSites)

            if let interrupted = DiveFileImportInterruption.rollbackIfNeededBeforeSave(modelContext: modelContext) {
                return interrupted
            }

            await DiveBuddyContactAutoLink.autoLinkUnlinkedBuddies(
                owner: owner,
                modelContext: modelContext,
                buddyIDs: importedBuddyIDs
            )
            await GoDiveFriendBuddyLinking.autoLinkUnlinkedBuddies(
                owner: owner,
                modelContext: modelContext,
                buddyIDs: importedBuddyIDs
            )

            if let interrupted = DiveFileImportInterruption.rollbackIfNeededBeforeSave(modelContext: modelContext) {
                return interrupted
            }

            try modelContext.save()
            try DiveActivityDiveNumbering.applyAutomaticSequentialRenumberIfNeeded(modelContext: modelContext)
            try DiveTripActivityLinking.applyAutoLinkForOwner(
                ownerProfileID: owner.id,
                modelContext: modelContext
            )
            try modelContext.save()
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
            modelContext.rollback()
            throw error
        }
    }
}
