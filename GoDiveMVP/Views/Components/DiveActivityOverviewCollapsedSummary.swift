import SwiftUI

/// Compact dive summary shown when the overview bottom panel is minimized.
struct DiveActivityOverviewCollapsedSummary: View {
    let dateText: String
    let titleText: String
    let linkedCatalogSiteID: UUID?
    var onOpenLinkedSite: (() -> Void)?
    let diveNumberText: String
    let maxDepthText: String
    var swimDistanceText: String? = nil
    let durationText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            DiveActivityLinkedSiteTitle(
                title: titleText,
                linkedCatalogSiteID: linkedCatalogSiteID,
                font: .headline.weight(.semibold),
                onOpenLinkedSite: onOpenLinkedSite
            )

            Text(dateText)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.tabUnselected)

            HStack(spacing: AppTheme.Spacing.sm) {
                summaryChip(label: "Dive", value: diveNumberText)
                if let swimDistanceText {
                    summaryChip(label: "Distance", value: swimDistanceText)
                }
                summaryChip(label: "Depth", value: maxDepthText)
                summaryChip(label: "Time", value: durationText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(collapsedSummaryAccessibilityLabel)
    }

    private var collapsedSummaryAccessibilityLabel: String {
        var parts = ["\(titleText)", dateText, "dive \(diveNumberText)"]
        if let swimDistanceText {
            parts.append("swim distance \(swimDistanceText)")
        }
        parts.append("max depth \(maxDepthText)")
        parts.append("duration \(durationText)")
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
