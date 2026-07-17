import Foundation
import SwiftData

/// User-created field-guide species (syncs with the private user store).
///
/// Catalog / bundled species remain on **`MarineLife`**. Sightings and overlays reference either
/// kind by stable **`uuid`** (`user-marine-life-*` for this model).
@Model
final class UserMarineLife {

    /// Stable id — always prefixed with **`FieldGuideMarineLifeAddPresentation.userCreatedUUIDPrefix`**.
    var uuid: String = ""

    var commonName: String = ""
    var featureImageURL: String = ""
    var featureImageResourceName: String = ""
    var featureModelResourceName: String = ""
    var scientificName: String = ""
    var category: String = ""
    var subcategory: String = ""
    var familyName: String = ""
    var aboutText: String = ""

    var minSizeMeters: Double = 0
    var maxSizeMeters: Double = 0
    var minDepthMeters: Double = 0
    var maxDepthMeters: Double = 0
    var avgDepthMeters: Double = 0

    var distinctiveFeatures: String = ""
    var abundance: String = ""
    var habitatBehavior: String = ""
    var diverReaction: String = ""

    /// Denormalized owner for predicates; kept in sync with **`owner`**.
    var ownerProfileID: UUID?
    @Relationship
    var owner: UserProfile?

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        uuid: String = FieldGuideMarineLifeAddPresentation.makeUserCreatedUUID(),
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
        diverReaction: String = "",
        owner: UserProfile? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
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
        self.owner = owner
        self.ownerProfileID = owner?.id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension UserMarineLife {
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
