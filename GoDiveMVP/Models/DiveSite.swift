import Foundation
import SwiftData

/// Named dive site catalog entry (coordinates, tags, rating). Linked from **`DiveActivity`** after import match.
@Model
final class DiveSite {

    var id: UUID
    var siteName: String
    /// Broadest place label (e.g. country). Default at declaration for SwiftData lightweight migration.
    var country: String = ""
    /// Subnational or survey region (e.g. state, province, atoll group).
    var region: String = ""
    /// Named water body (e.g. sea, strait, reef, bay).
    var bodyOfWater: String = ""
    var latCoords: Double?
    var longCoords: Double?
    var siteTags: [String]
    var siteRating: Int?

    @Relationship(inverse: \DiveActivity.diveSite)
    var diveActivities: [DiveActivity] = []

    init(
        id: UUID = UUID(),
        siteName: String,
        country: String = "",
        region: String = "",
        bodyOfWater: String = "",
        latCoords: Double? = nil,
        longCoords: Double? = nil,
        siteTags: [String] = [],
        siteRating: Int? = nil
    ) {
        self.id = id
        self.siteName = siteName
        self.country = country
        self.region = region
        self.bodyOfWater = bodyOfWater
        self.latCoords = latCoords
        self.longCoords = longCoords
        self.siteTags = siteTags
        self.siteRating = siteRating
    }
}
