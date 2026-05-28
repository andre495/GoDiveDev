import Foundation

/// Rows for marine-life already tagged on a dive media item.
enum MarineLifeMediaTagPresentation {

    struct TaggedSpeciesRow: Identifiable, Equatable, Sendable {
        var id: String { marineLifeUUID }
        let marineLifeUUID: String
        let commonName: String
        let scientificName: String
        let category: String
        let featureImageURL: String
        let detailLine: String
    }

    nonisolated static func taggedRows(
        mediaPhotoID: UUID,
        sightings: [SightingInstance],
        catalog: [MarineLife],
        unitSystem: DiveDisplayUnitSystem
    ) -> [TaggedSpeciesRow] {
        let catalogByUUID = Dictionary(uniqueKeysWithValues: catalog.map { ($0.uuid, $0) })
        var seenUUIDs = Set<String>()

        return sightings
            .filter { $0.mediaPhotoID == mediaPhotoID }
            .compactMap { sighting -> TaggedSpeciesRow? in
                guard !seenUUIDs.contains(sighting.marineLifeUUID) else { return nil }
                seenUUIDs.insert(sighting.marineLifeUUID)

                let species = sighting.marineLife ?? catalogByUUID[sighting.marineLifeUUID]
                guard let species else { return nil }

                let snapshot = species.fieldGuideCatalogSnapshot
                return TaggedSpeciesRow(
                    marineLifeUUID: species.uuid,
                    commonName: species.commonName,
                    scientificName: species.scientificName,
                    category: species.category,
                    featureImageURL: species.featureImageURL,
                    detailLine: FieldGuidePresentation.sizeDepthLine(
                        for: snapshot,
                        unitSystem: unitSystem
                    )
                )
            }
            .sorted {
                $0.commonName.localizedCaseInsensitiveCompare($1.commonName) == .orderedAscending
            }
    }
}
