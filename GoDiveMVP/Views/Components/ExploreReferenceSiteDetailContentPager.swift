import SwiftUI

/// Single-tab reference site detail pager — metadata + reference copy.
struct ExploreReferenceSiteDetailContentPager: View {
    let record: DiveSiteDisplayRecord
    let bottomScrollInset: CGFloat

    @State private var selectedPage: ExploreReferenceSiteDetailContentPage =
        ExploreReferenceSiteDetailContentPagerPresentation.defaultPage

    var body: some View {
        BlueSheetDetailPager(
            pagerAccessibilityIdentifier: "Explore.ReferenceSiteDetail.ContentPager",
            pages: ExploreReferenceSiteDetailContentPagerPresentation.pages,
            selection: $selectedPage,
            bottomScrollInset: bottomScrollInset,
            pageLayout: ExploreReferenceSiteDetailContentPagerPresentation.pagerPageLayout(for:),
            pageContent: pageContent(for:)
        )
    }

    @ViewBuilder
    private func pageContent(for page: ExploreReferenceSiteDetailContentPage) -> some View {
        switch page {
        case .details:
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                ExploreDiveSiteDetailMetadataView(record: record)

                Text("OpenDiveMap reference site. Log a dive here to add it to your catalog.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("Explore.ReferenceSiteDetail.Details")
        }
    }
}
