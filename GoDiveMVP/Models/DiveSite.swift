import Foundation
import SwiftData

/// Named dive site catalog entry (coordinates, tags, rating). Linked from **`DiveActivity`** after import match.
@Model
final class DiveSite {

    var id: UUID = UUID()
    var siteName: String = ""
    /// Broadest place label (e.g. country). Default at declaration for SwiftData lightweight migration.
    var country: String = ""
    /// Subnational or survey region (e.g. state, province, atoll group).
    var region: String = ""
    /// Named water body (e.g. sea, strait, reef, bay).
    var bodyOfWater: String = ""
    var latCoords: Double?
    var longCoords: Double?
    /// IANA timezone from reverse geocode (preferred for DST-aware offset at any dive instant).
    var timeZoneIdentifier: String?
    /// Seconds east of UTC at last timezone resolution (display fallback when **`timeZoneIdentifier`** unset).
    var timeZoneOffsetSeconds: Int?
    /// JSON site tags — CloudKit rejects stored `[String]` (`NSCodableAttributeType`).
    var siteTagsData: Data?
    @Transient
    var siteTags: [String] {
        get { AppSwiftDataCloudKitArrayStorage.decodeStringList(siteTagsData) }
        set { siteTagsData = AppSwiftDataCloudKitArrayStorage.encodeStringList(newValue) }
    }
    var siteRating: Int?
    /// Shore / boat / etc. (from OpenDiveMap **`entry`** when linked).
    var entry: String = ""
    /// Ocean / lake / etc. (from OpenDiveMap **`environment`** when linked).
    var environment: String = ""
    /// Catalog max depth in meters when known (OpenDiveMap **`maxDepthMeters`**).
    var maxDepthMeters: Int?
    /// **`DiveWaterType`** raw value; **`nil`** → salt water.
    var waterTypeRaw: String?
    @Transient
    var waterType: DiveWaterType? {
        get { waterTypeRaw.flatMap(DiveWaterType.init(rawValue:)) }
        set { waterTypeRaw = newValue?.rawValue }
    }
    /// **`DiveSiteOwnership`** raw value — OpenDiveMap/CDN reference vs legacy user-owned (migrated to **`UserDiveSite`**).
    var ownershipRaw: String = DiveSiteOwnership.catalogReference.rawValue

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
        ownership: DiveSiteOwnership? = nil
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
        self.ownershipRaw = (ownership ?? DiveSiteOwnership.inferred(fromSiteTags: siteTags)).rawValue
    }
}

extension DiveSite {
    var ownership: DiveSiteOwnership {
        get { DiveSiteOwnership(rawValue: ownershipRaw) ?? DiveSiteOwnership.inferred(fromSiteTags: siteTags) }
        set { ownershipRaw = newValue.rawValue }
    }

    /// Recomputes ownership from OpenDiveMap / CDN site tags.
    func refreshOwnershipFromSiteTags() {
        ownership = DiveSiteOwnership.inferred(fromSiteTags: siteTags)
    }

    /// Catalog default when **`waterType`** is unset (most dive sites are salt water).
    var resolvedWaterType: DiveWaterType {
        waterType ?? .saltwater
    }
}
