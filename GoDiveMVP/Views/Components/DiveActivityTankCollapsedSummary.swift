import SwiftUI

/// Minimized sheet summary for the **Tank** tab (pressure chips).
struct DiveActivityTankCollapsedSummary: View {
    let dateText: String
    let titleText: String
    let diveNumberText: String
    let startPressureText: String
    let endPressureText: String

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
                summaryChip(label: "Start", value: startPressureText)
                summaryChip(label: "End", value: endPressureText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(titleText), \(dateText), dive \(diveNumberText), start \(startPressureText), end \(endPressureText)"
        )
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
