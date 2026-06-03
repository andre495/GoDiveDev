import SwiftData
import SwiftUI

private enum FieldGuideRoute: Hashable {
    case category(String)
    case subcategory(categoryID: String, subcategoryID: String)
    case speciesDetail(String)
    case diveDetail(UUID)
}

struct FieldGuideView: View {
    @Environment(AccountSession.self) private var accountSession
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem
    @Query(sort: \MarineLife.commonName) private var catalog: [MarineLife]
    @Query(
        sort: [
            SortDescriptor(\DiveActivity.startTime, order: .reverse),
            SortDescriptor(\DiveActivity.id, order: .forward),
        ]
    )
    private var diveActivities: [DiveActivity]

    @State private var path: [FieldGuideRoute] = []
    @State private var section: FieldGuideSection = .fieldGuide
    @State private var speciesSearchQuery = ""
    @FocusState private var isSpeciesSearchFocused: Bool
    @State private var fieldGuideHeaderClearance: CGFloat = AppTheme.Layout.appHeaderClearanceFallback
    @State private var listScrollToTopNonce = 0

    private var catalogSnapshots: [MarineLifeCatalogSnapshot] {
        catalog.map(\.fieldGuideCatalogSnapshot)
    }

    private var categorySummaries: [FieldGuideCatalogIndex.CategorySummary] {
        FieldGuideCatalogIndex.summaries(for: catalogSnapshots)
    }

    private var filteredCatalogSnapshots: [MarineLifeCatalogSnapshot] {
        FieldGuideMarineLifeSearch.filtering(catalogSnapshots, query: speciesSearchQuery)
    }

    private var listRows: [FieldGuidePresentation.MarineLifeRowDisplayData] {
        FieldGuidePresentation.rowData(
            for: filteredCatalogSnapshots,
            sightedMarineLifeUUIDs: [],
            unitSystem: diveDisplayUnitSystem
        )
    }

    private var isFilteringSpecies: Bool {
        FieldGuideMarineLifeSearch.isFiltering(query: speciesSearchQuery)
    }

    private var showsSpeciesSearch: Bool {
        section == .fieldGuide && !catalog.isEmpty
    }

    private var ownerDiveActivities: [DiveActivity] {
        guard let ownerID = accountSession.currentProfile?.id else { return [] }
        return diveActivities.filter { $0.ownerProfileID == ownerID }
    }

