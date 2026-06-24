import Foundation

/// Shared Field Guide species search copy + accessibility ids.
enum FieldGuideSpeciesSearchEnvironment {
    nonisolated static let searchPlaceholder = "Search Marine Life"
    nonisolated static let searchFieldAccessibilityIdentifier = "fieldGuideSpeciesSearchField"
    nonisolated static let cancelAccessibilityIdentifier = "fieldGuideSearchCancel"
}

/// Catalog species search rows for hub + category + subcategory browse.
enum FieldGuideSpeciesSearchResultsPresentation {
    nonisolated static func rowData(
        catalogSnapshots: [MarineLifeCatalogSnapshot],
        query: String,
        unitSystem: DiveDisplayUnitSystem
    ) -> [FieldGuidePresentation.MarineLifeRowDisplayData] {
        FieldGuidePresentation.rowData(
            for: FieldGuideMarineLifeSearch.filtering(catalogSnapshots, query: query),
            sightedMarineLifeUUIDs: [],
            unitSystem: unitSystem
        )
    }

    nonisolated static func isFiltering(query: String) -> Bool {
        FieldGuideMarineLifeSearch.isFiltering(query: query)
    }
}
