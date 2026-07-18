import Foundation
import SwiftData

/// User-owned dive site (created locally / imported without an OpenDiveMap tag).
///
/// OpenDiveMap / CDN reference rows stay on **`DiveSite`**. Dives and trips reference either kind
/// by stable **`id`** (`diveSiteID` / `plannedSiteIDs`) — no cross-store SwiftData relationship.
@Model
final class UserDiveSite {

    var id: UUID = UUID()
    var siteName: String = ""
    var country: String = ""
    var region: String = ""
    var bodyOfWater: String = ""
    var latCoords: Double?
    var longCoords: Double?
    var timeZoneIdentifier: String?
    var timeZoneOffsetSeconds: Int?
    /// JSON site tags — CloudKit rejects stored `[String]` (`NSCodableAttributeType`).
    var siteTagsData: Data?
    @Transient
    var siteTags: [String] {
        get { AppSwiftDataCloudKitArrayStorage.decodeStringList(siteTagsData) }
        set { siteTagsData = AppSwiftDataCloudKitArrayStorage.encodeStringList(newValue) }
    }
    var siteRating: Int?
    var entry: String = ""
    var environment: String = ""
    var maxDepthMeters: Int?
    /// **`DiveWaterType`** raw value; **`nil`** → salt water.
    var waterTypeRaw: String?
    @Transient
    var waterType: DiveWaterType? {
        get { waterTypeRaw.flatMap(DiveWaterType.init(rawValue:)) }
        set { waterTypeRaw = newValue?.rawValue }
    }

    /// Denormalized owner for predicates; kept in sync with **`owner`**.
    var ownerProfileID: UUID?
    @Relationship
    var owner: UserProfile?

    /// When this row was snapshotted from a catalog / OpenDiveMap reference.
    var catalogDiveSiteID: UUID?
    var openDiveMapReferenceID: String?

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        siteName: String,
        country: String = "",
        region: String = "",
        bodyOfWater: String = "",
        latCoords: Double? = nil,
        longCoords: Double? = nil,
        timeZoneIdentifier: String? = nil,
        timeZoneOffsetSeconds: Int? = nil,
        siteTags: [String] = [],
        siteRating: Int? = nil,
        entry: String = "",
        environment: String = "",
        maxDepthMeters: Int? = nil,
        waterType: DiveWaterType? = nil,
        owner: UserProfile? = nil,
        catalogDiveSiteID: UUID? = nil,
        openDiveMapReferenceID: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.siteName = siteName
        self.country = country
        self.region = region
        self.bodyOfWater = bodyOfWater
        self.latCoords = latCoords
        self.longCoords = longCoords
        self.timeZoneIdentifier = timeZoneIdentifier
        self.timeZoneOffsetSeconds = timeZoneOffsetSeconds
        self.siteTags = siteTags
        self.siteRating = siteRating
        self.entry = entry
        self.environment = environment
        self.maxDepthMeters = maxDepthMeters
        self.waterType = waterType
        self.owner = owner
        self.ownerProfileID = owner?.id
        self.catalogDiveSiteID = catalogDiveSiteID
        self.openDiveMapReferenceID = openDiveMapReferenceID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Catalog default when **`waterType`** is unset (most dive sites are salt water).
    var resolvedWaterType: DiveWaterType {
        waterType ?? .saltwater
    }
}

extension UserDiveSite {
    /// Builds a user-store snapshot from a catalog / OpenDiveMap **`DiveSite`** (same id by default).
    ///
    /// Synced via CloudKit so **My Sites** / dive resolve survive reinstall when the local catalog
    /// **`DiveSite`** row does not.
    static func snapshot(from catalogSite: DiveSite, owner: UserProfile? = nil) -> UserDiveSite {
        UserDiveSite(
            id: catalogSite.id,
            siteName: catalogSite.siteName,
            country: catalogSite.country,
            region: catalogSite.region,
            bodyOfWater: catalogSite.bodyOfWater,
            latCoords: catalogSite.latCoords,
            longCoords: catalogSite.longCoords,
            timeZoneIdentifier: catalogSite.timeZoneIdentifier,
            timeZoneOffsetSeconds: catalogSite.timeZoneOffsetSeconds,
            siteTags: catalogSite.siteTags,
            siteRating: catalogSite.siteRating,
            entry: catalogSite.entry,
            environment: catalogSite.environment,
            maxDepthMeters: catalogSite.maxDepthMeters,
            waterType: catalogSite.waterType,
            owner: owner,
            catalogDiveSiteID: catalogSite.id,
            openDiveMapReferenceID: DiveSiteCatalogMatcher.referenceID(from: catalogSite.siteTags)
        )
    }

    /// Rebuilds a synced snapshot for an orphaned **`diveSiteID`** from bundled OpenDiveMap metadata.
    static func snapshot(
        from reference: DiveSiteReferenceSnapshot,
        id: UUID,
        owner: UserProfile? = nil
    ) -> UserDiveSite {
        var tags = [DiveSiteCatalogMatcher.openDiveMapSiteTag(referenceID: reference.id)]
        if !reference.entry.isEmpty { tags.append(reference.entry) }
        tags.append(contentsOf: reference.topologies)
        let siteName = DiveSiteCatalogMatcher.sanitizedReferenceDisplayName(reference.name) ?? reference.id
        return UserDiveSite(
            id: id,
            siteName: siteName,
            country: DiveSiteCountryPresentation.canonicalDisplayName(for: reference.country),
            region: "",
            bodyOfWater: reference.seaName,
            latCoords: reference.latitude,
            longCoords: reference.longitude,
            siteTags: tags,
            entry: reference.entry,
            environment: reference.environment,
            maxDepthMeters: reference.maxDepthMeters,
            waterType: .saltwater,
            owner: owner,
            catalogDiveSiteID: id,
            openDiveMapReferenceID: reference.id
        )
    }
}
