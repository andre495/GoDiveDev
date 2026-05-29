import Foundation
import SwiftData

/// Keeps the **`DiveSite`** catalog aligned with the log (Explore map pins, etc.).
enum DiveSiteCatalogMaintenance {

    /// Deletes catalog sites that have no linked **`DiveActivity`** rows (e.g. last dive at a user-added site was removed).
    ///
    /// Uses **`diveSiteID`** predicates (not **`diveActivities`**) so **`DiveBackgroundDeletionWorker`** (**`@ModelActor`**) can call this without crossing the main actor.
    /// After a single dive delete, only the site that was linked to that dive may become orphaned.
    nonisolated static func deleteSiteIfOrphaned(
        siteID: UUID?,
        modelContext: ModelContext,
        saveChanges: Bool = true
    ) throws {
        guard let siteID else { return }
        var activityDescriptor = FetchDescriptor<DiveActivity>(
            predicate: #Predicate<DiveActivity> { $0.diveSiteID == siteID }
        )
        activityDescriptor.fetchLimit = 1
        guard try modelContext.fetch(activityDescriptor).isEmpty else { return }

        var siteDescriptor = FetchDescriptor<DiveSite>(
            predicate: #Predicate<DiveSite> { $0.id == siteID }
        )
        siteDescriptor.fetchLimit = 1
        guard let site = try modelContext.fetch(siteDescriptor).first else { return }
        modelContext.delete(site)
        if saveChanges {
            try modelContext.save()
        }
    }

    nonisolated static func deleteSitesWithNoLinkedDives(modelContext: ModelContext) throws {
        let sites = try modelContext.fetch(FetchDescriptor<DiveSite>())
        var deletedAny = false
        for site in sites {
            let siteID = site.id
            var activityDescriptor = FetchDescriptor<DiveActivity>(
                predicate: #Predicate<DiveActivity> { $0.diveSiteID == siteID }
            )
            activityDescriptor.fetchLimit = 1
            let hasLinkedDive = try !modelContext.fetch(activityDescriptor).isEmpty
            if !hasLinkedDive {
                modelContext.delete(site)
                deletedAny = true
            }
        }
        if deletedAny {
            try modelContext.save()
        }
    }
}
