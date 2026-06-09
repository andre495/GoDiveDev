import Foundation

/// Rows for marine-life already tagged on a dive media item.
enum MarineLifeMediaTagPresentation {

    nonisolated static let sectionTitle = "Marine life"
    nonisolated static let untaggedPrompt = "Tag marine life spotted in this photo."
    nonisolated static let largeDetentUntaggedPrompt =
        "No fish tagged on this photo yet. Pull the sheet to medium height and tap the fish button to tag what you spotted."

    struct DescriptionSection: Identifiable, Equatable, Sendable {
        var id: String { title }
        let title: String
        let body: String
    }

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

    nonisolated static func taggedCommonNames(from rows: [TaggedSpeciesRow]) -> [String] {
        rows.map(\.commonName)
    }

    nonisolated static func mediumDetentAccessibilityLabel(taggedNames: [String]) -> String {
        guard !taggedNames.isEmpty else { return untaggedPrompt }
        return "Marine life: \(taggedNames.joined(separator: ", "))"
    }

    nonisolated static func resolvedTaggedSpecies(
        mediaPhotoID: UUID,
        sightings: [SightingInstance],
        catalog: [MarineLife]
    ) -> [MarineLife] {
        let catalogByUUID = Dictionary(uniqueKeysWithValues: catalog.map { ($0.uuid, $0) })
        var seenUUIDs = Set<String>()

        return sightings
            .filter { $0.mediaPhotoID == mediaPhotoID }
            .compactMap { sighting -> MarineLife? in
                guard !seenUUIDs.contains(sighting.marineLifeUUID) else { return nil }
                seenUUIDs.insert(sighting.marineLifeUUID)
                return sighting.marineLife ?? catalogByUUID[sighting.marineLifeUUID]
            }
            .sorted {
                $0.commonName.localizedCaseInsensitiveCompare($1.commonName) == .orderedAscending
            }
    }

    nonisolated static func descriptionSections(for species: MarineLife) -> [DescriptionSection] {
        var sections: [DescriptionSection] = []
        if !species.distinctiveFeatures.isEmpty {
            sections.append(DescriptionSection(title: "Distinctive features", body: species.distinctiveFeatures))
        }
        if !species.abundance.isEmpty {
            sections.append(DescriptionSection(title: "Abundance", body: species.abundance))
        }
        if !species.habitatBehavior.isEmpty {
            sections.append(DescriptionSection(title: "Habitat & behavior", body: species.habitatBehavior))
        }
        if !species.diverReaction.isEmpty {
            sections.append(DescriptionSection(title: "Diver reaction", body: species.diverReaction))
        }
        if !species.aboutText.isEmpty {
            sections.append(DescriptionSection(title: "About", body: species.aboutText))
        }
        return sections
    }
}
