import SwiftUI

/// Compact dive metrics band under the map overview header.
struct DiveActivityMapOverviewStatsBox: View {
    let layout: DiveActivityOverviewPresentation.MapOverviewStatsLayout
    var fillsAvailableHeight: Bool = false
    var showsEditButton: Bool = false
    var onEdit: (() -> Void)?

    /// Fixed layout height for progressive detent reveal (padding + depth gauge column).
    static let estimatedExpandedHeight: CGFloat = 204

    private enum Metrics {
        /// Sized for medium detent — larger presence without clipping (see stat text `frame(maxWidth: .infinity)`).
        static let contentPadding: CGFloat = 18
        static let editButtonInset: CGFloat = 10
        static let columnSpacing: CGFloat = 12
        static let statSpacing: CGFloat = 16
        static let iconSize: CGFloat = 38
        static let iconContentSpacing: CGFloat = 10
        static let cornerRadius: CGFloat = 14
        static let depthVisualWidth: CGFloat = 40
        static let depthGaugeHeight: CGFloat = 168
        static let titleLineSpacing: CGFloat = 1
        static let titleValueSpacing: CGFloat = 5
        static let labelFontSize: CGFloat = 12
        static let valueFontSize: CGFloat = 20
        static let unitFontSize: CGFloat = 12
        static let valueLineSpacing: CGFloat = 1
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            statsContent

            if showsEditButton, let onEdit {
                DiveActivitySectionHeaderActionButton(
                    systemImage: "ellipsis",
                    accessibilityLabel: "Edit dive stats"
                ) {
                    onEdit()
                }
                .padding(.top, Metrics.editButtonInset)
                .padding(.trailing, Metrics.editButtonInset)
                .accessibilityIdentifier("DiveOverview.MapStatsBox.Edit")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("DiveOverview.MapStatsBox")
    }

    private var statsContent: some View {
        HStack(alignment: .top, spacing: Metrics.columnSpacing) {
            leadingColumn
                .frame(maxWidth: .infinity, alignment: .leading)

            depthColumn
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Metrics.contentPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(maxHeight: fillsAvailableHeight ? .infinity : nil, alignment: .topLeading)
        .background {
            AppHighlightTileChrome(cornerRadius: Metrics.cornerRadius)
        }
    }

    private var leadingColumn: some View {
        VStack(alignment: .leading, spacing: Metrics.statSpacing) {
            statRow(layout.leadingStats[0], iconOnLeadingEdge: true)

            if fillsAvailableHeight {
                Spacer(minLength: 0)
            }

            statRow(layout.leadingStats[1], iconOnLeadingEdge: true)
        }
        .frame(maxHeight: fillsAvailableHeight ? .infinity : nil, alignment: .leading)
    }

    private var depthColumn: some View {
        HStack(alignment: .center, spacing: Metrics.iconContentSpacing) {
            VStack(alignment: .leading, spacing: Metrics.statSpacing) {
                ForEach(layout.depthStats) { stat in
                    statRow(stat, iconOnLeadingEdge: false)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            DiveMapOverviewDepthProfileVisual(
                maxDepthFraction: layout.depthGauge.maxFillFraction,
                avgDepthFraction: layout.depthGauge.avgLineFraction,
                showsAverageLine: layout.depthGauge.showsAverageLine,
                width: Metrics.depthVisualWidth,
                height: Metrics.depthGaugeHeight
            )
        }
    }

    private func statRow(
        _ stat: DiveActivityOverviewPresentation.MapOverviewStatsLayout.StatCell,
        iconOnLeadingEdge: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: Metrics.iconContentSpacing) {
            if iconOnLeadingEdge, let icon = stat.icon {
                DiveActivityMapOverviewStatIconView(icon: icon, size: Metrics.iconSize)
            }

            statTextBlock(stat)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(statAccessibilityLabel(stat))
    }

    private func statTextBlock(
        _ stat: DiveActivityOverviewPresentation.MapOverviewStatsLayout.StatCell
    ) -> some View {
        VStack(alignment: .leading, spacing: Metrics.titleValueSpacing) {
            VStack(alignment: .leading, spacing: Metrics.titleLineSpacing) {
                titleLine(stat.titleLine1)
                titleLine(stat.titleLine2)
            }

            valueNumberAndUnit(number: stat.valueNumber, unit: stat.valueUnit)
        }
    }

    private func titleLine(_ text: String) -> some View {
        Text(text)
            .font(.system(size: Metrics.labelFontSize, weight: .semibold))
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .allowsTightening(true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func valueNumberAndUnit(number: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: Metrics.valueLineSpacing) {
            Text(number)
                .font(.system(size: Metrics.valueFontSize, weight: .bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .allowsTightening(true)

            if !unit.isEmpty {
                Text(unit)
                    .font(.system(size: Metrics.unitFontSize, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statAccessibilityLabel(
        _ stat: DiveActivityOverviewPresentation.MapOverviewStatsLayout.StatCell
    ) -> String {
        let title = "\(stat.titleLine1) \(stat.titleLine2)"
        let value = stat.valueUnit.isEmpty ? stat.valueNumber : "\(stat.valueNumber) \(stat.valueUnit)"
        return "\(title), \(value)"
    }
}
