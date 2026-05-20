import Foundation
import SwiftData

/// Named dive site catalog entry (coordinates, tags, rating). Linked from **`DiveActivity`** after import match.
@Model
final class DiveSite {

    var id: UUID
    var siteName: String
    var latCoords: Double?
    var longCoords: Double?
    var siteTags: [String]
    var siteRating: Int?

    @Relationship(inverse: \DiveActivity.diveSite)
    var diveActivities: [DiveActivity] = []

    init(
        id: UUID = UUID(),
        siteName: String,
        latCoords: Double? = nil,
        longCoords: Double? = nil,
        siteTags: [String] = [],
        siteRating: Int? = nil
    ) {
        self.id = id
        self.siteName = siteName
        self.latCoords = latCoords
        self.longCoords = longCoords
        self.siteTags = siteTags
        self.siteRating = siteRating
    }
}
