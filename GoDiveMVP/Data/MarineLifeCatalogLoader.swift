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

    /// Lightweight Home enrich map — no MainActor **`bindModels`** of thousands of rows.
    nonisolated static func fetchCommonNameByUUID(container: ModelContainer) async -> [String: String] {
        await Task.detached(priority: .utility) {
            let context = ModelContext(container)
            let rows = (try? context.fetch(FetchDescriptor<MarineLife>())) ?? []
            var map: [String: String] = [:]
            map.reserveCapacity(rows.count)
            for row in rows {
                let uuid = row.uuid
                guard !uuid.isEmpty else { continue }
                map[uuid] = row.commonName
            }
            return map
        }.value
    }

    @MainActor
    static func bindModels(
        persistentIDs: [PersistentIdentifier],
        modelContext: ModelContext
    ) -> [MarineLife] {
        persistentIDs.compactMap { modelContext.model(for: $0) as? MarineLife }
    }

    /// Binds only the catalog rows needed for Home overlays / leaderboards (owner-tagged UUIDs).
    @MainActor
    static func bindModels(
        uuids: Set<String>,
        modelContext: ModelContext
    ) -> [MarineLife] {
        guard !uuids.isEmpty else { return [] }
        let uuidList = Array(uuids)
        let descriptor = FetchDescriptor<MarineLife>(
            predicate: #Predicate<MarineLife> { uuidList.contains($0.uuid) }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    @MainActor
    static func bindModel(
        uuid: String,
        modelContext: ModelContext
    ) -> MarineLife? {
        let trimmed = uuid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var descriptor = FetchDescriptor<MarineLife>(
            predicate: #Predicate<MarineLife> { $0.uuid == trimmed }
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first
    }

    @MainActor
    static func loadSortedCatalog(modelContext: ModelContext) async -> [MarineLife] {
        await Task.yield()
        let container = modelContext.container
        let persistentIDs = await fetchSortedPersistentIDs(container: container)
        guard !Task.isCancelled else { return [] }
        return bindModels(persistentIDs: persistentIDs, modelContext: modelContext)
    }

    @MainActor
    static func commonNameByUUID(from catalog: [MarineLife]) -> [String: String] {
        Dictionary(
            catalog.map { ($0.uuid, $0.commonName) },
            uniquingKeysWith: { first, _ in first }
        )
    }
}
