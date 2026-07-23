import Foundation
import SwiftData

enum FitSnorkelFileImport {
    nonisolated static let importSuccessMessagePrefix = "Imported snorkel session"

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
    static func importFromSecurityScopedURL(_ url: URL, modelContext: ModelContext) async -> SnorkelFileImportOutcome {
        do {
            let data = try readFitFileData(from: url)
            return await importFitData(data, modelContext: modelContext)
        } catch {
            GoDiveUserFacingError.recordImportRejection(error)
            return SnorkelFileImportOutcome(
                userMessage: GoDiveUserFacingError.importUserMessage(for: error),
                primaryInsertedActivityId: nil
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
    ) async -> SnorkelFileImportOutcome {
        let activity: SnorkelActivity
        do {
            activity = try FitSnorkelFileDecoder.buildSnorkelActivity(from: data)
        } catch let fit as FitSnorkelDecodeError {
            GoDiveUserFacingError.recordImportRejection(fit)
            return SnorkelFileImportOutcome(
                userMessage: GoDiveUserFacingError.importUserMessage(for: fit),
                primaryInsertedActivityId: nil
            )
        } catch {
            GoDiveUserFacingError.recordImportRejection(error)
            return SnorkelFileImportOutcome(
                userMessage: GoDiveUserFacingError.importUserMessage(for: error),
                primaryInsertedActivityId: nil
            )
        }

        guard let owner = owner ?? AccountSession.shared.currentProfile else {
            return SnorkelFileImportOutcome(
                userMessage: "Sign in to import snorkel sessions.",
                primaryInsertedActivityId: nil
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

    @MainActor
    static func persistImportedActivity(
        _ activity: SnorkelActivity,
        modelContext: ModelContext,
        owner: UserProfile? = nil,
        attachMedia: Bool = true,
        createMissingDiveSites: Bool = true
    ) async -> SnorkelFileImportOutcome {
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
            return SnorkelFileImportOutcome(
                userMessage: GoDiveUserFacingError.importUserMessage(for: error),
                primaryInsertedActivityId: nil
            )
        }
    }

    @MainActor
    private static func persistImportedActivityWhileAutosaveDisabled(
        _ activity: SnorkelActivity,
        modelContext: ModelContext,
        owner: UserProfile?,
        attachMedia: Bool,
        createMissingDiveSites: Bool
    ) async throws -> SnorkelFileImportOutcome {
        guard let owner = owner ?? AccountSession.shared.currentProfile else {
            return SnorkelFileImportOutcome(
                userMessage: "Sign in to import snorkel sessions.",
                primaryInsertedActivityId: nil
            )
        }
        if let interrupted = DiveFileImportInterruption.rollbackIfNeededBeforeSave(modelContext: modelContext) {
            return SnorkelFileImportOutcome(
                userMessage: interrupted.userMessage,
                primaryInsertedActivityId: nil
            )
        }

        let stored = try SnorkelActivityOwnership.activities(forOwnerProfileID: owner.id, modelContext: modelContext)
        let existing = stored.map { SnorkelActivityDuplicateMatcher.signature(for: $0) }
        let candidate = SnorkelActivityDuplicateMatcher.signature(for: activity)
        if let match = SnorkelActivityDuplicateMatcher.findDuplicate(for: candidate, among: existing),
           let duplicate = stored.first(where: { $0.id == match.existingId }) {
            return SnorkelFileImportOutcome(
                userMessage: SnorkelActivityDuplicateMatcher.importBlockedMessage(matching: duplicate),
                primaryInsertedActivityId: nil
            )
        }

        SnorkelActivityOwnership.assignOwner(owner, to: activity)
        var buddyRosterCache = SnorkelBuddyImportConsolidation.RosterCache()
        SnorkelBuddyImportConsolidation.prepareForInsert(
            activity,
            owner: owner,
            modelContext: modelContext,
            rosterCache: &buddyRosterCache
        )
        let importedBuddyIDs = Set(activity.buddies.compactMap(\.buddyID))
        modelContext.insert(activity)
        SnorkelProfilePointStore.insertStagedPointsAndSyncTrack(for: activity, into: modelContext)

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

        await DiveSiteTimeZoneResolution.ensureResolvedForLinkedSnorkelActivities(
            [activity],
            resolver: MapKitGeocodingTimeZoneResolver.shared
        )
        await SnorkelActivityTimeZoneResolution.resolveMissingOffset(for: activity)
        await ActivityWeatherImportCapture.captureForSnorkel(activity, catalogSites: catalogSites)

        if let interrupted = DiveFileImportInterruption.rollbackIfNeededBeforeSave(modelContext: modelContext) {
            return SnorkelFileImportOutcome(
                userMessage: interrupted.userMessage,
                primaryInsertedActivityId: nil
            )
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
            return SnorkelFileImportOutcome(
                userMessage: interrupted.userMessage,
                primaryInsertedActivityId: nil
            )
        }

        try modelContext.save()

        if attachMedia {
            await SnorkelLibraryMediaAutoAttachScheduler.attachAfterSnorkelPersisted(
                activity,
                ownerProfileID: owner.id,
                modelContext: modelContext
            )
        }

        let msg = "\(importSuccessMessagePrefix) starting \(activity.formattedStartDateTime())."
        return SnorkelFileImportOutcome(userMessage: msg, primaryInsertedActivityId: activity.id)
    }
}

struct SnorkelFileImportOutcome: Equatable, Sendable {
    let userMessage: String
    let primaryInsertedActivityId: UUID?
    let importedActivityCount: Int

    init(
        userMessage: String,
        primaryInsertedActivityId: UUID?,
        importedActivityCount: Int? = nil
    ) {
        self.userMessage = userMessage
        self.primaryInsertedActivityId = primaryInsertedActivityId
        if let importedActivityCount {
            self.importedActivityCount = max(0, importedActivityCount)
        } else {
            self.importedActivityCount = SnorkelFileImportSuccess.matches(userMessage) ? 1 : 0
        }
    }

    nonisolated var didSucceed: Bool {
        SnorkelFileImportSuccess.matches(userMessage)
    }
}

enum SnorkelFileImportSuccess {
    nonisolated static func matches(_ message: String) -> Bool {
        message.hasPrefix(FitSnorkelFileImport.importSuccessMessagePrefix)
    }
}
