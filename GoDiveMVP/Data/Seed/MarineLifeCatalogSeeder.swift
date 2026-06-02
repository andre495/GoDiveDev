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
    var existingByUUID = Dictionary(uniqueKeysWithValues: existing.map { ($0.uuid, $0) })

    for dto in dtos {
      let mapped = MarineLifeMapper.map(dto)
      if let existingSpecies = existingByUUID[mapped.uuid] {
        applyTaxonomy(from: mapped, to: existingSpecies)
      } else {
        context.insert(mapped)
        existingByUUID[mapped.uuid] = mapped
      }
    }

    if context.hasChanges {
      try context.save()
    }
  }

  private static func applyTaxonomy(from source: MarineLife, to destination: MarineLife) {
    destination.commonName = source.commonName
    destination.featureImageURL = source.featureImageURL
    destination.scientificName = source.scientificName
    destination.category = source.category
    destination.subcategory = source.subcategory
    destination.aboutText = source.aboutText
    destination.minSizeMeters = source.minSizeMeters
    destination.maxSizeMeters = source.maxSizeMeters
    destination.avgDepthMeters = source.avgDepthMeters
  }
}
