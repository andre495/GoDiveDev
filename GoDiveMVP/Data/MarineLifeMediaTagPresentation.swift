import CoreGraphics
import Foundation

/// Rows for marine-life already tagged on a dive media item.
enum MarineLifeMediaTagPresentation {

    nonisolated static let sectionTitle = "Marine life"
    nonisolated static let speciesRowThumbnailWidth: CGFloat = 96
    nonisolated static let speciesRowThumbnailHeight: CGFloat = 72
    /// Max visible characters on oval marine-life chips before an ellipsis suffix.
    nonisolated static let chipTitleMaxLength = 25
    /// Horizontal gap between species ovals (**medium** + **large** media detents).
    nonisolated static let chipRowSpacing: CGFloat = AppTheme.Spacing.sm

    nonisolated static let untaggedPrompt = "Tag marine life spotted in this photo."
    nonisolated static let largeDetentUntaggedPrompt =
        "No fish tagged on this photo yet. Tap + to tag what you spotted."

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
        let featureImageResourceName: String
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

                let species = catalogByUUID[sighting.marineLifeUUID]
                guard let species else { return nil }

                let snapshot = species.fieldGuideCatalogSnapshot
                return TaggedSpeciesRow(
                    marineLifeUUID: species.uuid,
                    commonName: species.commonName,
                    scientificName: species.scientificName,
                    category: species.category,
                    featureImageURL: species.featureImageURL,
                    featureImageResourceName: species.featureImageResourceName,
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

    nonisolated static func chipDisplayTitle(for commonName: String) -> String {
        let trimmed = commonName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > chipTitleMaxLength else { return trimmed }
        return String(trimmed.prefix(chipTitleMaxLength)) + "…"
    }

    /// Field Guide entry affordance under species overview on Media **large** / fullscreen overlay.
    nonisolated static let learnMoreLabel = "Learn More"

    nonisolated static func mediumDetentAccessibilityLabel(taggedNames: [String]) -> String {
        guard !taggedNames.isEmpty else { return untaggedPrompt }
        return "Marine life: \(taggedNames.joined(separator: ", "))"
    }

    nonisolated static func hasTaggedSpeciesOnMedia(
        mediaPhotoID: UUID,
        sightings: [SightingInstance]
    ) -> Bool {
        var seenSpeciesUUIDs = Set<String>()
        for sighting in sightings where sighting.mediaPhotoID == mediaPhotoID {
            guard !seenSpeciesUUIDs.contains(sighting.marineLifeUUID) else { continue }
            seenSpeciesUUIDs.insert(sighting.marineLifeUUID)
            return true
        }
        return false
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
                return catalogByUUID[sighting.marineLifeUUID]
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
