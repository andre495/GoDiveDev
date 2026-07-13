import SwiftData
import SwiftUI

/// Cross-log media grid rendered inside the **Search** results panel when the **Media** scope token is active.
/// Behaves like every other category scope: it stays at the search root with the tab-bar search field usable
/// for additional filter terms (site free text, `buddy:`, `tag:`, `trip:`, `species:`).
struct GlobalSearchMediaResultsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var ownerDiveActivities: [DiveActivity]
    @Query(sort: [SortDescriptor(\DiveMediaBuddyTag.id, order: .forward)])
    private var buddyMediaTags: [DiveMediaBuddyTag]
    @Query(sort: [SortDescriptor(\SightingInstance.sightingDateTime, order: .reverse)])
    private var sightings: [SightingInstance]
    @Query private var ownerTrips: [DiveTrip]

    @Binding var query: String

    @State private var displayCache: GlobalSearchMediaBrowsePresentation.DisplayCache?
    @State private var hasLoadedInitialContent = false
    @State private var isApplyingQueryFilter = false
    @State private var gallerySelectedMediaID: UUID?
    @State private var speciesCatalog: [MarineLife] = []
    @State private var indexRebuildTask: Task<Void, Never>?
    @State private var filterTask: Task<Void, Never>?
    /// Scroll position of the media grid — fades the back-row count title out as the user scrolls.
    @State private var scrollOffset: CGFloat = 0

    let ownerProfileID: UUID?
    let safeAreaTop: CGFloat
    @Binding var resultsTopChromeHeight: CGFloat
    let scrollDisabled: Bool
    let isSelectionBlocked: Bool
    let onBack: () -> Void
    let onOpenDive: (UUID) -> Void

    init(
        ownerProfileID: UUID?,
        query: Binding<String>,
        safeAreaTop: CGFloat,
        resultsTopChromeHeight: Binding<CGFloat>,
        scrollDisabled: Bool,
        isSelectionBlocked: Bool,
        onBack: @escaping () -> Void,
        onOpenDive: @escaping (UUID) -> Void
    ) {
        self.ownerProfileID = ownerProfileID
        _query = query
        self.safeAreaTop = safeAreaTop
        _resultsTopChromeHeight = resultsTopChromeHeight
        self.scrollDisabled = scrollDisabled
        self.isSelectionBlocked = isSelectionBlocked
        self.onBack = onBack
        self.onOpenDive = onOpenDive

        let filterOwnerID = ownerProfileID ?? Self.noOwnerQueryToken
        _ownerDiveActivities = Query(
            filter: #Predicate<DiveActivity> { $0.ownerProfileID == filterOwnerID },
            sort: [
                SortDescriptor(\DiveActivity.startTime, order: .reverse),
                SortDescriptor(\DiveActivity.id, order: .forward),
            ]
        )
        _ownerTrips = Query(
            filter: #Predicate<DiveTrip> { $0.ownerProfileID == filterOwnerID },
            sort: [
                SortDescriptor(\DiveTrip.startDate, order: .reverse),
                SortDescriptor(\DiveTrip.id, order: .forward),
            ]
        )
    }

    private static let noOwnerQueryToken = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    private var indexSnapshot: GlobalSearchMediaBrowsePresentation.IndexSnapshot? {
        displayCache?.snapshot
    }

    private var filteredMediaIDs: [UUID] {
        displayCache?.filteredMediaIDs ?? []
    }

    private var ownerDiveActivityIDs: Set<UUID> {
        Set(ownerDiveActivities.map(\.id))
    }

    private var resolvedFilter: GlobalSearchMediaBrowsePresentation.ResolvedFilter {
        GlobalSearchMediaBrowsePresentation.resolveFilter(from: query)
    }

    private var mediaItems: [DiveMediaPhoto] {
        let photoByID = Dictionary(
            uniqueKeysWithValues: ownerDiveActivities.flatMap(\.mediaPhotos).map { ($0.id, $0) }
        )
        return filteredMediaIDs.compactMap { photoByID[$0] }
    }

    private var linkedMediaItems: [TripDetailLinkedMediaItem] {
        TripDetailMediaPresentation.linkedMediaItems(from: ownerDiveActivities)
            .filter { filteredMediaIDs.contains($0.id) }
    }

    private var timeZoneOffsetByMediaID: [UUID: Int?] {
        TripDetailMediaPresentation.timeZoneOffsetByMediaID(
            from: ownerDiveActivities,
            itemIDs: linkedMediaItems
        )
    }

    private var mediaSightings: [SightingInstance] {
        let visibleIDs = Set(filteredMediaIDs)
        guard !visibleIDs.isEmpty else { return [] }
        return sightings.filter { sighting in
            guard let activityID = sighting.diveActivityID,
                  ownerDiveActivityIDs.contains(activityID),
                  let mediaPhotoID = sighting.mediaPhotoID
            else { return false }
            return visibleIDs.contains(mediaPhotoID)
        }
    }

    private var indexRefreshToken: String {
        "\(ownerDiveActivities.count)|\(buddyMediaTags.count)|\(sightings.count)|\(ownerTrips.count)|\(speciesCatalog.count)"
    }

    private var countTitle: String {
        guard hasLoadedInitialContent, let counts = displayCache?.mediaKindCounts else {
            return GlobalSearchMediaBrowsePresentation.loadingPageTitle
        }
        return GlobalSearchMediaBrowsePresentation.pageTitle(for: counts)
    }

    private var topInset: CGFloat {
        GlobalSearchPresentation.ContextTokenPresentation.resultsListTopInset(
            safeAreaTop: safeAreaTop,
            chromeHeight: resultsTopChromeHeight
        )
    }

    private var bottomInset: CGFloat {
        GlobalSearchPresentation.ContextTokenPresentation.tabSearchChromeHeight + AppTheme.Spacing.md
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    Color.clear
                        .frame(height: topInset)
                        .accessibilityHidden(true)

                    mediaGridSection
                        .padding(.horizontal, AppTheme.Spacing.lg)
                }
                .padding(.bottom, bottomInset)
            }
            .scrollDisabled(scrollDisabled)
            .ignoresSafeArea(edges: .top)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, offset in
                scrollOffset = offset
            }
            .accessibilityIdentifier(GlobalSearchMediaBrowsePresentation.rootAccessibilityIdentifier)

            LogbookTopChromeScrim(
                topObstructionHeight: GlobalSearchPresentation.ResultsChromePresentation.topScrimObstructionHeight(
                    safeAreaTop: safeAreaTop,
                    chromeHeight: resultsTopChromeHeight
                )
            )
            .padding(.top, -safeAreaTop)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
            .zIndex(GlobalSearchPresentation.ResultsChromePresentation.topScrimZIndex)

            GlobalSearchResultsTopChrome(
                statusBarSafeAreaTop: safeAreaTop,
                trailingTitle: countTitle,
                trailingTitleAccessibilityIdentifier: "GlobalSearch.MediaBrowse.CountTitle",
                trailingTitleOpacity: GlobalSearchPresentation.ResultsCountTitlePresentation.titleOpacity(
                    scrollOffset: scrollOffset
                ),
                onBack: onBack
            )
            .zIndex(GlobalSearchPresentation.ResultsChromePresentation.topChromeZIndex)
        }
        .onPreferenceChange(AppHeaderMetrics.HeightKey.self) { height in
            if height > 0 { resultsTopChromeHeight = height }
        }
        .task(id: ownerProfileID) {
            let container = modelContext.container
            let marineLifeIDs = await MarineLifeCatalogLoader.fetchSortedPersistentIDs(container: container)
            speciesCatalog = MarineLifeCatalogLoader.bindModels(
                persistentIDs: marineLifeIDs,
                modelContext: modelContext
            )
        }
        .task(id: indexRefreshToken) {
            scheduleIndexRebuild()
        }
        .onChange(of: query) { _, _ in
            scheduleQueryFilterRebuild()
        }
        .onDisappear {
            indexRebuildTask?.cancel()
            filterTask?.cancel()
        }
    }

    @ViewBuilder
    private var mediaGridSection: some View {
        if !hasLoadedInitialContent {
            loadingPlaceholder
        } else if indexSnapshot?.entries.isEmpty == true {
            emptyState(message: GlobalSearchMediaBrowsePresentation.emptyLibraryMessage)
        } else if showsFilteredEmptyState {
            emptyState(message: GlobalSearchMediaBrowsePresentation.emptyFilterMessage)
        } else if mediaItems.isEmpty {
            loadingPlaceholder
        } else {
            LinkedMediaGridSection(
                mediaItems: mediaItems,
                timeZoneOffsetByMediaID: timeZoneOffsetByMediaID,
                linkedMediaItems: linkedMediaItems,
                gallerySelectedMediaID: $gallerySelectedMediaID,
                featuredMediaPhotoID: nil,
                onToggleFeaturedTaggedMedia: nil,
                sightings: mediaSightings,
                marineLifeCatalog: speciesCatalog,
                ownerProfileID: ownerProfileID,
                fullscreenConfiguration: .trip,
                gridAccessibilityIdentifier: "GlobalSearch.MediaBrowse.Grid",
                gridItemAccessibilityPrefix: "GlobalSearch.MediaBrowse.Grid.Item",
                sectionAccessibilityIdentifier: "GlobalSearch.MediaBrowse.GridSection",
                emptyMessage: nil,
                emptyAccessibilityIdentifier: nil,
                isSelectionBlocked: isSelectionBlocked,
                onOpenDive: onOpenDive
            )
        }
    }

    private var showsFilteredEmptyState: Bool {
        guard hasLoadedInitialContent,
              !isApplyingQueryFilter,
              resolvedFilter.isActive,
              indexSnapshot?.entries.isEmpty == false,
              filteredMediaIDs.isEmpty
        else { return false }
        return true
    }

    private var loadingPlaceholder: some View {
        ProgressView()
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.lg)
            .accessibilityIdentifier("GlobalSearch.MediaBrowse.Loading")
    }

    private func emptyState(message: String) -> some View {
        Text(message)
            .font(.body)
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.lg)
            .accessibilityIdentifier("GlobalSearch.MediaBrowse.Empty")
    }

    private func scheduleIndexRebuild() {
        indexRebuildTask?.cancel()
        indexRebuildTask = Task { @MainActor in
            await Task.yield()
            let input = GlobalSearchMediaIndexSnapshotBuilder.captureInput(
                activities: ownerDiveActivities,
                buddyMediaTags: buddyMediaTags,
                sightings: sightings,
                ownerTrips: ownerTrips,
                speciesCatalog: speciesCatalog,
                ownerDiveActivityIDs: ownerDiveActivityIDs
            )
            let filter = GlobalSearchMediaBrowsePresentation.resolveFilter(from: query)
            let built = await Task.detached {
                GlobalSearchMediaBrowsePresentation.displayCache(from: input, filter: filter)
            }.value
            guard !Task.isCancelled else { return }
            displayCache = built
            hasLoadedInitialContent = true
            isApplyingQueryFilter = false
        }
    }

    private func scheduleQueryFilterRebuild() {
        guard hasLoadedInitialContent, let snapshot = indexSnapshot else { return }

        let filter = GlobalSearchMediaBrowsePresentation.resolveFilter(from: query)
        let fingerprint = GlobalSearchMediaBrowsePresentation.filterFingerprint(filter)
        if displayCache?.filterFingerprint == fingerprint {
            isApplyingQueryFilter = false
            return
        }

        filterTask?.cancel()
        isApplyingQueryFilter = true
        filterTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard !Task.isCancelled else { return }

            let built = await Task.detached {
                GlobalSearchMediaBrowsePresentation.displayCache(snapshot: snapshot, filter: filter)
            }.value
            guard !Task.isCancelled else { return }

            displayCache = built
            isApplyingQueryFilter = false
        }
    }
}
