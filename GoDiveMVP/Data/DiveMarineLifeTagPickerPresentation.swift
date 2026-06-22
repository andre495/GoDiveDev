import Foundation

/// Toolbar and Fishial affordances on **`DiveMarineLifeMediaTagsSheet`**.
enum DiveMarineLifeTagSheetPresentation {
    nonisolated static var showsFishialIdentifyAction: Bool {
        FishialSecretsBootstrap.isConfigured
    }

    nonisolated static func fishialIdentifyIsActive(confirmedSpeciesName: String?) -> Bool {
        DiveActivityMediaPresentation.fishialIdentifyControlIsActive(
            confirmedSpeciesName: confirmedSpeciesName
        )
    }
}

/// Catalog filtering for the dive media **Tag marine life** picker sheet.
enum DiveMarineLifeTagPickerPresentation {

    nonisolated static let searchPlaceholder = "Search by name or group"
    nonisolated static let searchDebounceNanoseconds: UInt64 = 80_000_000

    struct RowDisplayData: Identifiable, Equatable, Sendable {
        var id: String { marineLifeUUID }
        let marineLifeUUID: String
        let commonName: String
        let trailingLabel: String
        let detailLine: String
        let featureImageURL: String
        let featureImageResourceName: String
        let isTagged: Bool
    }

    struct CatalogCache: Equatable, Sendable {
        let snapshots: [MarineLifeCatalogSnapshot]
        let searchableTextByUUID: [String: String]

        nonisolated static func make(from catalog: [MarineLife]) -> CatalogCache {
            let snapshots = catalog.map(\.fieldGuideCatalogSnapshot)
            var searchableTextByUUID: [String: String] = [:]
            searchableTextByUUID.reserveCapacity(snapshots.count)
            for snapshot in snapshots {
                searchableTextByUUID[snapshot.uuid] = FieldGuideMarineLifeSearch.precomputedSearchText(
                    for: snapshot
                )
            }
            return CatalogCache(
                snapshots: snapshots,
                searchableTextByUUID: searchableTextByUUID
            )
        }
    }

    nonisolated static func isFiltering(query: String) -> Bool {
        FieldGuideMarineLifeSearch.isFiltering(query: query)
    }

    nonisolated static func filtering(_ catalog: [MarineLife], query: String) -> [MarineLife] {
        let cache = CatalogCache.make(from: catalog)
        let matchingUUIDs = Set(
            filteredSnapshots(
                snapshots: cache.snapshots,
                searchableTextByUUID: cache.searchableTextByUUID,
                query: query
            ).map(\.uuid)
        )
        return catalog.filter { matchingUUIDs.contains($0.uuid) }
    }

    nonisolated static func makePickerRows(
        snapshots: [MarineLifeCatalogSnapshot],
        taggedUUIDs: Set<String>,
        unitSystem: DiveDisplayUnitSystem
    ) -> [RowDisplayData] {
        snapshots.map { snapshot in
            RowDisplayData(
                marineLifeUUID: snapshot.uuid,
                commonName: snapshot.commonName,
                trailingLabel: FieldGuidePresentation.listTrailingLabel(for: snapshot),
                detailLine: FieldGuidePresentation.listDetailLine(
                    scientificName: snapshot.scientificName,
                    sizeDepthLine: FieldGuidePresentation.sizeDepthLine(
                        for: snapshot,
                        unitSystem: unitSystem
                    )
                ),
                featureImageURL: snapshot.featureImageURL,
                featureImageResourceName: snapshot.featureImageResourceName,
                isTagged: taggedUUIDs.contains(snapshot.uuid)
            )
        }
    }

    nonisolated static func filteredPickerRows(
        allRows: [RowDisplayData],
        snapshots: [MarineLifeCatalogSnapshot],
        searchableTextByUUID: [String: String],
        query: String
    ) -> [RowDisplayData] {
        guard isFiltering(query: query) else { return allRows }

        let matchingUUIDs = Set(
            filteredSnapshots(
                snapshots: snapshots,
                searchableTextByUUID: searchableTextByUUID,
                query: query
            ).map(\.uuid)
        )
        return allRows.filter { matchingUUIDs.contains($0.marineLifeUUID) }
    }

    nonisolated static func rowMarkedTagged(
        _ row: RowDisplayData,
        isTagged: Bool
    ) -> RowDisplayData {
        RowDisplayData(
            marineLifeUUID: row.marineLifeUUID,
            commonName: row.commonName,
            trailingLabel: row.trailingLabel,
            detailLine: row.detailLine,
            featureImageURL: row.featureImageURL,
            featureImageResourceName: row.featureImageResourceName,
            isTagged: isTagged
        )
    }

    nonisolated static func filteredSnapshots(
        snapshots: [MarineLifeCatalogSnapshot],
        searchableTextByUUID: [String: String],
        query: String
    ) -> [MarineLifeCatalogSnapshot] {
        FieldGuideMarineLifeSearch.filteringIndexed(
            snapshots,
            searchableTextByUUID: searchableTextByUUID,
            query: query
        )
    }
}
