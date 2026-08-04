import SwiftUI

/// Strava-style dive overview panel in the view hierarchy (not a separate **`.sheet`**) so it moves with **`NavigationStack`** pop.
struct DiveActivityOverviewEmbeddedPanel<CollapsedSummary: View, PanelContent: View>: View {
    @Binding var selectedDetent: DiveActivityOverviewDetent
    let layoutHeight: CGFloat
    let screenWidth: CGFloat
    let topSafeInset: CGFloat
    let bottomSafeInset: CGFloat
    @ViewBuilder var collapsedSummary: () -> CollapsedSummary
    @ViewBuilder var panelContent: () -> PanelContent
    var collapsedSummaryExpandsOnTap: Bool = true
    var showsPanelContentWhenMinimized: Bool = false
    var disablesPanelScrollWhenMinimized: Bool = false
    var isPanelScrollDisabled: Bool = false
    /// Frosted panel fill (e.g. minimized **Media** tab) so the hero remains visible underneath.
    var usesTranslucentChrome: Bool = false
    /// Feathered top mask on scroll content inside the panel body.
    var topScrollFadeHeight: CGFloat = 0
    /// Opaque panel surface behind scroll content when the top feather mask is active.
    var usesOpaquePanelScrollFadeBackground: Bool = false
    /// Optional sink for the panel’s live height fraction (resting detent or grabber drag).
    var liveHeightFraction: Binding<CGFloat>? = nil
    /// Optional per-frame channel — unthrottled drag fraction for gesture-driven heroes (tank chart).
    var liveSheetState: DiveActivityOverviewLiveSheetState? = nil
    /// Persisted vertical scroll offset for nested-navigation return (map / tank panel).
    @Binding var panelScrollOffsetY: CGFloat
    /// Last offset saved in **`DiveActivityOverviewUIStateStore`** while the binding may read zero during nested pushes.
    var scrollRestorationFallbackY: CGFloat = 0
    /// Remounts scroll when map / tank / media panel body changes.
    var panelScrollContentIdentity: AnyHashable = "default"
    /// Large-sheet horizontal swipe — translation width for tab paging (hero / minimized ignored).
    var onCommittedHorizontalTabSwipe: ((CGFloat) -> Void)? = nil

    @State private var grabberDragTranslation: CGFloat = 0

    private var layoutContext: DiveActivityOverviewSheetLayoutContext {
        DiveActivityOverviewSheetLayoutContext(
            layoutHeight: layoutHeight,
            screenWidth: screenWidth,
            topSafeInset: topSafeInset,
            bottomSafeInset: bottomSafeInset
        )
    }

    private var largeRestingFraction: CGFloat {
        DiveActivityOverviewPanelMetrics.largeHeightFraction(in: layoutContext)
    }

    private var restingHeightFraction: CGFloat {
        selectedDetent.resolvedHeightFraction(in: layoutContext)
    }

    private var isDragging: Bool { grabberDragTranslation != 0 }

    private var displayHeightFraction: CGFloat {
        guard isDragging, layoutHeight > 0 else {
            return restingHeightFraction
        }
        return DiveActivityOverviewPanelMetrics.heightFractionWhileDragging(
            restingFraction: restingHeightFraction,
            dragTranslation: grabberDragTranslation,
            layoutHeight: layoutHeight,
            largeRestingFraction: largeRestingFraction
        )
    }

    private var panelHeight: CGFloat {
        if isDragging {
            return DiveActivityOverviewDetent.sheetHeight(
                forHeightFraction: displayHeightFraction,
                layoutHeight: layoutHeight,
                bottomSafeInset: bottomSafeInset
            )
        }
        return DiveActivityOverviewDetent.sheetHeight(
            for: selectedDetent,
            layoutHeight: layoutHeight,
            bottomSafeInset: bottomSafeInset,
            screenWidth: screenWidth,
            topSafeInset: topSafeInset
        )
    }

    /// Height fraction passed to map panel content — continuous while dragging, resting detent otherwise.
    private var contentHeightFraction: CGFloat {
        isDragging ? displayHeightFraction : restingHeightFraction
    }

