import Foundation

/// Plain-text lines for the Fishial identify results sheet (debug-friendly MVP).
enum FishialIdentificationResultPresentation: Sendable {

    nonisolated static func resultLines(from outcome: DiveMediaFishialIdentification.Outcome) -> [String] {
        var lines: [String] = []
        lines.append("Selected still: \(outcome.selectedFilename)")
        if let coordinate = outcome.observationCoordinate {
            lines.append(
                "Dive location sent: \(FishialObservationLocation.locationHeaderValue(for: coordinate))"
            )
        } else {
            lines.append("Dive location sent: none (no coordinates on this dive)")
        }
        lines.append("Fish shapes detected: \(outcome.detectedFishCount)")
        lines.append("")

        if outcome.rankedSpecies.isEmpty {
            lines.append("No fish detected.")
            return lines
        }

        lines.append("Species matches:")
        for species in outcome.rankedSpecies {
            lines.append("• \(species.scientificName) — \(formattedAccuracy(species.accuracy))")
        }

        if !outcome.species.isEmpty {
            lines.append("")
            lines.append("Raw matches on selected still:")
            for match in outcome.species {
                lines.append("  - \(match.name) — \(formattedAccuracy(match.accuracy))")
            }
        }

        return lines
    }

    nonisolated static func formattedAccuracy(_ accuracy: Double) -> String {
        let percent = (accuracy * 100).rounded()
        return "\(Int(percent))%"
    }
}
