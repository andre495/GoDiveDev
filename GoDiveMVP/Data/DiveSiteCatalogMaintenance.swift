import Foundation
import SwiftData

/// Keeps the **`DiveSite`** catalog aligned with the log (Explore map pins, etc.).
enum DiveSiteCatalogMaintenance {

    /// Deletes catalog sites that have no linked **`DiveActivity`** rows (e.g. last dive at a user-added site was removed).
    static func deleteSitesWithNoLinkedDives(modelContext: ModelContext) throws {
        let sites = try modelContext.fetch(FetchDescriptor<DiveSite>())
        var deletedAny = false
        for site in sites where site.diveActivities.isEmpty {
            modelContext.delete(site)
            deletedAny = true
        }
        if deletedAny {
            try modelContext.save()
        }
    }
}
