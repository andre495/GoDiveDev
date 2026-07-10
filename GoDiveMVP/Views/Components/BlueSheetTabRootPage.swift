import SwiftUI

/// Home tab-root shell — same layout path as **`BlueSheetDetailPage`** (virtual full-screen hero + sheet stack).
/// Tab root does not wrap **`AppHeaderlessPage`** — **`LogOverviewView`** owns page background; an inner gradient duplicated the sheet seam band above **`HomeLifetimeStatsPanel`**.
struct BlueSheetTabRootPage<
    Hero: View,
    HeroOverlay: View,
    PanelBody: View,
    TopChrome: View
>: View {
    let configuration: BlueSheetDetailPageConfiguration
    let seamInputs: HomeOverviewPushedLayoutPresentation.SeamInputs
    let isNavigationStackAtRoot: Bool
    var allowsTopChromeHitTesting: Bool = true
    var onLayoutResolved: ((BlueSheetHeaderPageLayoutContext) -> Void)?

    @Binding var frozenRootViewportHeight: CGFloat?

    @ViewBuilder let hero: (_ context: BlueSheetHeaderPageLayoutContext) -> Hero
    @ViewBuilder let heroOverlay: (_ context: BlueSheetHeaderPageLayoutContext) -> HeroOverlay
    @ViewBuilder let panelContent: (_ context: BlueSheetHeaderPageLayoutContext) -> PanelBody
    @ViewBuilder let topChrome: (_ safeTop: CGFloat, _ topInset: CGFloat, _ context: BlueSheetHeaderPageLayoutContext) -> TopChrome

    @State private var headerClearance: CGFloat = AppTheme.Layout.appHeaderClearanceFallback
    @State private var layoutSafeAreaTopFloor = AppScrollUnderHeaderListLayout.resolvedSafeAreaTop(0)
    @State private var layoutViewportHeightFloor: CGFloat = 0

    var body: some View {
        BlueSheetPageShell(
            configuration: configuration,
            seamInputs: seamInputs,
            layoutMode: .tabRoot(
                isNavigationStackAtRoot: isNavigationStackAtRoot,
                frozenRootViewportHeight: frozenRootViewportHeight
            ),
            embedTopChromeInLayout: true,
            appliesPushedLayoutState: true,
            onLayoutResolved: { layout in
                if isNavigationStackAtRoot, layout.geometryHeight > 0 {
                    let frozenHeight = HomeTabRootLayoutPresentation.tabContentGeometryHeight(
                        geometryHeight: layout.geometryHeight,
                        isNavigationStackAtRoot: true,
                        frozenTabContentGeometryHeight: nil
                    )
                    Task { @MainActor in
                        if frozenRootViewportHeight != frozenHeight {
                            frozenRootViewportHeight = frozenHeight
                        }
                    }
                }
                onLayoutResolved?(layout)
            },
            headerClearance: $headerClearance,
            layoutSafeAreaTopFloor: $layoutSafeAreaTopFloor,
            layoutViewportHeightFloor: $layoutViewportHeightFloor,
            hero: hero,
            heroOverlay: heroOverlay,
            panelOverlay: { EmptyView() },
            panel: panelContent,
            topChrome: { safeTop, topInset, layout in
                topChrome(safeTop, topInset, layout)
                    .allowsHitTesting(allowsTopChromeHitTesting)
            },
            floatingChrome: { _, _, _ in
                EmptyView()
            }
        )
        .onPreferenceChange(AppHeaderMetrics.HeightKey.self) { height in
            if height > 0 { headerClearance = height }
        }
        .accessibilityIdentifier(configuration.accessibilityRootIdentifier)
    }
}
