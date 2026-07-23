import Foundation
import SwiftData
import os

/// One-time / idempotent store work after the production **`ModelContainer`** attaches — off the main actor so launch stays responsive.
enum AppLaunchMaintenance: Sendable {

    private static let log = Logger(subsystem: "PrimoSoftware.GoDiveMVP", category: "LaunchMaintenance")

    static func runInBackground(container: ModelContainer) {
        Task.detached(priority: .utility) {
            await performEssentialTier(container: container)
        }
        Task.detached(priority: .utility) {
            let delay = AppLaunchPostOverlayPresentation.deferredMaintenanceDelaySeconds
            try? await Task.sleep(for: .seconds(delay))
            await performDeferredTier(container: container)
        }
    }

    /// Fast, local correctness — dive numbers, migrations, bundled catalog seed.
    private static func performEssentialTier(container: ModelContainer) async {
        let context = ModelContext(container)
        context.autosaveEnabled = true
        do {
            try DiveActivityDiveNumbering.backfillMissingDiveNumbers(modelContext: context)
            try DiveBuddyLegacyMigration.migrateIfNeeded(modelContext: context)
            try MarineLifeCatalogSeeder.seedBundledCatalogIfNeeded(context: context)
            try MarineLifeCommonNameNormalization.normalizeStoredCatalogIfNeeded(modelContext: context)
            try AppSwiftDataOwnershipBackfill.backfillIfNeeded(modelContext: context)
            try AppSwiftDataHybridRowMigration.migrateIfNeeded(modelContext: context)
        } catch {
            log.error("AppLaunchMaintenance essential tier failed: \(String(describing: error), privacy: .private)")
        }
    }

    /// Network, PhotoKit, and large backfills — deferred so the first frame after launch stays responsive.
    private static func performDeferredTier(container: ModelContainer) async {
        let context = ModelContext(container)
        context.autosaveEnabled = true
        do {
            _ = await CatalogCDNRefresh.refreshIfNeeded(modelContext: context)
            try DiveActivityOpenDiveMapSiteBackfill.backfillIfNeeded(modelContext: context)
            try DiveProfileTrackBackfill.backfillIfNeeded(modelContext: context)
            try SnorkelSwimTrackBackfill.backfillIfNeeded(modelContext: context)
            try UserDiveSiteDuplicateConsolidation.consolidateIfNeeded(modelContext: context)
            #if canImport(UIKit)
            await DiveMediaPreviewStorage.backfillMissingPreviews(modelContext: context)
            #endif
            DiveMediaCloudIdentifierBackfill.backfillIfNeeded(modelContext: context)
            #if canImport(Photos)
            _ = DiveMediaReferencePruning.pruneMissingLibraryAssets(modelContext: context)
            #endif
            await AppSwiftDataDualStoreFactory.appendCloudKitAccountStatusDiagnostics()
            await syncFirebaseSocialProfileIfNeeded(modelContext: context)
        } catch {
            log.error("AppLaunchMaintenance deferred tier failed: \(String(describing: error), privacy: .private)")
        }
    }

    private static func syncFirebaseSocialProfileIfNeeded(modelContext: ModelContext) async {
        guard
            let profileID = AppLaunchSessionRestorePresentation.loadPersistedProfileID(),
            let profile = try? UserProfileStore.profile(id: profileID, modelContext: modelContext)
        else {
            return
        }
        let activities = (try? modelContext.fetch(FetchDescriptor<DiveActivity>()))?
            .filter { $0.ownerProfileID == profile.id } ?? []
        let totalDiveCount = DiveActivityDiveNumbering.numberedDiveCount(in: activities)
        _ = await GoDiveFirestoreUserProfileSync.syncIfAuthenticated(
            displayName: profile.displayName,
            appleUserIdentifier: profile.appleUserIdentifier,
            interests: GoDiveFirestoreUserProfileMapping.interests(
                doesScubaDiving: profile.doesScubaDiving,
                doesFreeDiving: profile.doesFreeDiving,
                doesSnorkeling: profile.doesSnorkeling
            ),
            totalDiveCount: totalDiveCount
        )
    }
}
