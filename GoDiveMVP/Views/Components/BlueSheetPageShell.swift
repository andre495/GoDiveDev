import SwiftUI

/// Shared **`GeometryReader`** + **`BlueSheetHeaderPageLayout`** wiring for tab-root and pushed-detail shells.
struct BlueSheetPageShell<
    Hero: View,
    HeroOverlay: View,
    PanelOverlay: View,
    Panel: View,
    TopChrome: View,
    FloatingChrome: View
>: View {
    let configuration: BlueSheetDetailPageConfiguration
    let seamInputs: HomeOverviewPushedLayoutPresentation.SeamInputs
    let layoutMode: BlueSheetPageLayoutMode
    var embedTopChromeInLayout: Bool
    var appliesPushedLayoutState: Bool
    var onLayoutResolved: ((BlueSheetHeaderPageLayoutContext) -> Void)?

    @Binding var headerClearance: CGFloat
    @Binding var layoutSafeAreaTopFloor: CGFloat
    @Binding var layoutViewportHeightFloor: CGFloat
    @State private var measuredTabBarClearance: CGFloat = 0

    @ViewBuilder let hero: (_ context: BlueSheetHeaderPageLayoutContext) -> Hero
    @ViewBuilder let heroOverlay: (_ context: BlueSheetHeaderPageLayoutContext) -> HeroOverlay
    @ViewBuilder let panelOverlay: () -> PanelOverlay
    @ViewBuilder let panel: (_ context: BlueSheetHeaderPageLayoutContext) -> Panel
    @ViewBuilder let topChrome: (_ safeTop: CGFloat, _ topInset: CGFloat, _ context: BlueSheetHeaderPageLayoutContext) -> TopChrome
    @ViewBuilder let floatingChrome: (_ safeTop: CGFloat, _ topInset: CGFloat, _ context: BlueSheetHeaderPageLayoutContext) -> FloatingChrome

    var body: some View {
        GeometryReader { proxy in
            let rawSafeTop = AppScrollUnderHeaderListLayout.resolvedSafeAreaTop(
                proxy.safeAreaInsets.top
            )
            let geometryHeight = max(proxy.size.height, 1)
            let layout = BlueSheetHeaderPageLayoutBuilder.make(
                proxy: proxy,
                headerClearance: headerClearance,
                layoutSafeAreaTopFloor: layoutSafeAreaTopFloor,
                layoutViewportHeightFloor: layoutViewportHeightFloor,
                seamInputs: seamInputs,
                mode: layoutMode,
                showsHero: configuration.showsHero,
                measuredTabBarClearance: measuredTabBarClearance
            )

            ZStack(alignment: .top) {
                BlueSheetHeaderPageLayout(
                    context: layout,
                    showsHero: configuration.showsHero,
                    hero: {
                        hero(layout)
                    },
                    heroOverlay: {
                        heroOverlay(layout)
                    },
                    panel: {
                        panel(layout)
                    },
                    topChrome: { safeTop, topInset in
                        if embedTopChromeInLayout {
                            topChrome(safeTop, topInset, layout)
                        } else {
                            EmptyView()
                        }
                    },
                    panelOverlay: {
                        panelOverlay()
                    }
                )

                if !embedTopChromeInLayout {
                    floatingChrome(layout.safeTop, layout.topInset, layout)
                }
            }
            .frame(width: proxy.size.width, height: layout.layoutHeight, alignment: .top)
            .modifier(
                BlueSheetPageShellLayoutStateModifier(
                    appliesPushedLayoutState: appliesPushedLayoutState,
                    headerClearance: $headerClearance,
                    layoutSafeAreaTopFloor: $layoutSafeAreaTopFloor,
                    layoutViewportHeightFloor: $layoutViewportHeightFloor,
                    rawSafeTop: rawSafeTop,
                    geometryHeight: geometryHeight
                )
            )
            .modifier(
                BlueSheetPageShellLayoutResolveModifier(
                    layout: layout,
                    onLayoutResolved: onLayoutResolved
                )
            )
            .rootTabBarClearanceReader(enabled: Self.measuresTabBarClearance(for: layoutMode))
            .onPreferenceChange(RootTabBarClearanceMetrics.HeightKey.self) { clearance in
                guard clearance > 0, abs(clearance - measuredTabBarClearance) > 0.5 else { return }
                measuredTabBarClearance = clearance
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private static func measuresTabBarClearance(for mode: BlueSheetPageLayoutMode) -> Bool {
        if case let .tabRoot(isNavigationStackAtRoot, _) = mode {
            return isNavigationStackAtRoot
        }
        return false
    }
}

/// Fires **`onLayoutResolved`** on first appear and whenever settled layout numbers change.
private struct BlueSheetPageShellLayoutResolveModifier: ViewModifier {
    let layout: BlueSheetHeaderPageLayoutContext
    let onLayoutResolved: ((BlueSheetHeaderPageLayoutContext) -> Void)?

    func body(content: Content) -> some View {
        content
            .onAppear {
                onLayoutResolved?(layout)
            }
            .onChange(of: layout) { _, settledLayout in
                onLayoutResolved?(settledLayout)
            }
    }
}

private struct BlueSheetPageShellLayoutStateModifier: ViewModifier {
    let appliesPushedLayoutState: Bool
    @Binding var headerClearance: CGFloat
    @Binding var layoutSafeAreaTopFloor: CGFloat
    @Binding var layoutViewportHeightFloor: CGFloat
    let rawSafeTop: CGFloat
    let geometryHeight: CGFloat

    func body(content: Content) -> some View {
        if appliesPushedLayoutState {
            content.blueSheetHeaderPageLayoutState(
                headerClearance: $headerClearance,
                layoutSafeAreaTopFloor: $layoutSafeAreaTopFloor,
                layoutViewportHeightFloor: $layoutViewportHeightFloor,
                rawSafeTop: rawSafeTop,
                geometryHeight: geometryHeight
            )
        } else {
            content
        }
    }
}
