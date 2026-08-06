import Foundation
import SwiftData

/// Idempotent load of bundled **`marine_life.json`** into the catalog (independent of dive mock seeding).
enum MarineLifeCatalogSeeder {
    static let bundledResourceName = "marine_life"
    /// SHA-256 of the last successfully applied bundled catalog payload.
    nonisolated static let appliedFingerprintDefaultsKey = "godive.marineLife.bundledSeed.sha256"

    static func seedBundledCatalogIfNeeded(
        context: ModelContext,
        resourceName: String = bundledResourceName,
        resourceExtension: String = "json",
        bundle: Bundle = .main,
        userDefaults: UserDefaults = .standard
    ) throws {
        guard let fileURL = bundle.url(forResource: resourceName, withExtension: resourceExtension) else {
            return
        }
        let data = try Data(contentsOf: fileURL)
        let fingerprint = CatalogCDNChecksum.sha256Hex(data)

        let catalogCount = try context.fetchCount(FetchDescriptor<MarineLife>())
        if catalogCount > 0,
           userDefaults.string(forKey: appliedFingerprintDefaultsKey) == fingerprint
        {
            return
        }

        let decoder = JSONDecoder()
        let dtos = try decoder.decode([MarineLifeDTO].self, from: data)
        _ = try MarineLifeCatalogUpsert.apply(dtos: dtos, modelContext: context)
        userDefaults.set(fingerprint, forKey: appliedFingerprintDefaultsKey)
    }

    static func resetAppliedFingerprintForTesting(userDefaults: UserDefaults = .standard) {
        userDefaults.removeObject(forKey: appliedFingerprintDefaultsKey)
    }
}
