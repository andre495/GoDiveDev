import Foundation
import SwiftData

/// When **`ViewSingleActivity`** needs catalog rows to resolve a map coordinate.
enum DiveActivityMapCoordinateResolution: Sendable {

    nonisolated static func needsCatalogSiteLookup(for activity: DiveActivity) -> Bool {
        guard activity.siteCoordinate == nil else { return false }
        if let entry = activity.entryCoordinate, DiveMapCoordinateResolver.isUsable(entry) {
            return false
        }
        guard let siteName = activity.siteName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !siteName.isEmpty
        else { return false }
        return true
    }

    @MainActor
    static func loadCatalogSitesIfNeeded(
        for activity: DiveActivity,
        modelContext: ModelContext
    ) throws -> [DiveSite] {
        guard needsCatalogSiteLookup(for: activity) else { return [] }
        return try modelContext.fetch(FetchDescriptor<DiveSite>())
    }
}
