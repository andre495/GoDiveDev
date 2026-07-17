import Foundation
import SwiftData

/// Shared upsert / prune for catalog **`MarineLife`** rows (bundled seed + CDN).
enum MarineLifeCatalogUpsert: Sendable {
    struct Outcome: Equatable, Sendable {
        var upsertedCount: Int
        var prunedCount: Int
    }

    /// Upserts by **`uuid`**, marks ownership **catalog**, prunes catalog-owned rows missing from the payload
    /// (preserves user-created / legacy-preserved UUIDs via **`FieldGuideMarineLifeAddPresentation`**).
    @discardableResult
    static func apply(
        dtos: [MarineLifeDTO],
        modelContext: ModelContext
    ) throws -> Outcome {
        guard !dtos.isEmpty else {
            return Outcome(upsertedCount: 0, prunedCount: 0)
        }

        let existing = try modelContext.fetch(FetchDescriptor<MarineLife>())
        var existingByUUID: [String: MarineLife] = [:]
        for row in existing {
            if existingByUUID[row.uuid] == nil {
                existingByUUID[row.uuid] = row
            }
        }

        let payloadUUIDs = Set(dtos.map(\.uuid))
        var upserted = 0

        for dto in dtos {
            let mapped = MarineLifeMapper.map(dto)
            if let existingSpecies = existingByUUID[mapped.uuid] {
                applyCatalogFields(from: mapped, to: existingSpecies)
                upserted += 1
            } else {
                modelContext.insert(mapped)
                existingByUUID[mapped.uuid] = mapped
                upserted += 1
            }
        }

        var pruned = 0
        for species in existing where shouldPrune(species, payloadUUIDs: payloadUUIDs) {
            modelContext.delete(species)
            pruned += 1
        }

        if modelContext.hasChanges {
            try modelContext.save()
        }

        return Outcome(upsertedCount: upserted, prunedCount: pruned)
    }

    private static func applyCatalogFields(from source: MarineLife, to destination: MarineLife) {
        destination.commonName = source.commonName
        destination.featureImageURL = source.featureImageURL
        destination.featureImageResourceName = source.featureImageResourceName
        destination.featureModelResourceName = source.featureModelResourceName
        destination.scientificName = source.scientificName
        destination.category = source.category
        destination.subcategory = source.subcategory
        destination.familyName = source.familyName
        destination.aboutText = source.aboutText
        destination.minSizeMeters = source.minSizeMeters
        destination.maxSizeMeters = source.maxSizeMeters
        destination.minDepthMeters = source.minDepthMeters
        destination.maxDepthMeters = source.maxDepthMeters
        destination.avgDepthMeters = source.avgDepthMeters
        destination.distinctiveFeatures = source.distinctiveFeatures
        destination.abundance = source.abundance
        destination.habitatBehavior = source.habitatBehavior
        destination.diverReaction = source.diverReaction
        destination.ownership = .catalog
    }

    private static func shouldPrune(_ species: MarineLife, payloadUUIDs: Set<String>) -> Bool {
        guard !payloadUUIDs.contains(species.uuid) else { return false }
        return !FieldGuideMarineLifeAddPresentation.shouldPreserveOnCatalogReseed(uuid: species.uuid)
    }
}
