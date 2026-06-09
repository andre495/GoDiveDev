import Foundation

/// Post-recognition review copy and branching for Fishial identify.
enum FishialIdentificationReviewPresentation: Sendable {

    enum ReviewMode: Equatable, Sendable {
        case noMatches
        case confirmSingle(FishialRecognitionPresentation.RankedSpecies)
        case selectFromMultiple([FishialRecognitionPresentation.RankedSpecies])
    }

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
