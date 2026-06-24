import SwiftUI

/// Read-only OpenDiveMap reference site pushed from **Explore** (blue sheet + map hero).
struct ExploreReferenceSiteDetailView: View {
    let snapshot: DiveSiteReferenceSnapshot

    private var record: DiveSiteDisplayRecord {
        DiveSitePresentation.listRecord(for: snapshot)
    }

    private var mapPins: [TripDetailMapPin] {
        ExploreDiveSiteDetailPresentation.mapPins(for: snapshot)
    }

    var body: some View {
        FieldGuideBlueSheetPage(
            accessibilityRootIdentifier: "Explore.ReferenceSiteDetail.Root",
            scrollAccessibilityIdentifier: "Explore.ReferenceSiteDetail.Scroll",
            hero: { context in
                referenceHeroContent(context: context)
            },
            pinnedContent: {
                ExploreDiveSiteDetailPinnedTitleView(
                    record: record,
                    accessibilityIdentifier: "Explore.ReferenceSiteDetail.TitleBlock"
                )
            },
            panelContent: { bottomScrollInset in
                BlueSheetHeaderScrollPageLayout.scrollPage(
                    bottomScrollInset: bottomScrollInset,
                    accessibilityIdentifier: "Explore.ReferenceSiteDetail.Scroll"
                ) {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                        ExploreDiveSiteDetailMetadataView(record: record)

                        Text("OpenDiveMap reference site. Log a dive here to add it to your catalog.")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppTheme.Spacing.md)
                }
            },
            heroOverlay: { _ in EmptyView() }
        )
    }

    @ViewBuilder
    private func referenceHeroContent(context: BlueSheetHeaderPageLayoutContext) -> some View {
        Group {
            if mapPins.isEmpty {
                Rectangle()
                    .fill(AppTheme.Colors.tabUnselected.opacity(0.12))
                    .overlay {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 56))
                            .foregroundStyle(AppTheme.Colors.tabUnselected)
                    }
                    .accessibilityLabel("Dive site header")
            } else {
                TripDetailMapView(
                    pins: mapPins,
                    fitLayout: context.mapFitLayout(),
                    onSiteSelected: { _ in }
                )
            }
        }
        .frame(height: context.heroHeight)
        .frame(maxWidth: .infinity)
        .clipped()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Explore.ReferenceSiteDetail.Hero")
    }
}
