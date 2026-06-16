import SwiftData
import SwiftUI

struct ExploreView: View {
    @Environment(AccountSession.self) private var accountSession
    @Query(sort: \DiveSite.siteName) private var diveSites: [DiveSite]
    @Query(sort: \MarineLife.commonName) private var marineLifeCatalog: [MarineLife]
    @Query(
        sort: [
            SortDescriptor(\DiveActivity.startTime, order: .reverse),
            SortDescriptor(\DiveActivity.id, order: .forward),
        ]
    )
    private var diveActivities: [DiveActivity]
    @State private var path: [ExploreRoute] = []
    @State private var viewMode: ExploreViewMode = .map
    @State private var siteSearchQuery = ""
    @FocusState private var isSiteSearchFocused: Bool
    @State private var exploreTopChromeHeight: CGFloat = AppTheme.Layout.appHeaderClearanceFallback
    @State private var listScrollToTopNonce = 0

    private var isExploreNavigationStackAtRoot: Bool {
        RootStackReturnNavigationPresentation.isStackAtRoot(pathCount: path.count)
    }

    private var filteredDiveSites: [DiveSite] {
        ExploreDiveSiteListSearch.filtering(diveSites, query: siteSearchQuery)
    }

    private var plottableSites: [ExploreCatalogMapPresentation.PlottedSite] {
        ExploreCatalogMapPresentation.plottableSites(from: diveSites)
    }

    private var siteListRows: [ExploreDiveSiteRowDisplayData] {
        ExploreDiveSiteListDisplay.rowData(for: filteredDiveSites)
    }

    private var isFilteringSites: Bool {
        ExploreDiveSiteListSearch.isFiltering(query: siteSearchQuery)
    }

    private var showsSiteListSearch: Bool {
        viewMode == .list && !diveSites.isEmpty
    }

    private var ownerDiveActivities: [DiveActivity] {
        guard let ownerID = accountSession.currentProfile?.id else { return [] }
        return diveActivities.filter { $0.ownerProfileID == ownerID }
    }

