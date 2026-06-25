import Foundation

/// Shared Field Guide species search copy + accessibility ids.
enum FieldGuideSpeciesSearchEnvironment {
    nonisolated static let searchPlaceholder = "Search Marine Life"
    nonisolated static let searchFieldAccessibilityIdentifier = "fieldGuideSpeciesSearchField"
    nonisolated static let cancelAccessibilityIdentifier = "fieldGuideSearchCancel"
}

/// Catalog species search rows for hub + category + subcategory browse.
enum FieldGuideSpeciesSearchResultsPresentation {
    nonisolated static func searchableTextByUUID(
        for catalogSnapshots: [MarineLifeCatalogSnapshot]
    ) -> [String: String] {
        var byUUID: [String: String] = [:]
        byUUID.reserveCapacity(catalogSnapshots.count)
        for entry in catalogSnapshots {
            byUUID[entry.uuid] = FieldGuideMarineLifeSearch.precomputedSearchText(for: entry)
        }
        return byUUID
    }

    nonisolated static func rowData(
        catalogSnapshots: [MarineLifeCatalogSnapshot],
        query: String,
        unitSystem: DiveDisplayUnitSystem
    ) -> [FieldGuidePresentation.MarineLifeRowDisplayData] {
        rowData(
            catalogSnapshots: catalogSnapshots,
            searchableTextByUUID: searchableTextByUUID(for: catalogSnapshots),
            query: query,
            unitSystem: unitSystem
        )
    }

    nonisolated static func rowData(
        catalogSnapshots: [MarineLifeCatalogSnapshot],
        searchableTextByUUID: [String: String],
        query: String,
        unitSystem: DiveDisplayUnitSystem
    ) -> [FieldGuidePresentation.MarineLifeRowDisplayData] {
        let filtered = FieldGuideMarineLifeSearch.filteringIndexed(
            catalogSnapshots,
            searchableTextByUUID: searchableTextByUUID,
            query: query
        )
        return FieldGuidePresentation.rowData(
            for: filtered,
            sightedMarineLifeUUIDs: [],
            unitSystem: unitSystem
        )
    }

    nonisolated static func isFiltering(query: String) -> Bool {
        FieldGuideMarineLifeSearch.isFiltering(query: query)
    }
}
