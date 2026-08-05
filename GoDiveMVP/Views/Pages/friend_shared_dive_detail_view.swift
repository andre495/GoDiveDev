import SwiftUI

/// Read-only friend activity detail — same map / tank (or heart rate) / media shell as owned dives & snorkels.
struct FriendSharedDiveDetailView: View {
    let dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    let friendName: String
    var friendPhotoURL: String? = nil
    var friendUID: String? = nil

    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem
    @State private var mediaDive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    @State private var selectedDiveTab: DiveActivityTab = .map
    @State private var selectedSnorkelTab: SnorkelActivityTab = .map
    @State private var overviewSheetDetent = DiveActivityOverviewDetent.defaultSelection
    @State private var overviewPanelLiveHeightFraction = DiveActivityOverviewDetent.defaultSelection.heightFraction
    /// Unthrottled per-frame drag channel — read only by the tank hero (scoped invalidation).
    @State private var overviewLiveSheetState = DiveActivityOverviewLiveSheetState()
    @State private var isOverviewPanelPresented = true
    @State private var overviewPanelScrollOffsetY: CGFloat = 0
    @State private var selectedMediaPreviewID: String?
    @State private var isFriendSharedMediaFullscreenPresented = false
    @State private var snorkelSnapshot = FriendSharedActivityDetailPresentation.SnorkelDerivedSnapshot.empty
    @State private var friendDepthChartScrubCallout: DiveDepthProfileScrubCallout?
    @State private var friendTankChartSeries = GoDiveSharedDiveProjectionMapping.FriendSharedDepthChartSeries.empty
    @State private var tankHeroPressureFillFraction: CGFloat = 1
    @State private var tankMinimizedProfileRevealProgress: CGFloat = 1
    @State private var tankMinimizedPsiUsedRevealProgress: CGFloat = 1
    @State private var tankMinimizedWaterTopFadeProgress: CGFloat = 0
    @State private var tankMinimizedChromeRevealProgress: CGFloat = 1

    private var currentUID: String? {
        GoDiveFirestoreUserProfileMapping.loadCachedFirebaseUID()
    }

    private var showsTaggedYou: Bool {
        GoDiveSharedDiveProjectionMapping.wasCurrentUserTagged(
            dive: dive,
            currentFirebaseUID: currentUID
        )
    }

    init(
        dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive,
        friendName: String,
        friendPhotoURL: String? = nil,
        friendUID: String? = nil
    ) {
        self.dive = dive
        self.friendName = friendName
        self.friendPhotoURL = friendPhotoURL
        self.friendUID = friendUID
        _mediaDive = State(initialValue: dive)
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
        .fullScreenCover(isPresented: $isFriendSharedMediaFullscreenPresented) {
            FriendSharedMediaFullscreenView(
                items: friendSharedMediaDisplayItems,
                selectedMediaID: $selectedMediaPreviewID
            )
        }
        .onChange(of: overviewSheetDetent) { oldDetent, newDetent in
            guard oldDetent != newDetent else { return }
            handleOverviewSheetDetentChange(from: oldDetent, to: newDetent)
        }
        .onChange(of: dive.id) { _, _ in
            resetTankMinimizedEntranceAnimationState()
        }
        .task(id: friendTankChartRefreshToken) {
            snorkelSnapshot = FriendSharedActivityDetailPresentation.snorkelDerivedSnapshot(from: dive)
            let dive = dive
            friendTankChartSeries = await Task.detached {
                GoDiveSharedDiveProjectionMapping.decodedDepthChartSeries(from: dive)
            }.value
        }
        .task(id: friendSharedMediaRefreshToken) {
            await refreshFriendSharedMediaDiveIfNeeded()
            let items = friendSharedMediaDisplayItems
            await FriendSharedMediaPresentation.prefetchContentIfAllowed(
                urls: FriendSharedMediaPresentation.allPhotoContentPrefetchURLs(items: items)
                    + FriendSharedMediaPresentation.allVideoContentPrefetchURLs(items: items)
            )
        }
    }

    private var friendSharedMediaRefreshToken: String {
        "\(friendUID ?? "")-\(dive.id)"
    }

    @MainActor
    private func refreshFriendSharedMediaDiveIfNeeded() async {
        guard let friendUID else { return }
        guard let fresh = await GoDiveSharedDiveProjectionSync.fetchFriendSharedDive(
            friendUID: friendUID,
            diveDocumentID: dive.id
        ) else { return }
        mediaDive = fresh
    }

    private var friendTankChartRefreshToken: String {
        let trackLength = dive.profileTrackBase64?.count ?? 0
        return "\(dive.id)-\(trackLength)"
    }

    private var friendSharedMediaDisplayItems: [FriendSharedMediaPresentation.DisplayItem] {
        FriendSharedMediaPresentation.orderedDisplayItems(for: mediaDive)
    }

