import SwiftUI

/// Floating back chrome for Field Guide blue-sheet pages without inline search (species detail).
struct FieldGuideBlueSheetBackChrome: View {
    let safeTop: CGFloat
    let topInset: CGFloat

    var body: some View {
        FieldGuideBlueSheetTopChromeLayer(safeTop: safeTop, topInset: topInset) {
            AppHeader(
                title: "",
                showsBackButton: true,
                showsBrandWordmark: false,
                statusBarSafeAreaTop: safeTop
            ) {
                EmptyView()
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .zIndex(1)
        }
    }
}

/// Back chevron + catalog search on one row (category / subcategory blue-sheet pages).
struct FieldGuideBlueSheetSearchBackChrome: View {
    @Binding var searchText: String
    @FocusState.Binding var isSearchFocused: Bool
    let safeTop: CGFloat
    let topInset: CGFloat
    let placeholder: String
    let searchFieldAccessibilityIdentifier: String
    let cancelAccessibilityIdentifier: String

    var body: some View {
        FieldGuideBlueSheetTopChromeLayer(safeTop: safeTop, topInset: topInset) {
            HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
                SecondaryDestinationBackButton()

                CatalogSearchField(
                    text: $searchText,
                    isFocused: $isSearchFocused,
                    placeholder: placeholder,
                    accessibilityIdentifier: searchFieldAccessibilityIdentifier
                )
                .frame(maxWidth: .infinity)

                if isSearchFocused {
                    Button {
                        isSearchFocused = false
                        searchText = ""
                    } label: {
                        Text("Cancel")
                            .font(.body.weight(.semibold))
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.Colors.tabSelected)
                    .accessibilityIdentifier(cancelAccessibilityIdentifier)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isSearchFocused)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .appTopChromeVerticalPadding()
            .fixedSize(horizontal: false, vertical: true)
            .contentShape(Rectangle())
            .background(alignment: .top) {
                if safeTop > 0.5 {
                    AppStatusBarEdgeScrim(safeAreaTop: safeTop)
                        .ignoresSafeArea(edges: .top)
                }
            }
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: AppHeaderMetrics.HeightKey.self, value: proxy.size.height)
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .zIndex(1)
        }
    }
}

private struct FieldGuideBlueSheetTopChromeLayer<Content: View>: View {
    let safeTop: CGFloat
    let topInset: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: .top) {
            LogbookTopChromeScrim(topObstructionHeight: topInset)
                .padding(.top, -safeTop)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
                .zIndex(0.5)

            Color.clear
                .frame(height: topInset)
                .frame(maxWidth: .infinity, alignment: .top)
                .contentShape(Rectangle())
                .accessibilityHidden(true)
                .zIndex(0.75)

            content()
        }
    }
}

/// Shared Field Guide pushed detail shell — **`BlueSheetHeaderPageLayout`** with custom hero + pinned summary.
struct FieldGuideBlueSheetPage<Hero: View, HeroOverlay: View, PinnedContent: View, PanelBody: View>: View {
    let accessibilityRootIdentifier: String
    let scrollAccessibilityIdentifier: String?
    var searchText: Binding<String>?
    var isSearchFocused: FocusState<Bool>.Binding?
    var searchPlaceholder: String?
    var searchFieldAccessibilityIdentifier: String?
    var cancelAccessibilityIdentifier: String?
    @ViewBuilder let hero: (_ context: BlueSheetHeaderPageLayoutContext) -> Hero
    @ViewBuilder let pinnedContent: () -> PinnedContent
    @ViewBuilder let panelContent: (_ bottomScrollInset: CGFloat) -> PanelBody
    @ViewBuilder let heroOverlay: (_ context: BlueSheetHeaderPageLayoutContext) -> HeroOverlay

    @State private var headerClearance: CGFloat = AppTheme.Layout.appHeaderClearanceFallback
    @State private var layoutSafeAreaTopFloor =
        DiveBuddyDetailPresentation.initialPushedLayoutSafeAreaTopFloor()
    @State private var layoutViewportHeightFloor =
        DiveBuddyDetailPresentation.initialPushedLayoutViewportFloor()

    private var seamInputs: HomeOverviewPushedLayoutPresentation.SeamInputs {
        HomeOverviewPushedLayoutPresentation.pushedPageSeamInputs()
    }

