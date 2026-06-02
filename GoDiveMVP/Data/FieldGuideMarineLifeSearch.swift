import Foundation

/// Filters Field Guide species by common name, scientific name, category, or subcategory.
enum FieldGuideMarineLifeSearch {

    nonisolated static func isFiltering(query: String) -> Bool {
        CatalogSubstringSearch.isFiltering(query: query)
    }

    nonisolated static func matches(_ entry: MarineLifeCatalogSnapshot, query: String) -> Bool {
        CatalogSubstringSearch.matchesAny(
            in: [
                entry.commonName,
                entry.scientificName,
                entry.category,
                entry.subcategory,
                entry.familyName,
                entry.distinctiveFeatures,
                entry.abundance,
                entry.habitatBehavior,
                entry.diverReaction,
                FieldGuideTaxonomy.categoryTitle(for: entry),
                FieldGuideTaxonomy.subcategoryTitle(for: entry),
            ],
            query: query
        )
    }

    nonisolated static func filtering(
        _ species: [MarineLifeCatalogSnapshot],
        query: String
    ) -> [MarineLifeCatalogSnapshot] {
        guard isFiltering(query: query) else { return species }
        return species.filter { matches($0, query: query) }
    }
}
