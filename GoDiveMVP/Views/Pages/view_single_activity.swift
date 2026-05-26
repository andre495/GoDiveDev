import PhotosUI
import SwiftUI
import SwiftData

struct ViewSingleActivity: View {
    @Bindable var activity: DiveActivity
    @Environment(\.modelContext) private var modelContext
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem
    @Environment(AccountSession.self) private var accountSession
    @Query private var diveSites: [DiveSite]

    private enum DetailNotes {
        static let maxCharacterCount = 2500
    }

    @State private var selectedActivityTab: DiveActivityTab = .map
    @State private var overviewSheetDetent = DiveActivityOverviewDetent.defaultSelection
    @State private var isOverviewPanelPresented = true
    /// Tank hero gas column (**1** = full); animates toward **`ending/beginning`** PSI when the sheet snaps to a shorter detent.
    @State private var tankHeroPressureFillFraction: CGFloat = 1
    @FocusState private var isNotesFieldFocused: Bool
    /// While the depth chart is scrubbed, holds the nearest profile sample (elapsed from dive start + depth).
    @State private var depthProfileScrubSample: DiveDepthProfileSample?
    @State private var depthChartPreviewMediaID: UUID?
    /// When **`true`**, map tab uses **`DiveOverviewMapTeardownPlaceholder`** instead of live MapKit (set before pop).
    @State private var overviewMapTeardownRequested = false
    @State private var showsMapSitePromptDialog = false
    @State private var showsAddDiveSiteSheet = false
    @State private var mapSitePromptUserDeclined = false
    @State private var editingField: DiveActivityEditableFieldID?
    @State private var showsBuddiesEditSheet = false
    @State private var showsAddEquipmentSheet = false
    @State private var equipmentLinkErrorMessage: String?
    @State private var diveMediaPickerItems: [PhotosPickerItem] = []
    @State private var selectedDiveMediaPhotoID: UUID?
    @State private var mediaImportOverlay: DiveMediaImportOverlayState = .hidden

    /// **More** tab: profile samples sorted by time (read-only).
    private var moreTabSortedProfilePoints: [DiveProfilePoint] {
        activity.profilePoints.sorted { $0.timestamp < $1.timestamp }
    }

    /// **More** tab: samples with non-**`nil`** **`tankPressurePSI`** (e.g. UDDF waypoint **`tankpressure`**).
    private var moreTabProfilePointsWithTankPressure: [DiveProfilePoint] {
        moreTabSortedProfilePoints.filter { $0.tankPressurePSI != nil }
    }

    private var showsLiveOverviewMap: Bool {
        DiveActivityOverviewMapTeardown.showsLiveMap(teardownRequested: overviewMapTeardownRequested)
    }

    /// Pan/zoom on the map tab only when the overview sheet is at the low (**minimized**) detent.
    private var isOverviewMapInteractive: Bool {
        selectedActivityTab == .map && overviewSheetDetent.allowsMapInteraction
    }

    private var showsMapSitePromptInfoButton: Bool {
        selectedActivityTab == .map
            && DiveActivityMapSitePrompt.showsInfoButton(
                for: activity,
                userDeclined: mapSitePromptUserDeclined
            )
    }

    var body: some View {
        AppHeaderlessPage(leadingEdgePopOnWillDismiss: requestOverviewMapTeardown) {
            diveOverviewHeroLayer
                .overlay(alignment: .top) {
                    activityTopChrome
                        .zIndex(1_000)
                }
                .overlay {
                    if mediaImportOverlay != .hidden {
                        DiveMediaImportProgressOverlay(state: mediaImportOverlay) {
                            mediaImportOverlay = .hidden
                        }
                        .zIndex(2_000)
                    }
                }
        }
        .hidesBottomTabBarWhenPushed()
        .task(id: activity.id) {
            let previousOffset = activity.timeZoneOffsetSeconds
            await DiveActivityTimeZoneResolution.resolveMissingOffset(for: activity)
            if activity.timeZoneOffsetSeconds != previousOffset {
                try? modelContext.save()
            }
        }
        .onAppear {
            overviewMapTeardownRequested = false
            reloadMapSitePromptDeclinedState()
            syncOverviewSheetPresentation(for: selectedActivityTab)
            presentMapSitePromptIfNeeded()
        }
        .onChange(of: selectedActivityTab) { _, newTab in
            syncOverviewSheetPresentation(for: newTab)
            if newTab != .tank {
                depthProfileScrubSample = nil
            }
            if newTab == .map {
                overviewMapTeardownRequested = false
                presentMapSitePromptIfNeeded()
            }
        }
        .onChange(of: activity.diveSite?.id) { _, _ in
            if activity.diveSite != nil {
                showsMapSitePromptDialog = false
            }
        }
        .onChange(of: activity.id) { _, _ in
            tankHeroPressureFillFraction = 1
            overviewMapTeardownRequested = false
            selectedDiveMediaPhotoID = nil
            reloadMapSitePromptDeclinedState()
            presentMapSitePromptIfNeeded()
        }
        .onChange(of: overviewSheetDetent) { oldDetent, newDetent in
            guard oldDetent != newDetent else { return }
            handleOverviewSheetDetentChange(from: oldDetent, to: newDetent)
        }
        .alert(
            DiveActivityMapSitePrompt.dialogTitle,
            isPresented: $showsMapSitePromptDialog
        ) {
            Button("Add new site") {
                showsAddDiveSiteSheet = true
            }
            Button("No", role: .cancel) {
                declineMapSitePrompt()
            }
        } message: {
            Text(DiveActivityMapSitePrompt.dialogMessage)
        }
        .sheet(isPresented: $showsAddDiveSiteSheet) {
            DiveSiteAddSheet(
                activity: activity,
                initialDraft: DiveActivityMapSitePrompt.draft(from: activity, catalogSite: activity.diveSite),
                onSaved: {
                    mapSitePromptUserDeclined = false
                }
            )
        }
        .sheet(item: $editingField) { field in
            DiveActivityFieldEditSheet(
                activity: activity,
                field: field,
                displayUnits: diveDisplayUnitSystem
            )
        }
        .sheet(isPresented: $showsBuddiesEditSheet) {
            DiveActivityBuddiesEditSheet(activity: activity)
        }
        .sheet(isPresented: $showsAddEquipmentSheet) {
            DiveActivityAddEquipmentSheet(
                items: addableEquipmentForSheet,
                onAdd: { linkEquipmentToDive($0) }
            )
        }
        .sheet(isPresented: depthChartMediaPreviewPresented) {
            if let media = depthChartPreviewMedia {
                DiveDepthProfileMediaPreviewSheet(
                    media: media,
                    timeZoneOffsetSeconds: activity.timeZoneOffsetSeconds,
                    captureContext: depthChartPreviewCaptureContext
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(AppTheme.Sheet.cornerRadius)
                .presentationBackground {
                    Color.black.ignoresSafeArea()
                }
            }
        }
        .alert("Could not add equipment", isPresented: equipmentLinkErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(equipmentLinkErrorMessage ?? "Try again.")
        }
        .onChange(of: diveMediaPickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await importDiveMediaPickerItems(items) }
        }
    }

