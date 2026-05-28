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
    var existingUUIDs = Set(existing.map(\.uuid))

    for dto in dtos {
      let species = MarineLifeMapper.map(dto)
      guard !existingUUIDs.contains(species.uuid) else { continue }
      context.insert(species)
      existingUUIDs.insert(species.uuid)
    }

    if context.hasChanges {
      try context.save()
    }
  }
}
