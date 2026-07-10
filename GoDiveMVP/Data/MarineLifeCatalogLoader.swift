import Foundation
import SwiftData

/// Loads the full **`MarineLife`** catalog off the main actor, then re-binds rows on the UI **`ModelContext`**.
enum MarineLifeCatalogLoader: Sendable {

    nonisolated static func fetchSortedPersistentIDs(container: ModelContainer) async -> [PersistentIdentifier] {
        await Task.detached(priority: .utility) {
            let context = ModelContext(container)
            let rows = (try? context.fetch(
                FetchDescriptor<MarineLife>(sortBy: [SortDescriptor(\.commonName)])
            )) ?? []
            return rows.map(\.persistentModelID)
        }.value
    }

    @MainActor
    static func bindModels(
        persistentIDs: [PersistentIdentifier],
        modelContext: ModelContext
    ) -> [MarineLife] {
        persistentIDs.compactMap { modelContext.model(for: $0) as? MarineLife }
    }

    @MainActor
    static func loadSortedCatalog(modelContext: ModelContext) async -> [MarineLife] {
        await Task.yield()
        let container = modelContext.container
        let persistentIDs = await fetchSortedPersistentIDs(container: container)
        guard !Task.isCancelled else { return [] }
        return bindModels(persistentIDs: persistentIDs, modelContext: modelContext)
    }
}