    private var activityTopChrome: some View {
        HStack(alignment: .center, spacing: 0) {
            SecondaryDestinationBackButton(
                minTapDimension: DiveActivityTabIcon.menuRowHeight,
                onWillDismiss: requestOverviewMapTeardown
            )
            .frame(width: DiveActivityTabIcon.menuRowHeight, height: DiveActivityTabIcon.menuRowHeight)

            activityIconTabBar
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.top, AppTheme.Spacing.sm)
        .allowsHitTesting(true)
    }

    private var activityIconTabBar: some View {
        HStack(spacing: 0) {
            ForEach(DiveActivityTab.allCases, id: \.self) { tab in
                Button {
                    selectActivityTab(tab)
                } label: {
                    tab.tabIconImage(isSelected: selectedActivityTab == tab)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: DiveActivityTabIcon.menuRowHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.accessibilityLabel)
                .accessibilityAddTraits(selectedActivityTab == tab ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("DiveActivity.IconTabs")
    }

    private var diveOverviewHeroLayer: some View {
        GeometryReader { geometry in
            let layoutHeight = max(geometry.size.height, 1)
            let bottomSafeInset = geometry.safeAreaInsets.bottom
            let mapCameraDetent = overviewSheetDetent.mapCameraDetent
            let bottomObstruction = DiveActivityOverviewDetent.bottomObstructionHeight(
                layoutHeight: layoutHeight,
                detent: overviewSheetDetent,
                bottomSafeInset: bottomSafeInset
            )
            let mapBottomObstruction = DiveActivityOverviewDetent.bottomObstructionHeight(
                layoutHeight: layoutHeight,
                detent: mapCameraDetent,
                bottomSafeInset: bottomSafeInset
            )
            let topObstruction = DiveActivityOverviewPanelMetrics.mapTopObstructionHeight(
                topSafeInset: geometry.safeAreaInsets.top,
                chromeRowHeight: DiveActivityTabIcon.menuRowHeight,
                chromeTopPadding: AppTheme.Spacing.sm
            )
            let isLandscape = DiveTankOverviewHeroPresentation.isLandscapeLayout(layoutSize: geometry.size)
            let hidesOverviewPanelForTankLandscape =
                selectedActivityTab == .tank
                && DiveTankOverviewHeroPresentation.hidesOverviewPanelInLandscapeTankMinimized(
                    detent: overviewSheetDetent,
                    isLandscape: isLandscape
                )
            let tankHeroBottomMargin = DiveTankOverviewHeroPresentation.tankHeroBottomContentMargin(
                layoutHeight: layoutHeight,
                detent: overviewSheetDetent,
                bottomSafeInset: bottomSafeInset,
                isLandscape: isLandscape
            )

            ZStack(alignment: .bottom) {
                Group {
                    switch selectedActivityTab {
                    case .map:
                        Group {
                            if showsLiveOverviewMap {
                                DiveLocationMapView(
                                    coordinate: overviewMapCoordinate,
                                    bottomContentMargin: mapBottomObstruction,
                                    topObstructionHeight: topObstruction,
                                    layoutHeight: layoutHeight,
                                    cameraLayoutDetent: mapCameraDetent,
                                    isUserInteractionEnabled: isOverviewMapInteractive
                                )
                                .allowsHitTesting(isOverviewMapInteractive)
                                .id(overviewMapViewIdentity)
                            } else {
                                DiveOverviewMapTeardownPlaceholder()
                            }
                        }
                        .overlay(alignment: .topTrailing) {
                            if showsMapSitePromptInfoButton {
                                DiveMapSitePromptInfoButton {
                                    showsMapSitePromptDialog = true
                                }
                                .padding(
                                    .top,
                                    DiveActivityOverviewPanelMetrics.mapSitePromptInfoButtonTopPadding(
                                        topSafeInset: geometry.safeAreaInsets.top,
                                        chromeRowHeight: DiveActivityTabIcon.menuRowHeight,
                                        chromeTopPadding: AppTheme.Spacing.sm
                                    )
                                )
                                .padding(.trailing, AppTheme.Spacing.md)
                            }
                        }
                        .ignoresSafeArea()
                    case .tank:
                        DiveTankOverviewHeroView(
                            bottomContentMargin: tankHeroBottomMargin,
                            topObstructionHeight: topObstruction,
                            layoutHeight: layoutHeight,
                            sheetDetent: overviewSheetDetent,
                            gasMixLabel: activity.tankHeroGasMixLabel,
                            pressureRemainingFraction: tankHeroPressureFillFraction,
                            oxygenMixPercent: activity.oxygenMix,
                            depthSamples: DiveDepthProfileSeries.samples(fromProfilePoints: moreTabSortedProfilePoints),
                            pressureSamples: DiveDepthProfileSeries.pressureSamples(fromProfilePoints: moreTabSortedProfilePoints),
                            mediaMarkers: depthProfileMediaMarkers,
                            mediaPhotosByID: depthProfileMediaPhotosByID,
                            onMediaMarkerTap: { depthChartPreviewMediaID = $0.mediaID },
                            maxDepthMeters: activity.maxDepthMeters,
                            pressureBaselinePSI: activity.tankPressureEndPSI
                                ?? DiveDepthProfileSeries.pressureSamples(fromProfilePoints: moreTabSortedProfilePoints).last?.pressurePSI,
                            tankPressureStartPSI: activity.tankPressureStartPSI,
                            tankPressureEndPSI: activity.tankPressureEndPSI,
                            sacRateDisplay: activity.tankHeroSACRateLine(displayUnits: diveDisplayUnitSystem),
                            rmvRateDisplay: activity.tankHeroRMVRateLine(displayUnits: diveDisplayUnitSystem)
                        )
                    case .camera:
                        DiveActivityMediaBackgroundView(
                            mediaItems: activity.sortedMediaPhotos,
                            selectedMediaID: $selectedDiveMediaPhotoID,
                            timeZoneOffsetSeconds: activity.timeZoneOffsetSeconds,
                            mediaCaptureContextsByID: mediaCaptureContextsByID,
                            sheetDetent: overviewSheetDetent,
                            isMediaTabSelected: selectedActivityTab == .camera,
                            bottomContentMargin: bottomObstruction
                        )
                        .ignoresSafeArea()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if isOverviewPanelPresented, !hidesOverviewPanelForTankLandscape {
                    DiveActivityOverviewEmbeddedPanel(
                        selectedDetent: $overviewSheetDetent,
                        layoutHeight: layoutHeight,
                        bottomSafeInset: bottomSafeInset,
                        collapsedSummary: {
                            switch selectedActivityTab {
                            case .map:
                                overviewCollapsedSummary
                            case .tank:
                                tankCollapsedSummary
                            case .camera:
                                photosCollapsedSummary
                            }
                        },
                        panelContent: {
                            switch selectedActivityTab {
                            case .map:
                                overviewBottomPanelContent
                            case .tank:
                                tankPanelContent
                            case .camera:
                                photosPanelContent
                            }
                        },
                        collapsedSummaryExpandsOnTap: selectedActivityTab != .camera
                    )
                    .zIndex(1)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .overlay(alignment: .top) {
                DiveOverviewMapTopScrim(topObstructionHeight: topObstruction)
                    .ignoresSafeArea(edges: .top)
            }
            .animation(
                .easeInOut(duration: DiveTankOverviewHeroPresentation.heroDetentAnimationDuration),
                value: hidesOverviewPanelForTankLandscape
            )
        }
        .ignoresSafeArea()
    }

    private func reloadMapSitePromptDeclinedState() {
        mapSitePromptUserDeclined = DiveActivityMapSitePromptStorage.isDeclined(activityID: activity.id)
    }

    private func presentMapSitePromptIfNeeded() {
        guard selectedActivityTab == .map else { return }
        guard DiveActivityMapSitePrompt.shouldPresentAutomatically(
            for: activity,
            userDeclined: mapSitePromptUserDeclined
        ) else { return }
        showsMapSitePromptDialog = true
    }

    private func declineMapSitePrompt() {
        mapSitePromptUserDeclined = true
        DiveActivityMapSitePromptStorage.setDeclined(activityID: activity.id, declined: true)
        showsMapSitePromptDialog = false
    }

    private func requestOverviewMapTeardown() {
        guard showsLiveOverviewMap else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            overviewMapTeardownRequested = true
        }
    }

    private func selectActivityTab(_ tab: DiveActivityTab) {
        guard tab != selectedActivityTab else { return }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if let detent = DiveActivityOverviewTabSelection.overviewDetent(whenSelecting: tab) {
                overviewSheetDetent = detent
                isOverviewPanelPresented = true
                if tab == .tank {
                    tankHeroPressureFillFraction = 1
                }
            } else {
                isOverviewPanelPresented = false
            }
            selectedActivityTab = tab
        }
    }

    private func syncOverviewSheetPresentation(for tab: DiveActivityTab) {
        if !isOverviewPanelPresented {
            isOverviewPanelPresented = true
        }
        if let detent = DiveActivityOverviewTabSelection.overviewDetent(whenSelecting: tab) {
            overviewSheetDetent = detent
        }
        if tab == .tank {
            tankHeroPressureFillFraction = 1
        }
    }

    private func handleOverviewSheetDetentChange(
        from oldDetent: DiveActivityOverviewDetent,
        to newDetent: DiveActivityOverviewDetent
    ) {
        guard selectedActivityTab == .tank else { return }
        if newDetent == .minimized, newDetent.heightFraction < oldDetent.heightFraction {
            animateTankHeroPressureDrainIfNeeded()
        } else if newDetent.heightFraction > oldDetent.heightFraction + 0.007 {
            tankHeroPressureFillFraction = 1
        }
    }

    private func animateTankHeroPressureDrainIfNeeded() {
        guard let target = DiveActivityTankPanelSummary.remainingPressureFillFraction(
            startPSI: activity.tankPressureStartPSI,
            endPSI: activity.tankPressureEndPSI
        ) else { return }
        let fraction = CGFloat(target)
        guard fraction < 0.999 else { return }
        withAnimation(.easeInOut(duration: 0.55)) {
            tankHeroPressureFillFraction = fraction
        }
    }

    /// **Temporary:** full field dump for **`DiveActivity`** + **`DiveProfilePoint`** (remove when More is productized).
    private var moreTabDebugDumpContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Text("Temporary: all persisted fields")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
                    .frame(maxWidth: .infinity, alignment: .leading)

                detailsSectionHeader("DiveActivity")
                basicSectionCard {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        detailLabeledRow(label: "id", value: activity.id.uuidString)
                        detailLabeledRow(label: "source", value: activity.source.rawValue)
                        detailLabeledRow(label: "sourceDiveId", value: activity.sourceDiveId ?? "nil")
                        detailLabeledRow(label: "startTime", value: activity.startTime.formatted(.iso8601))
                        detailLabeledRow(label: "durationMinutes", value: "\(activity.durationMinutes)")
                        detailLabeledRow(label: "maxDepthMeters", value: String(format: "%.6f", activity.maxDepthMeters))
                        detailLabeledRow(
                            label: "averageDepthMeters",
                            value: activity.averageDepthMeters.map { String(format: "%.6f", $0) } ?? "nil"
                        )
                        detailLabeledRow(
                            label: "bottomTimeSeconds",
                            value: activity.bottomTimeSeconds.map(String.init) ?? "nil"
                        )
                        detailLabeledRow(
                            label: "surfaceIntervalSeconds",
                            value: activity.surfaceIntervalSeconds.map(String.init) ?? "nil"
                        )
                        detailLabeledRow(
                            label: "diveNumber",
                            value: activity.diveNumber.map(String.init) ?? "nil"
                        )
                        detailLabeledRow(
                            label: "diveNumberExplicitlyNone",
                            value: activity.diveNumberExplicitlyNone ? "true" : "false"
                        )
                        detailLabeledRow(
                            label: "waterTempAvgCelsius",
                            value: activity.waterTempAvgCelsius.map { String(format: "%.6f", $0) } ?? "nil"
                        )
                        detailLabeledRow(
                            label: "waterTempMaxCelsius",
                            value: activity.waterTempMaxCelsius.map { String(format: "%.6f", $0) } ?? "nil"
                        )
                        detailLabeledRow(
                            label: "waterTempMinCelsius",
                            value: activity.waterTempMinCelsius.map { String(format: "%.6f", $0) } ?? "nil"
                        )
                        detailLabeledRow(
                            label: "avgAscentRateMetersPerSecond",
                            value: activity.avgAscentRateMetersPerSecond.map { String(format: "%.8f", $0) } ?? "nil"
                        )
                        detailLabeledRow(label: "siteName", value: activity.siteName ?? "nil")
                        detailLabeledRow(label: "locationName", value: activity.locationName ?? "nil")
                        if let c = activity.entryCoordinate {
                            detailLabeledRow(
                                label: "coordinate",
                                value: String(format: "lat %.8f, lon %.8f", c.latitude, c.longitude)
                            )
                        } else {
                            detailLabeledRow(label: "coordinate", value: "nil")
                        }
                        detailLabeledRow(
                            label: "notes",
                            value: activity.notes.map { $0.isEmpty ? "(empty string)" : $0 } ?? "nil"
                        )
                        detailLabeledRow(label: "buddies.count", value: "\(activity.buddies.count)")
                        ForEach(Array(activity.buddies.enumerated()), id: \.element.id) { index, buddy in
                            detailLabeledRow(
                                label: "buddies[\(index)].id",
                                value: buddy.id.uuidString
                            )
                            detailLabeledRow(
                                label: "buddies[\(index)].displayName",
                                value: buddy.displayName
                            )
                        }
                        detailLabeledRow(label: "profilePoints.count", value: "\(activity.profilePoints.count)")
                        detailLabeledRow(label: "rawImportVersion", value: activity.rawImportVersion ?? "nil")
                    }
                }

                detailsSectionHeader("Tank / cylinder")
                basicSectionCard {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        detailLabeledRow(label: "tankMaterial", value: activity.tankMaterial ?? "nil")
                        detailLabeledRow(label: "tankVolumeDescription", value: activity.tankVolumeDescription ?? "nil")
                        detailLabeledRow(
                            label: "tankPressureStartPSI",
                            value: activity.tankPressureStartPSI.map { String(format: "%.4f", $0) } ?? "nil"
                        )
                        detailLabeledRow(
                            label: "tankPressureEndPSI",
                            value: activity.tankPressureEndPSI.map { String(format: "%.4f", $0) } ?? "nil"
                        )
                    }
                }

                detailsSectionHeader("Tank on profile (samples)")
                basicSectionCard {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        detailLabeledRow(
                            label: "Samples with tankPressurePSI",
                            value: "\(moreTabProfilePointsWithTankPressure.count) / \(moreTabSortedProfilePoints.count)"
                        )
                        if let tankSample = moreTabProfilePointsWithTankPressure.first {
                            detailLabeledRow(
                                label: "First sample (timestamp)",
                                value: tankSample.formattedTimestamp(for: activity)
                            )
                            detailLabeledRow(
                                label: "First sample (timestamp, UTC)",
                                value: tankSample.timestamp.formatted(.iso8601)
                            )
                            detailLabeledRow(
                                label: "First sample depthMeters",
                                value: String(format: "%.6f", tankSample.depthMeters)
                            )
                            detailLabeledRow(
                                label: "First sample tankPressurePSI",
                                value: tankSample.tankPressurePSI.map { String(format: "%.4f", $0) } ?? "nil"
                            )
                        } else {
                            Text("No per-sample cylinder pressure on profile points (missing tank stream in FIT, or UDDF without waypoint tankpressure).")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.Colors.tabUnselected)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                detailsSectionHeader("DiveProfilePoint (one sample — earliest timestamp)")
                if let point = moreTabSortedProfilePoints.first {
                    basicSectionCard {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            detailLabeledRow(label: "persistentModelID", value: "\(point.persistentModelID)")
                            detailLabeledRow(label: "timestamp", value: point.formattedTimestamp(for: activity))
                            detailLabeledRow(
                                label: "timestamp (UTC)",
                                value: point.timestamp.formatted(.iso8601)
                            )
                            detailLabeledRow(label: "depthMeters", value: String(format: "%.6f", point.depthMeters))
                            detailLabeledRow(
                                label: "temperatureCelsius",
                                value: point.temperatureCelsius.map { String(format: "%.6f", $0) } ?? "nil"
                            )
                            detailLabeledRow(
                                label: "ascentRateMetersPerSecond",
                                value: point.ascentRateMetersPerSecond.map { String(format: "%.8f", $0) } ?? "nil"
                            )
                            detailLabeledRow(
                                label: "ndlSeconds",
                                value: point.ndlSeconds.map(String.init) ?? "nil"
                            )
                            detailLabeledRow(
                                label: "timeToSurfaceSeconds",
                                value: point.timeToSurfaceSeconds.map(String.init) ?? "nil"
                            )
                            detailLabeledRow(
                                label: "tankPressurePSI",
                                value: point.tankPressurePSI.map { String(format: "%.4f", $0) } ?? "nil"
                            )
                            detailLabeledRow(
                                label: "heartRateBPM",
                                value: point.heartRateBPM.map(String.init) ?? "nil"
                            )
                            detailLabeledRow(
                                label: "po2Bars",
                                value: point.po2Bars.map { String(format: "%.6f", $0) } ?? "nil"
                            )
                            detailLabeledRow(
                                label: "n2Load",
                                value: point.n2Load.map(String.init) ?? "nil"
                            )
                            detailLabeledRow(
                                label: "cnsLoad",
                                value: point.cnsLoad.map(String.init) ?? "nil"
                            )
                            detailLabeledRow(
                                label: "dive (parent id)",
                                value: point.dive?.id.uuidString ?? "nil"
                            )
                        }
                    }
                } else {
                    basicSectionCard {
                        Text("No profile points.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.tabUnselected)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(AppTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var detailsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                detailsSectionHeader("Source & import")
                basicSectionCard {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        detailLabeledRow(label: "Source", value: activity.source.rawValue)
                        if let sid = activity.sourceDiveId, !sid.isEmpty {
                            detailLabeledRow(label: "Source ID", value: sid)
                        }
                        if let ver = activity.rawImportVersion, !ver.isEmpty {
                            detailLabeledRow(label: "Import / format", value: ver)
                        }
                        detailLabeledRow(label: "Profile samples", value: "\(activity.profilePoints.count)")
                        if let coord = activity.entryCoordinate {
                            detailLabeledRow(
                                label: "GPS (first fix)",
                                value: String(format: "%.5f°, %.5f°", coord.latitude, coord.longitude)
                            )
                        } else {
                            detailLabeledRow(label: "GPS", value: "—")
                        }
                    }
                }

                detailsSectionHeader("Gas")
                basicSectionCard {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        detailLabeledRow(label: "Gas", value: activity.gasDetailsGasTypeLine)
                        detailLabeledRow(label: "O₂ mix", value: activity.gasDetailsOxygenMixLine)
                        detailLabeledRow(label: "Tank type", value: activity.gasDetailsTankTypeLine())
                        detailLabeledRow(
                            label: "Volume",
                            value: activity.gasDetailsTankVolumeLine(displayUnits: diveDisplayUnitSystem)
                        )
                        detailLabeledRow(
                            label: "Beginning pressure",
                            value: activity.gasDetailsBeginningPressureLine(displayUnits: diveDisplayUnitSystem)
                        )
                        detailLabeledRow(
                            label: "Ending pressure",
                            value: activity.gasDetailsEndingPressureLine(displayUnits: diveDisplayUnitSystem)
                        )
                    }
                }

                detailsSectionHeader("Buddies")
                basicSectionCard {
                    if activity.buddies.isEmpty {
                        Text("No buddies tagged.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.tabUnselected)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            ForEach(activity.buddies, id: \.id) { buddy in
                                Text(buddy.displayName)
                                    .font(.body)
                                    .foregroundStyle(AppTheme.Colors.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }

                detailsSectionHeader("Notes")
                notesEditorBox
            }
            .padding(AppTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var notesEditorBox: some View {
        TextEditor(text: notesBinding)
            .font(.body)
            .foregroundStyle(AppTheme.Colors.textPrimary)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.visible)
            .focused($isNotesFieldFocused)
            .padding(AppTheme.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
            .background(AppTheme.Colors.surfaceMuted.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.Colors.tabUnselected.opacity(0.22), lineWidth: 1)
            }
            .onAppear {
                clampNotesToLimitIfNeeded()
            }
    }

    private func clampNotesToLimitIfNeeded() {
        guard let notes = activity.notes else { return }
        guard notes.count > DetailNotes.maxCharacterCount else { return }
        activity.notes = String(notes.prefix(DetailNotes.maxCharacterCount))
    }

    private var notesBinding: Binding<String> {
        Binding(
            get: {
                String((activity.notes ?? "").prefix(DetailNotes.maxCharacterCount))
            },
            set: { newValue in
                let capped = String(newValue.prefix(DetailNotes.maxCharacterCount))
                activity.notes = capped.isEmpty ? nil : capped
            }
        )
    }

    private func detailLabeledRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.tabUnselected)
            Text(value)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailsSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.tabUnselected)
    }

    private func placeholderContent(title: String) -> some View {
        VStack {
            Spacer()
            Text("\(title) content coming next")
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.tabUnselected)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var overviewMapCoordinate: DiveCoordinate? {
        activity.resolvedMapCoordinate(catalogSites: diveSites)
    }

    /// Remounts **`DiveLocationMapView`** when dive or resolved coordinate changes (MapKit annotation refresh).
    private var overviewMapViewIdentity: String {
        DiveLocationMapPresentation.mapViewIdentity(
            activityID: activity.id,
            coordinate: overviewMapCoordinate
        )
    }

    private var tankCollapsedSummary: some View {
        DiveActivityTankCollapsedSummary(
            dateText: activity.formattedStartDateOnly(),
            titleText: "Tank & gas",
            diveNumberText: activity.diveNumberPlainLabel,
            startPressureText: shortPressureChip(activity.tankPressureStartPSI),
            endPressureText: shortPressureChip(activity.tankPressureEndPSI)
        )
    }

    private var photosCollapsedSummary: some View {
        DiveActivityPhotosPanelContent(
            mediaItems: activity.sortedMediaPhotos,
            selectedMediaID: $selectedDiveMediaPhotoID,
            timeZoneOffsetSeconds: activity.timeZoneOffsetSeconds,
            showsMediaCarousel: DiveActivityMediaPresentation.showsMediaCarouselInSheet(for: .minimized),
            showsSheetDetails: false,
            mediaPickerItems: $diveMediaPickerItems,
            isImportInProgress: mediaImportOverlay.isBlocking
        )
        .accessibilityIdentifier("DiveOverview.MediaPanel.Minimized")
    }

    private var photosPanelContent: some View {
        DiveActivityPhotosPanelContent(
            mediaItems: activity.sortedMediaPhotos,
            selectedMediaID: $selectedDiveMediaPhotoID,
            timeZoneOffsetSeconds: activity.timeZoneOffsetSeconds,
            showsMediaCarousel: DiveActivityMediaPresentation.showsMediaCarouselInSheet(
                for: overviewSheetDetent
            ),
            showsSheetDetails: DiveActivityMediaPresentation.showsMediaSheetDetails(
                for: overviewSheetDetent
            ),
            mediaPickerItems: $diveMediaPickerItems,
            isImportInProgress: mediaImportOverlay.isBlocking
        )
        .accessibilityIdentifier("DiveOverview.MediaPanel")
    }

    @MainActor
    private func importDiveMediaPickerItems(_ items: [PhotosPickerItem]) async {
        let total = items.count
        withAnimation(.easeInOut(duration: 0.15)) {
            mediaImportOverlay = .importing(completed: 0, total: total, stage: "Preparing…")
        }
        await Task.yield()

        let outcome = await DiveActivityMediaBatchImport.importPickerItems(
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
            diveMediaPickerItems = []
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
        diveMediaPickerItems = []
        if let lastAddedID = outcome.lastAddedMediaID {
            selectedDiveMediaPhotoID = lastAddedID
        }
    }

    private var tankPanelContent: some View {
        let stats = DiveActivityTankPanelSummary.profilePressureStats(from: activity.profilePoints)
        return VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            tankPanelHeader

            tankDepthProfileSection

            DiveActivityEditableSectionsView(
                activity: activity,
                tab: .tank,
                displayUnits: diveDisplayUnitSystem,
                profileGasStats: stats,
                onEditField: { editingField = $0 },
                onManageEquipment: { showsAddEquipmentSheet = true },
                onManageLinkedSite: { showsAddDiveSiteSheet = true },
                onManageBuddies: { showsBuddiesEditSheet = true }
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var addableEquipmentForSheet: [EquipmentItem] {
        guard let ownerID = accountSession.currentProfile?.id ?? activity.ownerProfileID else { return [] }
        return (
            try? DiveActivityEquipmentAssociation.addableEquipment(
                for: activity,
                ownerProfileID: ownerID,
                modelContext: modelContext
            )
        ) ?? []
    }

    private var equipmentLinkErrorBinding: Binding<Bool> {
        Binding(
            get: { equipmentLinkErrorMessage != nil },
            set: { if !$0 { equipmentLinkErrorMessage = nil } }
        )
    }

    private func linkEquipmentToDive(_ item: EquipmentItem) {
        do {
            try DiveActivityEquipmentAssociation.link(item, to: activity, modelContext: modelContext)
            try modelContext.save()
        } catch {
            equipmentLinkErrorMessage = error.localizedDescription
        }
    }

    private var tankPanelHeader: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(activity.formattedStartDateOnly())
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Text("Tank & gas")
                .font(.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Text("Dive \(activity.diveNumberPlainLabel) · \(activity.source.rawValue)")
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.tabUnselected)
        }
    }

    private func shortPressureChip(_ psi: Double?) -> String {
        guard let psi else { return "—" }
        let line = DiveQuantityFormatting.cylinderPressure(fromPSI: psi, system: diveDisplayUnitSystem)
        return line == "—" ? "—" : line
    }

    private var overviewSiteHeaderTitle: String {
        DiveActivityOverviewPresentation.siteHeaderTitle(
            siteName: activity.resolvedSiteName,
            fallback: activity.source.overviewFallbackSiteTitle
        )
    }

    private var overviewCollapsedSummary: some View {
        DiveActivityOverviewCollapsedSummary(
            dateText: activity.formattedStartDateOnly(),
            titleText: overviewSiteHeaderTitle,
            diveNumberText: activity.diveNumberPlainLabel,
            maxDepthText: formatDepth(activity.maxDepthMeters),
            durationText: "\(activity.durationMinutes) min"
        )
    }

    private var overviewBottomPanelContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text(overviewSiteHeaderTitle)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text(activity.formattedStartDateOnly())
                    .font(.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text("Dive \(activity.diveNumberPlainLabel) · \(activity.source.rawValue)")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.tabUnselected)

                if overviewMapCoordinate == nil {
                    Text("No location coordinates recorded for this dive.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.tabUnselected)
                }
            }

            DiveActivityEditableSectionsView(
                activity: activity,
                tab: .map,
                displayUnits: diveDisplayUnitSystem,
                profileGasStats: DiveActivityTankPanelSummary.profilePressureStats(
                    from: activity.profilePoints
                ),
                onEditField: { editingField = $0 },
                onManageEquipment: { showsAddEquipmentSheet = true },
                onManageLinkedSite: { showsAddDiveSiteSheet = true },
                onManageBuddies: { showsBuddiesEditSheet = true }
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tankDepthProfileSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            let samples = DiveDepthProfileSeries.samples(fromProfilePoints: activity.profilePoints)
            depthProfileHeroRow(scrubSample: depthProfileScrubSample)

            DiveDepthProfileChart(
                samples: samples,
                maxDepthHintMeters: activity.maxDepthMeters,
                onScrubSampleChange: { depthProfileScrubSample = $0 }
            )
            .frame(height: 220)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Depth profile chart")
            .accessibilityValue(
                samples.isEmpty
                    ? "No sample data available"
                    : depthProfileChartAccessibilitySummary(samples: samples)
            )
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.surfaceElevated.opacity(0.65))
        }
    }

    private var depthChartMediaPreviewPresented: Binding<Bool> {
        Binding(
            get: { depthChartPreviewMediaID != nil },
            set: { if !$0 { depthChartPreviewMediaID = nil } }
        )
    }

    private var depthChartPreviewMedia: DiveMediaPhoto? {
        guard let depthChartPreviewMediaID else { return nil }
        return activity.mediaPhotos.first { $0.id == depthChartPreviewMediaID }
    }

    private var mediaCaptureContextsByID: [UUID: DiveMediaCaptureContext] {
        let samples = DiveDepthProfileSeries.samples(fromProfilePoints: moreTabSortedProfilePoints)
        return DiveDepthProfileMediaPlotting.captureContextsByMediaID(
            mediaPhotos: activity.sortedMediaPhotos,
            profileSamples: samples,
            activityStartTime: activity.startTime,
            durationMinutes: activity.durationMinutes,
            profilePoints: moreTabSortedProfilePoints
        )
    }

    private var depthChartPreviewCaptureContext: DiveMediaCaptureContext? {
        guard let depthChartPreviewMediaID else { return nil }
        return mediaCaptureContextsByID[depthChartPreviewMediaID]
    }

    private var depthProfileMediaMarkers: [DiveDepthProfileMediaMarker] {
        let samples = DiveDepthProfileSeries.samples(fromProfilePoints: moreTabSortedProfilePoints)
        return DiveDepthProfileMediaPlotting.markers(
            mediaPhotos: activity.sortedMediaPhotos,
            profileSamples: samples,
            activityStartTime: activity.startTime,
            durationMinutes: activity.durationMinutes,
            profilePoints: moreTabSortedProfilePoints
        )
    }

    private var depthProfileMediaPhotosByID: [UUID: DiveMediaPhoto] {
        Dictionary(uniqueKeysWithValues: activity.sortedMediaPhotos.map { ($0.id, $0) })
    }


    private func basicSectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(AppTheme.Spacing.md)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.Colors.surfaceElevated)
            }
    }

