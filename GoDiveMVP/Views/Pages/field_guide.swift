import SwiftData
import SwiftUI

private enum FieldGuideRoute: Hashable {
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
    @State private var speciesSearchQuery = ""
    @FocusState private var isSpeciesSearchFocused: Bool
    @State private var fieldGuideHeaderClearance: CGFloat = AppTheme.Layout.appHeaderClearanceFallback
    @State private var listScrollToTopNonce = 0

    private var filteredCatalogSnapshots: [MarineLifeCatalogSnapshot] {
        FieldGuideMarineLifeSearch.filtering(
            catalog.map(\.fieldGuideCatalogSnapshot),
            query: speciesSearchQuery
        )
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

                    ZStack {
                        ZStack(alignment: .top) {
                            if !GoDiveUITestConfiguration.isActive {
                                WaterBubbleBackground()
                            }

                            Group {
                                fieldGuideListContent(
                                    topInset: listTopInset,
                                    bottomInset: listBottomInset
                                )
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                            if !catalog.isEmpty {
                                LogbookTopChromeScrim(topObstructionHeight: listTopInset)
                                    .padding(.top, -proxy.safeAreaInsets.top)
                                    .ignoresSafeArea(edges: .top)
                                    .zIndex(0.5)

                                FieldGuideTopChrome(
                                    searchText: $speciesSearchQuery,
                                    isSearchFocused: $isSpeciesSearchFocused
                                )
                                .zIndex(1)
                            }
                        }
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
        .onChange(of: isSpeciesSearchFocused) { _, isFocused in
            if !isFocused {
                dismissSpeciesSearchKeyboard()
            }
        }
    }

    private func handleFieldGuideTabReselect() {
        path.removeAll()
        isSpeciesSearchFocused = false
        RootTabListScrollSupport.scheduleScrollToTop { listScrollToTopNonce += 1 }
    }

    private func dismissSpeciesSearchKeyboard() {
        isSpeciesSearchFocused = false
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
    private func fieldGuideListContent(topInset: CGFloat, bottomInset: CGFloat) -> some View {
        if catalog.isEmpty {
            FieldGuideCatalogEmptyState()
                .padding(.top, topInset)
        } else if listRows.isEmpty && isFilteringSpecies {
            CatalogSearchEmptyState(
                title: "No matching species",
                message: "Try a different name, scientific name, or category."
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
