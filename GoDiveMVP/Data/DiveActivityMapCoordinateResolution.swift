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

    nonisolated static func fetchAllCatalogSitePersistentIDs(container: ModelContainer) async -> [PersistentIdentifier] {
        await Task.detached(priority: .utility) {
            let context = ModelContext(container)
            let rows = (try? context.fetch(FetchDescriptor<DiveSite>())) ?? []
            return rows.map(\.persistentModelID)
        }.value
    }

    @MainActor
    static func loadCatalogSitesIfNeeded(
        for activity: DiveActivity,
        modelContext: ModelContext,
        container: ModelContainer
    ) async -> [DiveSite] {
        guard needsCatalogSiteLookup(for: activity) else { return [] }
        let persistentIDs = await fetchAllCatalogSitePersistentIDs(container: container)
        guard !Task.isCancelled else { return [] }
        return persistentIDs.compactMap { modelContext.model(for: $0) as? DiveSite }
    }
}
