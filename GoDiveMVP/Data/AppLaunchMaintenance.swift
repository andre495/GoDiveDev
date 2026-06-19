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
            try DiveActivityOpenDiveMapSiteBackfill.backfillIfNeeded(modelContext: context)
            #if canImport(UIKit)
            await DiveMediaPreviewStorage.backfillMissingPreviews(modelContext: context)
            #endif
        } catch {
            #if DEBUG
            print("AppLaunchMaintenance failed: \(error)")
            #endif
        }
    }
}
