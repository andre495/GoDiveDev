import Foundation

/// Post-recognition review branching for Fishial identify — top-level for **nonisolated** **`Equatable`** (Swift 6).
enum FishialIdentificationReviewMode: Equatable, Sendable {
    case noMatches
    case confirmSingle(FishialRankedSpecies)
    case selectFromMultiple([FishialRankedSpecies])

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
    nonisolated static let noMatchesMessage = "Fishial did not suggest any species for this still."
    nonisolated static let confirmSinglePrompt = "Does this look like the fish in your photo?"
    nonisolated static let selectMultiplePrompt = "Which species match do you think is correct?"
    nonisolated static let savedConfirmationPrefix = "Saved fish ID:"

    nonisolated static func reviewMode(
        for rankedSpecies: [FishialRecognitionPresentation.RankedSpecies]
    ) -> ReviewMode {
        switch rankedSpecies.count {
        case 0:
            return .noMatches
        case 1:
            return .confirmSingle(rankedSpecies[0])
        default:
            return .selectFromMultiple(rankedSpecies)
        }
    }

    nonisolated static func formattedSpeciesLine(
        _ species: FishialRecognitionPresentation.RankedSpecies
    ) -> String {
        "\(species.scientificName) — \(FishialIdentificationResultPresentation.formattedAccuracy(species.accuracy))"
    }

    nonisolated static func mediumDetentAccessibilityLabel(speciesName: String) -> String {
        "Fish ID \(speciesName)"
    }
}
