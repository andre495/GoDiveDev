import Foundation

/// Filters Field Guide species by common name, scientific name, or category.
enum FieldGuideMarineLifeSearch {

    nonisolated static func isFiltering(query: String) -> Bool {
        CatalogSubstringSearch.isFiltering(query: query)
    }

    nonisolated static func matches(_ entry: MarineLifeCatalogSnapshot, query: String) -> Bool {
        CatalogSubstringSearch.matchesAny(
            in: [entry.commonName, entry.scientificName, entry.category],
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
