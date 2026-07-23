import SwiftUI

/// Minimized sheet summary for the snorkel **heart rate** tab.
struct SnorkelHeartRateCollapsedSummary: View {
    let dateText: String
    let titleText: String
    let avgHeartRateText: String
    let maxHeartRateText: String

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
                summaryChip(label: "Avg", value: avgHeartRateText)
                summaryChip(label: "Max", value: maxHeartRateText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
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
