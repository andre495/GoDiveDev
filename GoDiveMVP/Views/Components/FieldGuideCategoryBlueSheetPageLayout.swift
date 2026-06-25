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

/// Back chevron + catalog search on one row (category / subcategory browse list pages).
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
                    CatalogSearchDismissButton(
                        action: {
                            isSearchFocused = false
                            searchText = ""
                        },
                        accessibilityIdentifier: cancelAccessibilityIdentifier,
                        usesGlassButtonStyle: false
                    )
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

/// Back chevron + global species search on category / subcategory browse list pages.
struct FieldGuideBrowseSearchChrome: View {
    @Binding var searchText: String
    @FocusState.Binding var isSearchFocused: Bool
    let safeTop: CGFloat
    let topInset: CGFloat
    let onAddSpecies: () -> Void

    var body: some View {
        FieldGuideBlueSheetTopChromeLayer(safeTop: safeTop, topInset: topInset) {
            CatalogListSearchChrome(
                searchText: $searchText,
                isSearchFocused: $isSearchFocused,
                placeholder: FieldGuideSpeciesSearchEnvironment.searchPlaceholder,
                searchFieldAccessibilityIdentifier: FieldGuideSpeciesSearchEnvironment.searchFieldAccessibilityIdentifier,
                cancelAccessibilityIdentifier: FieldGuideSpeciesSearchEnvironment.cancelAccessibilityIdentifier,
                showsTrailingActions: true,
                reservesCancelSlotWhenUnfocused: true,
                leadingActions: {
                    SecondaryDestinationBackButton()
                },
                trailingActions: {
                    FieldGuideMarineLifeAddToolbarButton(action: onAddSpecies)
                }
            )
            .fixedSize(horizontal: false, vertical: true)
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

/// List-page chrome for Field Guide category / subcategory browse (logbook-style scroll under back + search).
enum FieldGuideCatalogBrowseListPresentation {
    nonisolated static let listRowSpacing: CGFloat = FieldGuideHubTileLayout.listRowSpacing
    nonisolated static let listBottomPadding: CGFloat = 16

    nonisolated static func listTopInset(safeAreaTop: CGFloat, headerClearance: CGFloat) -> CGFloat {
        safeAreaTop + headerClearance
    }

    nonisolated static func listBottomInset(safeAreaBottom: CGFloat) -> CGFloat {
        safeAreaBottom + listBottomPadding
    }
}

/// Catalog species search result rows — shared by hub + category + subcategory browse.
struct FieldGuideSpeciesSearchResultsRows: View {
    let catalogSnapshots: [MarineLifeCatalogSnapshot]
    let query: String
    let unitSystem: DiveDisplayUnitSystem
    let onSelectSpecies: (String) -> Void

    @State private var searchableTextByUUID: [String: String] = [:]
    @State private var displayedRows: [FieldGuidePresentation.MarineLifeRowDisplayData] = []
    @State private var rowsRefreshTask: Task<Void, Never>?

    var body: some View {
        Group {
            if displayedRows.isEmpty {
                CatalogSearchEmptyState(
                    title: "No matching species",
                    message: "Try a common name, scientific name, or group like “ray” or “cephalopod”."
                )
                .padding(.vertical, AppTheme.Spacing.lg)
                .listRowInsets(AppScrollUnderHeaderListLayout.horizontalRowInsets)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                ForEach(displayedRows) { row in
                    Button {
                        onSelectSpecies(row.marineLifeUUID)
                    } label: {
                        FieldGuideMarineLifeRow(data: row)
                            .equatable()
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(AppScrollUnderHeaderListLayout.horizontalRowInsets)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .onAppear {
            syncSearchIndex()
            scheduleDisplayedRowsRefresh(immediate: true)
        }
        .onChange(of: catalogSnapshots) { _, _ in
            syncSearchIndex()
            scheduleDisplayedRowsRefresh(immediate: true)
        }
        .onChange(of: query) { _, _ in
            scheduleDisplayedRowsRefresh()
        }
        .onChange(of: unitSystem) { _, _ in
            scheduleDisplayedRowsRefresh(immediate: true)
        }
        .onDisappear {
            rowsRefreshTask?.cancel()
            rowsRefreshTask = nil
        }
    }

    private func syncSearchIndex() {
        searchableTextByUUID = FieldGuideSpeciesSearchResultsPresentation.searchableTextByUUID(
            for: catalogSnapshots
        )
    }

    private func scheduleDisplayedRowsRefresh(immediate: Bool = false) {
        rowsRefreshTask?.cancel()
        let query = query
        let snapshots = catalogSnapshots
        let searchableTextByUUID = searchableTextByUUID
        let unitSystem = unitSystem
        let debounceNanoseconds = immediate
            ? UInt64(0)
            : CatalogSearchPresentation.debounceNanoseconds

        rowsRefreshTask = Task {
            if debounceNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: debounceNanoseconds)
            }
            guard !Task.isCancelled else { return }

            let rows = await Task.detached {
                FieldGuideSpeciesSearchResultsPresentation.rowData(
                    catalogSnapshots: snapshots,
                    searchableTextByUUID: searchableTextByUUID,
                    query: query,
                    unitSystem: unitSystem
                )
            }.value

            guard !Task.isCancelled else { return }
            displayedRows = rows
        }
    }
}

/// Field Guide category / subcategory browse — logbook-style list under back + search chrome.
struct FieldGuideCatalogBrowseListPage<Summary: View, ListRows: View>: View {
    let accessibilityRootIdentifier: String
    let listAccessibilityIdentifier: String?
    @Binding var searchText: String
    @FocusState.Binding var isSearchFocused: Bool
    let catalogSnapshots: [MarineLifeCatalogSnapshot]
    let unitSystem: DiveDisplayUnitSystem
    let onSelectSpecies: (String) -> Void
    let onAddSpecies: () -> Void
    @ViewBuilder let summary: () -> Summary
    @ViewBuilder let listRows: () -> ListRows

    @State private var headerClearance: CGFloat = AppTheme.Layout.appHeaderClearanceFallback

    private var isFilteringSpecies: Bool {
        FieldGuideSpeciesSearchResultsPresentation.isFiltering(query: searchText)
    }

    var body: some View {
        AppHeaderlessPage {
            GeometryReader { proxy in
                let listTopInset = AppScrollUnderHeaderListLayout.listTopInset(
                    safeAreaTop: proxy.safeAreaInsets.top,
                    headerClearance: headerClearance
                )
                let listBottomInset = AppScrollUnderHeaderListLayout.listBottomInset(
                    safeAreaBottom: proxy.safeAreaInsets.bottom
                )

                ZStack(alignment: .top) {
                    if !GoDiveUITestConfiguration.isActive {
                        WaterBubbleBackground()
                    }

                    List {
                        Color.clear
                            .frame(height: listTopInset)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .accessibilityHidden(true)

                        if isFilteringSpecies {
                            FieldGuideSpeciesSearchResultsRows(
                                catalogSnapshots: catalogSnapshots,
                                query: searchText,
                                unitSystem: unitSystem,
                                onSelectSpecies: onSelectSpecies
                            )
                        } else {
                            summary()
                                .listRowInsets(summaryRowInsets)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)

                            listRows()
                        }

                        Color.clear
                            .frame(height: listBottomInset)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .accessibilityHidden(true)
                    }
                    .listStyle(.plain)
                    .listRowSpacing(FieldGuideCatalogBrowseListPresentation.listRowSpacing)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .scrollDismissesKeyboard(.interactively)
                    .ignoresSafeArea(edges: [.top, .bottom])
                    .accessibilityIdentifier(listAccessibilityIdentifier ?? accessibilityRootIdentifier)

                    FieldGuideBrowseSearchChrome(
                        searchText: $searchText,
                        isSearchFocused: $isSearchFocused,
                        safeTop: proxy.safeAreaInsets.top,
                        topInset: listTopInset,
                        onAddSpecies: onAddSpecies
                    )
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .ignoresSafeArea(edges: .bottom)
            }
            .onPreferenceChange(AppHeaderMetrics.HeightKey.self) { height in
                if height > 0 { headerClearance = height }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .hidesBottomTabBarWhenPushed()
        .accessibilityIdentifier(accessibilityRootIdentifier)
    }

    private var summaryRowInsets: EdgeInsets {
        EdgeInsets(
            top: 0,
            leading: AppTheme.Spacing.lg,
            bottom: AppTheme.Spacing.sm,
            trailing: AppTheme.Spacing.lg
        )
    }
}

typealias FieldGuideCategoryBlueSheetBackChrome = FieldGuideBlueSheetBackChrome
