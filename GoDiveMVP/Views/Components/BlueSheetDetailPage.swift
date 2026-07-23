import SwiftUI

/// Canonical **blue sheet** shell for pushed detail pages (buddy, trip, species, dive site).
///
/// Shares hero + sheet proportions with **`BlueSheetTabRootPage`** via **`BlueSheetPageLayoutBuilder`**.
struct BlueSheetDetailPage<
    Hero: View,
    HeroOverlay: View,
    PanelOverlay: View,
    PinnedContent: View,
    PanelBody: View,
    TopChrome: View
>: View {
    let configuration: BlueSheetDetailPageConfiguration
    var seamInputs: HomeOverviewPushedLayoutPresentation.SeamInputs?

    @ViewBuilder let hero: (_ context: BlueSheetHeaderPageLayoutContext) -> Hero
    @ViewBuilder let heroOverlay: (_ context: BlueSheetHeaderPageLayoutContext) -> HeroOverlay
    @ViewBuilder let panelOverlay: () -> PanelOverlay
    @ViewBuilder let pinnedContent: () -> PinnedContent
    @ViewBuilder let panelContent: (_ bottomScrollInset: CGFloat, _ context: BlueSheetHeaderPageLayoutContext) -> PanelBody
    @ViewBuilder let topChrome: (_ safeTop: CGFloat, _ topInset: CGFloat, _ context: BlueSheetHeaderPageLayoutContext) -> TopChrome

    @State private var headerClearance: CGFloat = AppTheme.Layout.appHeaderClearanceFallback
    @State private var layoutSafeAreaTopFloor =
        DiveBuddyDetailPresentation.initialPushedLayoutSafeAreaTopFloor()
    @State private var layoutViewportHeightFloor =
        DiveBuddyDetailPresentation.initialPushedLayoutViewportFloor()

    private var resolvedSeamInputs: HomeOverviewPushedLayoutPresentation.SeamInputs {
        seamInputs ?? HomeOverviewPushedLayoutPresentation.pushedPageSeamInputs()
    }

    var body: some View {
        AppHeaderlessPage {
            BlueSheetPageShell(
                configuration: configuration,
                seamInputs: resolvedSeamInputs,
                layoutMode: .pushedDetail(transitionViewportHeightFloor: layoutViewportHeightFloor),
                embedTopChromeInLayout: true,
                appliesPushedLayoutState: true,
                onLayoutResolved: nil,
                headerClearance: $headerClearance,
                layoutSafeAreaTopFloor: $layoutSafeAreaTopFloor,
                layoutViewportHeightFloor: $layoutViewportHeightFloor,
                hero: hero,
                heroOverlay: heroOverlay,
                panelOverlay: panelOverlay,
                panel: { layout in
                    panelBody(layout: layout)
                },
                topChrome: topChrome,
                floatingChrome: { _, _, _ in
                    EmptyView()
                }
            )
        }
        .ignoresSafeArea(edges: [.horizontal])
        .modifier(BlueSheetDetailPageTabBarVisibilityModifier(
            hidesTabBarWhenPushed: configuration.hidesTabBarWhenPushed
        ))
        .accessibilityIdentifier(configuration.accessibilityRootIdentifier)
    }

    @ViewBuilder
    private func panelBody(layout: BlueSheetHeaderPageLayoutContext) -> some View {
        let pinnedBottomPadding = configuration.pinnedSummaryBottomPadding
            ?? BlueSheetDetailPagePinnedSummaryPresentation.defaultPinnedSummaryBottomPaddingBeforeDivider
        let horizontalPadding = BlueSheetDetailPagePinnedSummaryPresentation.horizontalPadding
        VStack(alignment: .leading, spacing: 0) {
            pinnedSummarySection(
                layout: layout,
                pinnedBottomPadding: pinnedBottomPadding
            )
            .padding(.horizontal, horizontalPadding)

            BlueSheetDetailPanelContentTopDivider()

            panelContent(layout.bottomScrollInset, layout)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, horizontalPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func pinnedSummarySection(
        layout: BlueSheetHeaderPageLayoutContext,
        pinnedBottomPadding: CGFloat
    ) -> some View {
        if configuration.showsHero {
            pinnedContent()
                .padding(.top, BlueSheetDetailPagePinnedSummaryPresentation.seamTopPadding)
                .padding(.bottom, pinnedBottomPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier(
                    "\(configuration.accessibilityRootIdentifier).\(BlueSheetDetailPagePinnedSummaryPresentation.pinnedSummaryAccessibilitySuffix)"
                )
        } else {
            pinnedContent()
                .padding(.top, layout.headerScrollClearance)
                .padding(.bottom, BlueSheetDetailPagePinnedSummaryPresentation.bodyBottomPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier(
                    "\(configuration.accessibilityRootIdentifier).\(BlueSheetDetailPagePinnedSummaryPresentation.pinnedSummaryAccessibilitySuffix)"
                )
        }
    }
}

private struct BlueSheetDetailPageTabBarVisibilityModifier: ViewModifier {
    let hidesTabBarWhenPushed: Bool

    func body(content: Content) -> some View {
        if hidesTabBarWhenPushed {
            content.hidesBottomTabBarWhenPushed()
        } else {
            content
        }
    }
}
