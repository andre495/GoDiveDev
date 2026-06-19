import Foundation
import SwiftData

/// One-time backfill linking existing dives and local catalog sites to the bundled OpenDiveMap reference.
enum DiveActivityOpenDiveMapSiteBackfill {
    private static let completedKey = "goDiveOpenDiveMapSiteLinkBackfillComplete"

    static func backfillIfNeeded(modelContext: ModelContext) throws {
        guard !UserDefaults.standard.bool(forKey: completedKey) else { return }
        _ = try DiveActivitySiteAssociation.backfillOpenDiveMapSiteLinks(modelContext: modelContext)
        UserDefaults.standard.set(true, forKey: completedKey)
    }

    #if DEBUG
    static func resetCompletionFlagForTesting() {
        UserDefaults.standard.removeObject(forKey: completedKey)
    }
    #endif
}