    var body: some View {
        NavigationStack(path: $path) {
            AppHeaderlessPage {
                GeometryReader { proxy in
                    let topInset = proxy.safeAreaInsets.top + exploreTopChromeHeight
                    let bottomInset = proxy.safeAreaInsets.bottom + AppTheme.Spacing.md

                    ZStack(alignment: .top) {
                        if viewMode == .list, !GoDiveUITestConfiguration.isActive {
                            WaterBubbleBackground()
                        }

                        Group {
                            switch viewMode {
                            case .map:
                                ExploreCatalogMapView(sites: plottableSites) { siteID in
                                    path.append(.siteDetail(siteID))
                                }
                                .ignoresSafeArea()
                            case .list:
                                exploreSiteList(topInset: topInset, bottomInset: bottomInset)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        if viewMode == .list, !diveSites.isEmpty {
                            LogbookTopChromeScrim(topObstructionHeight: topInset)
                                .padding(.top, -proxy.safeAreaInsets.top)
                                .ignoresSafeArea(edges: .top)
                                .allowsHitTesting(false)
                                .zIndex(0.5)
                        }

                        ExploreTopChrome(
                            viewMode: $viewMode,
                            siteSearchQuery: $siteSearchQuery,
                            isSiteSearchFocused: $isSiteSearchFocused,
                            showsSiteSearch: showsSiteListSearch,
                            statusBarSafeAreaTop: proxy.safeAreaInsets.top,
                            onOpenTripPlanner: { path.append(.tripPlanner) }
                        )
                        .frame(maxWidth: .infinity, alignment: .top)
                        .zIndex(1)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .ignoresSafeArea(edges: .bottom)
                }
                .onPreferenceChange(AppHeaderMetrics.HeightKey.self) { height in
                    if height > 0 { exploreTopChromeHeight = height }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .restoresRootTabBarWhenStackIsEmpty(isExploreNavigationStackAtRoot)
            .animation(nil, value: path.count)
            .navigationDestination(for: ExploreRoute.self) { route in
                switch route {
                case .tripPlanner:
                    TripPlannerView()
                case .tripDetail(let tripID):
                    TripDetailStackNavigationPresentation.tripDetailDestination(tripID: tripID)
                case .tripDetailMedia(let tripID, let mediaID):
                    TripDetailStackNavigationPresentation.tripDetailDestination(
                        tripID: tripID,
                        initialContentPage: .media,
                        initialSelectedMediaID: mediaID
                    )
                case .siteDetail(let siteID):
                    if let site = diveSites.first(where: { $0.id == siteID }) {
                        ExploreDiveSiteDetailView(
                            site: site,
                            ownerProfileID: accountSession.currentProfile?.id
                        )
                    } else {
                        Text("This dive site is no longer in the catalog.")
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .padding()
                    }
                case .speciesDetail(let marineLifeUUID):
                    if let species = marineLifeCatalog.first(where: { $0.uuid == marineLifeUUID }) {
                        FieldGuideMarineLifeDetailView(
                            species: species,
                            ownerProfileID: accountSession.currentProfile?.id
                        ) { activityID in
                            path.append(.diveDetail(activityID))
                        }
                    } else {
                        Text("This species is no longer in the catalog.")
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .padding()
                    }
                case .diveDetail(let id):
                    if let activity = ownerDiveActivities.first(where: { $0.id == id }) {
                        ViewSingleActivity(activity: activity)
                    } else {
                        Text("This dive is no longer in your log.")
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .padding()
                    }
                }
            }
        }
        .environment(\.openCatalogDiveSiteDetail) { siteID in
            path.append(.siteDetail(siteID))
            TripDetailMapNavigationDebug.parentStackAppendedRoute(
                stack: .explore,
                siteID: siteID,
                pathCountAfterAppend: path.count
            )
        }
        .environment(\.openTripDetail) { tripID in
            path.append(.tripDetail(tripID))
        }
        .environment(\.openTripDetailMedia) { launch in
            path.append(.tripDetailMedia(tripID: launch.tripID, mediaID: launch.mediaID))
        }
        .navigationInteractivePopGestureForHiddenNavBar()
        .rootTabReselectObserver(notification: .exploreTabReselected)
        .onReceive(NotificationCenter.default.publisher(for: .exploreTabReselected)) { _ in
            handleExploreTabReselect()
        }
        .onChange(of: viewMode) { _, mode in
            if mode != .list {
                dismissSiteSearchKeyboard()
            }
        }
        .onChange(of: isSiteSearchFocused) { _, isFocused in
            if !isFocused {
                dismissSiteSearchKeyboard()
            }
        }
    }

    private func dismissSiteSearchKeyboard() {
        isSiteSearchFocused = false
    }

    private func handleExploreTabReselect() {
        path.removeAll()
        isSiteSearchFocused = false
        guard viewMode == .list else { return }
        RootTabListScrollSupport.scheduleScrollToTop { listScrollToTopNonce += 1 }
    }

    @ViewBuilder
    private func exploreSiteList(topInset: CGFloat, bottomInset: CGFloat) -> some View {
        if diveSites.isEmpty {
            exploreSiteListEmptyState
                .padding(.top, topInset)
                .padding(.horizontal, AppTheme.Spacing.lg)
        } else if siteListRows.isEmpty && isFilteringSites {
            CatalogSearchEmptyState(
                title: "No matching dive sites",
                message: "Try a different site name or place."
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

                ForEach(siteListRows) { row in
                    Button {
                        path.append(.siteDetail(row.id))
                    } label: {
                        ExploreDiveSiteRow(data: row)
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
                    .accessibilityIdentifier("Explore.SiteRow.\(row.id.uuidString)")
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
            .scrollDismissesKeyboard(.interactively)
            .background(Color.clear)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea(edges: [.top, .bottom])
            .listScrollToTopTrigger(nonce: listScrollToTopNonce)
        }
    }

    private var exploreSiteListEmptyState: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer(minLength: AppTheme.Spacing.lg)

            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.Colors.accent.opacity(0.85))

            Text("No dive sites yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text("Sites appear here when you add them to the catalog or import dives with site names.")
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

#Preview {
    ExploreView()
        .modelContainer(try! AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true))
}
