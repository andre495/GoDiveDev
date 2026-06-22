import Foundation
import SwiftData

/// One-time backfill linking existing dives and local catalog sites to the bundled OpenDiveMap reference.
enum DiveActivityOpenDiveMapSiteBackfill {
    private static let completedKey = "goDiveOpenDiveMapSiteLinkBackfillComplete"

    static func backfillIfNeeded(modelContext: ModelContext) throws {
        if !UserDefaults.standard.bool(forKey: completedKey) {
            _ = try DiveActivitySiteAssociation.backfillOpenDiveMapSiteLinks(modelContext: modelContext)
            UserDefaults.standard.set(true, forKey: completedKey)
        }
        try DiveActivitySiteAssociation.normalizeOpenDiveMapCatalogSiteNames(modelContext: modelContext)
    }

    #if DEBUG
    static func resetCompletionFlagForTesting() {
        UserDefaults.standard.removeObject(forKey: completedKey)
    }
    #endif
}
