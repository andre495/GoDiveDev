import SwiftUI

/// Map-tab overview sheet header — dive **#**, site, place, and start date/time.
struct DiveActivityMapOverviewHeader: View {
    let diveNumberChip: String?
    let siteTitle: String
    let linkedCatalogSiteID: UUID?
    var onOpenLinkedSite: (() -> Void)?
    let regionCountryLine: String?
    let dateDashTimeLine: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            if let diveNumberChip {
                diveNumberChipLabel(diveNumberChip)
            }

            DiveActivityLinkedSiteTitle(
                title: siteTitle,
                linkedCatalogSiteID: linkedCatalogSiteID,
                onOpenLinkedSite: onOpenLinkedSite
            )

            if let regionCountryLine, !regionCountryLine.isEmpty {
                Text(regionCountryLine)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .multilineTextAlignment(.leading)
            }

            Text(dateDashTimeLine)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("DiveOverview.MapHeader")
    }

    private func diveNumberChipLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.accent)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background {
                Capsule(style: .continuous)
                    .strokeBorder(AppTheme.Colors.accent.opacity(0.55), lineWidth: 1)
                    .background {
                        Capsule(style: .continuous)
                            .fill(AppTheme.Colors.accent.opacity(0.1))
                    }
            }
            .accessibilityLabel("Dive number \(title)")
    }
}
