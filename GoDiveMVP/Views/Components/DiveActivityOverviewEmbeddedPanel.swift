import SwiftUI

/// Strava-style dive overview panel in the view hierarchy (not a separate **`.sheet`**) so it moves with **`NavigationStack`** pop.
struct DiveActivityOverviewEmbeddedPanel<CollapsedSummary: View, PanelContent: View>: View {
    @Binding var selectedDetent: DiveActivityOverviewDetent
    let layoutHeight: CGFloat
    let bottomSafeInset: CGFloat
    @ViewBuilder var collapsedSummary: () -> CollapsedSummary
    @ViewBuilder var panelContent: () -> PanelContent

    @State private var grabberDragTranslation: CGFloat = 0

    private var isDragging: Bool { grabberDragTranslation != 0 }

    private var displayHeightFraction: CGFloat {
        guard isDragging, layoutHeight > 0 else {
            return selectedDetent.heightFraction
        }
        return DiveActivityOverviewPanelMetrics.heightFractionWhileDragging(
            restingFraction: selectedDetent.heightFraction,
            dragTranslation: grabberDragTranslation,
            layoutHeight: layoutHeight
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
            bottomSafeInset: bottomSafeInset
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            panelGrabberRow
                .contentShape(Rectangle())
                .highPriorityGesture(panelDragGesture)

            DiveActivityOverviewSheetContent(
                selectedDetent: $selectedDetent,
                liveHeightFraction: isDragging ? displayHeightFraction : nil,
                collapsedSummary: collapsedSummary,
                panelContent: panelContent
            )
        }
        .frame(height: panelHeight, alignment: .top)
        .frame(maxWidth: .infinity)
        .clipped()
        .diveActivityOverviewEmbeddedPanelChrome()
        .accessibilityIdentifier("DiveActivity.OverviewEmbeddedPanel")
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
                let current = selectedDetent.heightFraction
                let predicted = DiveActivityOverviewPanelMetrics.heightFractionWhileDragging(
                    restingFraction: current,
                    dragTranslation: value.predictedEndTranslation.height,
                    layoutHeight: layoutHeight
                )
                let snapped = DiveActivityOverviewPanelMetrics.snappedHeightFractionAfterDrag(
                    currentFraction: current,
                    predictedFraction: predicted,
                    verticalTranslation: value.translation.height
                )
                let nextDetent = DiveActivityOverviewDetent.nearest(toHeightFraction: snapped)
                withAnimation(panelDetentAnimation) {
                    selectedDetent = nextDetent
                    grabberDragTranslation = 0
                }
            }
    }

    private var panelDetentAnimation: Animation {
        .interactiveSpring(response: 0.32, dampingFraction: 0.86, blendDuration: 0.12)
    }
}

extension View {
    /// Matches **`appSheetPresentationChrome()`** for the embedded dive overview panel.
    func diveActivityOverviewEmbeddedPanelChrome() -> some View {
        background {
            Rectangle()
                .fill(.thinMaterial)
                .opacity(AppTheme.Sheet.embeddedOverviewMaterialOpacity)
        }
        .clipShape(
            .rect(
                topLeadingRadius: AppTheme.Sheet.cornerRadius,
                topTrailingRadius: AppTheme.Sheet.cornerRadius,
                style: .continuous
            )
        )
        .ignoresSafeArea(edges: .bottom)
    }
}
