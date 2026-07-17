import Foundation
import SwiftData

/// Idempotent ownership backfill for hybrid catalog rows (Phase 1).
enum AppSwiftDataOwnershipBackfill {

    static func backfillIfNeeded(modelContext: ModelContext) throws {
        let marineLife = try modelContext.fetch(FetchDescriptor<MarineLife>())
        for species in marineLife {
            let inferred = MarineLifeOwnership.inferred(fromUUID: species.uuid)
            if species.ownershipRaw != inferred.rawValue {
                species.ownershipRaw = inferred.rawValue
            }
        }

        let sites = try modelContext.fetch(FetchDescriptor<DiveSite>())
        for site in sites {
            let inferred = DiveSiteOwnership.inferred(fromSiteTags: site.siteTags)
            if site.ownershipRaw != inferred.rawValue {
                site.ownershipRaw = inferred.rawValue
            }
        }

        if modelContext.hasChanges {
            try modelContext.save()
        }
    }
}
