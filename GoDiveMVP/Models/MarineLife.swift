import Foundation
import SwiftData

/// Bundled / future remote **catalog** species row (objective field-guide data only).
///
/// Per-user sighting state lives on **`MarineLifeUserRecord`** (keyed by **`uuid`** + **`ownerProfileID`**).
@Model
final class MarineLife {

    /// Stable catalog id from bundled JSON or a future API (not the SwiftData row id).
    @Attribute(.unique) var uuid: String

    var commonName: String
    /// Remote or bundled image URL for list / detail hero.
    var featureImageURL: String
    var scientificName: String
    var category: String
    /// Taxonomy slug or display label (e.g. `sharks-and-rays`, `Disk and Large Oval`).
    /// Default at declaration for SwiftData lightweight migration on existing stores.
    var subcategory: String = ""
    var aboutText: String

    /// Observed size range and typical depth — stored in **meters**; UI uses **`DiveDisplayUnitSystem`**.
    var minSizeMeters: Double
    var maxSizeMeters: Double
    var avgDepthMeters: Double

    @Relationship(deleteRule: .cascade, inverse: \MarineLifeUserRecord.marineLife)
    var userRecords: [MarineLifeUserRecord] = []

    @Relationship
    var sightingInstances: [SightingInstance] = []

    init(
        uuid: String,
        commonName: String,
        featureImageURL: String = "",
        scientificName: String = "",
        category: String = "",
        subcategory: String = "",
        aboutText: String = "",
        minSizeMeters: Double = 0,
        maxSizeMeters: Double = 0,
        avgDepthMeters: Double = 0
    ) {
        self.uuid = uuid
        self.commonName = commonName
        self.featureImageURL = featureImageURL
        self.scientificName = scientificName
        self.category = category
        self.subcategory = subcategory
        self.aboutText = aboutText
        self.minSizeMeters = minSizeMeters
        self.maxSizeMeters = maxSizeMeters
        self.avgDepthMeters = avgDepthMeters
    }
}

extension MarineLife {
    var fieldGuideCatalogSnapshot: MarineLifeCatalogSnapshot {
        MarineLifeCatalogSnapshot(
            uuid: uuid,
            commonName: commonName,
            scientificName: scientificName,
            category: category,
            subcategory: subcategory,
            featureImageURL: featureImageURL,
            minSizeMeters: minSizeMeters,
            maxSizeMeters: maxSizeMeters,
            avgDepthMeters: avgDepthMeters
        )
    }
}
