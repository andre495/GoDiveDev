import SwiftUI
import SwiftData
import PhotosUI

struct ViewSingleSnorkelActivity: View {
    private struct DerivedSnorkelData {
        var sortedProfileSnapshots: [SnorkelDerivedProfilePointSnapshot] = []
        var heartRateSamples: [SnorkelHeartRateProfileSample] = []
        var trackCoordinates: [DiveCoordinate] = []
        var sortedMediaItems: [SnorkelMediaPhoto] = []
        var mediaPhotosByID: [UUID: SnorkelMediaPhoto] = [:]
        var heartRateStats = SnorkelHeartRatePanelSummary.ProfileHeartRateStats(
            sampleCount: 0,
            minBPM: nil,
            maxBPM: nil
        )
    }

    @Bindable var activity: SnorkelActivity
    var initialMediaFocusID: UUID? = nil

    init(activity: SnorkelActivity, initialMediaFocusID: UUID? = nil) {
        self._activity = Bindable(wrappedValue: activity)
        self.initialMediaFocusID = initialMediaFocusID
        _pendingInitialMediaFocusID = State(initialValue: initialMediaFocusID)
        if initialMediaFocusID != nil {
            _selectedActivityTab = State(initialValue: .camera)
            _overviewSheetDetent = State(initialValue: .large)
            _selectedMediaPhotoID = State(initialValue: initialMediaFocusID)
            _isOverviewPanelPresented = State(initialValue: true)
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem
    @Environment(\.openCatalogDiveSiteDetail) private var openCatalogDiveSiteDetail

    @State private var selectedActivityTab: SnorkelActivityTab = .map
    @State private var overviewSheetDetent = DiveActivityOverviewDetent.defaultSelection
    @State private var overviewPanelLiveHeightFraction = DiveActivityOverviewDetent.defaultSelection.heightFraction
    @State private var isOverviewPanelPresented = true
    @State private var overviewMapTeardownRequested = false
    @State private var selectedMediaPhotoID: UUID?
    @State private var pendingInitialMediaFocusID: UUID?
    @State private var didApplyInitialMediaFocus = false
    @State private var derivedSnorkelData = DerivedSnorkelData()
    @State private var catalogSitesForMapResolution: [DiveSite] = []
    @State private var overviewPanelScrollOffsetY: CGFloat = 0
    @State private var marineLifeCatalog: [MarineLife] = []
    @State private var snorkelMediaPickerItems: [PhotosPickerItem] = []
    @State private var mediaImportOverlay: DiveMediaImportOverlayState = .hidden
    @State private var mediaPresentationEpoch = 0
    @State private var marineLifeTagMediaID: UUID?
    @State private var buddyTagMediaID: UUID?
    @State private var fishialIdentifyMediaID: UUID?

    var body: some View {
        AppHeaderlessPage(leadingEdgePopOnWillDismiss: requestOverviewMapTeardown) {
            ZStack(alignment: .top) {
                snorkelOverviewHeroLayer
                activityTopChrome
                    .zIndex(1_000)
                mediaImportOverlayIfNeeded
            }
        }
        .diveActivityLandscapeOrientation()
        .hidesBottomTabBarWhenPushed()
        .onAppear(perform: handleSnorkelActivityAppear)
        .onDisappear {
            persistSnorkelOverviewUIState()
        }
        .onChange(of: initialMediaFocusID) { _, _ in
            didApplyInitialMediaFocus = false
            applyInitialMediaFocusIfNeeded()
        }
        .onChange(of: overviewPanelScrollOffsetY) { _, offset in
            guard offset > 4 else { return }
            persistSnorkelOverviewUIState()
        }
        .onChange(of: selectedActivityTab) { _, newTab in
            overviewPanelScrollOffsetY = 0
            if newTab == .map {
                overviewMapTeardownRequested = false
            }
        }
        .task(id: derivedDataRefreshToken) {
            await refreshDerivedSnorkelDataAsync()
        }
        .task(id: catalogSiteMapLookupToken) {
            await loadCatalogSitesForMapResolutionIfNeeded()
        }
        .task(id: selectedActivityTab) {
            guard selectedActivityTab == .camera else { return }
            await loadMarineLifeCatalogIfNeeded()
        }
        .sheet(isPresented: marineLifeTagSheetPresented) {
            if let media = marineLifeTagTargetMedia {
                SnorkelMarineLifeTagPickerSheet(
                    media: media,
                    snorkel: activity,
                    onTagged: {}
                )
            }
        }
        .sheet(isPresented: buddyTagSheetPresented) {
            if let media = buddyTagTargetMedia {
                SnorkelMediaBuddyTagPickerSheet(
                    media: media,
                    snorkel: activity,
                    onTagged: {}
                )
            }
        }
        .sheet(isPresented: fishialIdentifySheetPresented) {
            if let media = fishialIdentifyTargetMedia {
                SnorkelMediaFishialIdentifySheet(
                    media: media,
                    snorkel: activity,
                    catalogSites: catalogSitesForMapResolution
                )
            }
        }
        .onChange(of: snorkelMediaPickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await importSnorkelMediaPickerItems(items) }
        }
    }

    @ViewBuilder
    private var mediaImportOverlayIfNeeded: some View {
        if mediaImportOverlay != .hidden {
            DiveMediaImportProgressOverlay(state: mediaImportOverlay) {
                mediaImportOverlay = .hidden
            }
        }
    }

    private var catalogSiteMapLookupToken: String {
        "\(activity.id.uuidString)-\(activity.diveSiteID?.uuidString ?? "none")"
    }

    private var derivedDataRefreshToken: String {
        "\(activity.id.uuidString)-\(activity.mediaPhotos.count)-\(activity.marineLifeSightings.count)-\(activity.mediaBuddyTags.count)"
    }

    private var showsLiveOverviewMap: Bool {
        DiveActivityOverviewMapTeardown.showsLiveMap(teardownRequested: overviewMapTeardownRequested)
    }

    private func requestOverviewMapTeardown() {
        overviewMapTeardownRequested = true
    }

    private var activityTopChrome: some View {
        GlassEffectContainer {
            ZStack {
                HStack {
                    SecondaryDestinationBackButton(onWillDismiss: requestOverviewMapTeardown)
                    Spacer(minLength: 0)
                }
                SnorkelActivityIconTabBar(
                    selection: $selectedActivityTab,
                    onSelect: selectSnorkelActivityTab
                )
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.top, AppTheme.Spacing.sm)
        .animation(nil, value: overviewSheetDetent)
    }

    private func selectSnorkelActivityTab(_ tab: SnorkelActivityTab) {
        if tab == .camera, tab == selectedActivityTab {
            syncSnorkelOverviewSheetPresentation(for: tab)
            bumpMediaPresentationEpoch()
            return
        }
        guard tab != selectedActivityTab else { return }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if let detent = DiveActivityOverviewTabSelection.overviewDetent(whenSelectingSnorkel: tab) {
                overviewSheetDetent = detent
                isOverviewPanelPresented = true
            } else {
                isOverviewPanelPresented = false
            }
            selectedActivityTab = tab
            if tab == .camera {
                bumpMediaPresentationEpoch()
            }
        }
    }

    private func syncSnorkelOverviewSheetPresentation(for tab: SnorkelActivityTab) {
        if !isOverviewPanelPresented {
            isOverviewPanelPresented = true
        }
        if let detent = DiveActivityOverviewTabSelection.overviewDetent(whenSelectingSnorkel: tab) {
            overviewSheetDetent = detent
        }
    }

    private func bumpMediaPresentationEpoch() {
        mediaPresentationEpoch &+= 1
    }

    private var snorkelOverviewHeroLayer: some View {
        GeometryReader { geometry in
            let layoutHeight = max(geometry.size.height, 1)
            let bottomSafeInset = geometry.safeAreaInsets.bottom
            let overviewLayoutContext = DiveActivityOverviewSheetLayoutContext(
                layoutHeight: layoutHeight,
                screenWidth: geometry.size.width,
                topSafeInset: geometry.safeAreaInsets.top,
                bottomSafeInset: bottomSafeInset
            )
            let mapLargeRestingFraction = DiveActivityOverviewPanelMetrics.largeHeightFraction(
                in: overviewLayoutContext
            )
            let bottomObstruction = DiveActivityOverviewDetent.bottomObstructionHeight(
                layoutHeight: layoutHeight,
                detent: overviewSheetDetent,
                bottomSafeInset: bottomSafeInset,
                screenWidth: overviewLayoutContext.screenWidth,
                topSafeInset: overviewLayoutContext.topSafeInset
            )
            let topObstruction = DiveActivityOverviewPanelMetrics.mapTopObstructionHeight(
                topSafeInset: geometry.safeAreaInsets.top,
                chromeRowHeight: DiveActivityTabIcon.menuRowHeight,
                chromeTopPadding: AppTheme.Spacing.sm
            )
            let isLandscape = DiveActivityOverviewLandscapePresentation.isLandscapeLayout(
                layoutSize: geometry.size
            )
            let hidesOverviewPanelInLandscape = DiveActivityOverviewLandscapePresentation.hidesOverviewPanel(
                isLandscape: isLandscape
            )
            let isMapInteractive = selectedActivityTab == .map
                && DiveActivityOverviewLandscapePresentation.allowsMapInteraction(
                    isLandscape: isLandscape,
                    detentAllowsInteraction: overviewSheetDetent.allowsMapInteraction
                )
            let mapBottomMargin = DiveActivityOverviewLandscapePresentation.mapBottomContentMargin(
                layoutContext: overviewLayoutContext,
                detent: overviewSheetDetent,
                liveHeightFraction: selectedActivityTab == .map ? overviewPanelLiveHeightFraction : nil,
                isLandscape: isLandscape
            )
            let trackBottomMargin = DiveActivityOverviewLandscapePresentation.mapBottomContentMargin(
                layoutContext: overviewLayoutContext,
                detent: overviewSheetDetent,
                liveHeightFraction: selectedActivityTab == .heartRate ? overviewPanelLiveHeightFraction : nil,
                isLandscape: isLandscape
            )
            let mediaUsesFullBleedHero = DiveActivityOverviewLandscapePresentation.mediaUsesFullBleedHero(
                isLandscape: isLandscape,
                detentUsesFullBleed: DiveActivityMediaPresentation.usesFullBleedMediaHero(
                    for: overviewSheetDetent
                )
            )
            let marineLifeTagTopPadding = DiveActivityOverviewPanelMetrics.marineLifeTagButtonTopPadding(
                topSafeInset: geometry.safeAreaInsets.top,
                chromeRowHeight: DiveActivityTabIcon.menuRowHeight,
                chromeTopPadding: AppTheme.Spacing.sm
            )

            ZStack(alignment: .bottom) {
                Group {
                    switch selectedActivityTab {
                    case .map:
                        Group {
                            if showsLiveOverviewMap {
                                DiveLocationMapView(
                                    coordinate: overviewMapCoordinate,
                                    bottomContentMargin: mapBottomMargin,
                                    topObstructionHeight: topObstruction,
                                    layoutHeight: layoutHeight,
                                    sheetHeightFraction: overviewPanelLiveHeightFraction,
                                    largeRestingFraction: mapLargeRestingFraction,
                                    isUserInteractionEnabled: isMapInteractive
                                )
                                .allowsHitTesting(isMapInteractive)
                                .id(overviewMapViewIdentity)
                            } else {
                                DiveOverviewMapTeardownPlaceholder()
                            }
                        }
                        .ignoresSafeArea()
                    case .heartRate:
                        SnorkelSwimTrackMapView(
                            trackCoordinates: derivedSnorkelData.trackCoordinates,
                            bottomContentMargin: trackBottomMargin,
                            topObstructionHeight: topObstruction,
                            layoutHeight: layoutHeight,
                            cameraLayoutDetent: overviewSheetDetent.mapCameraDetent,
                            isUserInteractionEnabled: overviewSheetDetent == .minimized
                        )
                        .ignoresSafeArea()
                    case .camera:
                        SnorkelActivityMediaBackgroundView(
                            mediaItems: derivedSnorkelData.sortedMediaItems,
                            selectedMediaID: $selectedMediaPhotoID,
                            timeZoneOffsetSeconds: activity.timeZoneOffsetSeconds,
                            sheetDetent: overviewSheetDetent,
                            sheetHeightFraction: overviewPanelLiveHeightFraction,
                            layoutHeight: layoutHeight,
                            screenWidth: geometry.size.width,
                            topSafeAreaInset: geometry.safeAreaInsets.top,
                            topObstructionHeight: topObstruction,
                            bottomSafeInset: bottomSafeInset,
                            isLandscape: isLandscape,
                            isMediaTabSelected: selectedActivityTab == .camera,
                            presentationEpoch: mediaPresentationEpoch,
                            deepLinkMediaID: pendingInitialMediaFocusID ?? initialMediaFocusID,
                            onTagMarineLife: { tagMarineLifeFromMedia($0) },
                            marineLifeSightings: activity.marineLifeSightings,
                            marineLifeTagTopPadding: marineLifeTagTopPadding,
                            bottomContentMargin: mediaUsesFullBleedHero ? 0 : bottomObstruction,
                            captureOverlayBottomInset: isLandscape
                                ? 0
                                : DiveActivityMediaPresentation.captureOverlayBottomInset(
                                    layoutHeight: layoutHeight,
                                    detent: overviewSheetDetent,
                                    bottomSafeInset: bottomSafeInset
                                ),
                            mediaPickerItems: $snorkelMediaPickerItems,
                            isImportInProgress: mediaImportOverlay.isBlocking,
                            hasTaggedBuddiesOnSelectedMedia: !selectedMediaTaggedBuddies.isEmpty,
                            hasTaggedMarineLifeOnSelectedMedia: !selectedMediaTaggedSpecies.isEmpty,
                            isSelectedMediaFeatured: {
                                guard let selectedMediaPhotoID else { return false }
                                return SnorkelActivityMediaPresentation.featuredPhotoID(on: activity)
                                    == selectedMediaPhotoID
                            }(),
                            onToggleFeatured: {
                                guard let media = SnorkelActivityMediaPresentation.selectedMedia(
                                    selectedID: selectedMediaPhotoID,
                                    in: derivedSnorkelData.sortedMediaItems
                                ) else { return }
                                toggleFeaturedMedia(media)
                            },
                            onToggleMarineLifeTags: derivedSnorkelData.sortedMediaItems.isEmpty
                                ? nil
                                : { tagMarineLifeFromSelectedMedia() },
                            onToggleBuddyTags: derivedSnorkelData.sortedMediaItems.isEmpty
                                ? nil
                                : { tagBuddiesFromSelectedMedia() }
                        )
                        .ignoresSafeArea()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if isOverviewPanelPresented, !hidesOverviewPanelInLandscape {
                    DiveActivityOverviewEmbeddedPanel(
                        selectedDetent: $overviewSheetDetent,
                        layoutHeight: layoutHeight,
                        screenWidth: geometry.size.width,
                        topSafeInset: geometry.safeAreaInsets.top,
                        bottomSafeInset: bottomSafeInset,
                        collapsedSummary: {
                            switch selectedActivityTab {
                            case .map:
                                mapCollapsedSummary
                            case .heartRate:
                                heartRateCollapsedSummary
                            case .camera:
                                EmptyView()
                            }
                        },
                        panelContent: {
                            switch selectedActivityTab {
                            case .map:
                                mapPanelContent
                            case .heartRate:
                                heartRatePanelContent
                            case .camera:
                                photosOverviewPanelContent(layoutHeight: layoutHeight)
                            }
                        },
                        collapsedSummaryExpandsOnTap: selectedActivityTab != .camera,
                        showsPanelContentWhenMinimized: selectedActivityTab != .heartRate,
                        disablesPanelScrollWhenMinimized: selectedActivityTab != .heartRate,
                        isPanelScrollDisabled: DiveActivityMediaPresentation.disablesPanelScroll(
                            isMediaTabSelected: selectedActivityTab == .camera,
                            detent: overviewSheetDetent
                        ),
                        usesTranslucentChrome: selectedActivityTab == .camera
                            && DiveActivityMediaPresentation.usesTranslucentOverviewPanel(
                                for: overviewSheetDetent
                            ),
                        topScrollFadeHeight: DiveActivityMediaPresentation.panelTopScrollFadeHeight(
                            detent: overviewSheetDetent,
                            isMediaTabSelected: selectedActivityTab == .camera
                        ),
                        usesOpaquePanelScrollFadeBackground:
                            DiveActivityMediaPresentation.panelTopScrollUsesOpaqueFadeBackground(
                                detent: overviewSheetDetent,
                                isMediaTabSelected: selectedActivityTab == .camera
                            ),
                        liveHeightFraction: $overviewPanelLiveHeightFraction,
                        panelScrollOffsetY: $overviewPanelScrollOffsetY,
                        scrollRestorationFallbackY: snorkelScrollRestorationFallbackY,
                        panelScrollContentIdentity: selectedActivityTab
                    )
                    .zIndex(1)
                }
            }
            .overlay(alignment: .top) {
                if DiveActivityMediaPresentation.showsHeroTopChromeScrim(
                    isMediaTabSelected: selectedActivityTab == .camera
                ) {
                    DiveOverviewMapTopScrim(topObstructionHeight: topObstruction)
                        .ignoresSafeArea(edges: .top)
                }
            }
            .animation(.diveOverviewPanelDetent, value: overviewSheetDetent)
            .animation(nil, value: isLandscape)
        }
        .ignoresSafeArea()
    }

    private var overviewMapCoordinate: DiveCoordinate? {
        activity.resolvedMapCoordinate(catalogSites: catalogSitesForMapResolution)
    }

    private var overviewMapViewIdentity: String {
        DiveLocationMapPresentation.mapViewIdentity(
            activityID: activity.id,
            coordinate: overviewMapCoordinate
        )
    }

    private var siteHeaderTitle: String {
        SnorkelActivityOverviewPresentation.siteHeaderTitle(siteName: activity.resolvedSiteName)
    }

    private var mapCollapsedSummary: some View {
        DiveActivityOverviewCollapsedSummary(
            dateText: activity.formattedStartDateOnly(),
            titleText: siteHeaderTitle,
            linkedCatalogSiteID: activity.diveSiteID,
            onOpenLinkedSite: openLinkedDiveSiteOverview,
            diveNumberText: "Snorkel",
            maxDepthText: formatDepth(activity.maxDepthMeters),
            swimDistanceText: formattedSwimDistance(activity.swimDistanceMeters),
            durationText: "\(activity.durationMinutes) min"
        )
    }

    private var heartRateCollapsedSummary: some View {
        SnorkelHeartRateCollapsedSummary(
            dateText: activity.formattedStartDateOnly(),
            titleText: "Heart rate",
            avgHeartRateText: bpmChip(activity.avgHeartRateBPM),
            maxHeartRateText: bpmChip(activity.maxHeartRateBPM)
        )
    }

    private var mapPanelContent: some View {
        SnorkelActivityMapOverviewPanelContent(
            activity: activity,
            overviewSheetDetent: $overviewSheetDetent,
            mapCoordinate: activity.resolvedMapCoordinate(catalogSites: catalogSitesForMapResolution),
            siteTitle: siteHeaderTitle,
            linkedCatalogSiteID: activity.diveSiteID,
            onOpenLinkedSite: openLinkedDiveSiteOverview,
            regionCountryLine: overviewMapHeaderRegionCountryLine
        )
    }

    private var heartRatePanelContent: some View {
        SnorkelHeartRateOverviewPanelContent(
            siteTitle: siteHeaderTitle,
            linkedCatalogSiteID: activity.diveSiteID,
            onOpenLinkedSite: openLinkedDiveSiteOverview,
            regionCountryLine: overviewMapHeaderRegionCountryLine,
            dateDashTimeLine: DiveActivityOverviewPresentation.startDateDashTimeLine(
                startTime: activity.startTime,
                timeZoneOffsetSeconds: activity.timeZoneOffsetSeconds
            ),
            overviewSheetDetent: $overviewSheetDetent,
            avgHeartRateBPM: activity.avgHeartRateBPM,
            maxHeartRateBPM: activity.maxHeartRateBPM,
            profileHeartRateStats: derivedSnorkelData.heartRateStats,
            heartRateSamples: derivedSnorkelData.heartRateSamples,
            totalCalories: activity.totalCalories
        )
    }

    private var selectedMediaTaggedSpecies: [MarineLife] {
        guard let media = SnorkelActivityMediaPresentation.selectedMedia(
            selectedID: selectedMediaPhotoID,
            in: derivedSnorkelData.sortedMediaItems
        ) else { return [] }
        return MarineLifeMediaTagPresentation.resolvedTaggedSpecies(
            mediaPhotoID: media.id,
            sightings: activity.marineLifeSightings,
            catalog: marineLifeCatalog
        )
    }

    private var selectedMediaTaggedBuddies: [DiveBuddy] {
        guard let media = SnorkelActivityMediaPresentation.selectedMedia(
            selectedID: selectedMediaPhotoID,
            in: derivedSnorkelData.sortedMediaItems
        ) else { return [] }
        return DiveMediaBuddyTagPresentation.resolvedTaggedBuddies(
            mediaPhotoID: media.id,
            tags: activity.mediaBuddyTags
        )
    }

    private func photosOverviewPanelContent(layoutHeight: CGFloat) -> some View {
        let hasMedia = !derivedSnorkelData.sortedMediaItems.isEmpty
        let showsMarineLifeTagInSheet = DiveActivityMediaPresentation.showsMarineLifeTagInSheet(
            for: overviewSheetDetent
        )
        let showsBuddyTagInSheet = DiveActivityMediaPresentation.showsBuddyTagInSheet(
            for: overviewSheetDetent
        )
        let canTagMarineLife = hasMedia && (
            showsMarineLifeTagInSheet
                || DiveActivityMediaPresentation.showsLargeDetentAddMarineLifeControl(
                    for: overviewSheetDetent
                )
        )
        let canTagBuddies = hasMedia && (
            showsBuddyTagInSheet
                || DiveActivityMediaPresentation.showsLargeDetentAddBuddyControl(
                    for: overviewSheetDetent
                )
        )
        let taggedSpecies = hasMedia ? selectedMediaTaggedSpecies : []
        let taggedBuddies = hasMedia ? selectedMediaTaggedBuddies : []
        let expandsMarineLifeDetail =
            DiveActivityMediaPresentation.opensMarineLifeDetailOnSheetFishTap(
                detent: overviewSheetDetent
            )
            || DiveActivityMediaPresentation.opensMarineLifeDetailOnTaggedChipTap(
                detent: overviewSheetDetent,
                taggedSpeciesCount: taggedSpecies.count
            )
        return SnorkelActivityPhotosPanelContent(
            mediaItems: derivedSnorkelData.sortedMediaItems,
            selectedMediaID: $selectedMediaPhotoID,
            timeZoneOffsetSeconds: activity.timeZoneOffsetSeconds,
            sheetDetent: overviewSheetDetent,
            layoutHeight: layoutHeight,
            showsMediaCarousel: DiveActivityMediaPresentation.showsMediaCarouselInSheet(
                for: overviewSheetDetent
            ),
            showsMarineLifeTagInSheet: showsMarineLifeTagInSheet,
            onTagMarineLife: canTagMarineLife
                ? { tagMarineLifeFromSelectedMedia() }
                : nil,
            showsBuddyTagInSheet: showsBuddyTagInSheet,
            onTagBuddies: canTagBuddies
                ? { tagBuddiesFromSelectedMedia() }
                : nil,
            onIdentifyFish: canTagMarineLife && DiveMarineLifeTagSheetPresentation.showsFishialIdentifyAction
                ? { identifyFishFromSelectedMedia() }
                : nil,
            onExpandMarineLifeDetail: expandsMarineLifeDetail
                ? {
                    withAnimation(.diveOverviewPanelDetent) {
                        overviewSheetDetent = .large
                    }
                }
                : nil,
            onCollapsePanelToMedium: {
                withAnimation(.diveOverviewPanelDetent) {
                    overviewSheetDetent = .large
                }
            },
            featuredMediaID: SnorkelActivityMediaPresentation.featuredPhotoID(on: activity),
            onToggleFeatured: { toggleFeaturedMedia($0) },
            onUserSelectMedia: { _ in },
            taggedSpecies: taggedSpecies,
            taggedBuddies: taggedBuddies,
            ownerProfileID: activity.ownerProfileID,
            activityKind: .snorkel,
            diveNumberChip: nil,
            siteTitle: siteHeaderTitle,
            linkedCatalogSiteID: activity.diveSiteID,
            onOpenLinkedSite: openLinkedDiveSiteOverview,
            regionCountryLine: overviewMapHeaderRegionCountryLine,
            dateDashTimeLine: DiveActivityOverviewPresentation.startDateDashTimeLine(
                startTime: activity.startTime,
                timeZoneOffsetSeconds: activity.timeZoneOffsetSeconds
            ),
            mediaPickerItems: $snorkelMediaPickerItems,
            isImportInProgress: mediaImportOverlay.isBlocking
        )
        .animation(nil, value: overviewSheetDetent)
        .accessibilityIdentifier(snorkelMediaPanelAccessibilityIdentifier)
    }

    private var snorkelMediaPanelAccessibilityIdentifier: String {
        switch overviewSheetDetent {
        case .large:
            "SnorkelOverview.MediaPanel.Large"
        case .minimized:
            "SnorkelOverview.MediaPanel.Minimized"
        }
    }

    private func toggleFeaturedMedia(_ media: SnorkelMediaPhoto) {
        let resolvedFeaturedID = SnorkelActivityMediaPresentation.featuredPhotoID(on: activity)
        let newValue: UUID? = resolvedFeaturedID == media.id ? nil : media.id
        try? SnorkelActivityMediaStorage.setFeaturedMedia(
            newValue,
            on: activity,
            modelContext: modelContext
        )
    }

    private func tagMarineLifeFromSelectedMedia() {
        guard let media = SnorkelActivityMediaPresentation.selectedMedia(
            selectedID: selectedMediaPhotoID,
            in: derivedSnorkelData.sortedMediaItems
        ) else { return }
        tagMarineLifeFromMedia(media)
    }

    private func tagBuddiesFromSelectedMedia() {
        guard let media = SnorkelActivityMediaPresentation.selectedMedia(
            selectedID: selectedMediaPhotoID,
            in: derivedSnorkelData.sortedMediaItems
        ) else { return }
        tagBuddiesFromMedia(media)
    }

    private func identifyFishFromSelectedMedia() {
        guard let media = SnorkelActivityMediaPresentation.selectedMedia(
            selectedID: selectedMediaPhotoID,
            in: derivedSnorkelData.sortedMediaItems
        ) else { return }
        fishialIdentifyMediaID = media.id
    }

    @MainActor
    private func importSnorkelMediaPickerItems(_ items: [PhotosPickerItem]) async {
        let total = items.count
        withAnimation(.easeInOut(duration: 0.15)) {
            mediaImportOverlay = .importing(completed: 0, total: total, stage: "Preparing…")
        }
        await Task.yield()

        let outcome = await SnorkelActivityMediaBatchImport.importPickerItems(
            items,
            into: activity,
            modelContext: modelContext
        ) { completed, total, stage in
            withAnimation(.easeInOut(duration: 0.12)) {
                mediaImportOverlay = .importing(completed: completed, total: total, stage: stage)
            }
        }

        if let failureMessage = outcome.failureMessage {
            withAnimation(.easeInOut(duration: 0.15)) {
                mediaImportOverlay = .failed(failureMessage)
            }
            snorkelMediaPickerItems = []
            return
        }

        withAnimation(.easeInOut(duration: 0.15)) {
            mediaImportOverlay = .importing(
                completed: outcome.savedCount,
                total: total,
                stage: "Complete"
            )
        }
        try? await Task.sleep(for: .milliseconds(450))

        mediaImportOverlay = .hidden
        snorkelMediaPickerItems = []
        if let lastAddedID = outcome.lastAddedMediaID {
            selectedMediaPhotoID = lastAddedID
        }
    }

    private var marineLifeTagSheetPresented: Binding<Bool> {
        Binding(
            get: { marineLifeTagMediaID != nil },
            set: { isPresented in
                if !isPresented {
                    marineLifeTagMediaID = nil
                }
            }
        )
    }

    private var marineLifeTagTargetMedia: SnorkelMediaPhoto? {
        guard let marineLifeTagMediaID else { return nil }
        return derivedSnorkelData.mediaPhotosByID[marineLifeTagMediaID]
    }

    private func tagMarineLifeFromMedia(_ media: SnorkelMediaPhoto) {
        marineLifeTagMediaID = media.id
    }

    private var buddyTagSheetPresented: Binding<Bool> {
        Binding(
            get: { buddyTagMediaID != nil },
            set: { isPresented in
                if !isPresented {
                    buddyTagMediaID = nil
                }
            }
        )
    }

    private var buddyTagTargetMedia: SnorkelMediaPhoto? {
        guard let buddyTagMediaID else { return nil }
        return derivedSnorkelData.mediaPhotosByID[buddyTagMediaID]
    }

    private func tagBuddiesFromMedia(_ media: SnorkelMediaPhoto) {
        buddyTagMediaID = media.id
    }

    private var fishialIdentifySheetPresented: Binding<Bool> {
        Binding(
            get: { fishialIdentifyMediaID != nil },
            set: { isPresented in
                if !isPresented {
                    fishialIdentifyMediaID = nil
                }
            }
        )
    }

    private var fishialIdentifyTargetMedia: SnorkelMediaPhoto? {
        guard let fishialIdentifyMediaID else { return nil }
        return derivedSnorkelData.mediaPhotosByID[fishialIdentifyMediaID]
    }

    @MainActor
    private func loadMarineLifeCatalogIfNeeded() async {
        guard marineLifeCatalog.isEmpty else { return }
        marineLifeCatalog = await MarineLifeCatalogLoader.loadSortedCatalog(modelContext: modelContext)
    }

    private var overviewMapHeaderRegionCountryLine: String? {
        DiveActivityOverviewPresentation.mapHeaderRegionCountryLine(
            diveSite: activity.resolvedLinkedSite,
            locationName: activity.locationName
        )
    }

    private func openLinkedDiveSiteOverview() {
        guard let siteID = activity.diveSiteID else { return }
        openCatalogDiveSiteDetail?(siteID)
    }

    private func formatDepth(_ meters: Double?) -> String {
        guard let meters, meters > 0 else { return "—" }
        return DiveQuantityFormatting.depth(meters: meters, system: diveDisplayUnitSystem)
    }

    private func formattedSwimDistance(_ meters: Double?) -> String? {
        guard let meters, meters > 0 else { return nil }
        return DiveQuantityFormatting.swimDistance(meters: meters, system: diveDisplayUnitSystem)
    }

    private func bpmChip(_ value: Int?) -> String {
        guard let value, value > 0 else { return "—" }
        return "\(value) bpm"
    }

    private func applyInitialMediaFocusIfNeeded() {
        guard !didApplyInitialMediaFocus else { return }
        guard let mediaID = initialMediaFocusID ?? pendingInitialMediaFocusID else { return }
        didApplyInitialMediaFocus = true
        pendingInitialMediaFocusID = nil
        selectedActivityTab = .camera
        selectedMediaPhotoID = mediaID
        isOverviewPanelPresented = true
        overviewSheetDetent = .large
    }

    private func handleSnorkelActivityAppear() {
        if initialMediaFocusID != nil, !didApplyInitialMediaFocus {
            DiveActivityOverviewUIStateStore.removeSnorkel(activityID: activity.id)
            applyInitialMediaFocusIfNeeded()
        } else {
            _ = restoreSnorkelOverviewUIStateIfNeeded()
        }
        overviewMapTeardownRequested = false
    }

    @discardableResult
    private func restoreSnorkelOverviewUIStateIfNeeded() -> Bool {
        guard let snapshot = DiveActivityOverviewUIStateStore.snorkelSnapshot(for: activity.id) else {
            return false
        }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            selectedActivityTab = snapshot.selectedActivityTab
            overviewSheetDetent = snapshot.overviewSheetDetent
            isOverviewPanelPresented = snapshot.isOverviewPanelPresented
            selectedMediaPhotoID = snapshot.selectedMediaPhotoID
            overviewPanelScrollOffsetY = snapshot.overviewPanelScrollOffsetY
        }
        if snapshot.selectedActivityTab == .camera {
            mediaPresentationEpoch &+= 1
        }
        return true
    }

    private func persistSnorkelOverviewUIState() {
        DiveActivityOverviewUIStateStore.saveSnorkel(
            SnorkelActivityOverviewUISnapshot(
                selectedActivityTab: selectedActivityTab,
                overviewSheetDetent: overviewSheetDetent,
                isOverviewPanelPresented: isOverviewPanelPresented,
                selectedMediaPhotoID: selectedMediaPhotoID,
                overviewPanelScrollOffsetY: overviewPanelScrollOffsetY
            ),
            for: activity.id
        )
    }

    private var storedSnorkelOverviewPanelScrollOffsetY: CGFloat {
        DiveActivityOverviewUIStateStore.snorkelSnapshot(for: activity.id)?.overviewPanelScrollOffsetY ?? 0
    }

    private var snorkelScrollRestorationFallbackY: CGFloat {
        guard overviewPanelScrollOffsetY < 4 else { return 0 }
        let stored = storedSnorkelOverviewPanelScrollOffsetY
        return stored > 4 ? stored : 0
    }

    @MainActor
    private func refreshDerivedSnorkelDataAsync() async {
        let activityID = activity.id
        let mediaPhotos = SnorkelActivityMediaPresentation.sortedPhotos(activity.mediaPhotos)
        try? SnorkelProfilePointStore.ensurePointsLoaded(for: activity, modelContext: modelContext)
        let points = (try? SnorkelProfilePointStore.fetchPoints(
            for: activityID,
            modelContext: modelContext
        )) ?? []
        let profileSnapshots = points.map {
            SnorkelDerivedProfilePointSnapshot(
                timestamp: $0.timestamp,
                latitude: $0.latitude,
                longitude: $0.longitude,
                heartRateBPM: $0.heartRateBPM
            )
        }

        let buildResult = await Task.detached(priority: .userInitiated) {
            SnorkelDerivedDataBuilder.build(from: profileSnapshots)
        }.value

        guard !Task.isCancelled else { return }

        derivedSnorkelData = DerivedSnorkelData(
            sortedProfileSnapshots: buildResult.sortedProfilePoints,
            heartRateSamples: buildResult.heartRateSamples,
            trackCoordinates: buildResult.trackCoordinates,
            sortedMediaItems: mediaPhotos,
            mediaPhotosByID: Dictionary(uniqueKeysWithValues: mediaPhotos.map { ($0.id, $0) }),
            heartRateStats: buildResult.heartRateStats
        )
        mediaPresentationEpoch &+= 1
        applyInitialMediaFocusIfNeeded()
    }

    @MainActor
    private func loadCatalogSitesForMapResolutionIfNeeded() async {
        guard DiveActivityMapCoordinateResolution.needsCatalogSiteLookup(for: activity) else {
            catalogSitesForMapResolution = []
            return
        }
        guard catalogSitesForMapResolution.isEmpty else { return }
        catalogSitesForMapResolution = await DiveActivityMapCoordinateResolution.loadCatalogSitesIfNeeded(
            for: activity,
            modelContext: modelContext,
            container: modelContext.container
        )
    }
}
