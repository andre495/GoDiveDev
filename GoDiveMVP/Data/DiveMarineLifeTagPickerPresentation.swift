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

    nonisolated static func isFiltering(query: String) -> Bool {
        FieldGuideMarineLifeSearch.isFiltering(query: query)
    }

    nonisolated static func filtering(_ catalog: [MarineLife], query: String) -> [MarineLife] {
        guard isFiltering(query: query) else { return catalog }

        let matchingUUIDs = Set(
            FieldGuideMarineLifeSearch.filtering(
                catalog.map(\.fieldGuideCatalogSnapshot),
                query: query
            ).map(\.uuid)
        )
        return catalog.filter { matchingUUIDs.contains($0.uuid) }
    }
}
