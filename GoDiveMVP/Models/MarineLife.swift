import Foundation
import SwiftData

/// Bundled / future remote **catalog** species row (objective field-guide data only).
///
/// Per-user sighting state lives on **`MarineLifeUserRecord`** (keyed by **`uuid`** + **`ownerProfileID`**).
@Model
final class MarineLife {

    /// Stable catalog id from bundled JSON or a future API (not the SwiftData row id).
    /// Uniqueness is app-enforced (`AppSwiftDataLogicalUniqueness`) — CloudKit forbids `@Attribute(.unique)`.
    var uuid: String = ""

    /// **`MarineLifeOwnership`** raw value — catalog vs user-created for the hybrid store split.
    var ownershipRaw: String = MarineLifeOwnership.catalog.rawValue

    var commonName: String = ""
    /// Remote image URL (legacy fallback / provenance); prefer **`featureImageResourceName`** offline.
    var featureImageURL: String = ""
    /// Bundled JPEG resource name (no extension) under **`Resources/MarineLifePhotos/`**.
    var featureImageResourceName: String = ""
    /// Bundled USDZ resource name (no extension) for RealityKit detail hero; empty uses photo / placeholder.
    var featureModelResourceName: String = ""
    /// Remote USDZ URL (Firebase Storage); prefer bundled / disk cache offline.
    var featureModelURL: String = ""
    var scientificName: String = ""
    var category: String = ""
    /// Taxonomy slug or display label (e.g. `sharks-and-rays`, `Disk and Large Oval`).
    /// Default at declaration for SwiftData lightweight migration on existing stores.
    var subcategory: String = ""
    /// Family group label (e.g. Angelfishes).
    var familyName: String = ""
    var aboutText: String = ""

    /// Observed size range and typical depth — stored in **meters**; UI uses **`DiveDisplayUnitSystem`**.
    var minSizeMeters: Double = 0
    var maxSizeMeters: Double = 0
    var minDepthMeters: Double = 0
    var maxDepthMeters: Double = 0
    var avgDepthMeters: Double = 0

    var distinctiveFeatures: String = ""
    var abundance: String = ""
    var habitatBehavior: String = ""
    var diverReaction: String = ""

    init(
        uuid: String,
        commonName: String,
        featureImageURL: String = "",
        featureImageResourceName: String = "",
        featureModelResourceName: String = "",
        featureModelURL: String = "",
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
        diverReaction: String = "",
        ownership: MarineLifeOwnership? = nil
    ) {
        self.uuid = uuid
        self.ownershipRaw = (ownership ?? MarineLifeOwnership.inferred(fromUUID: uuid)).rawValue
        self.commonName = MarineLifeCommonNameFormatting.normalized(commonName)
        self.featureImageURL = featureImageURL
        self.featureImageResourceName = featureImageResourceName
        self.featureModelResourceName = featureModelResourceName
        self.featureModelURL = featureModelURL
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
    var ownership: MarineLifeOwnership {
        get { MarineLifeOwnership(rawValue: ownershipRaw) ?? MarineLifeOwnership.inferred(fromUUID: uuid) }
        set { ownershipRaw = newValue.rawValue }
    }

    /// Recomputes ownership from the stable UUID (catalog seed / user-created prefix).
    func refreshOwnershipFromUUID() {
        ownership = MarineLifeOwnership.inferred(fromUUID: uuid)
    }

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
            featureModelURL: featureModelURL,
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
