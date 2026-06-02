import SwiftUI

/// Compact summary when the Field Guide sightings panel is minimized.
struct FieldGuideSightingsCollapsedSummary: View {
    let totalSightings: Int
    let uniqueSpeciesCount: Int
    let regionCount: Int
    let topRegionLabel: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sightings overview")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            if let topRegionLabel, !topRegionLabel.isEmpty {
                Text(topRegionLabel)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
                    .lineLimit(2)
            } else {
                Text("Regional heat map")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
            }

            HStack(spacing: AppTheme.Spacing.sm) {
                summaryChip(label: "Logged", value: "\(totalSightings)")
                summaryChip(label: "Species", value: "\(uniqueSpeciesCount)")
                summaryChip(label: "Regions", value: "\(regionCount)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        var parts = ["Sightings overview", "\(totalSightings) logged", "\(uniqueSpeciesCount) species", "\(regionCount) regions"]
        if let topRegionLabel, !topRegionLabel.isEmpty {
            parts.append("Most active \(topRegionLabel)")
        }
        return parts.joined(separator: ", ")
    }

    private func summaryChip(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppTheme.Colors.tabUnselected)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
