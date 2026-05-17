import SwiftUI

/// Compact dive summary shown when the overview bottom panel is minimized.
struct DiveActivityOverviewCollapsedSummary: View {
    let dateText: String
    let titleText: String
    let diveNumberText: String
    let maxDepthText: String
    let durationText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(dateText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.tabUnselected)

            Text(titleText)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(2)

            HStack(spacing: AppTheme.Spacing.sm) {
                summaryChip(label: "Dive", value: diveNumberText)
                summaryChip(label: "Depth", value: maxDepthText)
                summaryChip(label: "Time", value: durationText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(titleText), \(dateText), dive \(diveNumberText), max depth \(maxDepthText), duration \(durationText)")
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
