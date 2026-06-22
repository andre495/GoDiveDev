import Foundation

/// Post-recognition review branching for Fishial identify — top-level for **nonisolated** **`Equatable`** (Swift 6).
enum FishialIdentificationReviewMode: Equatable, Sendable {
    case noFishDetected
    case unmatchedFishialSuggestion(String)
    case confirmSingle(FishialCatalogReviewOption)
    case selectFromMultiple([FishialCatalogReviewOption])

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.noFishDetected, .noFishDetected):
            return true
        case (.unmatchedFishialSuggestion(let left), .unmatchedFishialSuggestion(let right)):
            return left == right
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
    nonisolated static let noFishDetectedMessage =
        "Fishial did not detect a fish in this still."
    nonisolated static let confirmSinglePrompt = "Does this look like the fish in your photo?"
    nonisolated static let selectMultiplePrompt =
        "Select all catalog species you think are correct. You can choose more than one."
    nonisolated static let fieldGuideEntryLinkTitle = "View field guide entry"
    nonisolated static let savedConfirmationPrefix = "Tagged marine life:"
    nonisolated static let savedFishIDNote =
        FishialConfirmedSpeciesPresentation.savedFishIDNote(speciesCount: 1)

    nonisolated static func unmatchedFieldGuideMessage(speciesName: String) -> String {
        "Fishial thinks this is a \(speciesName), but GoDive has no such record in its field guide."
    }

    nonisolated static func reviewMode(
        for catalogOptions: [FishialCatalogReviewOption],
        rankedSpecies: [FishialRankedSpecies]
    ) -> ReviewMode {
        switch catalogOptions.count {
        case 0:
            if let topSpecies = rankedSpecies.first?.scientificName.trimmingCharacters(in: .whitespacesAndNewlines),
               !topSpecies.isEmpty {
                return .unmatchedFishialSuggestion(topSpecies)
            }
            return .noFishDetected
        case 1:
            return .confirmSingle(catalogOptions[0])
        default:
            return .selectFromMultiple(catalogOptions)
        }
    }

    /// Backward-compatible helper when Fishial ranked species are unavailable.
    nonisolated static func reviewMode(
        for catalogOptions: [FishialCatalogReviewOption]
    ) -> ReviewMode {
        reviewMode(for: catalogOptions, rankedSpecies: [])
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
