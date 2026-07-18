import Foundation
import SwiftData

/// CloudKit policy for the hybrid dual-store stack (Phase 2+).
///
/// - **User store (on-disk production):** private CloudKit mirroring.
/// - **Catalog / diagnostics / in-memory / unified test containers:** `.none`.
/// - Crash reports still use the **public** database via `CrashReportCloudUploader` (not SwiftData mirroring).
enum AppSwiftDataCloudKitCompatibility: Sendable {

    /// Shared iCloud container (SwiftData private sync + opt-in crash public upload).
    nonisolated static let iCloudContainerIdentifier = "iCloud.PrimoSoftware.GoDiveMVP"

    /// Catalog, diagnostics, in-memory, and unified test containers.
    nonisolated static let localOnlyCloudKitDatabase: ModelConfiguration.CloudKitDatabase = .none

    /// Production user-store mirroring target.
    nonisolated static var privateUserCloudKitDatabase: ModelConfiguration.CloudKitDatabase {
        .private(iCloudContainerIdentifier)
    }

    /// Legacy name used by unified in-memory / migration-source containers (always local-only).
    nonisolated static let requiredCloudKitDatabase: ModelConfiguration.CloudKitDatabase = localOnlyCloudKitDatabase

    /// Attributes that previously used `@Attribute(.unique)` — CloudKit unsupported.
    /// Uniqueness is enforced in app code (`AppSwiftDataLogicalUniqueness`).
    nonisolated static let removedUniqueAttributeKeys: [String] = [
        "MarineLife.uuid",
        "SightingInstance.sightingUUID",
    ]

    /// Codable / transformable value types previously stored on `@Model` — CloudKit rejects
    /// `NSCodableAttributeType`. Prefer primitives / `Data` + `@Transient` wrappers.
    nonisolated static let removedCodableAttributeKeys: [String] = [
        "DiveActivity.entryCoordinate", // → entryLatitude / entryLongitude
        "DiveActivity.source", // → sourceRaw
        "DiveActivity.diveCurrentStrength", // → diveCurrentStrengthRaw
        "DiveActivity.diveVisibility", // → diveVisibilityRaw
        "DiveActivity.diveWaterType", // → diveWaterTypeRaw
        "MarineLifeUserRecord.activitiesSightedOn", // → activitiesSightedOnData
        "MarineLifeUserRecord.sitesSightedOn", // → sitesSightedOnData
        "MarineLifeUserRecord.userTaggedMedia", // → userTaggedMediaData
        "DiveTrip.countries", // → countriesData
        "DiveTrip.plannedSiteIDs", // → plannedSiteIDsData
        "UserDiveSite.siteTags", // → siteTagsData
        "UserDiveSite.waterType", // → waterTypeRaw
        "DiveSite.siteTags", // → siteTagsData
        "DiveSite.waterType", // → waterTypeRaw
    ]

    /// Cross-store relationship blockers (empty after Phase 1b).
    nonisolated static let pendingCrossStoreRelationshipBreaks: [String] = []

    nonisolated static func cloudKitDatabaseDescription(
        _ database: ModelConfiguration.CloudKitDatabase
    ) -> String {
        String(describing: database)
    }

    nonisolated static func isLocalOnlyCloudKitDatabase(
        _ database: ModelConfiguration.CloudKitDatabase
    ) -> Bool {
        cloudKitDatabaseDescription(database)
            == cloudKitDatabaseDescription(localOnlyCloudKitDatabase)
    }

    nonisolated static func isPrivateUserCloudKitDatabase(
        _ database: ModelConfiguration.CloudKitDatabase
    ) -> Bool {
        cloudKitDatabaseDescription(database)
            == cloudKitDatabaseDescription(privateUserCloudKitDatabase)
    }

    /// True when the configuration matches unified / local-only policy (tests, catalog, diagnostics).
    nonisolated static func usesRequiredCloudKitPolicy(
        _ database: ModelConfiguration.CloudKitDatabase
    ) -> Bool {
        isLocalOnlyCloudKitDatabase(database)
    }

    /// Phase 2 dual-store policy: user private; catalog + diagnostics local-only.
    nonisolated static func usesPhase2DualStoreCloudKitPolicy(
        user: ModelConfiguration.CloudKitDatabase,
        catalog: ModelConfiguration.CloudKitDatabase,
        diagnostics: ModelConfiguration.CloudKitDatabase
    ) -> Bool {
        isPrivateUserCloudKitDatabase(user)
            && isLocalOnlyCloudKitDatabase(catalog)
            && isLocalOnlyCloudKitDatabase(diagnostics)
    }

    /// Partition coverage: every production model appears in exactly one store list.
    nonisolated static func partitionCoverageIssues() -> [String] {
        let user = Set(AppSwiftDataStorePartition.userModelTypeNames)
        let catalog = Set(AppSwiftDataStorePartition.catalogModelTypeNames)
        let diagnostics = Set(AppSwiftDataStorePartition.diagnosticsModelTypeNames)
        var issues: [String] = []

        let overlapUserCatalog = user.intersection(catalog)
        if !overlapUserCatalog.isEmpty {
            issues.append("user∩catalog: \(overlapUserCatalog.sorted().joined(separator: ", "))")
        }
        let overlapUserDiagnostics = user.intersection(diagnostics)
        if !overlapUserDiagnostics.isEmpty {
            issues.append("user∩diagnostics: \(overlapUserDiagnostics.sorted().joined(separator: ", "))")
        }
        let overlapCatalogDiagnostics = catalog.intersection(diagnostics)
        if !overlapCatalogDiagnostics.isEmpty {
            issues.append("catalog∩diagnostics: \(overlapCatalogDiagnostics.sorted().joined(separator: ", "))")
        }

        let union = user.union(catalog).union(diagnostics)
        let all = Set(AppSwiftDataStorePartition.allModelTypeNames)
        let missing = all.subtracting(union)
        if !missing.isEmpty {
            issues.append("missing from partition union: \(missing.sorted().joined(separator: ", "))")
        }
        let extra = union.subtracting(all)
        if !extra.isEmpty {
            issues.append("extra in partition lists: \(extra.sorted().joined(separator: ", "))")
        }
        return issues
    }
}

/// App-level uniqueness replacing CloudKit-incompatible `@Attribute(.unique)`.
enum AppSwiftDataLogicalUniqueness {

    nonisolated static func existingMarineLife(
        uuid: String,
        modelContext: ModelContext
    ) throws -> MarineLife? {
        let target = uuid
        var descriptor = FetchDescriptor<MarineLife>(
            predicate: #Predicate { $0.uuid == target }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    nonisolated static func existingUserMarineLife(
        uuid: String,
        modelContext: ModelContext
    ) throws -> UserMarineLife? {
        let target = uuid
        var descriptor = FetchDescriptor<UserMarineLife>(
            predicate: #Predicate { $0.uuid == target }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    nonisolated static func existingSighting(
        sightingUUID: String,
        modelContext: ModelContext
    ) throws -> SightingInstance? {
        let target = sightingUUID
        var descriptor = FetchDescriptor<SightingInstance>(
            predicate: #Predicate { $0.sightingUUID == target }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
