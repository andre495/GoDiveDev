import SwiftUI

/// Body of the persistent dive overview **`.sheet`** (map + tank tabs).
struct DiveActivityOverviewSheetContent<CollapsedSummary: View, PanelContent: View>: View {
    @Binding var selectedDetent: DiveActivityOverviewDetent
    @ViewBuilder var collapsedSummary: () -> CollapsedSummary
    @ViewBuilder var panelContent: () -> PanelContent

    /// Keeps the heavy scroll body mounted after first expand so detent changes do not rebuild the chart.
    @State private var keepsExpandedPanelMounted = true

    var body: some View {
        ZStack(alignment: .top) {
            if keepsExpandedPanelMounted {
                OverviewPanelScrollArea(
                    restingDetent: selectedDetent,
                    onExpand: { selectedDetent = .large },
                    onCollapseToMedium: { selectedDetent = .medium }
                ) {
                    panelContent()
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.bottom, AppTheme.Spacing.lg)
                }
                .opacity(selectedDetent == .minimized ? 0 : 1)
                .allowsHitTesting(selectedDetent != .minimized)
                .accessibilityHidden(selectedDetent == .minimized)
                .frame(maxWidth: .infinity, maxHeight: selectedDetent == .minimized ? 1 : nil)
                .clipped()
            }

            if selectedDetent == .minimized {
                Button {
                    selectedDetent = .medium
                } label: {
                    collapsedSummary()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Expands dive details")
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.bottom, AppTheme.Spacing.md)
            }
        }
        .animation(nil, value: selectedDetent)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Dive details")
        .accessibilityValue(selectedDetent.accessibilityDescription)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                if let taller = selectedDetent.nextTaller() {
                    selectedDetent = taller
                }
            case .decrement:
                if let shorter = selectedDetent.nextShorter() {
                    selectedDetent = shorter
                }
            @unknown default:
                break
            }
        }
        .onAppear {
            if selectedDetent != .minimized {
                keepsExpandedPanelMounted = true
            }
        }
    }
}

// MARK: - Native sheet presentation

extension View {
    /// Standard dive overview sheet chrome: three detents, system grabber, hero interaction through **medium**.
    func diveActivityOverviewSheetPresentation(
        selectedDetent: Binding<DiveActivityOverviewDetent>
    ) -> some View {
        presentationDetents(
            DiveActivityOverviewDetent.allPresentationDetents,
            selection: Binding(
                get: { selectedDetent.wrappedValue.presentationDetent },
                set: { newDetent in
                    guard let matched = DiveActivityOverviewDetent(presentationDetent: newDetent),
                          matched != selectedDetent.wrappedValue
                    else { return }
                    selectedDetent.wrappedValue = matched
                }
            )
        )
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(
            .enabled(upThrough: DiveActivityOverviewDetent.medium.presentationDetent)
        )
        .presentationCornerRadius(DiveActivityOverviewPanelChrome.topCornerRadius)
        .presentationBackground {
            Rectangle()
                .fill(.thinMaterial)
                .opacity(DiveActivityOverviewPanelChrome.sheetBackgroundOpacity)
        }
        .presentationContentInteraction(.scrolls)
        .interactiveDismissDisabled()
    }
}

// MARK: - Scroll area

/// Tracks scroll offset locally; parent only receives one-shot expand / collapse callbacks.
struct OverviewPanelScrollArea<Content: View>: View {
    let restingDetent: DiveActivityOverviewDetent
    let onExpand: () -> Void
    let onCollapseToMedium: () -> Void
    @ViewBuilder var content: () -> Content

    @State private var lastScrollOffsetY: CGFloat = 0
    @State private var didFireExpandThisGesture = false
    @State private var pendingDetentScrollTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            content()
        }
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y
        } action: { _, newOffset in
            lastScrollOffsetY = newOffset
            handleScrollOffset(newOffset)
        }
        .onScrollPhaseChange { _, phase in
            guard phase == .idle || phase == .decelerating else { return }
            handleScrollEnded()
        }
        .onDisappear {
            pendingDetentScrollTask?.cancel()
        }
    }

    private func handleScrollOffset(_ offsetY: CGFloat) {
        if offsetY < 8 {
            didFireExpandThisGesture = false
        }

        guard DiveActivityOverviewPanelMetrics.shouldExpandFromScroll(
            restingFraction: restingDetent.heightFraction,
            scrollOffsetY: offsetY
        ), !didFireExpandThisGesture
        else { return }

        didFireExpandThisGesture = true
        scheduleDetentScrollAction(onExpand)
    }

    private func handleScrollEnded() {
        guard DiveActivityOverviewPanelMetrics.shouldCollapseToMediumFromScroll(
            restingFraction: restingDetent.heightFraction,
            scrollOffsetY: lastScrollOffsetY
        ) else { return }

        scheduleDetentScrollAction(onCollapseToMedium)
    }

    /// Coalesces rapid scroll callbacks so sheet detent changes do not stack in one frame.
    private func scheduleDetentScrollAction(_ action: @escaping () -> Void) {
        pendingDetentScrollTask?.cancel()
        pendingDetentScrollTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(48))
            guard !Task.isCancelled else { return }
            action()
        }
    }
}
