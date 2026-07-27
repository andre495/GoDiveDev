import SwiftUI

/// Read-only friend activity detail — same map / tank (or heart rate) / media shell as owned dives & snorkels.
struct FriendSharedDiveDetailView: View {
    let dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    let friendName: String

    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem
    @State private var selectedDiveTab: DiveActivityTab = .map
    @State private var selectedSnorkelTab: SnorkelActivityTab = .map
    @State private var overviewSheetDetent = DiveActivityOverviewDetent.defaultSelection
    @State private var overviewPanelLiveHeightFraction = DiveActivityOverviewDetent.defaultSelection.heightFraction
    @State private var isOverviewPanelPresented = true
    @State private var overviewPanelScrollOffsetY: CGFloat = 0
    @State private var selectedMediaPreviewID: String?
    @State private var snorkelSnapshot = FriendSharedActivityDetailPresentation.SnorkelDerivedSnapshot.empty
    @State private var friendDepthChartScrubCallout: DiveDepthProfileScrubCallout?

    private var currentUID: String? {
        GoDiveFirestoreUserProfileMapping.loadCachedFirebaseUID()
    }

    private var showsTaggedYou: Bool {
        GoDiveSharedDiveProjectionMapping.wasCurrentUserTagged(
            dive: dive,
            currentFirebaseUID: currentUID
        )
    }

    var body: some View {
        Group {
            switch dive.resolvedActivityKind {
            case .scubaDive:
                scubaDetailPage
            case .snorkel:
                snorkelDetailPage
            }
        }
        .hidesBottomTabBarWhenPushed()
        .accessibilityIdentifier("FriendSharedDiveDetail.Root")
        .task(id: dive.id) {
            snorkelSnapshot = FriendSharedActivityDetailPresentation.snorkelDerivedSnapshot(from: dive)
        }
    }

    // MARK: - Scuba

    private var scubaDetailPage: some View {
        AppHeaderlessPage {
            ZStack(alignment: .top) {
                scubaHeroLayer
                topChrome {
                    DiveActivityIconTabBar(
                        selection: $selectedDiveTab,
                        onSelect: selectDiveTab
                    )
                }
            }
        }
        .diveActivityLandscapeOrientation()
    }

