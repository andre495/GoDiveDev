import Foundation
import SwiftData

/// One-time OpenDiveMap linking plus every-launch hydrate of synced **`UserDiveSite`** snapshots.
enum DiveActivityOpenDiveMapSiteBackfill {
    private static let completedKey = "goDiveOpenDiveMapSiteLinkBackfillComplete"

    static func backfillIfNeeded(modelContext: ModelContext) throws {
        if !UserDefaults.standard.bool(forKey: completedKey) {
            _ = try DiveActivitySiteAssociation.backfillOpenDiveMapSiteLinks(modelContext: modelContext)
            UserDefaults.standard.set(true, forKey: completedKey)
        } else {
            // CloudKit restore can reintroduce orphaned diveSiteIDs after the one-time link pass.
            let hydrated = try DiveActivitySiteAssociation.hydrateSyncedUserDiveSitesForLinkedDives(
                modelContext: modelContext
            )
            if hydrated > 0 {
                try modelContext.save()
            }
        }
        try DiveActivitySiteAssociation.normalizeOpenDiveMapCatalogSiteNames(modelContext: modelContext)
        try DiveActivitySiteAssociation.normalizeCatalogSiteCountries(modelContext: modelContext)
    }

    #if DEBUG
    static func resetCompletionFlagForTesting() {
        UserDefaults.standard.removeObject(forKey: completedKey)
    }
    #endif
}
