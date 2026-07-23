import SwiftUI

/// Body of the persistent dive overview panel (map + tank tabs) — embedded or **`.sheet`**.
struct DiveActivityOverviewSheetContent<CollapsedSummary: View, PanelContent: View>: View {
    @Binding var selectedDetent: DiveActivityOverviewDetent
    var layoutContext: DiveActivityOverviewSheetLayoutContext = .presentationReference
    /// When set (embedded grabber drag), layout follows the finger instead of the resting detent.
    var liveHeightFraction: CGFloat? = nil
    @Binding var panelScrollOffsetY: CGFloat
    @ViewBuilder var collapsedSummary: () -> CollapsedSummary
    @ViewBuilder var panelContent: () -> PanelContent
    /// When **`false`**, minimized content handles its own taps (e.g. **Media** carousel); expand via grabber.
    var collapsedSummaryExpandsOnTap: Bool = true
    /// **Media** tab: keep one panel (and carousel) mounted at **minimized** instead of swapping to **`collapsedSummary`**.
    var showsPanelContentWhenMinimized: Bool = false
    /// Disables vertical scroll in the compact minimized band (avoids scroll geometry churn).
    var disablesPanelScrollWhenMinimized: Bool = false
    /// Forces scroll off regardless of detent (e.g. **Media** **minimized** / **medium** carousel pin).
    var isPanelScrollDisabled: Bool = false
    /// Soft top fade on panel scroll content (e.g. **Media** **large** tagged-species detail).
    var topScrollFadeHeight: CGFloat = 0
    /// Solid panel fill behind scroll content so the feather mask fades into opaque chrome, not the hero.
    var usesOpaquePanelScrollFadeBackground: Bool = false
    /// Store-backed offset when the scroll binding was cleared during nested **`NavigationLink`** pushes.
    var scrollRestorationFallbackY: CGFloat = 0
    /// Remounts panel scroll when switching map / tank / media tab content.
    var panelScrollContentIdentity: AnyHashable = "default"

    /// Keeps the heavy scroll body mounted after first expand so detent changes do not rebuild the chart.
    @State private var keepsExpandedPanelMounted = true

    private var layoutHeightFraction: CGFloat {
        liveHeightFraction ?? selectedDetent.resolvedHeightFraction(in: layoutContext)
    }

    private var largeRestingFraction: CGFloat {
        DiveActivityOverviewPanelMetrics.largeHeightFraction(in: layoutContext)
    }

    private var showsMinimizedLayout: Bool {
        DiveActivityOverviewPanelMetrics.isMinimized(layoutHeightFraction)
    }

    private var showsCollapsedSummaryOverlay: Bool {
        showsMinimizedLayout && !showsPanelContentWhenMinimized
    }

    private var hidesMountedPanelContent: Bool {
        showsMinimizedLayout && !showsPanelContentWhenMinimized
    }

    /// When the outer panel must not scroll (**Media** tab), host content in a fixed frame so
    /// nested pinned-chrome scroll views receive a bounded height.
    private var usesFixedPanelContentHost: Bool {
        isPanelScrollDisabled
            || (showsMinimizedLayout && disablesPanelScrollWhenMinimized)
    }

