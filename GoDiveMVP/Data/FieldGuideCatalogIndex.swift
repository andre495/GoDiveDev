import Foundation

/// Field guide hub row payload — top-level so **Hashable** stays **nonisolated** (Swift 6).
struct FieldGuideCategorySummary: Sendable, Identifiable {
    var id: String { categoryID }
    let categoryID: String
    let speciesCount: Int
    let subcategoryCounts: [String: Int]
}

extension FieldGuideCategorySummary: Equatable {
    /// Explicit **nonisolated** equality for Swift Testing **`#expect`** (Swift 6).
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.categoryID == rhs.categoryID
            && lhs.speciesCount == rhs.speciesCount
            && lhs.subcategoryCounts == rhs.subcategoryCounts
    }
}

extension FieldGuideCategorySummary: Hashable {
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(categoryID)
        hasher.combine(speciesCount)
        hasher.combine(subcategoryCounts)
    }
}

/// Species counts and lookups for the field guide browse hierarchy.
enum FieldGuideCatalogIndex {

    typealias CategorySummary = FieldGuideCategorySummary

    /// Precomputed species rows for a subcategory mosaic — carried in navigation so push does not re-filter the catalog.
    struct SubcategoryBrowsePayload: Sendable, Equatable, Hashable {
        let categoryID: String
        let subcategoryID: String
        let title: String
        let species: [MarineLifeCatalogSnapshot]
    }

    typealias SubcategorySpeciesIndex = [String: [String: [MarineLifeCatalogSnapshot]]]

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

    nonisolated static func subcategorySpeciesIndex(
        for catalog: [MarineLifeCatalogSnapshot]
    ) -> SubcategorySpeciesIndex {
        var buckets: SubcategorySpeciesIndex = [:]

        for entry in catalog {
            let categoryID = FieldGuideTaxonomy.resolvedCategoryID(for: entry)
            let subcategoryID = FieldGuideTaxonomy.resolvedSubcategoryID(for: entry)
            buckets[categoryID, default: [:]][subcategoryID, default: []].append(entry)
        }

        for categoryID in buckets.keys {
            guard var subcategoryBuckets = buckets[categoryID] else { continue }
            for subcategoryID in subcategoryBuckets.keys {
                subcategoryBuckets[subcategoryID]?.sort {
                    $0.commonName.localizedCaseInsensitiveCompare($1.commonName) == .orderedAscending
                }
            }
            buckets[categoryID] = subcategoryBuckets
        }

        return buckets
    }

    nonisolated static func browsePayload(
        categoryID: String,
        subcategoryID: String,
        speciesIndex: SubcategorySpeciesIndex
    ) -> SubcategoryBrowsePayload {
        let normalizedCategoryID = FieldGuideTaxonomy.normalizedCategoryID(categoryID)
        let normalizedSubcategoryID = FieldGuideTaxonomy.normalizedSubcategoryID(subcategoryID)
        let species: [MarineLifeCatalogSnapshot]
        if normalizedSubcategoryID.isEmpty {
            species = (speciesIndex[normalizedCategoryID] ?? [:])
                .values
                .flatMap { $0 }
                .sorted {
                    $0.commonName.localizedCaseInsensitiveCompare($1.commonName) == .orderedAscending
                }
        } else {
            species = speciesIndex[normalizedCategoryID]?[normalizedSubcategoryID] ?? []
        }
        let title: String
        if normalizedSubcategoryID.isEmpty {
            title = FieldGuideTaxonomy.category(id: categoryID)?.title ?? "Species"
        } else {
            title = FieldGuideTaxonomy.subcategory(
                categoryID: categoryID,
                subcategoryID: subcategoryID
            )?.title ?? "Species"
        }

        return SubcategoryBrowsePayload(
            categoryID: normalizedCategoryID,
            subcategoryID: normalizedSubcategoryID,
            title: title,
            species: species
        )
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

    /// Whether a catalog snapshot has a bundled or remote feature photo.
    nonisolated static func speciesHasCatalogImage(_ snapshot: MarineLifeCatalogSnapshot) -> Bool {
        FieldGuideMarineLifeBundledImagePresentation.imageSource(
            featureImageResourceName: snapshot.featureImageResourceName,
            featureImageURL: snapshot.featureImageURL
        ) != .none
    }

    /// First species in a subcategory (alphabetical) that has a catalog photo — any species in the group otherwise.
    nonisolated static func representativeSpecies(
        categoryID: String,
        subcategoryID: String,
        speciesIndex: SubcategorySpeciesIndex
    ) -> MarineLifeCatalogSnapshot? {
        let species = species(
            categoryID: categoryID,
            subcategoryID: subcategoryID,
            speciesIndex: speciesIndex
        )
        return species.first(where: speciesHasCatalogImage(_:)) ?? species.first
    }

    /// First species in a category (alphabetical) that has a catalog photo — for the **All species** row.
    nonisolated static func representativeSpecies(
        categoryID: String,
        speciesIndex: SubcategorySpeciesIndex
    ) -> MarineLifeCatalogSnapshot? {
        representativeSpecies(
            categoryID: categoryID,
            subcategoryID: "",
            speciesIndex: speciesIndex
        )
    }

    nonisolated private static func species(
        categoryID: String,
        subcategoryID: String,
        speciesIndex: SubcategorySpeciesIndex
    ) -> [MarineLifeCatalogSnapshot] {
        browsePayload(
            categoryID: categoryID,
            subcategoryID: subcategoryID,
            speciesIndex: speciesIndex
        ).species
    }
}
