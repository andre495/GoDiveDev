import Foundation
import SwiftData

/// Migrates legacy hybrid rows into dedicated user-store models (Phase 1).
///
/// - User-created `MarineLife` (`user-marine-life-*`) → `UserMarineLife`
/// - User-owned `DiveSite` (no OpenDiveMap tag) → `UserDiveSite`
///
/// Catalog OpenDiveMap / bundled rows stay on `MarineLife` / `DiveSite`.
enum AppSwiftDataHybridRowMigration {

    struct Result: Equatable, Sendable {
        var migratedSpeciesCount: Int = 0
        var migratedSiteCount: Int = 0
        var plannedSiteIDBackfillCount: Int = 0

        nonisolated init(
            migratedSpeciesCount: Int = 0,
            migratedSiteCount: Int = 0,
            plannedSiteIDBackfillCount: Int = 0
        ) {
            self.migratedSpeciesCount = migratedSpeciesCount
            self.migratedSiteCount = migratedSiteCount
            self.plannedSiteIDBackfillCount = plannedSiteIDBackfillCount
        }
    }

    @discardableResult
    nonisolated static func migrateIfNeeded(modelContext: ModelContext) throws -> Result {
        var result = Result()
        result.migratedSpeciesCount = try migrateUserMarineLife(modelContext: modelContext)
        result.migratedSiteCount = try migrateUserDiveSites(modelContext: modelContext)
        if modelContext.hasChanges {
            try modelContext.save()
        }
        return result
    }

    private nonisolated static func migrateUserMarineLife(modelContext: ModelContext) throws -> Int {
        let catalog = try modelContext.fetch(FetchDescriptor<MarineLife>())
        var migrated = 0
        for species in catalog where FieldGuideMarineLifeAddPresentation.isUserCreated(uuid: species.uuid) {
            if try AppSwiftDataLogicalUniqueness.existingUserMarineLife(
                uuid: species.uuid,
                modelContext: modelContext
            ) != nil {
                modelContext.delete(species)
                continue
            }
            let user = UserMarineLife(
                uuid: species.uuid,
                commonName: species.commonName,
                featureImageURL: species.featureImageURL,
                featureImageResourceName: species.featureImageResourceName,
                featureModelResourceName: species.featureModelResourceName,
                scientificName: species.scientificName,
                category: species.category,
                subcategory: species.subcategory,
                familyName: species.familyName,
                aboutText: species.aboutText,
                minSizeMeters: species.minSizeMeters,
                maxSizeMeters: species.maxSizeMeters,
                minDepthMeters: species.minDepthMeters,
                maxDepthMeters: species.maxDepthMeters,
                avgDepthMeters: species.avgDepthMeters,
                distinctiveFeatures: species.distinctiveFeatures,
                abundance: species.abundance,
                habitatBehavior: species.habitatBehavior,
                diverReaction: species.diverReaction
            )
            modelContext.insert(user)
            modelContext.delete(species)
            migrated += 1
        }
        return migrated
    }

    private nonisolated static func migrateUserDiveSites(modelContext: ModelContext) throws -> Int {
        let catalog = try modelContext.fetch(FetchDescriptor<DiveSite>())
        var migrated = 0
        for site in catalog where DiveSiteOwnership.inferred(fromSiteTags: site.siteTags) == .userOwned {
            if try DiveLinkedSiteResolver.existingUserDiveSite(id: site.id, modelContext: modelContext) != nil {
                modelContext.delete(site)
                continue
            }
            let user = UserDiveSite(
                id: site.id,
                siteName: site.siteName,
                country: site.country,
                region: site.region,
                bodyOfWater: site.bodyOfWater,
                latCoords: site.latCoords,
                longCoords: site.longCoords,
                timeZoneIdentifier: site.timeZoneIdentifier,
                timeZoneOffsetSeconds: site.timeZoneOffsetSeconds,
                siteTags: site.siteTags,
                siteRating: site.siteRating,
                entry: site.entry,
                environment: site.environment,
                maxDepthMeters: site.maxDepthMeters,
                waterType: site.waterType
            )
            modelContext.insert(user)
            modelContext.delete(site)
            migrated += 1
        }
        return migrated
    }
}
