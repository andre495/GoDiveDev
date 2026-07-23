import SwiftUI

/// Heart-rate tab panel — replaces tank / gas sections on snorkel detail.
struct SnorkelHeartRateOverviewPanelContent: View {
    let siteTitle: String
    let linkedCatalogSiteID: UUID?
    let onOpenLinkedSite: (() -> Void)?
    let regionCountryLine: String?
    let dateDashTimeLine: String
    @Binding var overviewSheetDetent: DiveActivityOverviewDetent
    let avgHeartRateBPM: Int?
    let maxHeartRateBPM: Int?
    let profileHeartRateStats: SnorkelHeartRatePanelSummary.ProfileHeartRateStats
    let heartRateSamples: [SnorkelHeartRateProfileSample]
    let totalCalories: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            if overviewSheetDetent != .minimized {
                DiveActivityMapOverviewHeader(
                    activityKind: .snorkel,
                    diveNumberChip: nil,
                    siteTitle: siteTitle,
                    linkedCatalogSiteID: linkedCatalogSiteID,
                    onOpenLinkedSite: onOpenLinkedSite,
                    regionCountryLine: regionCountryLine,
                    dateDashTimeLine: dateDashTimeLine
                )
            }

            heartRateStatsRow

            SnorkelHeartRateProfileChart(
                samples: heartRateSamples,
                sessionMaxBPMHint: maxHeartRateBPM
            )
            .frame(height: 160)
            .accessibilityIdentifier("SnorkelOverview.HeartRateChart")

            if let calories = totalCalories, calories > 0 {
                HStack {
                    Text("Calories")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.tabUnselected)
                    Spacer()
                    Text("\(calories)")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var heartRateStatsRow: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            statBlock(
                title: "Avg",
                value: formattedBPM(avgHeartRateBPM),
                unit: "bpm"
            )
            statBlock(
                title: "Max",
                value: formattedBPM(maxHeartRateBPM ?? profileHeartRateStats.maxBPM),
                unit: "bpm"
            )
            statBlock(
                title: "Samples",
                value: profileHeartRateStats.sampleCount > 0
                    ? "\(profileHeartRateStats.sampleCount)"
                    : "—",
                unit: ""
            )
        }
    }

    private func statBlock(title: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppTheme.Colors.tabUnselected)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.tabUnselected)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formattedBPM(_ value: Int?) -> String {
        SnorkelHeartRatePanelSummary.formattedBPM(value)
    }
}
