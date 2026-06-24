import SwiftUI

/// Marine-life species logged at a dive site — navigates to Field Guide species detail.
struct ExploreDiveSiteMarineLifeListSection: View {
    let speciesLinks: [DiveSiteMarineLifePresentation.SightedSpeciesLinkData]
    let listAccessibilityIdentifier: String

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            ForEach(speciesLinks) { link in
                NavigationLink(value: ExploreRoute.speciesDetail(link.marineLifeUUID)) {
                    speciesLinkRow(link)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(
                    "Explore.DiveSiteDetail.MarineLife.\(link.marineLifeUUID)"
                )
            }
        }
        .accessibilityIdentifier(listAccessibilityIdentifier)
    }

    private func speciesLinkRow(
        _ link: DiveSiteMarineLifePresentation.SightedSpeciesLinkData
    ) -> some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
            Text(link.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.leading)

            Spacer(minLength: AppTheme.Spacing.sm)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.tabUnselected)
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.surfaceElevated)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.Colors.tabUnselected.opacity(0.12), lineWidth: 1)
        }
    }
}
