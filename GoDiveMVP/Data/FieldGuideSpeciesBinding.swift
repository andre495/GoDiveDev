import Foundation

/// Shared Field Guide detail binding for catalog **`MarineLife`** and user **`UserMarineLife`**.
enum FieldGuideSpeciesBinding {
    case catalog(MarineLife)
    case user(UserMarineLife)

    var uuid: String {
        switch self {
        case .catalog(let species): species.uuid
        case .user(let species): species.uuid
        }
    }

    var commonName: String {
        switch self {
        case .catalog(let species): species.commonName
        case .user(let species): species.commonName
        }
    }

    var scientificName: String {
        switch self {
        case .catalog(let species): species.scientificName
        case .user(let species): species.scientificName
        }
    }

    var aboutText: String {
        switch self {
        case .catalog(let species): species.aboutText
        case .user(let species): species.aboutText
        }
    }

    var distinctiveFeatures: String {
        switch self {
        case .catalog(let species): species.distinctiveFeatures
        case .user(let species): species.distinctiveFeatures
        }
    }

    var featureModelResourceName: String {
        switch self {
        case .catalog(let species): species.featureModelResourceName
        case .user(let species): species.featureModelResourceName
        }
    }

    var featureImageResourceName: String {
        switch self {
        case .catalog(let species): species.featureImageResourceName
        case .user(let species): species.featureImageResourceName
        }
    }

    var featureImageURL: String {
        switch self {
        case .catalog(let species): species.featureImageURL
        case .user(let species): species.featureImageURL
        }
    }

    var minSizeMeters: Double {
        switch self {
        case .catalog(let species): species.minSizeMeters
        case .user(let species): species.minSizeMeters
        }
    }

    var maxSizeMeters: Double {
        switch self {
        case .catalog(let species): species.maxSizeMeters
        case .user(let species): species.maxSizeMeters
        }
    }

    var minDepthMeters: Double {
        switch self {
        case .catalog(let species): species.minDepthMeters
        case .user(let species): species.minDepthMeters
        }
    }

    var maxDepthMeters: Double {
        switch self {
        case .catalog(let species): species.maxDepthMeters
        case .user(let species): species.maxDepthMeters
        }
    }

    var avgDepthMeters: Double {
        switch self {
        case .catalog(let species): species.avgDepthMeters
        case .user(let species): species.avgDepthMeters
        }
    }

    var fieldGuideCatalogSnapshot: MarineLifeCatalogSnapshot {
        switch self {
        case .catalog(let species): species.fieldGuideCatalogSnapshot
        case .user(let species): species.fieldGuideCatalogSnapshot
        }
    }

    var canEdit: Bool {
        switch self {
        case .catalog(let species):
            FieldGuideMarineLifeAddPresentation.isUserEditable(species)
        case .user(let species):
            FieldGuideMarineLifeAddPresentation.isUserEditable(species)
        }
    }
}