    var body: some View {
        AppHeaderlessPage {
            GeometryReader { proxy in
                let rawSafeTop = AppScrollUnderHeaderListLayout.resolvedSafeAreaTop(
                    proxy.safeAreaInsets.top
                )
                let geometryHeight = max(proxy.size.height, 1)
                let heroHeight = BlueSheetHeaderPageLayoutBuilder.heroHeight(
                    geometryHeight: geometryHeight,
                    screenWidth: proxy.size.width,
                    topSafeAreaInset: HomeOverviewLayout.pushedHeroTopSafeAreaInset(
                        rawGeometrySafeTop: proxy.safeAreaInsets.top,
                        transitionSafeTopFloor: layoutSafeAreaTopFloor
                    ),
                    statsPanelContentHeight: seamInputs.statsPanelContentHeight,
                    showsBuddyLeaderboard: seamInputs.showsBuddyLeaderboard,
                    transitionViewportFloor: layoutViewportHeightFloor
                )
                let layout = BlueSheetHeaderPageLayoutBuilder.make(
                    proxy: proxy,
                    headerClearance: headerClearance,
                    layoutSafeAreaTopFloor: layoutSafeAreaTopFloor,
                    layoutViewportHeightFloor: layoutViewportHeightFloor,
                    heroHeight: heroHeight,
                    showsHero: true
                )

                BlueSheetHeaderPageLayout(
                    context: layout,
                    showsHero: true,
                    hero: {
                        hero(layout)
                    },
                    heroOverlay: {
                        heroOverlay(layout)
                    },
                    panel: {
                        VStack(alignment: .leading, spacing: 0) {
                            pinnedContent()
                                .padding(.horizontal, AppTheme.Spacing.md)
                                .padding(.top, AppTheme.Spacing.md)
                                .padding(.bottom, AppTheme.Spacing.sm)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityIdentifier("\(accessibilityRootIdentifier).PinnedSummary")

                            panelContent(layout.bottomScrollInset)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    },
                    backChrome: { safeTop, topInset in
                        if let searchText,
                           let isSearchFocused,
                           let searchPlaceholder,
                           let searchFieldAccessibilityIdentifier,
                           let cancelAccessibilityIdentifier {
                            FieldGuideBlueSheetSearchBackChrome(
                                searchText: searchText,
                                isSearchFocused: isSearchFocused,
                                safeTop: safeTop,
                                topInset: topInset,
                                placeholder: searchPlaceholder,
                                searchFieldAccessibilityIdentifier: searchFieldAccessibilityIdentifier,
                                cancelAccessibilityIdentifier: cancelAccessibilityIdentifier
                            )
                        } else {
                            FieldGuideBlueSheetBackChrome(
                                safeTop: safeTop,
                                topInset: topInset
                            )
                        }
                    }
                )
                .blueSheetHeaderPageLayoutState(
                    headerClearance: $headerClearance,
                    layoutSafeAreaTopFloor: $layoutSafeAreaTopFloor,
                    layoutViewportHeightFloor: $layoutViewportHeightFloor,
                    rawSafeTop: rawSafeTop,
                    geometryHeight: geometryHeight
                )
            }
        }
        .ignoresSafeArea(edges: [.horizontal])
        .hidesBottomTabBarWhenPushed()
        .accessibilityIdentifier(accessibilityRootIdentifier)
    }
}

/// Category / subcategory detail — category gradient hero in the header band.
struct FieldGuideCategoryBlueSheetPage<PinnedContent: View, ScrollContent: View>: View {
    let categoryID: String
    let systemImage: String
    let heroImageName: String?
    let accessibilityRootIdentifier: String
    let scrollAccessibilityIdentifier: String?
    @Binding var searchText: String
    @FocusState.Binding var isSearchFocused: Bool
    let searchPlaceholder: String
    let searchFieldAccessibilityIdentifier: String
    let cancelAccessibilityIdentifier: String
    @ViewBuilder let pinnedContent: () -> PinnedContent
    @ViewBuilder let scrollContent: () -> ScrollContent

    var body: some View {
        FieldGuideBlueSheetPage(
            accessibilityRootIdentifier: accessibilityRootIdentifier,
            scrollAccessibilityIdentifier: scrollAccessibilityIdentifier,
            searchText: $searchText,
            isSearchFocused: $isSearchFocused,
            searchPlaceholder: searchPlaceholder,
            searchFieldAccessibilityIdentifier: searchFieldAccessibilityIdentifier,
            cancelAccessibilityIdentifier: cancelAccessibilityIdentifier,
            hero: { context in
                FieldGuideCategoryHeroImage(
                    categoryID: categoryID,
                    systemImage: systemImage,
                    heroImageName: heroImageName,
                    totalHeight: context.heroHeight,
                    fullBleed: true
                )
            },
            pinnedContent: pinnedContent,
            panelContent: { bottomScrollInset in
                BlueSheetHeaderScrollPageLayout.scrollPage(
                    bottomScrollInset: bottomScrollInset,
                    accessibilityIdentifier: scrollAccessibilityIdentifier
                ) {
                    scrollContent()
                        .padding(.horizontal, AppTheme.Spacing.md)
                }
            },
            heroOverlay: { _ in EmptyView() }
        )
    }
}

typealias FieldGuideCategoryBlueSheetBackChrome = FieldGuideBlueSheetBackChrome
