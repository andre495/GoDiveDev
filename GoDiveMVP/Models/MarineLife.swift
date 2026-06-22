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
    /// Remote image URL (legacy fallback / provenance); prefer **`featureImageResourceName`** offline.
    var featureImageURL: String
    /// Bundled JPEG resource name (no extension) under **`Resources/MarineLifePhotos/`**.
    var featureImageResourceName: String = ""
    /// Bundled USDZ resource name (no extension) for RealityKit detail hero; empty uses photo / placeholder.
    var featureModelResourceName: String = ""
    var scientificName: String
    var category: String
    /// Taxonomy slug or display label (e.g. `sharks-and-rays`, `Disk and Large Oval`).
    /// Default at declaration for SwiftData lightweight migration on existing stores.
    var subcategory: String = ""
    /// Family group label (e.g. Angelfishes).
    var familyName: String = ""
    var aboutText: String

    /// Observed size range and typical depth — stored in **meters**; UI uses **`DiveDisplayUnitSystem`**.
    var minSizeMeters: Double
    var maxSizeMeters: Double
    var minDepthMeters: Double = 0
    var maxDepthMeters: Double = 0
    var avgDepthMeters: Double

    var distinctiveFeatures: String = ""
    var abundance: String = ""
    var habitatBehavior: String = ""
    var diverReaction: String = ""

    @Relationship(deleteRule: .cascade, inverse: \MarineLifeUserRecord.marineLife)
    var userRecords: [MarineLifeUserRecord] = []

    @Relationship
    var sightingInstances: [SightingInstance] = []

    init(
        uuid: String,
        commonName: String,
        featureImageURL: String = "",
        featureImageResourceName: String = "",
        featureModelResourceName: String = "",
        scientificName: String = "",
        category: String = "",
        subcategory: String = "",
        familyName: String = "",
        aboutText: String = "",
        minSizeMeters: Double = 0,
        maxSizeMeters: Double = 0,
        minDepthMeters: Double = 0,
        maxDepthMeters: Double = 0,
        avgDepthMeters: Double = 0,
        distinctiveFeatures: String = "",
        abundance: String = "",
        habitatBehavior: String = "",
        diverReaction: String = ""
    ) {
        self.uuid = uuid
        self.commonName = MarineLifeCommonNameFormatting.normalized(commonName)
        self.featureImageURL = featureImageURL
        self.featureImageResourceName = featureImageResourceName
        self.featureModelResourceName = featureModelResourceName
        self.scientificName = scientificName
        self.category = category
        self.subcategory = subcategory
        self.familyName = familyName
        self.aboutText = aboutText
        self.minSizeMeters = minSizeMeters
        self.maxSizeMeters = maxSizeMeters
        self.minDepthMeters = minDepthMeters
        self.maxDepthMeters = maxDepthMeters
        self.avgDepthMeters = avgDepthMeters
        self.distinctiveFeatures = distinctiveFeatures
        self.abundance = abundance
        self.habitatBehavior = habitatBehavior
        self.diverReaction = diverReaction
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
            featureImageResourceName: featureImageResourceName,
            featureModelResourceName: featureModelResourceName,
            minSizeMeters: minSizeMeters,
            maxSizeMeters: maxSizeMeters,
            avgDepthMeters: avgDepthMeters,
            familyName: familyName,
            minDepthMeters: minDepthMeters,
            maxDepthMeters: maxDepthMeters,
            distinctiveFeatures: distinctiveFeatures,
            abundance: abundance,
            habitatBehavior: habitatBehavior,
            diverReaction: diverReaction
        )
    }
}
