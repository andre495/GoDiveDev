import Foundation
import SwiftData

/// UUID-only resolution for catalog **`MarineLife`** and user **`UserMarineLife`** rows.
enum MarineLifeSpeciesResolver {

    /// Merged Field Guide snapshots (catalog + user-created).
    static func allCatalogSnapshots(modelContext: ModelContext) throws -> [MarineLifeCatalogSnapshot] {
        let catalog = try modelContext.fetch(FetchDescriptor<MarineLife>())
            .map(\.fieldGuideCatalogSnapshot)
        let user = try modelContext.fetch(FetchDescriptor<UserMarineLife>())
            .map(\.fieldGuideCatalogSnapshot)
        return catalog + user
    }

    static func snapshot(
        uuid: String,
        modelContext: ModelContext
    ) throws -> MarineLifeCatalogSnapshot? {
        if let user = try AppSwiftDataLogicalUniqueness.existingUserMarineLife(
            uuid: uuid,
            modelContext: modelContext
        ) {
            return user.fieldGuideCatalogSnapshot
        }
        if let catalog = try AppSwiftDataLogicalUniqueness.existingMarineLife(
            uuid: uuid,
            modelContext: modelContext
        ) {
            return catalog.fieldGuideCatalogSnapshot
        }
        return nil
    }

    static func snapshot(
        uuid: String,
        catalogByUUID: [String: MarineLifeCatalogSnapshot]
    ) -> MarineLifeCatalogSnapshot? {
        catalogByUUID[uuid]
    }

    static func commonName(
        uuid: String,
        catalogByUUID: [String: MarineLifeCatalogSnapshot]
    ) -> String? {
        let name = catalogByUUID[uuid]?.commonName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? nil : name
    }
}

/// ID-only resolution for catalog **`DiveSite`** and user **`UserDiveSite`** rows.
enum DiveLinkedSiteResolver {

    struct ResolvedSite: Equatable, Sendable {
        var id: UUID
        var siteName: String
        var country: String
        var region: String
        var bodyOfWater: String
        var latCoords: Double?
        var longCoords: Double?
        var timeZoneIdentifier: String?
        var timeZoneOffsetSeconds: Int?
        var siteTags: [String]
        var entry: String
        var environment: String
        var maxDepthMeters: Int?
        var waterType: DiveWaterType?
        var isUserOwned: Bool

        nonisolated var resolvedWaterType: DiveWaterType {
            waterType ?? .saltwater
        }

        nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id
        }
    }

    static func resolve(id: UUID, modelContext: ModelContext) throws -> ResolvedSite? {
        if let user = try existingUserDiveSite(id: id, modelContext: modelContext) {
            return resolved(from: user)
        }
        if let catalog = try existingCatalogDiveSite(id: id, modelContext: modelContext) {
            return resolved(from: catalog)
        }
        return nil
    }

    static func resolve(
        id: UUID?,
        userSitesByID: [UUID: UserDiveSite],
        catalogSitesByID: [UUID: DiveSite]
    ) -> ResolvedSite? {
        guard let id else { return nil }
        if let user = userSitesByID[id] {
            return resolved(from: user)
        }
        if let catalog = catalogSitesByID[id] {
            return resolved(from: catalog)
        }
        return nil
    }

    nonisolated static func existingUserDiveSite(id: UUID, modelContext: ModelContext) throws -> UserDiveSite? {
        let target = id
        var descriptor = FetchDescriptor<UserDiveSite>(predicate: #Predicate { $0.id == target })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    nonisolated static func existingCatalogDiveSite(id: UUID, modelContext: ModelContext) throws -> DiveSite? {
        let target = id
        var descriptor = FetchDescriptor<DiveSite>(predicate: #Predicate { $0.id == target })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    static func resolved(from site: UserDiveSite) -> ResolvedSite {
        ResolvedSite(
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
            entry: site.entry,
            environment: site.environment,
            maxDepthMeters: site.maxDepthMeters,
            waterType: site.waterType,
            isUserOwned: true
        )
    }

    static func resolved(from site: DiveSite) -> ResolvedSite {
        ResolvedSite(
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
            entry: site.entry,
            environment: site.environment,
            maxDepthMeters: site.maxDepthMeters,
            waterType: site.waterType,
            isUserOwned: DiveSiteOwnership.inferred(fromSiteTags: site.siteTags) == .userOwned
        )
    }
}
