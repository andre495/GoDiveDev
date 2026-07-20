import Foundation
import SwiftData
import os

/// One-time / idempotent store work after the production **`ModelContainer`** attaches — off the main actor so launch stays responsive.
enum AppLaunchMaintenance: Sendable {

    private static let log = Logger(subsystem: "PrimoSoftware.GoDiveMVP", category: "LaunchMaintenance")

    static func runInBackground(container: ModelContainer) {
        Task.detached(priority: .utility) {
            await perform(container: container)
        }
    }

    private static func perform(container: ModelContainer) async {
        let context = ModelContext(container)
        context.autosaveEnabled = true
        do {
            try DiveActivityDiveNumbering.backfillMissingDiveNumbers(modelContext: context)
            try DiveBuddyLegacyMigration.migrateIfNeeded(modelContext: context)
            try MarineLifeCatalogSeeder.seedBundledCatalogIfNeeded(context: context)
            _ = await CatalogCDNRefresh.refreshIfNeeded(modelContext: context)
            try MarineLifeCommonNameNormalization.normalizeStoredCatalogIfNeeded(modelContext: context)
            try DiveActivityOpenDiveMapSiteBackfill.backfillIfNeeded(modelContext: context)
            try AppSwiftDataOwnershipBackfill.backfillIfNeeded(modelContext: context)
            try AppSwiftDataHybridRowMigration.migrateIfNeeded(modelContext: context)
            try DiveProfileTrackBackfill.backfillIfNeeded(modelContext: context)
            try UserDiveSiteDuplicateConsolidation.consolidateIfNeeded(modelContext: context)
            try reconcileSignedInProfileIdentityIfNeeded(modelContext: context)
            try syncSignedInUserPreferencesIfNeeded(modelContext: context)
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
            log.error("AppLaunchMaintenance failed: \(String(describing: error), privacy: .private)")
        }
    }

    private static func syncSignedInUserPreferencesIfNeeded(modelContext: ModelContext) throws {
        guard
            let profileID = AppLaunchSessionRestorePresentation.loadPersistedProfileID(),
            let profile = try UserProfileStore.profile(id: profileID, modelContext: modelContext)
        else {
            return
        }
        try UserPreferencesSync.syncForSignedInOwner(profile, modelContext: modelContext)
    }

    private static func reconcileSignedInProfileIdentityIfNeeded(modelContext: ModelContext) throws {
        guard
            let profileID = AppLaunchSessionRestorePresentation.loadPersistedProfileID(),
            let profile = try UserProfileStore.profile(id: profileID, modelContext: modelContext)
        else {
            return
        }
        let outcome = try UserProfileCloudKitIdentityMerge.reconcile(
            appleUserIdentifier: profile.appleUserIdentifier,
            preferredSessionProfileID: profile.id,
            modelContext: modelContext
        )
        if outcome.didChangeCanonicalID {
            AppLaunchSessionRestorePresentation.savePersistedProfileID(outcome.canonicalProfileID)
            Task { @MainActor in
                _ = try? AccountSession.shared.reconcileCloudKitIdentityIfNeeded(
                    modelContext: modelContext.container.mainContext
                )
            }
        }
    }

    private static func syncFirebaseSocialProfileIfNeeded(modelContext: ModelContext) async {
        guard
            let profileID = AppLaunchSessionRestorePresentation.loadPersistedProfileID(),
            let profile = try? UserProfileStore.profile(id: profileID, modelContext: modelContext)
        else {
            return
        }
        _ = await GoDiveFirestoreUserProfileSync.syncIfAuthenticated(
            displayName: profile.displayName,
            appleUserIdentifier: profile.appleUserIdentifier,
            interests: GoDiveFirestoreUserProfileMapping.interests(
                doesScubaDiving: profile.doesScubaDiving,
                doesFreeDiving: profile.doesFreeDiving,
                doesSnorkeling: profile.doesSnorkeling
            )
        )
    }
}
