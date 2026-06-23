import Foundation

/// Filters Field Guide subcategory rows on category detail pages.
enum FieldGuideSubcategorySearchPresentation {

    nonisolated static func isFiltering(query: String) -> Bool {
        CatalogSubstringSearch.isFiltering(query: query)
    }

    nonisolated static func matches(_ subcategory: FieldGuideTaxonomy.Subcategory, query: String) -> Bool {
        let haystacks = [subcategory.title, subcategory.hint]
        if CatalogSubstringSearch.matchesAny(in: haystacks, query: query) {
            return true
        }
        guard let needle = CatalogSubstringSearch.normalizedQuery(query) else { return true }
        let tokens = needle.split(separator: " ").map(String.init)
        guard tokens.count > 1 else { return false }
        let combined = haystacks
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .joined(separator: " ")
        return tokens.allSatisfy { combined.contains($0) }
    }

    nonisolated static func filtering(
        _ subcategories: [FieldGuideTaxonomy.Subcategory],
        query: String
    ) -> [FieldGuideTaxonomy.Subcategory] {
        guard isFiltering(query: query) else { return subcategories }
        return subcategories.filter { matches($0, query: query) }
    }

    nonisolated static func showsAllSpeciesFallback(
        subcategories: [FieldGuideTaxonomy.Subcategory],
        speciesCount: Int,
        query: String
    ) -> Bool {
        guard subcategories.isEmpty, speciesCount > 0 else { return false }
        guard isFiltering(query: query) else { return true }
        return CatalogSubstringSearch.matchesAny(
            in: ["All species", "Browse every species in this category"],
            query: query
        )
    }
}
