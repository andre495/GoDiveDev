import Foundation
import SwiftData

/// Loads the full **`DiveSite`** catalog off the main actor, then re-binds rows on the UI **`ModelContext`**.
enum DiveSiteCatalogLoader: Sendable {

    nonisolated static func fetchSortedPersistentIDs(container: ModelContainer) async -> [PersistentIdentifier] {
        await Task.detached(priority: .utility) {
            let context = ModelContext(container)
            let rows = (try? context.fetch(
                FetchDescriptor<DiveSite>(sortBy: [SortDescriptor(\.siteName)])
            )) ?? []
            return rows.map(\.persistentModelID)
        }.value
    }

    @MainActor
    static func bindModels(
        persistentIDs: [PersistentIdentifier],
        modelContext: ModelContext
    ) -> [DiveSite] {
        persistentIDs.compactMap { modelContext.model(for: $0) as? DiveSite }
    }

    @MainActor
    static func loadSortedCatalog(modelContext: ModelContext) async -> [DiveSite] {
        await Task.yield()
        let container = modelContext.container
        let persistentIDs = await fetchSortedPersistentIDs(container: container)
        guard !Task.isCancelled else { return [] }
        return bindModels(persistentIDs: persistentIDs, modelContext: modelContext)
    }
}