    private var scubaHeroLayer: some View {
        GeometryReader { geometry in
            let layoutHeight = max(geometry.size.height, 1)
            let bottomSafeInset = geometry.safeAreaInsets.bottom
            let overviewLayoutContext = DiveActivityOverviewSheetLayoutContext(
                layoutHeight: layoutHeight,
                screenWidth: geometry.size.width,
                topSafeInset: geometry.safeAreaInsets.top,
                bottomSafeInset: bottomSafeInset
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
            let mapCoordinate = FriendSharedActivityDetailPresentation.mapCoordinate(from: dive)
            let mapLargeRestingFraction = DiveActivityOverviewPanelMetrics.largeHeightFraction(
                in: overviewLayoutContext
            )
            let mapBottomMargin = DiveActivityOverviewLandscapePresentation.mapBottomContentMargin(
                layoutContext: overviewLayoutContext,
                detent: overviewSheetDetent,
                liveHeightFraction: selectedDiveTab == .map ? overviewPanelLiveHeightFraction : nil,
                isLandscape: isLandscape
            )
            let isMapInteractive = selectedDiveTab == .map
                && DiveActivityOverviewLandscapePresentation.allowsMapInteraction(
                    isLandscape: isLandscape,
                    detentAllowsInteraction: overviewSheetDetent.allowsMapInteraction
                )

            ZStack(alignment: .bottom) {
                Group {
                    switch selectedDiveTab {
                    case .map:
                        DiveLocationMapView(
                            coordinate: mapCoordinate,
                            bottomContentMargin: mapBottomMargin,
                            topObstructionHeight: topObstruction,
                            layoutHeight: layoutHeight,
                            sheetHeightFraction: overviewPanelLiveHeightFraction,
                            largeRestingFraction: mapLargeRestingFraction,
                            isUserInteractionEnabled: isMapInteractive
                        )
                        .allowsHitTesting(isMapInteractive)
                        .ignoresSafeArea()
                    case .tank:
                        friendTankHeroChart(
                            layoutSize: geometry.size,
                            layoutHeight: layoutHeight,
                            topObstruction: topObstruction,
                            bottomObstruction: bottomObstruction
                        )
                        .ignoresSafeArea()
                    case .camera:
                        FriendSharedActivityMediaHeroView(
                            previews: dive.mediaPreviews,
                            selectedPreviewID: $selectedMediaPreviewID,
                            layoutHeight: layoutHeight,
                            topObstructionHeight: topObstruction,
                            bottomObstructionHeight: bottomObstruction
                        )
                        .ignoresSafeArea()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if isOverviewPanelPresented {
                    DiveActivityOverviewEmbeddedPanel(
                        selectedDetent: $overviewSheetDetent,
                        layoutHeight: layoutHeight,
                        screenWidth: geometry.size.width,
                        topSafeInset: geometry.safeAreaInsets.top,
                        bottomSafeInset: bottomSafeInset,
                        collapsedSummary: {
                            switch selectedDiveTab {
                            case .map:
                                scubaMapCollapsedSummary
                            case .tank:
                                scubaTankCollapsedSummary
                            case .camera:
                                EmptyView()
                            }
                        },
                        panelContent: {
                            switch selectedDiveTab {
                            case .map:
                                FriendSharedActivityMapPanelContent(
                                    dive: dive,
                                    friendName: friendName,
                                    showsTaggedYou: showsTaggedYou,
                                    overviewSheetDetent: $overviewSheetDetent
                                )
                            case .tank:
                                FriendSharedActivityTankPanelContent(
                                    dive: dive,
                                    friendName: friendName,
                                    showsTaggedYou: showsTaggedYou,
                                    overviewSheetDetent: $overviewSheetDetent
                                )
                            case .camera:
                                FriendSharedActivityMediaPanelContent(
                                    dive: dive,
                                    friendName: friendName,
                                    showsTaggedYou: showsTaggedYou,
                                    selectedPreviewID: $selectedMediaPreviewID
                                )
                            }
                        },
                        collapsedSummaryExpandsOnTap: selectedDiveTab != .camera,
                        showsPanelContentWhenMinimized: selectedDiveTab != .tank,
                        disablesPanelScrollWhenMinimized: selectedDiveTab != .tank,
                        isPanelScrollDisabled: DiveActivityMediaPresentation.disablesPanelScroll(
                            isMediaTabSelected: selectedDiveTab == .camera,
                            detent: overviewSheetDetent
                        ),
                        usesTranslucentChrome: selectedDiveTab == .camera
                            && DiveActivityMediaPresentation.usesTranslucentOverviewPanel(
                                for: overviewSheetDetent
                            ),
                        topScrollFadeHeight: DiveActivityMediaPresentation.panelTopScrollFadeHeight(
                            detent: overviewSheetDetent,
                            isMediaTabSelected: selectedDiveTab == .camera
                        ),
                        usesOpaquePanelScrollFadeBackground:
                            DiveActivityMediaPresentation.panelTopScrollUsesOpaqueFadeBackground(
                                detent: overviewSheetDetent,
                                isMediaTabSelected: selectedDiveTab == .camera
                            ),
                        liveHeightFraction: $overviewPanelLiveHeightFraction,
                        panelScrollOffsetY: $overviewPanelScrollOffsetY,
                        panelScrollContentIdentity: selectedDiveTab
                    )
                    .zIndex(1)
                }
            }
            .overlay(alignment: .top) {
                if DiveActivityMediaPresentation.showsHeroTopChromeScrim(
                    isMediaTabSelected: selectedDiveTab == .camera
                ) {
                    DiveOverviewMapTopScrim(topObstructionHeight: topObstruction)
                        .ignoresSafeArea(edges: .top)
                }
            }
            .overlay(alignment: .top) {
                if selectedDiveTab == .tank, let friendDepthChartScrubCallout {
                    GeometryReader { geometry in
                        DiveDepthProfileScrubCalloutLabel(callout: friendDepthChartScrubCallout)
                            .frame(maxWidth: .infinity, alignment: .top)
                            .padding(
                                .top,
                                DiveDepthProfileScrubCalloutPresentation.labelTopPadding(
                                    topSafeInset: geometry.safeAreaInsets.top,
                                    chromeTopPadding: AppTheme.Spacing.sm
                                )
                            )
                    }
                    .allowsHitTesting(false)
                }
            }
            .animation(.diveOverviewPanelDetent, value: overviewSheetDetent)
        }
        .ignoresSafeArea()
    }

    private var scubaMapCollapsedSummary: some View {
        DiveActivityOverviewCollapsedSummary(
            dateText: FriendSharedActivityDetailPresentation.startDateText(for: dive),
            titleText: FriendSharedActivityDetailPresentation.siteHeaderTitle(for: dive),
            linkedCatalogSiteID: nil,
            onOpenLinkedSite: nil,
            diveNumberText: FriendSharedActivityDetailPresentation.diveNumberPlainLabel(for: dive),
            maxDepthText: FriendSharedActivityDetailPresentation.formattedMaxDepth(
                for: dive,
                unitSystem: diveDisplayUnitSystem
            ),
            durationText: FriendSharedActivityDetailPresentation.formattedDuration(for: dive)
        )
    }

    private var scubaTankCollapsedSummary: some View {
        DiveActivityTankCollapsedSummary(
            dateText: FriendSharedActivityDetailPresentation.startDateText(for: dive),
            titleText: "Tank & gas",
            diveNumberText: FriendSharedActivityDetailPresentation.diveNumberPlainLabel(for: dive),
            startPressureText: FriendSharedActivityDetailPresentation.formattedPressure(
                psi: dive.tankPressureStartPSI,
                unitSystem: diveDisplayUnitSystem
            ),
            endPressureText: FriendSharedActivityDetailPresentation.formattedPressure(
                psi: dive.tankPressureEndPSI,
                unitSystem: diveDisplayUnitSystem
            )
        )
    }

    @ViewBuilder
    private func friendTankHeroChart(
        layoutSize: CGSize,
        layoutHeight: CGFloat,
        topObstruction: CGFloat,
        bottomObstruction: CGFloat
    ) -> some View {
        let chartFrame = DiveTankOverviewHeroPresentation.minimizedProfileChartFrame(
            layoutSize: layoutSize,
            layoutHeight: layoutHeight,
            topObstructionHeight: topObstruction,
            bottomContentMargin: bottomObstruction,
            isLandscape: false,
            detent: overviewSheetDetent
        )
        FriendSharedDepthProfileChartView(
            dive: dive,
            allowsInteraction: true,
            animatesWaterFill: true,
            chromeStyle: .edgeToEdge,
            topEdgeFadeFraction: overviewSheetDetent == .minimized
                ? DiveTankOverviewHeroPresentation.minimizedPortraitChartTopFadeFraction
                : 0,
            topObstructionHeight: topObstruction,
            pinsScrubCalloutUnderTabMenu: true,
            activeScrubCallout: $friendDepthChartScrubCallout
        )
        .frame(width: chartFrame.width, height: chartFrame.height)
        .position(x: chartFrame.midX, y: chartFrame.midY)
        .accessibilityIdentifier("FriendSharedDiveDetail.Tank.ProfileChart")
    }

    private func selectDiveTab(_ tab: DiveActivityTab) {
        guard tab != selectedDiveTab else {
            syncOverviewSheetPresentation(forDiveTab: tab)
            return
        }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if let detent = DiveActivityOverviewTabSelection.overviewDetent(whenSelecting: tab) {
                overviewSheetDetent = detent
                isOverviewPanelPresented = true
            } else {
                isOverviewPanelPresented = false
            }
            selectedDiveTab = tab
        }
    }

    private func syncOverviewSheetPresentation(forDiveTab tab: DiveActivityTab) {
        if !isOverviewPanelPresented {
            isOverviewPanelPresented = true
        }
        if let detent = DiveActivityOverviewTabSelection.overviewDetent(whenSelecting: tab) {
            overviewSheetDetent = detent
        }
    }

    // MARK: - Snorkel

    private var snorkelDetailPage: some View {
        AppHeaderlessPage {
            ZStack(alignment: .top) {
                snorkelHeroLayer
                topChrome {
                    SnorkelActivityIconTabBar(
                        selection: $selectedSnorkelTab,
                        onSelect: selectSnorkelTab
                    )
                }
            }
        }
        .diveActivityLandscapeOrientation()
    }

    private var snorkelHeroLayer: some View {
        GeometryReader { geometry in
            let layoutHeight = max(geometry.size.height, 1)
            let bottomSafeInset = geometry.safeAreaInsets.bottom
            let overviewLayoutContext = DiveActivityOverviewSheetLayoutContext(
                layoutHeight: layoutHeight,
                screenWidth: geometry.size.width,
                topSafeInset: geometry.safeAreaInsets.top,
                bottomSafeInset: bottomSafeInset
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
            let trackCoordinates = FriendSharedActivityDetailPresentation.swimTrackCoordinates(from: dive)
            let mapCoordinate = FriendSharedActivityDetailPresentation.mapCoordinate(from: dive)
            let mapBottomMargin = DiveActivityOverviewLandscapePresentation.mapBottomContentMargin(
                layoutContext: overviewLayoutContext,
                detent: overviewSheetDetent,
                liveHeightFraction: selectedSnorkelTab == .map ? overviewPanelLiveHeightFraction : nil,
                isLandscape: isLandscape
            )
            let heartRateBottomMargin = DiveActivityOverviewLandscapePresentation.mapBottomContentMargin(
                layoutContext: overviewLayoutContext,
                detent: overviewSheetDetent,
                liveHeightFraction: selectedSnorkelTab == .heartRate ? overviewPanelLiveHeightFraction : nil,
                isLandscape: isLandscape
            )
            let isMapInteractive = selectedSnorkelTab == .map
                && DiveActivityOverviewLandscapePresentation.allowsMapInteraction(
                    isLandscape: isLandscape,
                    detentAllowsInteraction: overviewSheetDetent.allowsMapInteraction
                )

            ZStack(alignment: .bottom) {
                Group {
                    switch selectedSnorkelTab {
                    case .map:
                        if trackCoordinates.count >= 2 {
                            SnorkelSwimTrackMapView(
                                trackCoordinates: trackCoordinates,
                                bottomContentMargin: mapBottomMargin,
                                topObstructionHeight: topObstruction,
                                layoutHeight: layoutHeight,
                                cameraFitting: .heroBand,
                                isUserInteractionEnabled: isMapInteractive
                            )
                        } else if let mapCoordinate {
                            DiveLocationMapView(
                                coordinate: mapCoordinate,
                                bottomContentMargin: mapBottomMargin,
                                topObstructionHeight: topObstruction,
                                layoutHeight: layoutHeight,
                                sheetHeightFraction: overviewPanelLiveHeightFraction,
                                isUserInteractionEnabled: isMapInteractive
                            )
                        } else {
                            heroPlaceholder(systemName: "map")
                        }
                    case .heartRate:
                        SnorkelHeartRateOverviewHeroView(
                            samples: snorkelSnapshot.heartRateSamples,
                            sessionMaxBPMHint: snorkelSnapshot.maxHeartRateBPM,
                            bottomContentMargin: heartRateBottomMargin,
                            topObstructionHeight: topObstruction
                        )
                    case .camera:
                        FriendSharedActivityMediaHeroView(
                            previews: dive.mediaPreviews,
                            selectedPreviewID: $selectedMediaPreviewID,
                            layoutHeight: layoutHeight,
                            topObstructionHeight: topObstruction,
                            bottomObstructionHeight: bottomObstruction
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

                if isOverviewPanelPresented {
                    DiveActivityOverviewEmbeddedPanel(
                        selectedDetent: $overviewSheetDetent,
                        layoutHeight: layoutHeight,
                        screenWidth: geometry.size.width,
                        topSafeInset: geometry.safeAreaInsets.top,
                        bottomSafeInset: bottomSafeInset,
                        collapsedSummary: {
                            switch selectedSnorkelTab {
                            case .map:
                                snorkelMapCollapsedSummary
                            case .heartRate:
                                snorkelHeartRateCollapsedSummary
                            case .camera:
                                EmptyView()
                            }
                        },
                        panelContent: {
                            switch selectedSnorkelTab {
                            case .map:
                                FriendSharedActivityMapPanelContent(
                                    dive: dive,
                                    friendName: friendName,
                                    showsTaggedYou: showsTaggedYou,
                                    overviewSheetDetent: $overviewSheetDetent
                                )
                            case .heartRate:
                                FriendSharedActivityHeartRatePanelContent(
                                    dive: dive,
                                    friendName: friendName,
                                    showsTaggedYou: showsTaggedYou,
                                    snorkelSnapshot: snorkelSnapshot,
                                    overviewSheetDetent: $overviewSheetDetent
                                )
                            case .camera:
                                FriendSharedActivityMediaPanelContent(
                                    dive: dive,
                                    friendName: friendName,
                                    showsTaggedYou: showsTaggedYou,
                                    selectedPreviewID: $selectedMediaPreviewID
                                )
                            }
                        },
                        collapsedSummaryExpandsOnTap: selectedSnorkelTab != .camera,
                        showsPanelContentWhenMinimized: selectedSnorkelTab != .heartRate,
                        disablesPanelScrollWhenMinimized: selectedSnorkelTab != .heartRate,
                        isPanelScrollDisabled: DiveActivityMediaPresentation.disablesPanelScroll(
                            isMediaTabSelected: selectedSnorkelTab == .camera,
                            detent: overviewSheetDetent
                        ),
                        usesTranslucentChrome: selectedSnorkelTab == .camera
                            && DiveActivityMediaPresentation.usesTranslucentOverviewPanel(
                                for: overviewSheetDetent
                            ),
                        topScrollFadeHeight: DiveActivityMediaPresentation.panelTopScrollFadeHeight(
                            detent: overviewSheetDetent,
                            isMediaTabSelected: selectedSnorkelTab == .camera
                        ),
                        usesOpaquePanelScrollFadeBackground:
                            DiveActivityMediaPresentation.panelTopScrollUsesOpaqueFadeBackground(
                                detent: overviewSheetDetent,
                                isMediaTabSelected: selectedSnorkelTab == .camera
                            ),
                        liveHeightFraction: $overviewPanelLiveHeightFraction,
                        panelScrollOffsetY: $overviewPanelScrollOffsetY,
                        panelScrollContentIdentity: selectedSnorkelTab
                    )
                    .zIndex(1)
                }
            }
            .overlay(alignment: .top) {
                if DiveActivityMediaPresentation.showsHeroTopChromeScrim(
                    isMediaTabSelected: selectedSnorkelTab == .camera
                ) {
                    DiveOverviewMapTopScrim(topObstructionHeight: topObstruction)
                        .ignoresSafeArea(edges: .top)
                }
            }
            .animation(.diveOverviewPanelDetent, value: overviewSheetDetent)
        }
        .ignoresSafeArea()
    }

    private var snorkelMapCollapsedSummary: some View {
        DiveActivityOverviewCollapsedSummary(
            dateText: FriendSharedActivityDetailPresentation.startDateText(for: dive),
            titleText: FriendSharedActivityDetailPresentation.siteHeaderTitle(for: dive),
            linkedCatalogSiteID: nil,
            onOpenLinkedSite: nil,
            diveNumberText: "Snorkel",
            maxDepthText: FriendSharedActivityDetailPresentation.formattedMaxDepth(
                for: dive,
                unitSystem: diveDisplayUnitSystem
            ),
            swimDistanceText: FriendSharedActivityDetailPresentation.formattedSwimDistance(
                for: dive,
                unitSystem: diveDisplayUnitSystem
            ),
            durationText: FriendSharedActivityDetailPresentation.formattedDuration(for: dive)
        )
    }

    private var snorkelHeartRateCollapsedSummary: some View {
        SnorkelHeartRateCollapsedSummary(
            dateText: FriendSharedActivityDetailPresentation.startDateText(for: dive),
            titleText: "Heart rate",
            avgHeartRateText: formattedBPM(snorkelSnapshot.avgHeartRateBPM),
            maxHeartRateText: formattedBPM(snorkelSnapshot.maxHeartRateBPM)
        )
    }

    private func selectSnorkelTab(_ tab: SnorkelActivityTab) {
        guard tab != selectedSnorkelTab else {
            syncOverviewSheetPresentation(forSnorkelTab: tab)
            return
        }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if let detent = DiveActivityOverviewTabSelection.overviewDetent(whenSelectingSnorkel: tab) {
                overviewSheetDetent = detent
                isOverviewPanelPresented = true
            } else {
                isOverviewPanelPresented = false
            }
            selectedSnorkelTab = tab
        }
    }

    private func syncOverviewSheetPresentation(forSnorkelTab tab: SnorkelActivityTab) {
        if !isOverviewPanelPresented {
            isOverviewPanelPresented = true
        }
        if let detent = DiveActivityOverviewTabSelection.overviewDetent(whenSelectingSnorkel: tab) {
            overviewSheetDetent = detent
        }
    }

    // MARK: - Shared chrome

    private func topChrome<Center: View>(@ViewBuilder center: () -> Center) -> some View {
        GlassEffectContainer {
            ZStack {
                HStack {
                    SecondaryDestinationBackButton()
                    Spacer(minLength: 0)
                }
                center()
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.top, AppTheme.Spacing.sm)
        .zIndex(1_000)
        .allowsHitTesting(true)
    }

    private func heroPlaceholder(systemName: String) -> some View {
        AppTheme.Colors.screenBackgroundGradient
            .overlay {
                Image(systemName: systemName)
                    .font(.largeTitle)
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
            }
    }

    private func formattedBPM(_ value: Int?) -> String {
        guard let value, value > 0 else { return "—" }
        return "\(value)"
    }
}

// MARK: - Media hero

struct FriendSharedActivityMediaHeroView: View {
    let previews: [GoDiveSharedDiveProjectionMapping.MediaPreviewSnapshot]
    @Binding var selectedPreviewID: String?
    let layoutHeight: CGFloat
    let topObstructionHeight: CGFloat
    let bottomObstructionHeight: CGFloat

    var body: some View {
        ZStack {
            AppTheme.Colors.screenBackgroundGradient

            if previews.isEmpty {
                VStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.largeTitle)
                        .foregroundStyle(AppTheme.Colors.tabUnselected)
                    Text(GoDiveFriendsPresentation.mediaHiddenLabel)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppTheme.Spacing.lg)
                }
            } else {
                TabView(selection: $selectedPreviewID) {
                    ForEach(previews, id: \.photoID) { preview in
                        AsyncImage(url: URL(string: preview.previewURL)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            default:
                                AppTheme.Colors.surfaceElevated
                                    .overlay { ProgressView() }
                            }
                        }
                        .tag(Optional(preview.photoID))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: previews.count > 1 ? .automatic : .never))
            }
        }
        .padding(.top, topObstructionHeight)
        .padding(.bottom, bottomObstructionHeight)
        .onAppear {
            if selectedPreviewID == nil {
                selectedPreviewID = previews.first?.photoID
            }
        }
    }
}
