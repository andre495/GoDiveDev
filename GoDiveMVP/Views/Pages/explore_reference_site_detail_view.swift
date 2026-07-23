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
        BlueSheetDetailPage(
            configuration: .pushedDetailWithStandardPanelBodySpacing(
                accessibilityRootIdentifier: "Explore.ReferenceSiteDetail.Root"
            ),
            hero: { context in
                referenceHeroContent(context: context)
            },
            heroOverlay: { _ in EmptyView() },
            panelOverlay: { EmptyView() },
            pinnedContent: {
                BlueSheetPinnedSummary(
                    title: record.displayName,
                    subtitle: record.pinnedLocationLine,
                    subtitleAccessibilityIdentifier: record.pinnedLocationLine == nil
                        ? nil
                        : "Explore.ReferenceSiteDetail.TitleBlock.Location",
                    accessibilityIdentifier: "Explore.ReferenceSiteDetail.TitleBlock"
                )
            },
            panelContent: { bottomScrollInset, _ in
                ExploreReferenceSiteDetailContentPager(
                    record: record,
                    bottomScrollInset: bottomScrollInset
                )
            },
            topChrome: { safeTop, topInset, _ in
                BlueSheetDetailTopChrome(
                    safeTop: safeTop,
                    topInset: topInset,
                    showsEditAction: false,
                    isEditEnabled: false,
                    onEdit: {},
                    editAccessibilityIdentifier: "Explore.ReferenceSiteDetail.Edit"
                )
            }
        )
    }

    @ViewBuilder
    private func referenceHeroContent(context: BlueSheetHeaderPageLayoutContext) -> some View {
        BlueSheetDetailHeroBandFill(accessibilityIdentifier: "Explore.ReferenceSiteDetail.Hero") {
            if mapPins.isEmpty {
                BlueSheetDetailHeroPlaceholder(style: .diveSite)
            } else {
                TripDetailMapView(
                    pins: mapPins,
                    fitLayout: context.mapFitLayout(),
                    onSiteSelected: { _ in }
                )
            }
        }
    }
}
