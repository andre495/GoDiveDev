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
    /// Persisted vertical scroll offset for nested-navigation return (map / tank panel).
    @Binding var panelScrollOffsetY: CGFloat
    /// Last offset saved in **`DiveActivityOverviewUIStateStore`** while the binding may read zero during nested pushes.
    var scrollRestorationFallbackY: CGFloat = 0
    /// Remounts scroll when map / tank / media panel body changes.
    var panelScrollContentIdentity: AnyHashable = "default"

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
        }
        .frame(height: panelHeight, alignment: .top)
        .frame(maxWidth: .infinity)
        .clipped()
        .animation(isDragging ? nil : .diveOverviewPanelDetent, value: panelHeight)
        .diveActivityOverviewEmbeddedPanelChrome(translucent: usesTranslucentChrome)
        .accessibilityIdentifier("DiveActivity.OverviewEmbeddedPanel")
        .onAppear(perform: publishLiveHeightFraction)
        .onChange(of: selectedDetent) { _, _ in
            publishLiveHeightFraction()
        }
        .onChange(of: grabberDragTranslation) { _, _ in
            publishLiveHeightFraction()
        }
    }

    private func publishLiveHeightFraction() {
        liveHeightFraction?.wrappedValue = contentHeightFraction
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
                }
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
                withAnimation(.diveOverviewPanelDetent) {
                    selectedDetent = nextDetent
                    grabberDragTranslation = 0
                }
            }
    }
}
