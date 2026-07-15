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
    @State private var fullscreenMediaSelection: FullscreenMediaSelection?
    @State private var speciesCatalog: [MarineLife] = []
    @State private var indexRebuildTask: Task<Void, Never>?
    @State private var filterTask: Task<Void, Never>?
    /// Count-title opacity derived from scroll position. Stored as the *derived* value (not the raw
    /// offset) so scrolling past the fade band stops invalidating the whole media list every frame.
    @State private var countTitleOpacity: Double = 1
    /// Resolved models for the current filter — updated with **`displayCache`**, not during scroll.
    @State private var resolvedMediaItems: [DiveMediaPhoto] = []
    @State private var resolvedPhotoByID: [UUID: DiveMediaPhoto] = [:]

    let ownerProfileID: UUID?
    /// Prebuilt browse cache filled by the hidden search warmer — lets this grid paint on open
    /// without re-capturing every dive/photo/tag on the main actor.
    let snapshotStore: GlobalSearchMediaSnapshotStore
    let safeAreaTop: CGFloat
    @Binding var resultsTopChromeHeight: CGFloat
    let scrollDisabled: Bool
    let isSelectionBlocked: Bool
    let onBack: () -> Void
    let onOpenDive: (UUID) -> Void

    private struct FullscreenMediaSelection: Identifiable {
        let id: UUID
        var tagOverviewMode: DiveActivityMediaLargeDetentMode? = nil
    }

    init(
        ownerProfileID: UUID?,
        query: Binding<String>,
        snapshotStore: GlobalSearchMediaSnapshotStore,
        safeAreaTop: CGFloat,
        resultsTopChromeHeight: Binding<CGFloat>,
        scrollDisabled: Bool,
        isSelectionBlocked: Bool,
        onBack: @escaping () -> Void,
        onOpenDive: @escaping (UUID) -> Void
    ) {
        self.ownerProfileID = ownerProfileID
        _query = query
        self.snapshotStore = snapshotStore
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

    private var monthSections: [GlobalSearchMediaBrowsePresentation.MonthSection] {
        displayCache?.monthSections ?? []
    }

    private var ownerDiveActivityIDs: Set<UUID> {
        Set(ownerDiveActivities.map(\.id))
    }

    private var resolvedFilter: GlobalSearchMediaBrowsePresentation.ResolvedFilter {
        GlobalSearchMediaBrowsePresentation.resolveFilter(from: query)
    }

    private var linkedMediaItemsForFullscreen: [TripDetailLinkedMediaItem] {
        let visibleIDs = Set(filteredMediaIDs)
        return TripDetailMediaPresentation.linkedMediaItems(from: ownerDiveActivities)
            .filter { visibleIDs.contains($0.id) }
    }

    private var timeZoneOffsetByMediaIDForFullscreen: [UUID: Int?] {
        TripDetailMediaPresentation.timeZoneOffsetByMediaID(
            from: ownerDiveActivities,
            itemIDs: linkedMediaItemsForFullscreen
        )
    }

    private var mediaSightingsForFullscreen: [SightingInstance] {
        let visibleIDs = Set(filteredMediaIDs)
        guard !visibleIDs.isEmpty else { return [] }
        let ownerActivityIDs = ownerDiveActivityIDs
        return sightings.filter { sighting in
            guard let activityID = sighting.diveActivityID,
                  ownerActivityIDs.contains(activityID),
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

    private var bottomInset: CGFloat {
        GlobalSearchPresentation.ContextTokenPresentation.tabSearchChromeHeight + AppTheme.Spacing.md
    }

    private var pinnedHeaderTopMargin: CGFloat {
        // Count title shares the back row — pin month headers below chrome (scoped results clearance),
        // not on the back-button centerline used by multi-category section titles.
        GlobalSearchPresentation.ResultsSectionHeaderPresentation.scrollContentTopMarginBelowChrome(
            chromeHeight: resultsTopChromeHeight
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            mediaBrowseList
                .scrollDisabled(scrollDisabled)
                .onScrollGeometryChange(for: Double.self) { geometry in
                    // Transform to the final opacity so the action (and a body invalidation)
                    // only fires inside the 44 pt fade band, not on every scroll frame.
                    GlobalSearchPresentation.ResultsCountTitlePresentation.titleOpacity(
                        scrollOffset: geometry.contentOffset.y + geometry.contentInsets.top
                    )
                } action: { _, opacity in
                    countTitleOpacity = opacity
                }
                .accessibilityIdentifier(GlobalSearchMediaBrowsePresentation.rootAccessibilityIdentifier)
                .fullScreenCover(item: $fullscreenMediaSelection) { selection in
                    LinkedMediaFullscreenView(
                        mediaItems: resolvedMediaItems,
                        timeZoneOffsetByMediaID: timeZoneOffsetByMediaIDForFullscreen,
                        linkedMediaItems: linkedMediaItemsForFullscreen,
                        selectedMediaID: $gallerySelectedMediaID,
                        configuration: .trip,
                        featuredMediaPhotoID: nil,
                        onToggleFeatured: nil,
                        sightings: mediaSightingsForFullscreen,
                        marineLifeCatalog: speciesCatalog,
                        ownerProfileID: ownerProfileID,
                        initialTagOverviewMode: selection.tagOverviewMode,
                        onOpenDive: onOpenDive
                    )
                    .onAppear {
                        gallerySelectedMediaID = selection.id
                    }
                }

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
                trailingTitleOpacity: countTitleOpacity,
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
    private var mediaBrowseList: some View {
        List {
            mediaBrowseListContent
        }
        .listStyle(.plain)
        .listSectionSpacing(0)
        .listRowSpacing(0)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .contentMargins(
            .top,
            pinnedHeaderTopMargin,
            for: .scrollContent
        )
        .contentMargins(
            .bottom,
            bottomInset,
            for: .scrollContent
        )
    }

    @ViewBuilder
    private var mediaBrowseListContent: some View {
        if !hasLoadedInitialContent {
            mediaBrowseStatusRow(loadingPlaceholder)
        } else if indexSnapshot?.entries.isEmpty == true {
            mediaBrowseStatusRow(emptyState(message: GlobalSearchMediaBrowsePresentation.emptyLibraryMessage))
        } else if showsFilteredEmptyState {
            mediaBrowseStatusRow(emptyState(message: GlobalSearchMediaBrowsePresentation.emptyFilterMessage))
        } else if resolvedMediaItems.isEmpty {
            mediaBrowseStatusRow(loadingPlaceholder)
        } else {
            ForEach(monthSections) { section in
                Section {
                    GlobalSearchMediaBrowseMonthGrid(
                        sectionID: section.id,
                        mediaIDs: section.mediaIDs,
                        mediaItems: section.mediaIDs.compactMap { resolvedPhotoByID[$0] },
                        marineLifeTaggedMediaIDs: displayCache?.marineLifeTaggedMediaIDs ?? [],
                        buddyTaggedMediaIDs: displayCache?.buddyTaggedMediaIDs ?? [],
                        marineLifeTagCountByMediaID: displayCache?.marineLifeTagCountByMediaID ?? [:],
                        buddyTagCountByMediaID: displayCache?.buddyTagCountByMediaID ?? [:],
                        isSelectionBlocked: isSelectionBlocked,
                        onSelectMedia: { mediaID in
                            openFullscreen(mediaID: mediaID, tagOverviewMode: nil)
                        },
                        onSelectMediaTagOverview: { mediaID, mode in
                            openFullscreen(mediaID: mediaID, tagOverviewMode: mode)
                        },
                        onOpenDive: onOpenDive
                    )
                    .equatable()
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .padding(.bottom, AppTheme.Spacing.md)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listSectionSeparator(.hidden)
                    .listRowBackground(Color.clear)
                } header: {
                    GlobalSearchResultsSectionHeader(title: section.title)
                        .accessibilityIdentifier("GlobalSearch.MediaBrowse.MonthSection.\(section.id)")
                }
                .headerProminence(.increased)
            }
        }
    }

    private func mediaBrowseStatusRow<Content: View>(_ content: Content) -> some View {
        content
            .padding(.horizontal, AppTheme.Spacing.lg)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
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

    private func openFullscreen(
        mediaID: UUID,
        tagOverviewMode: DiveActivityMediaLargeDetentMode?
    ) {
        gallerySelectedMediaID = mediaID
        fullscreenMediaSelection = FullscreenMediaSelection(
            id: mediaID,
            tagOverviewMode: tagOverviewMode
        )
    }

    private func applyResolvedMedia(from cache: GlobalSearchMediaBrowsePresentation.DisplayCache) {
        let photoByID = Dictionary(
            uniqueKeysWithValues: ownerDiveActivities.flatMap(\.mediaPhotos).map { ($0.id, $0) }
        )
        let items = cache.filteredMediaIDs.compactMap { photoByID[$0] }
        resolvedMediaItems = items
        resolvedPhotoByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        // No bulk session-cache seeding here: the session cache holds only `carouselLimit`
        // entries, so decoding every stored JPEG on the main actor just to evict them was a
        // page-open hitch. Visible cells seed themselves in `DiveActivityMediaThumbnailView`.
    }

    private func scheduleIndexRebuild() {
        indexRebuildTask?.cancel()

        if applyPrewarmedSnapshotIfCurrent() { return }

        let dataToken = indexRefreshToken
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
            applyDisplayCache(built)
            // Share the fresh snapshot so the warmer and the next browse open skip the re-capture.
            snapshotStore.displayCache = built
            snapshotStore.dataToken = dataToken
        }
    }

    /// Paints from the warmer-prebuilt snapshot when the underlying data is unchanged, skipping the
    /// main-actor capture of every dive/photo/tag during the results-panel slide-in. While the local
    /// species catalog is still loading, a core-token match is enough (the prewarmed snapshot was
    /// built with species names included); when the species load finishes and re-fires the rebuild
    /// task, the exact-match branch turns that second pass into a no-op instead of a full rebuild.
    private func applyPrewarmedSnapshotIfCurrent() -> Bool {
        guard let warmCache = snapshotStore.displayCache,
              GlobalSearchMediaBrowsePresentation.canReusePrewarmedSnapshot(
                  storeToken: snapshotStore.dataToken,
                  currentToken: indexRefreshToken,
                  isSpeciesCatalogLoaded: !speciesCatalog.isEmpty
              )
        else { return false }

        let filter = resolvedFilter
        let fingerprint = GlobalSearchMediaBrowsePresentation.filterFingerprint(filter)

        if hasLoadedInitialContent,
           let current = displayCache,
           current.filterFingerprint == fingerprint,
           current.snapshot.refreshToken == warmCache.snapshot.refreshToken {
            return true
        }

        if warmCache.filterFingerprint == fingerprint {
            applyDisplayCache(warmCache)
            return true
        }

        // Same data, different query text: re-filter the prewarmed snapshot off-main (no re-capture).
        let snapshot = warmCache.snapshot
        indexRebuildTask = Task { @MainActor in
            let built = await Task.detached {
                GlobalSearchMediaBrowsePresentation.displayCache(snapshot: snapshot, filter: filter)
            }.value
            guard !Task.isCancelled else { return }
            applyDisplayCache(built)
        }
        return true
    }

    private func applyDisplayCache(_ cache: GlobalSearchMediaBrowsePresentation.DisplayCache) {
        displayCache = cache
        applyResolvedMedia(from: cache)
        hasLoadedInitialContent = true
        isApplyingQueryFilter = false
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

            applyDisplayCache(built)
        }
    }
}

/// Single month’s media grid for Search → Media — **`Equatable`** so count-title fade skips thumbnail rebuilds.
private struct GlobalSearchMediaBrowseMonthGrid: View, Equatable {
    let sectionID: String
    /// Section media IDs from the display cache — used for equality so comparisons never
    /// touch SwiftData model getters (`mediaItems.map(\.id)`) during scroll invalidations.
    let mediaIDs: [UUID]
    let mediaItems: [DiveMediaPhoto]
    let marineLifeTaggedMediaIDs: Set<UUID>
    let buddyTaggedMediaIDs: Set<UUID>
    let marineLifeTagCountByMediaID: [UUID: Int]
    let buddyTagCountByMediaID: [UUID: Int]
    let isSelectionBlocked: Bool
    let onSelectMedia: (UUID) -> Void
    let onSelectMediaTagOverview: (UUID, DiveActivityMediaLargeDetentMode) -> Void
    let onOpenDive: (UUID) -> Void

    static func == (
        lhs: GlobalSearchMediaBrowseMonthGrid,
        rhs: GlobalSearchMediaBrowseMonthGrid
    ) -> Bool {
        lhs.sectionID == rhs.sectionID
            && lhs.mediaIDs == rhs.mediaIDs
            && lhs.mediaItems.count == rhs.mediaItems.count
            && lhs.marineLifeTaggedMediaIDs == rhs.marineLifeTaggedMediaIDs
            && lhs.buddyTaggedMediaIDs == rhs.buddyTaggedMediaIDs
            && lhs.marineLifeTagCountByMediaID == rhs.marineLifeTagCountByMediaID
            && lhs.buddyTagCountByMediaID == rhs.buddyTagCountByMediaID
            && lhs.isSelectionBlocked == rhs.isSelectionBlocked
    }

    var body: some View {
        LinkedMediaGridSection(
            mediaItems: mediaItems,
            timeZoneOffsetByMediaID: [:],
            linkedMediaItems: [],
            gallerySelectedMediaID: .constant(nil),
            featuredMediaPhotoID: nil,
            onToggleFeaturedTaggedMedia: nil,
            sightings: [],
            marineLifeCatalog: [],
            ownerProfileID: nil,
            buddyTaggedMediaIDs: buddyTaggedMediaIDs,
            marineLifeTaggedMediaIDs: marineLifeTaggedMediaIDs,
            buddyTagCountByMediaID: buddyTagCountByMediaID,
            marineLifeTagCountByMediaID: marineLifeTagCountByMediaID,
            prefersStoredPreviewThumbnails: false,
            fullscreenConfiguration: .trip,
            gridAccessibilityIdentifier: "GlobalSearch.MediaBrowse.Grid.\(sectionID)",
            gridItemAccessibilityPrefix: "GlobalSearch.MediaBrowse.Grid.Item",
            sectionAccessibilityIdentifier: "GlobalSearch.MediaBrowse.GridSection.\(sectionID)",
            emptyMessage: nil,
            emptyAccessibilityIdentifier: nil,
            isSelectionBlocked: isSelectionBlocked,
            presentsFullscreenCover: false,
            onSelectMedia: onSelectMedia,
            onSelectMediaTagOverview: onSelectMediaTagOverview,
            onOpenDive: onOpenDive
        )
    }
}
