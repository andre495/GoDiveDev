import Foundation
import SwiftData

/// One-time / idempotent store work after the production **`ModelContainer`** attaches — off the main actor so launch stays responsive.
enum AppLaunchMaintenance: Sendable {

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
        } catch {
            #if DEBUG
            print("AppLaunchMaintenance failed: \(error)")
            #endif
        }
    }

    private static func syncSignedInUserPreferencesIfNeeded(modelContext: ModelContext) throws {
        guard
            let profileID = AppLaunchSessionRestorePresentation.persistedProfileID(
                storedUUIDString: UserDefaults.standard.string(
                    forKey: AppLaunchSessionRestorePresentation.currentProfileIDUserDefaultsKey
                )
            ),
            let profile = try UserProfileStore.profile(id: profileID, modelContext: modelContext)
        else {
            return
        }
        try UserPreferencesSync.syncForSignedInOwner(profile, modelContext: modelContext)
    }

    private static func reconcileSignedInProfileIdentityIfNeeded(modelContext: ModelContext) throws {
        guard
            let profileID = AppLaunchSessionRestorePresentation.persistedProfileID(
                storedUUIDString: UserDefaults.standard.string(
                    forKey: AppLaunchSessionRestorePresentation.currentProfileIDUserDefaultsKey
                )
            ),
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
            UserDefaults.standard.set(
                outcome.canonicalProfileID.uuidString,
                forKey: AppLaunchSessionRestorePresentation.currentProfileIDUserDefaultsKey
            )
            Task { @MainActor in
                _ = try? AccountSession.shared.reconcileCloudKitIdentityIfNeeded(
                    modelContext: modelContext.container.mainContext
                )
            }
        }
    }
}
