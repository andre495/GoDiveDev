import Foundation

/// Off-main Field Guide hub index from already-captured catalog snapshots.
enum FieldGuideCatalogCacheBuild: Sendable {
    struct Output: Sendable {
        let snapshots: [MarineLifeCatalogSnapshot]
        let categorySummaries: [FieldGuideCatalogIndex.CategorySummary]
        let subcategorySpeciesIndex: FieldGuideCatalogIndex.SubcategorySpeciesIndex
    }

    /// Builds hub summaries + subcategory mosaic index. Call from **`Task.detached`**.
    nonisolated static func make(snapshots: [MarineLifeCatalogSnapshot]) -> Output {
        Output(
            snapshots: snapshots,
            categorySummaries: FieldGuideCatalogIndex.summaries(for: snapshots),
            subcategorySpeciesIndex: FieldGuideCatalogIndex.subcategorySpeciesIndex(for: snapshots)
        )
    }
}
