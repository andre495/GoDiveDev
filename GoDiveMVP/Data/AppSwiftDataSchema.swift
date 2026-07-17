import Foundation
import SwiftData

/// Shared SwiftData schema for production and tests.
enum AppSwiftDataSchema {
    nonisolated static var modelTypes: [any PersistentModel.Type] {
        AppSwiftDataStorePartition.allModelTypes
    }

    /// Builds a **`ModelContainer`**.
    ///
    /// - **In-memory** (tests / previews): single unified configuration (simpler fixtures); CloudKit **off**.
    /// - **On-disk** (production): dual user / catalog / diagnostics via **`AppSwiftDataDualStoreBootstrap`**.
    ///   Phase 2: private CloudKit on the user store (local fallback). Legacy unified migration is
    ///   **out of scope** — clean install for dual + CloudKit.
    ///
    /// On-disk stores perform file I/O — use **`AppModelContainer.loadProduction()`** at launch on a
    /// background thread; in-memory is fine on any thread.
    nonisolated static func makeContainer(isStoredInMemoryOnly: Bool) throws -> ModelContainer {
        if isStoredInMemoryOnly {
            return try makeUnifiedContainer(isStoredInMemoryOnly: true)
        }
        return try AppSwiftDataDualStoreBootstrap.openProductionContainer().container
    }

    /// On-disk with an explicit store URL (legacy unified **`default.store`** recovery path).
    nonisolated static func makeUnifiedContainer(
        isStoredInMemoryOnly: Bool,
        storeURL: URL?
    ) throws -> ModelContainer {
        let schema = Schema(modelTypes)
        let configuration: ModelConfiguration
        if isStoredInMemoryOnly {
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: AppSwiftDataCloudKitCompatibility.requiredCloudKitDatabase
            )
        } else if let storeURL {
            configuration = ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: AppSwiftDataCloudKitCompatibility.requiredCloudKitDatabase
            )
        } else {
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: AppSwiftDataCloudKitCompatibility.requiredCloudKitDatabase
            )
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// Single-configuration container (legacy shape). Used for in-memory tests and as the migration source.
    nonisolated static func makeUnifiedContainer(isStoredInMemoryOnly: Bool) throws -> ModelContainer {
        try makeUnifiedContainer(isStoredInMemoryOnly: isStoredInMemoryOnly, storeURL: nil)
    }
}
