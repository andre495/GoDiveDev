import SwiftUI

/// List-page chrome for Field Guide category / subcategory browse (logbook-style scroll under collapsible title).
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

/// Field Guide category / subcategory browse — logbook-style list under collapsible title chrome.
struct FieldGuideCatalogBrowseListPage<Summary: View, ListRows: View>: View {
    let title: String
    let titleAccessibilityIdentifier: String
    let accessibilityRootIdentifier: String
    let listAccessibilityIdentifier: String?
    let onAddSpecies: () -> Void
    @ViewBuilder let summary: () -> Summary
    @ViewBuilder let listRows: () -> ListRows

    @State private var headerClearance: CGFloat = AppTheme.Layout.appHeaderClearanceFallback
    @State private var isHeaderCollapsed = false

    var body: some View {
        AppHeaderlessPage {
            GeometryReader { proxy in
                let safeTop = AppScrollUnderHeaderListLayout.resolvedSafeAreaTop(proxy.safeAreaInsets.top)
                let listTopInset = AppScrollUnderHeaderListLayout.listTopInset(
                    safeAreaTop: safeTop,
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

                        summary()
                            .listRowInsets(summaryRowInsets)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)

                        listRows()

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
                    .onScrollGeometryChange(for: CGFloat.self) { geometry in
                        geometry.contentOffset.y + geometry.contentInsets.top
                    } action: { offset, _ in
                        isHeaderCollapsed = CollapsibleInlineTitleHeaderPresentation
                            .isCollapsed(forScrollOffset: offset)
                    }
                    .accessibilityIdentifier(listAccessibilityIdentifier ?? accessibilityRootIdentifier)

                    LogbookTopChromeScrim(
                        topObstructionHeight: listTopInset,
                        featherHeight: CollapsibleInlineTitleHeaderPresentation.listScrollFadeFeatherHeight
                    )
                    .padding(.top, -safeTop)
                    .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)
                    .zIndex(0.5)

                    Color.clear
                        .frame(height: listTopInset)
                        .frame(maxWidth: .infinity, alignment: .top)
                        .contentShape(Rectangle())
                        .accessibilityHidden(true)
                        .zIndex(0.75)

                    FieldGuideBrowseCollapsibleHeader(
                        title: title,
                        isCollapsed: isHeaderCollapsed,
                        statusBarSafeAreaTop: safeTop,
                        titleAccessibilityIdentifier: titleAccessibilityIdentifier,
                        onAddSpecies: onAddSpecies
                    )
                    .frame(maxWidth: .infinity, alignment: .top)
                    .zIndex(1)
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