    private func openFriendSharedMediaFullscreen(mediaID: String? = nil) {
        if let mediaID {
            selectedMediaPreviewID = mediaID
        } else if selectedMediaPreviewID == nil {
            selectedMediaPreviewID = friendSharedMediaDisplayItems.first?.mediaID
        }
        isFriendSharedMediaFullscreenPresented = true
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
            let hidesOverviewPanelInLandscape = DiveActivityOverviewLandscapePresentation.hidesOverviewPanel(
                isLandscape: isLandscape
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
            let mediaUsesFullBleedHero = DiveActivityOverviewLandscapePresentation.mediaUsesFullBleedHero(
                isLandscape: isLandscape,
                detentUsesFullBleed: DiveActivityMediaPresentation.usesFullBleedMediaHero(
                    for: overviewSheetDetent
                )
            )
            let tankChartSizingBottomMargin = DiveActivityOverviewDetent.bottomObstructionHeight(
                layoutHeight: layoutHeight,
                detent: .large,
                bottomSafeInset: bottomSafeInset,
                screenWidth: overviewLayoutContext.screenWidth,
                topSafeInset: overviewLayoutContext.topSafeInset
            )
            let tankHeroBottomMargin = DiveTankOverviewHeroPresentation.tankHeroBottomContentMargin(
                layoutContext: overviewLayoutContext,
                detent: overviewSheetDetent,
                isLandscape: isLandscape,
                liveHeightFraction: selectedDiveTab == .tank
                    ? overviewPanelLiveHeightFraction
                    : nil
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
                        DiveTankOverviewHeroView(
                            layoutSize: geometry.size,
                            bottomContentMargin: tankHeroBottomMargin,
                            chartSizingBottomContentMargin: tankChartSizingBottomMargin,
                            topObstructionHeight: topObstruction,
                            layoutHeight: layoutHeight,
                            sheetDetent: overviewSheetDetent,
                            gasMixLabel: FriendSharedActivityDetailPresentation.tankHeroGasMixLabel(for: dive),
                            pressureRemainingFraction: tankHeroPressureFillFraction,
                            oxygenMixPercent: dive.oxygenMix,
                            depthSamples: friendTankChartSeries.depthSamples,
                            pressureSamples: friendTankChartSeries.pressureSamples,
                            maxDepthMeters: dive.maxDepthMeters ?? 0,
                            pressureBaselinePSI: friendTankChartSeries.pressureBaselinePSI
                                ?? dive.tankPressureEndPSI,
                            tankPressureStartPSI: dive.tankPressureStartPSI,
                            tankPressureEndPSI: dive.tankPressureEndPSI,
                            sacRateDisplay: FriendSharedActivityDetailPresentation.tankHeroSACRateLine(
                                for: dive,
                                displayUnits: diveDisplayUnitSystem
                            ),
                            rmvRateDisplay: FriendSharedActivityDetailPresentation.tankHeroRMVRateLine(
                                for: dive,
                                displayUnits: diveDisplayUnitSystem
                            ),
                            profileLineRevealProgress: tankMinimizedProfileRevealProgress,
                            psiUsedRevealProgress: tankMinimizedPsiUsedRevealProgress,
                            liveHeightFraction: overviewPanelLiveHeightFraction,
                            liveSheetState: overviewLiveSheetState,
                            sheetLayoutContext: overviewLayoutContext,
                            waterTopHalfFadeProgress: tankMinimizedWaterTopFadeProgress,
                            minimizedChromeRevealProgress: tankMinimizedChromeRevealProgress,
                            scrubCallout: $friendDepthChartScrubCallout
                        )
                        .ignoresSafeArea()
                        .accessibilityIdentifier("FriendSharedDiveDetail.Tank.Hero")
                    case .camera:
                        FriendSharedActivityMediaHeroView(
                            items: friendSharedMediaDisplayItems,
                            dive: mediaDive,
                            selectedMediaID: $selectedMediaPreviewID,
                            sheetDetent: overviewSheetDetent,
                            sheetHeightFraction: overviewPanelLiveHeightFraction,
                            layoutHeight: layoutHeight,
                            screenWidth: geometry.size.width,
                            topSafeAreaInset: geometry.safeAreaInsets.top,
                            topObstructionHeight: topObstruction,
                            bottomSafeInset: bottomSafeInset,
                            isLandscape: isLandscape,
                            isMediaTabSelected: selectedDiveTab == .camera,
                            bottomContentMargin: mediaUsesFullBleedHero ? 0 : bottomObstruction,
                            captureOverlayBottomInset: isLandscape
                                ? 0
                                : DiveActivityMediaPresentation.captureOverlayBottomInset(
                                    layoutHeight: layoutHeight,
                                    detent: overviewSheetDetent,
                                    bottomSafeInset: bottomSafeInset
                                ),
                            onOpenFullscreen: { openFriendSharedMediaFullscreen() }
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
                                    dive: mediaDive,
                                    friendName: friendName,
                                    friendPhotoURL: friendPhotoURL,
                                    showsTaggedYou: showsTaggedYou,
                                    overviewSheetDetent: $overviewSheetDetent
                                )
                            case .tank:
                                FriendSharedActivityTankPanelContent(
                                    dive: mediaDive,
                                    friendName: friendName,
                                    friendPhotoURL: friendPhotoURL,
                                    showsTaggedYou: showsTaggedYou,
                                    overviewSheetDetent: $overviewSheetDetent
                                )
                            case .camera:
                                FriendSharedActivityMediaPanelContent(
                                    dive: mediaDive,
                                    overviewSheetDetent: $overviewSheetDetent,
                                    layoutHeight: layoutHeight,
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
                        liveSheetState: overviewLiveSheetState,
                        panelScrollOffsetY: $overviewPanelScrollOffsetY,
                        panelScrollContentIdentity: selectedDiveTab,
                        onCommittedHorizontalTabSwipe: { translationWidth in
                            guard let next = DiveActivityOverviewTabPagerPresentation
                                .diveTabAfterHorizontalSwipe(
                                    from: selectedDiveTab,
                                    translationWidth: translationWidth
                                )
                            else { return }
                            selectDiveTab(next)
                        }
                    )
                    .overlay(alignment: .topTrailing) {
                        friendTankMinimizedRotatePhoneHintOverlay(isLandscape: isLandscape)
                    }
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
                                friendDepthChartScrubCalloutTopPadding(in: geometry)
                            )
                    }
                    .allowsHitTesting(false)
                }
            }
            .animation(nil, value: overviewSheetDetent)
            .animation(nil, value: isLandscape)
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func friendTankMinimizedRotatePhoneHintOverlay(isLandscape: Bool) -> some View {
        if selectedDiveTab == .tank,
           overviewSheetDetent == .minimized,
           !isLandscape,
           DiveTankOverviewHeroPresentation.showsRotatePhoneHint(
               for: .minimized,
               isLandscape: false,
               depthSampleCount: friendTankChartSeries.depthSamples.count
           ) {
            DiveTankRotatePhoneHintView()
                .padding(.top, DiveTankOverviewHeroPresentation.minimizedPortraitRotateHintTopInset)
                .padding(.trailing, AppTheme.Spacing.md)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private func friendDepthChartScrubCalloutTopPadding(in geometry: GeometryProxy) -> CGFloat {
        let layoutHeight = max(geometry.size.height, 1)
        let isLandscape = DiveActivityOverviewLandscapePresentation.isLandscapeLayout(
            layoutSize: geometry.size
        )
        if overviewSheetDetent == .minimized && !isLandscape {
            let overviewLayoutContext = DiveActivityOverviewSheetLayoutContext(
                layoutHeight: layoutHeight,
                screenWidth: geometry.size.width,
                topSafeInset: geometry.safeAreaInsets.top,
                bottomSafeInset: geometry.safeAreaInsets.bottom
            )
            let topObstruction = DiveActivityOverviewPanelMetrics.mapTopObstructionHeight(
                topSafeInset: geometry.safeAreaInsets.top,
                chromeRowHeight: DiveActivityTabIcon.menuRowHeight,
                chromeTopPadding: AppTheme.Spacing.sm
            )
            let bottomMargin = DiveTankOverviewHeroPresentation.tankHeroBottomContentMargin(
                layoutContext: overviewLayoutContext,
                detent: .minimized,
                isLandscape: false,
                liveHeightFraction: overviewPanelLiveHeightFraction
            )
            let largeMargin = DiveActivityOverviewDetent.bottomObstructionHeight(
                layoutHeight: layoutHeight,
                detent: .large,
                bottomSafeInset: geometry.safeAreaInsets.bottom,
                screenWidth: geometry.size.width,
                topSafeInset: geometry.safeAreaInsets.top
            )
            let chartFrame = DiveTankOverviewHeroPresentation.minimizedProfileChartFrame(
                layoutSize: geometry.size,
                layoutHeight: layoutHeight,
                topObstructionHeight: topObstruction,
                bottomContentMargin: bottomMargin,
                isLandscape: false,
                detent: .minimized,
                chartSizingBottomContentMargin: largeMargin
            )
            return DiveDepthProfileScrubCalloutPresentation.labelTopPaddingPinnedAtMinimizedPortraitChartFade(
                chartFrame: chartFrame
            )
        }
        return DiveDepthProfileScrubCalloutPresentation.labelTopPadding(
            topSafeInset: geometry.safeAreaInsets.top,
            chromeTopPadding: AppTheme.Spacing.sm
        )
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
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            FriendSharedActivityIdentityHeader(
                dive: dive,
                friendName: friendName,
                friendPhotoURL: friendPhotoURL
            )

            HStack(spacing: AppTheme.Spacing.sm) {
                friendSharedTankCollapsedChip(
                    label: "Start",
                    value: FriendSharedActivityDetailPresentation.formattedPressure(
                        psi: dive.tankPressureStartPSI,
                        unitSystem: diveDisplayUnitSystem
                    )
                )
                friendSharedTankCollapsedChip(
                    label: "End",
                    value: FriendSharedActivityDetailPresentation.formattedPressure(
                        psi: dive.tankPressureEndPSI,
                        unitSystem: diveDisplayUnitSystem
                    )
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func friendSharedTankCollapsedChip(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppTheme.Colors.tabUnselected)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func selectDiveTab(_ tab: DiveActivityTab) {
        guard tab != selectedDiveTab else {
            syncOverviewSheetPresentation(forDiveTab: tab)
            return
        }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if tab != .tank {
                friendDepthChartScrubCallout = nil
            }
            if let detent = DiveActivityOverviewTabSelection.friendSharedOverviewDetent(whenSelecting: tab) {
                overviewSheetDetent = detent
                isOverviewPanelPresented = true
                if tab == .tank {
                    resetTankMinimizedEntranceAnimationState()
                }
            } else {
                isOverviewPanelPresented = false
            }
            selectedDiveTab = tab
            if tab == .camera, selectedMediaPreviewID == nil {
                selectedMediaPreviewID = friendSharedMediaDisplayItems.first?.mediaID
            }
        }
    }

    private func syncOverviewSheetPresentation(forDiveTab tab: DiveActivityTab) {
        if !isOverviewPanelPresented {
            isOverviewPanelPresented = true
        }
        if let detent = DiveActivityOverviewTabSelection.friendSharedOverviewDetent(whenSelecting: tab) {
            overviewSheetDetent = detent
        }
        if tab == .tank {
            resetTankMinimizedEntranceAnimationState()
        }
    }

    private func handleOverviewSheetDetentChange(
        from oldDetent: DiveActivityOverviewDetent,
        to newDetent: DiveActivityOverviewDetent
    ) {
        // Consume the grabber release position (nil for tap/programmatic detent changes).
        let dragReleaseFraction = overviewLiveSheetState.dragReleaseHeightFraction
        overviewLiveSheetState.dragReleaseHeightFraction = nil
        guard dive.resolvedActivityKind == .scubaDive, selectedDiveTab == .tank else { return }
        if DiveTankOverviewHeroPresentation.shouldPlayMinimizedEntranceAnimation(
            from: oldDetent,
            to: newDetent
        ) {
            if let dragReleaseFraction,
               DiveTankOverviewHeroPresentation.shouldSkipMinimizedEntranceAfterDrag(
                   liveHeightFraction: dragReleaseFraction,
                   layoutContext: .presentationReference
               ) {
                finishTankMinimizedStateAfterDrag()
            } else {
                playTankMinimizedEntranceAnimation()
            }
        } else if newDetent.heightFraction > oldDetent.heightFraction + 0.007 {
            resetTankMinimizedEntranceAnimationState()
        }
    }

    private func resetTankMinimizedEntranceAnimationState() {
        tankHeroPressureFillFraction = 1
        tankMinimizedProfileRevealProgress = 1
        tankMinimizedPsiUsedRevealProgress = 1
        tankMinimizedWaterTopFadeProgress = 0
        tankMinimizedChromeRevealProgress = 1
    }

    private func finishTankMinimizedStateAfterDrag() {
        let targetFill = DiveActivityTankPanelSummary.remainingPressureFillFraction(
            startPSI: dive.tankPressureStartPSI,
            endPSI: dive.tankPressureEndPSI
        )
        let fraction = CGFloat(targetFill ?? 1)

        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) {
            tankMinimizedProfileRevealProgress = 1
            tankMinimizedPsiUsedRevealProgress = 1
            tankMinimizedWaterTopFadeProgress = 1
            tankMinimizedChromeRevealProgress = 1
            tankHeroPressureFillFraction = fraction
        }
    }

    private func playTankMinimizedEntranceAnimation() {
        let targetFill = DiveActivityTankPanelSummary.remainingPressureFillFraction(
            startPSI: dive.tankPressureStartPSI,
            endPSI: dive.tankPressureEndPSI
        )
        let fraction = CGFloat(targetFill ?? 1)

        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) {
            tankMinimizedProfileRevealProgress = 0
            tankMinimizedPsiUsedRevealProgress = 0
            tankMinimizedWaterTopFadeProgress = 0
            tankMinimizedChromeRevealProgress = 0
            tankHeroPressureFillFraction = 1
        }

        withAnimation(DiveTankOverviewHeroPresentation.minimizedWaterTopFadeAnimation) {
            tankMinimizedWaterTopFadeProgress = 1
            tankMinimizedChromeRevealProgress = 1
        }

        withAnimation(DiveTankOverviewHeroPresentation.minimizedEntranceLineAnimation) {
            tankMinimizedProfileRevealProgress = 1
            tankMinimizedPsiUsedRevealProgress = 1
            if fraction < 0.999 {
                tankHeroPressureFillFraction = fraction
            }
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
            let hidesOverviewPanelInLandscape = DiveActivityOverviewLandscapePresentation.hidesOverviewPanel(
                isLandscape: isLandscape
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
            let mediaUsesFullBleedHero = DiveActivityOverviewLandscapePresentation.mediaUsesFullBleedHero(
                isLandscape: isLandscape,
                detentUsesFullBleed: DiveActivityMediaPresentation.usesFullBleedMediaHero(
                    for: overviewSheetDetent
                )
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
                            layoutSize: geometry.size,
                            layoutHeight: layoutHeight,
                            bottomContentMargin: heartRateBottomMargin,
                            topObstructionHeight: topObstruction,
                            sheetDetent: overviewSheetDetent
                        )
                    case .camera:
                        FriendSharedActivityMediaHeroView(
                            items: friendSharedMediaDisplayItems,
                            dive: mediaDive,
                            selectedMediaID: $selectedMediaPreviewID,
                            sheetDetent: overviewSheetDetent,
                            sheetHeightFraction: overviewPanelLiveHeightFraction,
                            layoutHeight: layoutHeight,
                            screenWidth: geometry.size.width,
                            topSafeAreaInset: geometry.safeAreaInsets.top,
                            topObstructionHeight: topObstruction,
                            bottomSafeInset: bottomSafeInset,
                            isLandscape: isLandscape,
                            isMediaTabSelected: selectedSnorkelTab == .camera,
                            bottomContentMargin: mediaUsesFullBleedHero ? 0 : bottomObstruction,
                            captureOverlayBottomInset: isLandscape
                                ? 0
                                : DiveActivityMediaPresentation.captureOverlayBottomInset(
                                    layoutHeight: layoutHeight,
                                    detent: overviewSheetDetent,
                                    bottomSafeInset: bottomSafeInset
                                ),
                            onOpenFullscreen: { openFriendSharedMediaFullscreen() }
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

                if isOverviewPanelPresented, !hidesOverviewPanelInLandscape {
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
                                    dive: mediaDive,
                                    friendName: friendName,
                                    friendPhotoURL: friendPhotoURL,
                                    showsTaggedYou: showsTaggedYou,
                                    overviewSheetDetent: $overviewSheetDetent
                                )
                            case .heartRate:
                                FriendSharedActivityHeartRatePanelContent(
                                    dive: mediaDive,
                                    friendName: friendName,
                                    showsTaggedYou: showsTaggedYou,
                                    snorkelSnapshot: snorkelSnapshot,
                                    overviewSheetDetent: $overviewSheetDetent
                                )
                            case .camera:
                                FriendSharedActivityMediaPanelContent(
                                    dive: mediaDive,
                                    overviewSheetDetent: $overviewSheetDetent,
                                    layoutHeight: layoutHeight,
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
                        panelScrollContentIdentity: selectedSnorkelTab,
                        onCommittedHorizontalTabSwipe: { translationWidth in
                            guard let next = DiveActivityOverviewTabPagerPresentation
                                .snorkelTabAfterHorizontalSwipe(
                                    from: selectedSnorkelTab,
                                    translationWidth: translationWidth
                                )
                            else { return }
                            selectSnorkelTab(next)
                        }
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
            .animation(nil, value: overviewSheetDetent)
            .animation(nil, value: isLandscape)
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
            if let detent = DiveActivityOverviewTabSelection.friendSharedOverviewDetent(whenSelectingSnorkel: tab) {
                overviewSheetDetent = detent
                isOverviewPanelPresented = true
            } else {
                isOverviewPanelPresented = false
            }
            selectedSnorkelTab = tab
            if tab == .camera, selectedMediaPreviewID == nil {
                selectedMediaPreviewID = friendSharedMediaDisplayItems.first?.mediaID
            }
        }
    }

    private func syncOverviewSheetPresentation(forSnorkelTab tab: SnorkelActivityTab) {
        if !isOverviewPanelPresented {
            isOverviewPanelPresented = true
        }
        if let detent = DiveActivityOverviewTabSelection.friendSharedOverviewDetent(whenSelectingSnorkel: tab) {
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
    private struct MediaSelectionSignature: Equatable {
        var count: Int
        var firstID: String?
        var lastID: String?
    }

    let items: [FriendSharedMediaPresentation.DisplayItem]
    let dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    @Binding var selectedMediaID: String?
    var sheetDetent: DiveActivityOverviewDetent = .large
    var sheetHeightFraction: CGFloat = DiveActivityOverviewPanelMetrics.referenceLargeHeightFraction
    var layoutHeight: CGFloat = 0
    var screenWidth: CGFloat = 0
    var topSafeAreaInset: CGFloat = 0
    var topObstructionHeight: CGFloat = 0
    var bottomSafeInset: CGFloat = 0
    var isLandscape: Bool = false
    var isMediaTabSelected: Bool = true
    var bottomContentMargin: CGFloat = 0
    var captureOverlayBottomInset: CGFloat = 0
    var onOpenFullscreen: (() -> Void)? = nil

    @State private var isPlaybackPausedByUser = false
    @State private var showsPlaybackChrome = true

    private var showsBackgroundMedia: Bool {
        DiveActivityMediaPresentation.showsBackgroundPhotos(for: sheetDetent)
    }

    private var shouldPlayBackgroundVideo: Bool {
        DiveActivityMediaPresentation.shouldPlayBackgroundVideo(
            isMediaTabSelected: isMediaTabSelected,
            detent: sheetDetent
        )
    }

    private var mediaHeroFullBleedProgress: CGFloat {
        DiveActivityMediaHeroPresentation.resolvedFitFillProgress(
            sheetHeightFraction: sheetHeightFraction,
            layoutHeight: layoutHeight,
            screenWidth: screenWidth,
            isLandscape: isLandscape,
            topSafeInset: topSafeAreaInset,
            bottomSafeInset: bottomSafeInset
        )
    }

    private func mediaHeroBandRect(viewportSize: CGSize) -> CGRect {
        DiveActivityMediaHeroPresentation.heroBandRect(
            viewportSize: viewportSize,
            layoutHeight: layoutHeight,
            sheetHeightFraction: sheetHeightFraction,
            bottomSafeInset: bottomSafeInset,
            topObstructionHeight: topObstructionHeight
        )
    }

    private var showsLandscapeGridStyleChrome: Bool {
        DiveActivityMediaPresentation.showsLandscapeGridStyleMediaChrome(
            isLandscape: isLandscape,
            hasMedia: !items.isEmpty
        )
    }

    private var selectedItem: FriendSharedMediaPresentation.DisplayItem? {
        guard let selectedMediaID else { return items.first }
        return items.first(where: { $0.mediaID == selectedMediaID }) ?? items.first
    }

    private var isSelectedMediaFeatured: Bool {
        guard let selectedMediaID,
              let featuredID = FriendSharedMediaPresentation.resolvedFeaturedMediaID(for: dive)
        else { return false }
        return selectedMediaID == featuredID
    }

    var body: some View {
        ZStack {
            AppTheme.Colors.screenBackgroundGradient
                .ignoresSafeArea()

            if showsBackgroundMedia {
                if items.isEmpty {
                    emptyState
                } else {
                    landscapeMediaPager
                }
            }

            if showsLandscapeGridStyleChrome, isMediaTabSelected {
                landscapeGridStyleChromeOverlay
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("FriendSharedDiveDetail.MediaBackground")
        .onAppear { syncSelectionToMedia() }
        .onChange(of: mediaIDsSignature) { _, _ in
            syncSelectionToMedia()
        }
        .onChange(of: selectedMediaID) { _, _ in
            isPlaybackPausedByUser = false
            showsPlaybackChrome = true
        }
    }

    private var mediaIDsSignature: MediaSelectionSignature {
        MediaSelectionSignature(
            count: items.count,
            firstID: items.first?.mediaID,
            lastID: items.last?.mediaID
        )
    }

    private var landscapeMediaPager: some View {
        Group {
            if showsLandscapeGridStyleChrome {
                mediaPager
                    .simultaneousGesture(
                        TapGesture().onEnded { _ in
                            toggleLandscapePlaybackChrome()
                        }
                    )
            } else {
                mediaPager
            }
        }
    }

    private var mediaPager: some View {
        GeometryReader { geometry in
            let viewportSize = geometry.size
            let heroBand = mediaHeroBandRect(viewportSize: viewportSize)
            let heroProgress = mediaHeroFullBleedProgress
            let showsGridChrome = showsLandscapeGridStyleChrome

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(items) { item in
                        FriendSharedActivityMediaHeroPageView(
                            item: item,
                            isVideoPlaybackActive: shouldPlayBackgroundVideo && selectedMediaID == item.mediaID,
                            isPausedByUserHoldFromParent: showsGridChrome
                                && isPlaybackPausedByUser
                                && selectedMediaID == item.mediaID,
                            showsCaptureDateOverlay: DiveActivityMediaPresentation.showsCaptureDateOnHero(
                                for: sheetDetent
                            ) && !showsGridChrome,
                            usesLiquidGlassCaptureOverlay:
                                DiveActivityMediaPresentation.usesLiquidGlassCaptureOverlayOnHero(
                                    for: sheetDetent
                                ) && !showsGridChrome,
                            captureOverlayBottomInset: captureOverlayBottomInset,
                            captureDateLine: FriendSharedActivityDetailPresentation.dateDashTimeLine(for: dive),
                            enablesHoldToPauseGesture: !showsGridChrome,
                            heroFitFillProgress: heroProgress,
                            heroBandRect: heroBand
                        )
                        .containerRelativeFrame(.horizontal, count: 1, span: 1, spacing: 0)
                        .frame(height: viewportSize.height)
                        .background(Color.black)
                        .id(item.mediaID)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $selectedMediaID)
            .frame(width: viewportSize.width, height: viewportSize.height)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture {
                guard !showsLandscapeGridStyleChrome else { return }
                onOpenFullscreen?()
            }
            .task(id: prefetchToken) {
                await prefetchFriendSharedMedia()
            }
            .onChange(of: selectedMediaID) { _, newValue in
                Task {
                    await prefetchContent(around: newValue)
                }
            }
        }
        .animation(.interactiveSpring(response: 0.38, dampingFraction: 0.86), value: sheetHeightFraction)
        .ignoresSafeArea()
        .padding(.bottom, bottomContentMargin)
        .accessibilityIdentifier("FriendSharedDiveDetail.MediaBackground.Pager")
    }

    private var landscapeGridStyleChromeOverlay: some View {
        GeometryReader { geometry in
            let chromeOpacity = LinkedMediaFullscreenPresentation.playbackChromeOpacity(
                dismissProgress: 0,
                showsPlaybackChrome: showsPlaybackChrome
            )
            let isSelectedVideo = selectedItem?.kind == .video
            let showsCenterPlayback = LinkedMediaFullscreenPresentation.showsCenterPlaybackControl(
                isVideo: isSelectedVideo,
                showsPlaybackChrome: showsPlaybackChrome
            )
            let starTopInset = LinkedMediaFullscreenPresentation.topChromeRowOffset(
                safeAreaTop: geometry.safeAreaInsets.top,
                containerSize: geometry.size
            )

            ZStack {
                TripDetailMediaGalleryOverlayControls(
                    bottomLeadingChrome: .captureTimestamp(
                        primaryLine: FriendSharedActivityDetailPresentation.dateDashTimeLine(for: dive),
                        secondaryLine: nil
                    ),
                    isFeatured: isSelectedMediaFeatured,
                    showsMediaTagButtons: false,
                    onToggleFeatured: nil,
                    featuredStarPlacement: .topTrailing,
                    featuredStarTopInset: starTopInset,
                    featureToggleAccessibilityIdentifier: "FriendSharedDiveDetail.Media.Landscape.FeatureStar",
                    captureTimestampAccessibilityIdentifier: "FriendSharedDiveDetail.Media.Landscape.CaptureTimestamp"
                )
                .padding(.bottom, geometry.safeAreaInsets.bottom)
                .opacity(chromeOpacity)
                .allowsHitTesting(false)

                if showsCenterPlayback {
                    LinkedMediaFullscreenCenterPlaybackControl(
                        isPaused: isPlaybackPausedByUser,
                        action: toggleLandscapePlaybackPausedByUser
                    )
                    .opacity(chromeOpacity)
                    .allowsHitTesting(chromeOpacity > 0.2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.18), value: showsPlaybackChrome)
        }
        .ignoresSafeArea()
        .accessibilityIdentifier("FriendSharedDiveDetail.Media.Landscape.Chrome")
    }

    private var emptyState: some View {
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
        .padding(.top, topObstructionHeight)
        .padding(.bottom, bottomContentMargin)
        .accessibilityIdentifier("FriendSharedDiveDetail.MediaBackground.Empty")
    }

    private var prefetchToken: String {
        items.map(\.mediaID).joined(separator: "-")
    }

    private func syncSelectionToMedia() {
        guard !items.isEmpty else {
            selectedMediaID = nil
            return
        }
        if let selectedMediaID,
           items.contains(where: { $0.mediaID == selectedMediaID }) {
            return
        }
        selectedMediaID = items.first?.mediaID
    }

    private func toggleLandscapePlaybackChrome() {
        showsPlaybackChrome.toggle()
    }

    private func toggleLandscapePlaybackPausedByUser() {
        guard selectedItem?.kind == .video else { return }
        isPlaybackPausedByUser.toggle()
        if !showsPlaybackChrome {
            showsPlaybackChrome = true
        }
    }

    private func prefetchFriendSharedMedia() async {
        let thumbURLs = FriendSharedMediaPresentation.detailThumbnailPrefetchURLs(items: items)
        let allowsNetwork = AppNetworkConnectivitySnapshot.shared.allowsCloudMediaFetch
        await GoDiveSharedMediaCache.shared.prefetch(
            remoteURLStrings: thumbURLs,
            tier: .thumb,
            allowsNetworkFetch: allowsNetwork
        )
        await FriendSharedMediaPresentation.prefetchContentIfAllowed(
            urls: FriendSharedMediaPresentation.allPhotoContentPrefetchURLs(items: items)
                + FriendSharedMediaPresentation.allVideoContentPrefetchURLs(items: items)
        )
        await prefetchContent(around: selectedMediaID)
    }

    private func prefetchContent(around selectedID: String?) async {
        let contentURLs = FriendSharedMediaPresentation.detailContentPrefetchURLs(
            items: items,
            selectedMediaID: selectedID
        )
        let photoURLs = contentURLs.filter { raw in
            guard let item = items.first(where: { $0.contentURL == raw }) else { return true }
            return item.kind != .video
        }
        await FriendSharedMediaPresentation.prefetchContentIfAllowed(urls: photoURLs)
    }
}

private struct FriendSharedActivityMediaHeroPageView: View {
    let item: FriendSharedMediaPresentation.DisplayItem
    var isVideoPlaybackActive: Bool
    var isPausedByUserHoldFromParent: Bool
    var showsCaptureDateOverlay: Bool
    var usesLiquidGlassCaptureOverlay: Bool
    var captureOverlayBottomInset: CGFloat
    var captureDateLine: String
    var enablesHoldToPauseGesture: Bool
    /// **0** = aspect-fill in **`heroBandRect`** (top + sides to sheet seam); **1** = full viewport fill.
    var heroFitFillProgress: CGFloat = 1
    var heroBandRect: CGRect = .zero

    @State private var isPausedByUserHold = false
    @State private var resolvedMediaAspect: CGFloat = 16.0 / 9.0

    var body: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { geometry in
                heroClippedMediaContainer(
                    viewport: geometry.size,
                    mediaAspect: resolvedMediaAspect
                ) {
                    Group {
                        if item.kind == .video {
                            FriendSharedRemoteVideoPlayerView(
                                item: item,
                                isPlaybackActive: isVideoPlaybackActive
                                    && !isPausedByUserHold
                                    && !isPausedByUserHoldFromParent,
                                onDisplayedImageAspectChange: { aspect in
                                    resolvedMediaAspect = aspect
                                }
                            )
                        } else {
                            FriendSharedMediaImageView(
                                item: item,
                                fidelity: .progressive,
                                onDisplayedImageAspectChange: { aspect in
                                    resolvedMediaAspect = aspect
                                }
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                }
            }

            if showsCaptureDateOverlay {
                captureDateOverlay
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, captureOverlayBottomInset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .gesture(holdToPauseGesture, including: enablesHoldToPauseGesture ? .gesture : .subviews)
    }

    private func heroClippedMediaContainer<Content: View>(
        viewport: CGSize,
        mediaAspect: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        // Single layout path — avoid a structural branch at full bleed so remote
        // `AVPlayer` representables are not dismantled mid-detent drag.
        let usesFullViewportBand = heroBandRect.height <= 0
        let size: CGSize = usesFullViewportBand
            ? viewport
            : DiveActivityMediaHeroPresentation.interpolatedMediaSize(
                mediaAspect: mediaAspect,
                band: heroBandRect,
                viewport: viewport,
                progress: heroFitFillProgress
            )
        let centerY: CGFloat = usesFullViewportBand
            ? viewport.height / 2
            : DiveActivityMediaHeroPresentation.interpolatedMediaCenterY(
                band: heroBandRect,
                viewportHeight: viewport.height,
                mediaAspect: mediaAspect,
                progress: heroFitFillProgress
            )
        return content()
            .frame(width: size.width, height: size.height)
            .position(x: viewport.width / 2, y: centerY)
            .frame(width: viewport.width, height: viewport.height)
            .clipped()
    }

    private var captureDateOverlay: some View {
        Group {
            if usesLiquidGlassCaptureOverlay {
                MediaCaptureTimestampChromeLabel(
                    primaryLine: captureDateLine,
                    secondaryLine: nil,
                    accessibilityIdentifier: "FriendSharedDiveDetail.Media.CaptureTimestamp"
                )
            } else {
                Text(captureDateLine)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.55), in: Capsule())
            }
        }
        .padding(AppTheme.Spacing.md)
        .accessibilityLabel("Activity date \(captureDateLine)")
    }

    private var holdToPauseGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.2)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                guard item.kind == .video else { return }
                if case .second(true, _) = value {
                    isPausedByUserHold = true
                }
            }
            .onEnded { _ in
                isPausedByUserHold = false
            }
    }
}
