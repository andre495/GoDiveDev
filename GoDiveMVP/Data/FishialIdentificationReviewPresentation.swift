import Foundation

/// Post-recognition review branching for Fishial identify — top-level for **nonisolated** **`Equatable`** (Swift 6).
enum FishialIdentificationReviewMode: Equatable, Sendable {
    case noMatches
    case confirmSingle(FishialCatalogReviewOption)
    case selectFromMultiple([FishialCatalogReviewOption])

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.noMatches, .noMatches):
            return true
        case (.confirmSingle(let left), .confirmSingle(let right)):
            return left == right
        case (.selectFromMultiple(let left), .selectFromMultiple(let right)):
            return left == right
        default:
            return false
        }
    }
}

/// Post-recognition review copy and branching for Fishial identify.
enum FishialIdentificationReviewPresentation: Sendable {

    typealias ReviewMode = FishialIdentificationReviewMode

    nonisolated static let mediumDetentSectionTitle = "Fish ID"
    nonisolated static let noMatchesMessage =
        "Fishial did not match any species in our marine life catalog for this still."
    nonisolated static let confirmSinglePrompt = "Does this look like the fish in your photo?"
    nonisolated static let selectMultiplePrompt = "Which catalog species match do you think is correct?"
    nonisolated static let savedConfirmationPrefix = "Tagged marine life:"
    nonisolated static let savedFishIDNote =
        "This species is tagged on the photo and shown in the Fish ID row at medium height."

    nonisolated static func reviewMode(
        for catalogOptions: [FishialCatalogReviewOption]
    ) -> ReviewMode {
        switch catalogOptions.count {
        case 0:
            return .noMatches
        case 1:
            return .confirmSingle(catalogOptions[0])
        default:
            return .selectFromMultiple(catalogOptions)
        }
    }

    nonisolated static func formattedSpeciesLine(
        _ option: FishialCatalogReviewOption
    ) -> String {
        "\(option.catalogCommonName) (\(option.catalogScientificName)) — "
            + FishialIdentificationResultPresentation.formattedAccuracy(option.fishialAccuracy)
    }

    nonisolated static func mediumDetentAccessibilityLabel(speciesName: String) -> String {
        "Fish ID \(speciesName)"
    }
}
