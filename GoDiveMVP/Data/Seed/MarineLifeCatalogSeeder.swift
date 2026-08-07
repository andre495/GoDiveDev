import Foundation
import SwiftData

/// Idempotent load of bundled **`marine_life.json`** into the catalog (independent of dive mock seeding).
enum MarineLifeCatalogSeeder {
    static let bundledResourceName = "marine_life"
    /// SHA-256 of the last successfully applied bundled catalog payload.
    nonisolated static let appliedFingerprintDefaultsKey = "godive.marineLife.bundledSeed.sha256"
    /// File size + modification date of the bundled JSON when the fingerprint was applied.
    /// Lets launch skip reading ~700 KB when the resource is unchanged.
    nonisolated static let appliedResourceAttributesDefaultsKey = "godive.marineLife.bundledSeed.resourceAttributes"

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

        let catalogCount = try context.fetchCount(FetchDescriptor<MarineLife>())
        let currentAttributes = resourceAttributesToken(at: fileURL)
        if catalogCount > 0,
           userDefaults.string(forKey: appliedFingerprintDefaultsKey) != nil,
           let currentAttributes,
           userDefaults.string(forKey: appliedResourceAttributesDefaultsKey) == currentAttributes
        {
            return
        }

        let data = try Data(contentsOf: fileURL)
        let fingerprint = CatalogCDNChecksum.sha256Hex(data)

        if catalogCount > 0,
           userDefaults.string(forKey: appliedFingerprintDefaultsKey) == fingerprint
        {
            if let currentAttributes {
                userDefaults.set(currentAttributes, forKey: appliedResourceAttributesDefaultsKey)
            }
            return
        }

        let decoder = JSONDecoder()
        let dtos = try decoder.decode([MarineLifeDTO].self, from: data)
        _ = try MarineLifeCatalogUpsert.apply(dtos: dtos, modelContext: context)
        userDefaults.set(fingerprint, forKey: appliedFingerprintDefaultsKey)
        if let currentAttributes {
            userDefaults.set(currentAttributes, forKey: appliedResourceAttributesDefaultsKey)
        }
    }

    static func resetAppliedFingerprintForTesting(userDefaults: UserDefaults = .standard) {
        userDefaults.removeObject(forKey: appliedFingerprintDefaultsKey)
        userDefaults.removeObject(forKey: appliedResourceAttributesDefaultsKey)
    }

    /// Stable token for “same bundled file as last apply” without hashing contents.
    nonisolated static func resourceAttributesToken(at fileURL: URL) -> String? {
        guard
            let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
            let fileSize = values.fileSize,
            let modificationDate = values.contentModificationDate
        else {
            return nil
        }
        return "\(fileSize)|\(modificationDate.timeIntervalSinceReferenceDate)"
    }
}