    var body: some View {
        NavigationStack(path: $path) {
            AppHeaderlessPage {
                GeometryReader { proxy in
                    let listTopInset = proxy.safeAreaInsets.top + fieldGuideHeaderClearance
                    let listBottomInset = proxy.safeAreaInsets.bottom + AppTheme.Spacing.md

                    ZStack(alignment: .top) {
                        sectionContent(
                            topInset: listTopInset,
                            bottomInset: listBottomInset
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        if showsTopChromeScrim {
                            LogbookTopChromeScrim(topObstructionHeight: listTopInset)
                                .padding(.top, -proxy.safeAreaInsets.top)
                                .ignoresSafeArea(edges: .top)
                                .allowsHitTesting(false)
                                .zIndex(0.5)
                        }

                        FieldGuideTopChrome(
                            section: $section,
                            searchText: $speciesSearchQuery,
                            isSearchFocused: $isSpeciesSearchFocused,
                            showsSpeciesSearch: showsSpeciesSearch,
                            statusBarSafeAreaTop: proxy.safeAreaInsets.top
                        )
                        .zIndex(1)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .ignoresSafeArea(edges: .bottom)
                }
                .onPreferenceChange(AppHeaderMetrics.HeightKey.self) { height in
                    if height > 0 { fieldGuideHeaderClearance = height }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: FieldGuideRoute.self) { route in
                switch route {
                case .category(let categoryID):
                    if let summary = categorySummaries.first(where: { $0.categoryID == categoryID }) {
                        FieldGuideCategoryDetailView(
                            categoryID: categoryID,
                            summary: summary,
                            onSelectSubcategory: { subcategoryID in
                                path.append(.subcategory(categoryID: categoryID, subcategoryID: subcategoryID))
                            }
                        )
                    } else {
                        missingCategoryPlaceholder
                    }
                case .subcategory(let categoryID, let subcategoryID):
                    FieldGuideSubcategorySpeciesView(
                        categoryID: categoryID,
                        subcategoryID: subcategoryID,
                        catalog: catalogSnapshots,
                        unitSystem: diveDisplayUnitSystem,
                        onSelectSpecies: { uuid in
                            path.append(.speciesDetail(uuid))
                        }
                    )
                case .speciesDetail(let marineLifeUUID):
                    if let species = catalog.first(where: { $0.uuid == marineLifeUUID }) {
                        FieldGuideMarineLifeDetailView(
                            species: species,
                            ownerProfileID: accountSession.currentProfile?.id
                        ) { activityID in
                            path.append(.diveDetail(activityID))
                        }
                    } else {
                        missingSpeciesPlaceholder
                    }
                case .diveDetail(let id):
                    if let activity = ownerDiveActivities.first(where: { $0.id == id }) {
                        ViewSingleActivity(activity: activity)
                    } else {
                        missingDivePlaceholder
                    }
                }
            }
        }
        .navigationInteractivePopGestureForHiddenNavBar()
        .rootTabReselectObserver(notification: .fieldGuideTabReselected)
        .onReceive(NotificationCenter.default.publisher(for: .fieldGuideTabReselected)) { _ in
            handleFieldGuideTabReselect()
        }
        .onChange(of: section) { _, newSection in
            if newSection != .fieldGuide {
                dismissSpeciesSearchKeyboard()
            }
        }
        .onChange(of: isSpeciesSearchFocused) { _, isFocused in
            if !isFocused {
                dismissSpeciesSearchKeyboard()
            }
        }
    }

    private var showsTopChromeScrim: Bool {
        switch section {
        case .fieldGuide:
            return !catalog.isEmpty
        case .sightings:
            return true
        }
    }

    @ViewBuilder
    private func sectionContent(topInset: CGFloat, bottomInset: CGFloat) -> some View {
        switch section {
        case .fieldGuide:
            ZStack(alignment: .top) {
                if !GoDiveUITestConfiguration.isActive {
                    WaterBubbleBackground()
                }

                fieldGuideCatalogListContent(
                    topInset: topInset,
                    bottomInset: bottomInset
                )
            }
        case .sightings:
            FieldGuideSightingsOverviewView()
        }
    }

    private func handleFieldGuideTabReselect() {
        path.removeAll()
        isSpeciesSearchFocused = false
        guard section == .fieldGuide else { return }
        RootTabListScrollSupport.scheduleScrollToTop { listScrollToTopNonce += 1 }
    }

    private func dismissSpeciesSearchKeyboard() {
        isSpeciesSearchFocused = false
    }

    private var missingCategoryPlaceholder: some View {
        Text("This category is not available.")
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .padding()
    }

    private var missingSpeciesPlaceholder: some View {
        Text("This species is no longer in the catalog.")
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .padding()
    }

    private var missingDivePlaceholder: some View {
        Text("This dive is no longer in your log.")
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .padding()
    }

    @ViewBuilder
    private func fieldGuideCatalogListContent(topInset: CGFloat, bottomInset: CGFloat) -> some View {
        if catalog.isEmpty {
            FieldGuideCatalogEmptyState()
                .padding(.top, topInset)
        } else if isFilteringSpecies {
            fieldGuideSearchResultsList(topInset: topInset, bottomInset: bottomInset)
        } else {
            FieldGuideCatalogHubView(summaries: categorySummaries) { categoryID in
                path.append(.category(categoryID))
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear.frame(height: topInset)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: bottomInset)
            }
            .scrollDismissesKeyboard(.interactively)
            .ignoresSafeArea(edges: [.top, .bottom])
        }
    }

    @ViewBuilder
    private func fieldGuideSearchResultsList(topInset: CGFloat, bottomInset: CGFloat) -> some View {
        if listRows.isEmpty {
            CatalogSearchEmptyState(
                title: "No matching species",
                message: "Try a common name, scientific name, or group like “ray” or “cephalopod”."
            )
            .padding(.top, topInset)
        } else {
            List {
                Color.clear
                    .frame(height: topInset)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .accessibilityHidden(true)

                ForEach(listRows) { row in
                    Button {
                        path.append(.speciesDetail(row.marineLifeUUID))
                    } label: {
                        FieldGuideMarineLifeRow(data: row)
                            .equatable()
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(
                        EdgeInsets(
                            top: 0,
                            leading: AppTheme.Spacing.lg,
                            bottom: 0,
                            trailing: AppTheme.Spacing.lg
                        )
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

                Color.clear
                    .frame(height: bottomInset)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .accessibilityHidden(true)
            }
            .listStyle(.plain)
            .listRowSpacing(AppTheme.Spacing.md)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .animation(nil, value: listRows.count)
            .scrollDismissesKeyboard(.interactively)
            .ignoresSafeArea(edges: [.top, .bottom])
            .listScrollToTopTrigger(nonce: listScrollToTopNonce)
        }
    }
}

// MARK: - Empty states

private struct FieldGuideCatalogEmptyState: View {
    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer(minLength: AppTheme.Spacing.lg)

            AppComingSoonPlaceholder(
                systemImage: "leaf",
                message: "Species catalog is loading. Check back shortly."
            )

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, AppTheme.Spacing.lg)
    }
}

#Preview {
    FieldGuideView()
        .environment(AccountSession.shared)
        .modelContainer(try! AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true))
}
