import Foundation
import SwiftData

/// Idempotent load of bundled **`marine_life.json`** into the catalog (independent of dive mock seeding).
enum MarineLifeCatalogSeeder {
  static let bundledResourceName = "marine_life"

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
    _ = try MarineLifeCatalogUpsert.apply(dtos: dtos, modelContext: context)
  }
}