    var body: some View {
        VStack(spacing: 0) {
            panelGrabberRow
                .contentShape(Rectangle())
                .highPriorityGesture(panelDragGesture)

            DiveActivityOverviewSheetContent(
                selectedDetent: $selectedDetent,
                layoutContext: layoutContext,
                liveHeightFraction: contentHeightFraction,
                panelScrollOffsetY: $panelScrollOffsetY,
                collapsedSummary: collapsedSummary,
                panelContent: panelContent,
                collapsedSummaryExpandsOnTap: collapsedSummaryExpandsOnTap,
                showsPanelContentWhenMinimized: showsPanelContentWhenMinimized,
                disablesPanelScrollWhenMinimized: disablesPanelScrollWhenMinimized,
                isPanelScrollDisabled: isPanelScrollDisabled,
                topScrollFadeHeight: topScrollFadeHeight,
                usesOpaquePanelScrollFadeBackground: usesOpaquePanelScrollFadeBackground,
                scrollRestorationFallbackY: scrollRestorationFallbackY,
                panelScrollContentIdentity: panelScrollContentIdentity
            )
            .simultaneousGesture(horizontalTabSwipeGesture)
        }
        .frame(height: panelHeight, alignment: .top)
        .frame(maxWidth: .infinity)
        .clipped()
        .animation(isDragging ? nil : .diveOverviewPanelDetent, value: panelHeight)
        .diveActivityOverviewEmbeddedPanelChrome(translucent: usesTranslucentChrome)
        .accessibilityIdentifier("DiveActivity.OverviewEmbeddedPanel")
        .onAppear {
            publishLiveHeightFraction(force: true)
            liveSheetState?.heightFraction = contentHeightFraction
        }
        .onChange(of: selectedDetent) { _, _ in
            publishLiveHeightFraction(force: true)
            // Tap-to-expand / programmatic detent changes ride the same spring as the panel height;
            // for drag releases `onEnded` already set the resting value inside this animation.
            guard !isDragging else { return }
            withAnimation(.diveOverviewPanelDetent) {
                liveSheetState?.heightFraction = restingHeightFraction
            }
        }
        .onChange(of: grabberDragTranslation) { _, newTranslation in
            // Force on drag end so hero/map settle at the resting seam without waiting for epsilon.
            publishLiveHeightFraction(force: newTranslation == 0)
        }
    }

    private func publishLiveHeightFraction(force: Bool = false) {
        guard let liveHeightFraction else { return }
        let next = contentHeightFraction
        guard DiveActivityOverviewPanelMetrics.shouldPublishLiveHeightFraction(
            previous: liveHeightFraction.wrappedValue,
            next: next,
            force: force
        ) else { return }
        liveHeightFraction.wrappedValue = next
    }

    private var panelGrabberRow: some View {
        Capsule()
            .fill(AppTheme.Colors.tabUnselected.opacity(0.55))
            .frame(width: 36, height: 5)
            .padding(.top, AppTheme.Spacing.sm)
            .padding(.bottom, AppTheme.Spacing.sm)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 28)
            .accessibilityHidden(true)
    }

    private var panelDragGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { value in
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    grabberDragTranslation = value.translation.height
                    liveSheetState?.heightFraction = displayHeightFraction
                }
                publishLiveHeightFraction()
            }
            .onEnded { value in
                let current = restingHeightFraction
                let predicted = DiveActivityOverviewPanelMetrics.heightFractionWhileDragging(
                    restingFraction: current,
                    dragTranslation: value.predictedEndTranslation.height,
                    layoutHeight: layoutHeight,
                    largeRestingFraction: largeRestingFraction
                )
                let snapped = DiveActivityOverviewPanelMetrics.snappedHeightFractionAfterDrag(
                    currentFraction: current,
                    predictedFraction: predicted,
                    verticalTranslation: value.translation.height,
                    largeRestingFraction: largeRestingFraction
                )
                let nextDetent = DiveActivityOverviewDetent.nearest(
                    toHeightFraction: snapped,
                    largeRestingFraction: largeRestingFraction
                )
                // Record the release position before the detent mutation so the page's
                // detent-change handler can tell drag-driven snaps from taps.
                liveSheetState?.dragReleaseHeightFraction = displayHeightFraction
                withAnimation(.diveOverviewPanelDetent) {
                    selectedDetent = nextDetent
                    grabberDragTranslation = 0
                    // Same spring as the panel height so hero transforms settle in sync.
                    liveSheetState?.heightFraction = nextDetent.resolvedHeightFraction(in: layoutContext)
                }
            }
    }

    /// Sheet body only (not the grabber, not the hero). No-ops when minimized or mid-grabber-drag.
    private var horizontalTabSwipeGesture: some Gesture {
        DragGesture(
            minimumDistance: DiveActivityOverviewTabPagerPresentation.swipeMinimumDistance
        )
        .onEnded { value in
            guard onCommittedHorizontalTabSwipe != nil else { return }
            guard DiveActivityOverviewTabPagerPresentation.allowsHorizontalTabSwipe(
                detent: selectedDetent,
                isGrabberDragging: isDragging
            ) else { return }
            guard DiveActivityOverviewTabPagerPresentation.isHorizontalSwipeDominant(
                translation: value.translation
            ) else { return }
            onCommittedHorizontalTabSwipe?(value.translation.width)
        }
    }
}
