import Foundation

struct TripDetailMarineLifeCarouselItem: Equatable, Identifiable, Sendable {
    var id: String { marineLifeUUID }
    let marineLifeUUID: String
    let catalogSnapshot: MarineLifeCatalogSnapshot
    /// **`FieldGuideCategoryAccent`** lookup key.
    let categoryID: String
    let sightingCountLabel: String
    let hasCatalogEntry: Bool
}

enum TripDetailMarineLifePresentation: Sendable {

    nonisolated static func carouselItems(
        from summaries: [DiveTripMarineLifeSummary],
        catalogByUUID: [String: MarineLifeCatalogSnapshot]
    ) -> [TripDetailMarineLifeCarouselItem] {
        summaries.map { summary in
            if let snapshot = catalogByUUID[summary.marineLifeUUID] {
                return TripDetailMarineLifeCarouselItem(
                    marineLifeUUID: summary.marineLifeUUID,
                    catalogSnapshot: snapshot,
                    categoryID: FieldGuideTaxonomy.resolvedCategoryID(for: snapshot),
                    sightingCountLabel: sightingCountLabel(count: summary.sightingCount),
                    hasCatalogEntry: true
                )
            }

            let fallbackSnapshot = MarineLifeCatalogSnapshot(
                uuid: summary.marineLifeUUID,
                commonName: summary.commonName,
                scientificName: "",
                category: "",
                subcategory: "",
                featureImageURL: "",
                minSizeMeters: 0,
                maxSizeMeters: 0,
                avgDepthMeters: 0
            )
            return TripDetailMarineLifeCarouselItem(
                marineLifeUUID: summary.marineLifeUUID,
                catalogSnapshot: fallbackSnapshot,
                categoryID: "fish",
                sightingCountLabel: sightingCountLabel(count: summary.sightingCount),
                hasCatalogEntry: false
            )
        }
    }

    @MainActor
    static func carouselItems(
        from summaries: [DiveTripMarineLifeSummary],
        catalog: [MarineLife],
        unitSystem: DiveDisplayUnitSystem
    ) -> [TripDetailMarineLifeCarouselItem] {
        let catalogByUUID = Dictionary(uniqueKeysWithValues: catalog.map {
            ($0.uuid, $0.fieldGuideCatalogSnapshot)
        })
        return carouselItems(from: summaries, catalogByUUID: catalogByUUID)
    }

    nonisolated static func sightingCountLabel(count: Int) -> String {
        switch count {
        case 0:
            return "No sightings"
        case 1:
            return "1 sighting"
        default:
            return "\(count) sightings"
        }
    }
}
