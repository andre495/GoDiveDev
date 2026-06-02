import Foundation

/// Species counts and lookups for the field guide browse hierarchy.
enum FieldGuideCatalogIndex {

    struct CategorySummary: Sendable, Identifiable, Equatable {
        var id: String { categoryID }
        let categoryID: String
        let speciesCount: Int
        let subcategoryCounts: [String: Int]
    }

    nonisolated static func summaries(for catalog: [MarineLifeCatalogSnapshot]) -> [CategorySummary] {
        var subCounts: [String: [String: Int]] = [:]
        var categoryTotals: [String: Int] = [:]

        for entry in catalog {
            let categoryID = FieldGuideTaxonomy.resolvedCategoryID(for: entry)
            let subcategoryID = FieldGuideTaxonomy.resolvedSubcategoryID(for: entry)
            categoryTotals[categoryID, default: 0] += 1
            subCounts[categoryID, default: [:]][subcategoryID, default: 0] += 1
        }

        return FieldGuideTaxonomy.categories.map { definition in
            CategorySummary(
                categoryID: definition.id,
                speciesCount: categoryTotals[definition.id, default: 0],
                subcategoryCounts: subCounts[definition.id, default: [:]]
            )
        }
    }

    nonisolated static func species(
        in categoryID: String,
        subcategoryID: String,
        catalog: [MarineLifeCatalogSnapshot]
    ) -> [MarineLifeCatalogSnapshot] {
        catalog.filter { entry in
            FieldGuideTaxonomy.resolvedCategoryID(for: entry) == FieldGuideTaxonomy.normalizedCategoryID(categoryID)
                && FieldGuideTaxonomy.resolvedSubcategoryID(for: entry) == FieldGuideTaxonomy.normalizedSubcategoryID(subcategoryID)
        }
        .sorted { $0.commonName.localizedCaseInsensitiveCompare($1.commonName) == .orderedAscending }
    }

    nonisolated static func species(
        in categoryID: String,
        catalog: [MarineLifeCatalogSnapshot]
    ) -> [MarineLifeCatalogSnapshot] {
        catalog.filter {
            FieldGuideTaxonomy.resolvedCategoryID(for: $0) == FieldGuideTaxonomy.normalizedCategoryID(categoryID)
        }
        .sorted { $0.commonName.localizedCaseInsensitiveCompare($1.commonName) == .orderedAscending }
    }
}
