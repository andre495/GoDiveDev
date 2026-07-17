import Foundation
import SwiftData

/// Idempotent load of bundled **`marine_life_sample.json`** into the catalog (independent of dive mock seeding).
enum MarineLifeCatalogSeeder {
  static let bundledResourceName = "marine_life_sample"

  static func seedBundledCatalogIfNeeded(
    context: ModelContext,
    resourceName: String = bundledResourceName,
    resourceExtension: String = "json",
    bundle: Bundle = .main
  ) throws {
    let dtos = try MockDiveDataLoader.loadMarineLife(
      resourceName: resourceName,
      resourceExtension: resourceExtension,
      bundle: bundle
    )
    guard !dtos.isEmpty else { return }

    let existing = try context.fetch(FetchDescriptor<MarineLife>())
    var existingByUUID: [String: MarineLife] = [:]
    for row in existing {
      if existingByUUID[row.uuid] == nil {
        existingByUUID[row.uuid] = row
      }
    }

    let bundledUUIDs = Set(dtos.map(\.uuid))

    for dto in dtos {
      let mapped = MarineLifeMapper.map(dto)
      if let existingSpecies = existingByUUID[mapped.uuid] {
        applyCatalogFields(from: mapped, to: existingSpecies)
      } else {
        context.insert(mapped)
        existingByUUID[mapped.uuid] = mapped
      }
    }

    for species in existing where shouldPrune(species, bundledUUIDs: bundledUUIDs) {
      context.delete(species)
    }

    if context.hasChanges {
      try context.save()
    }
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

  private static func shouldPrune(_ species: MarineLife, bundledUUIDs: Set<String>) -> Bool {
    guard !bundledUUIDs.contains(species.uuid) else { return false }
    return !FieldGuideMarineLifeAddPresentation.shouldPreserveOnCatalogReseed(uuid: species.uuid)
  }
}