    @ViewBuilder
    private func depthProfileHeroRow(scrubSample: DiveDepthProfileSample?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.lg) {
            VStack(alignment: .leading, spacing: 4) {
                Text(depthProfileHeroPrimaryLabel(scrubSample: scrubSample))
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
                Text(depthProfileHeroPrimaryValue(scrubSample: scrubSample))
                    .font(.title2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                Text(depthProfileHeroSecondaryLabel(scrubSample: scrubSample))
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
                Text(depthProfileHeroSecondaryValue(scrubSample: scrubSample))
                    .font(.title2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func depthProfileHeroPrimaryLabel(scrubSample: DiveDepthProfileSample?) -> String {
        scrubSample == nil ? "Total dive time" : "From start"
    }

    private func depthProfileHeroSecondaryLabel(scrubSample: DiveDepthProfileSample?) -> String {
        scrubSample == nil ? "Max depth" : "Depth"
    }

    private func depthProfileHeroPrimaryValue(scrubSample: DiveDepthProfileSample?) -> String {
        if let scrub = scrubSample {
            return formattedMinutesSinceDiveStart(scrub.elapsedSeconds)
        }
        return "\(activity.durationMinutes) min"
    }

    private func depthProfileHeroSecondaryValue(scrubSample: DiveDepthProfileSample?) -> String {
        if let scrub = scrubSample {
            return formatDepth(scrub.depthMeters)
        }
        return formatDepth(activity.maxDepthMeters)
    }

    /// Elapsed time from dive **`startTime`** for the scrubbed profile sample (minutes).
    private func formattedMinutesSinceDiveStart(_ elapsedSeconds: Double) -> String {
        let minutes = elapsedSeconds / 60.0
        let roundedToTenth = (minutes * 10).rounded() / 10
        if abs(roundedToTenth - roundedToTenth.rounded()) < 0.001 {
            return "\(Int(roundedToTenth.rounded())) min"
        }
        return String(format: "%.1f min", roundedToTenth)
    }

    private func depthProfileChartAccessibilitySummary(
        samples: [DiveDepthProfileSample]
    ) -> String {
        if let scrub = depthProfileScrubSample {
            return "\(formattedMinutesSinceDiveStart(scrub.elapsedSeconds)), \(formatDepth(scrub.depthMeters))"
        }
        return "Total dive time \(activity.durationMinutes) minutes, max depth \(formatDepth(activity.maxDepthMeters))"
    }

    private func formatDepth(_ meters: Double) -> String {
        DiveQuantityFormatting.depth(meters: meters, system: diveDisplayUnitSystem)
    }

}

@MainActor
private func viewSingleActivityPreview() -> some View {
    let schema = Schema([
        DiveActivity.self,
        DiveBuddyTag.self,
        DiveProfilePoint.self,
        DiveSite.self,
    ])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [configuration])
    let sampleActivity = DiveActivity(
        source: .manual,
        sourceDiveId: "preview-dive",
        startTime: .now,
        durationMinutes: 42,
        maxDepthMeters: 18.3,
        averageDepthMeters: 12.0,
        bottomTimeSeconds: 2100,
        surfaceIntervalSeconds: 3600,
        diveNumber: 44,
        waterTempAvgCelsius: 27.3,
        waterTempMaxCelsius: 28.0,
        waterTempMinCelsius: 26.0,
        siteName: "Salt Pier",
        locationName: "Bonaire",
        entryCoordinate: DiveCoordinate(latitude: 12.08316, longitude: -68.28330),
        notes: "Day Two Dive Five. Night dive at Salt Pier from MacDive XML sample.\n\nTarpon under the pier, octopus on the east piling. Jamie spotted a frogfish near the ladder.",
        tankMaterial: "aluminum",
        tankVolumeDescription: "11.1 L",
        tankPressureStartPSI: 2999.6,
        tankPressureEndPSI: 752.4,
        rawImportVersion: "preview"
    )
    let previewDepths: [Double] = [1, 6, 14, 18.3, 18, 12, 5, 1]
    for (i, depth) in previewDepths.enumerated() {
        let t = sampleActivity.startTime.addingTimeInterval(TimeInterval(i * 4 * 60))
        sampleActivity.profilePoints.append(DiveProfilePoint(timestamp: t, depthMeters: depth))
    }
    let previewContext = ModelContext(container)
    previewContext.insert(sampleActivity)
    try! previewContext.save()

    return NavigationStack {
        ViewSingleActivity(activity: sampleActivity)
    }
    .modelContainer(container)
}

#Preview {
    MainActor.assumeIsolated {
        viewSingleActivityPreview()
    }
}