    var body: some View {
        ZStack(alignment: .top) {
            if keepsExpandedPanelMounted {
                Group {
                    if usesFixedPanelContentHost {
                        panelContent()
                            .environment(\.diveOverviewPanelHeightFraction, layoutHeightFraction)
                            .padding(.top, DiveActivityOverviewPanelMetrics.panelContentTopPadding)
                            .padding(.horizontal, AppTheme.Spacing.md)
                            .padding(.bottom, AppTheme.Spacing.lg)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    } else {
                        OverviewPanelScrollArea(
                            restingDetent: selectedDetent,
                            layoutContext: layoutContext,
                            onExpand: {
                                withAnimation(.diveOverviewPanelDetent) {
                                    selectedDetent = .large
                                }
                            },
                            onCollapseToMinimized: {
                                withAnimation(.diveOverviewPanelDetent) {
                                    selectedDetent = .minimized
                                }
                            },
                            isScrollDisabled: false,
                            topScrollFadeHeight: topScrollFadeHeight,
                            usesOpaquePanelScrollFadeBackground: usesOpaquePanelScrollFadeBackground,
                            fallbackScrollOffsetY: scrollRestorationFallbackY,
                            contentIdentity: panelScrollContentIdentity,
                            persistedScrollOffsetY: $panelScrollOffsetY
                        ) {
                            panelContent()
                                .environment(\.diveOverviewPanelHeightFraction, layoutHeightFraction)
                                .padding(.top, DiveActivityOverviewPanelMetrics.panelContentTopPadding)
                                .padding(.horizontal, AppTheme.Spacing.md)
                                .padding(.bottom, AppTheme.Spacing.lg)
                        }
                        .frame(maxHeight: .infinity, alignment: .top)
                    }
                }
                .opacity(hidesMountedPanelContent ? 0 : 1)
                .allowsHitTesting(!hidesMountedPanelContent)
                .accessibilityHidden(hidesMountedPanelContent)
                .clipped()
            }

            if showsCollapsedSummaryOverlay {
                Group {
                    if collapsedSummaryExpandsOnTap {
                        Button {
                            withAnimation(.diveOverviewPanelDetent) {
                                selectedDetent = .large
                            }
                        } label: {
                            collapsedSummary()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Expands dive details")
                    } else {
                        collapsedSummary()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, DiveActivityOverviewPanelMetrics.panelContentTopPadding)
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
            if !DiveActivityOverviewPanelMetrics.isMinimized(layoutHeightFraction) || showsPanelContentWhenMinimized {
                keepsExpandedPanelMounted = true
            }
        }
        .onChange(of: showsPanelContentWhenMinimized) { _, showsPanelContent in
            if showsPanelContent {
                keepsExpandedPanelMounted = true
            }
        }
    }
}

// MARK: - Native sheet presentation

extension View {
    /// Standard dive overview sheet chrome: two detents (**minimized** + blue-sheet **large**), system grabber.
    func diveActivityOverviewSheetPresentation(
        selectedDetent: Binding<DiveActivityOverviewDetent>,
        screenHeight: CGFloat,
        screenWidth: CGFloat,
        topSafeInset: CGFloat,
        bottomSafeInset: CGFloat
    ) -> some View {
        let resolvedScreenHeight = screenHeight > 1
            ? screenHeight
            : DiveActivityOverviewDetent.presentationReferenceScreenHeight
        let resolvedScreenWidth = screenWidth > 1
            ? screenWidth
            : DiveActivityOverviewDetent.presentationReferenceScreenWidth
        let resolvedBottomSafeInset = screenHeight > 1
            ? bottomSafeInset
            : DiveActivityOverviewDetent.presentationReferenceBottomSafeInset
        let resolvedTopSafeInset = screenHeight > 1
            ? topSafeInset
            : DiveActivityOverviewSheetLayoutContext.presentationReference.topSafeInset
        let detents = DiveActivityOverviewDetent.allPresentationDetents(
            screenHeight: resolvedScreenHeight,
            screenWidth: resolvedScreenWidth,
            topSafeInset: resolvedTopSafeInset,
            bottomSafeInset: resolvedBottomSafeInset
        )
        return presentationDetents(
            detents,
            selection: Binding(
                get: {
                    selectedDetent.wrappedValue.presentationDetent(
                        screenHeight: resolvedScreenHeight,
                        screenWidth: resolvedScreenWidth,
                        topSafeInset: resolvedTopSafeInset,
                        bottomSafeInset: resolvedBottomSafeInset
                    )
                },
                set: { newDetent in
                    guard
                        let matched = DiveActivityOverviewDetent(
                            presentationDetent: newDetent,
                            screenHeight: resolvedScreenHeight,
                            screenWidth: resolvedScreenWidth,
                            topSafeInset: resolvedTopSafeInset,
                            bottomSafeInset: resolvedBottomSafeInset
                        ),
                        matched != selectedDetent.wrappedValue
                    else { return }
                    selectedDetent.wrappedValue = matched
                }
            )
        )
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(
            .enabled(
                upThrough: DiveActivityOverviewDetent.large.presentationDetent(
                    screenHeight: resolvedScreenHeight,
                    screenWidth: resolvedScreenWidth,
                    topSafeInset: resolvedTopSafeInset,
                    bottomSafeInset: resolvedBottomSafeInset
                )
            )
        )
        .appSheetPresentationChrome()
        .presentationContentInteraction(.scrolls)
        .interactiveDismissDisabled()
    }
}

// MARK: - Scroll area

/// Tracks scroll offset locally; parent only receives one-shot expand / collapse callbacks.
struct OverviewPanelScrollArea<Content: View>: View {
    let restingDetent: DiveActivityOverviewDetent
    var layoutContext: DiveActivityOverviewSheetLayoutContext = .presentationReference
    let onExpand: () -> Void
    let onCollapseToMinimized: () -> Void
    var isScrollDisabled = false
    var topScrollFadeHeight: CGFloat = 0
    var usesOpaquePanelScrollFadeBackground = false
    /// Last known offset from **`DiveActivityOverviewUIStateStore`** when the binding was cleared during nested navigation.
    var fallbackScrollOffsetY: CGFloat = 0
    /// Forces a fresh **`ScrollView`** when overview tab content changes (map / tank / media).
    var contentIdentity: AnyHashable = "default"
    @Binding var persistedScrollOffsetY: CGFloat
    @ViewBuilder var content: () -> Content

    @State private var lastScrollOffsetY: CGFloat = 0
    @State private var didFireExpandThisGesture = false
    @State private var pendingDetentScrollTask: Task<Void, Never>?
    @State private var scrollRestorationInset: CGFloat = 0
    @State private var acceptsScrollOffsetPersistence = true

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if scrollRestorationInset > 0 {
                    Color.clear
                        .frame(height: scrollRestorationInset)
                        .accessibilityHidden(true)
                }
                content()
            }
        }
        .id(contentIdentity)
        .frame(maxHeight: .infinity, alignment: .top)
        .background {
            if usesOpaquePanelScrollFadeBackground, topScrollFadeHeight > 0 {
                AppOverviewSheetPanelBackground()
            }
        }
        .overviewPanelTopScrollFade(height: topScrollFadeHeight)
        .scrollDisabled(isScrollDisabled)
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y
        } action: { _, newOffset in
            if DiveActivityOverviewScrollRestoration.shouldIgnoreSuddenScrollResetToTop(
                proposedOffset: newOffset,
                persistedOffset: persistedScrollOffsetY,
                lastReportedOffset: lastScrollOffsetY
            ) {
                return
            }
            lastScrollOffsetY = newOffset
            if DiveActivityOverviewScrollRestoration.shouldPersistScrollOffsetBinding(
                proposedOffset: newOffset,
                acceptsPersistence: acceptsScrollOffsetPersistence
            ) {
                persistedScrollOffsetY = newOffset
            }
            handleScrollOffset(newOffset)
        }
        .onAppear {
            acceptsScrollOffsetPersistence = true
            applyScrollRestorationInsetIfNeeded()
        }
        .onChange(of: contentIdentity) { _, _ in
            scrollRestorationInset = 0
            lastScrollOffsetY = 0
            didFireExpandThisGesture = false
        }
        .onScrollPhaseChange { _, phase in
            guard phase == .idle || phase == .decelerating else { return }
            handleScrollEnded()
        }
        .onDisappear {
            acceptsScrollOffsetPersistence = false
            pendingDetentScrollTask?.cancel()
            let preserved = DiveActivityOverviewScrollRestoration.preservedScrollOffset(
                binding: persistedScrollOffsetY,
                lastReportedOffset: lastScrollOffsetY
            )
            if preserved > 4 {
                persistedScrollOffsetY = preserved
            }
            scrollRestorationInset = 0
        }
    }

    private func applyScrollRestorationInsetIfNeeded() {
        guard DiveActivityOverviewScrollRestoration.shouldApplyScrollRestorationInset(
            fallback: fallbackScrollOffsetY,
            persisted: persistedScrollOffsetY
        ) else {
            scrollRestorationInset = 0
            return
        }
        let target = DiveActivityOverviewScrollRestoration.effectiveScrollOffsetForRestoration(
            persisted: persistedScrollOffsetY,
            fallback: fallbackScrollOffsetY
        )
        if persistedScrollOffsetY < target {
            persistedScrollOffsetY = target
        }
        scrollRestorationInset = target
    }

    private func handleScrollOffset(_ offsetY: CGFloat) {
        if offsetY < 8 {
            didFireExpandThisGesture = false
        }

        guard DiveActivityOverviewPanelMetrics.shouldExpandFromScroll(
            restingFraction: restingDetent.resolvedHeightFraction(in: layoutContext),
            scrollOffsetY: offsetY,
            largeRestingFraction: DiveActivityOverviewPanelMetrics.largeHeightFraction(in: layoutContext)
        ), !didFireExpandThisGesture
        else { return }

        didFireExpandThisGesture = true
        scheduleDetentScrollAction(onExpand)
    }

    private func handleScrollEnded() {
        guard DiveActivityOverviewPanelMetrics.shouldCollapseFromScroll(
            restingFraction: restingDetent.resolvedHeightFraction(in: layoutContext),
            scrollOffsetY: lastScrollOffsetY,
            largeRestingFraction: DiveActivityOverviewPanelMetrics.largeHeightFraction(in: layoutContext)
        ) else { return }

        scheduleDetentScrollAction(onCollapseToMinimized)
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

// MARK: - Top scroll fade

private struct OverviewPanelTopScrollFadeModifier: ViewModifier {
    let height: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if height > 0, !reduceTransparency {
            content.mask {
                VStack(spacing: 0) {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black.opacity(0.28), location: 0.42),
                            .init(color: .black.opacity(0.72), location: 0.78),
                            .init(color: .black, location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: height)
                    Rectangle().fill(Color.black)
                }
            }
        } else {
            content
        }
    }
}

extension View {
    /// Soft top edge on overview panel scroll content instead of a hard clip.
    func overviewPanelTopScrollFade(height: CGFloat) -> some View {
        modifier(OverviewPanelTopScrollFadeModifier(height: height))
    }
}
