import SwiftUI

/// Reusable **blue sheet header page** shell: optional media/map hero, overlapping blue sheet, scrollable panel body.
///
/// Reference: **`TripDetailView`**, **`ViewDiveBuddyDetails`**, **`GoDiveMVP/cursor/blue_sheet_header_page.md`**.
struct BlueSheetHeaderPageLayout<
    Hero: View,
    HeroOverlay: View,
    Panel: View,
    TopChrome: View,
    PanelOverlay: View
>: View {
    let context: BlueSheetHeaderPageLayoutContext
    let showsHero: Bool
    var usesProfileBubblePanelBackground: Bool = false

    @ViewBuilder var hero: () -> Hero
    @ViewBuilder var heroOverlay: () -> HeroOverlay
    @ViewBuilder var panel: () -> Panel
    @ViewBuilder var panelOverlay: () -> PanelOverlay
    @ViewBuilder var topChrome: (_ safeTop: CGFloat, _ topInset: CGFloat) -> TopChrome

    init(
        context: BlueSheetHeaderPageLayoutContext,
        showsHero: Bool,
        usesProfileBubblePanelBackground: Bool = false,
        @ViewBuilder hero: @escaping () -> Hero,
        @ViewBuilder heroOverlay: @escaping () -> HeroOverlay,
        @ViewBuilder panel: @escaping () -> Panel,
        @ViewBuilder topChrome: @escaping (_ safeTop: CGFloat, _ topInset: CGFloat) -> TopChrome,
        @ViewBuilder panelOverlay: @escaping () -> PanelOverlay
    ) {
        self.context = context
        self.showsHero = showsHero
        self.usesProfileBubblePanelBackground = usesProfileBubblePanelBackground
        self.hero = hero
        self.heroOverlay = heroOverlay
        self.panel = panel
        self.panelOverlay = panelOverlay
        self.topChrome = topChrome
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: showsHero ? -HomeLifetimeStatsLayout.panelOverlap : 0) {
                if showsHero {
                    PushedHeroBand(
                        height: context.heroHeight,
                        topSafeAreaInset: context.heroTopSafeAreaInset
                    ) {
                        hero()
                    }
                }

                HomeLifetimeStatsPanel(
                    overlapsMedia: showsHero,
                    bottomSafeAreaInset: context.panelBottomSafeAreaInset,
                    usesHomeDebugPanelTint: context.presentation == .tabRoot,
                    appliesHorizontalContentPadding: context.presentation == .tabRoot,
                    usesProfileBubbleBackground: usesProfileBubblePanelBackground
                ) {
                    panel()
                }
                .overlay(alignment: .topLeading) {
                    panelOverlay()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(1)
                .ignoresSafeArea(edges: .bottom)
            }
            .overlay(alignment: .top) {
                if showsHero {
                    heroOverlay()
                        .frame(
                            width: context.geometryWidth,
                            height: context.heroHeight,
                            alignment: .bottomTrailing
                        )
                        .zIndex(2)
                }
            }

            topChrome(context.safeTop, context.topInset)
        }
        .frame(width: context.geometryWidth, height: context.layoutHeight)
        .ignoresSafeArea(edges: .bottom)
        .animation(nil, value: context.heroHeight)
    }
}

extension BlueSheetHeaderPageLayout where PanelOverlay == EmptyView {
    init(
        context: BlueSheetHeaderPageLayoutContext,
        showsHero: Bool,
        @ViewBuilder hero: @escaping () -> Hero,
        @ViewBuilder heroOverlay: @escaping () -> HeroOverlay,
        @ViewBuilder panel: @escaping () -> Panel,
        @ViewBuilder topChrome: @escaping (_ safeTop: CGFloat, _ topInset: CGFloat) -> TopChrome
    ) {
        self.init(
            context: context,
            showsHero: showsHero,
            usesProfileBubblePanelBackground: false,
            hero: hero,
            heroOverlay: heroOverlay,
            panel: panel,
            topChrome: topChrome,
            panelOverlay: { EmptyView() }
        )
    }
}

// MARK: - Layout state (header clearance + push transition floors)

extension View {

    /// Wires the standard blue-sheet-header layout latches used by trip + buddy detail.
    func blueSheetHeaderPageLayoutState(
        headerClearance: Binding<CGFloat>,
        layoutSafeAreaTopFloor: Binding<CGFloat>,
        layoutViewportHeightFloor: Binding<CGFloat>,
        rawSafeTop: CGFloat,
        geometryHeight: CGFloat
    ) -> some View {
        modifier(
            BlueSheetHeaderPageLayoutStateModifier(
                headerClearance: headerClearance,
                layoutSafeAreaTopFloor: layoutSafeAreaTopFloor,
                layoutViewportHeightFloor: layoutViewportHeightFloor,
                rawSafeTop: rawSafeTop,
                geometryHeight: geometryHeight
            )
        )
    }
}

private struct BlueSheetHeaderPageLayoutStateModifier: ViewModifier {
    @Binding var headerClearance: CGFloat
    @Binding var layoutSafeAreaTopFloor: CGFloat
    @Binding var layoutViewportHeightFloor: CGFloat
    let rawSafeTop: CGFloat
    let geometryHeight: CGFloat

    func body(content: Content) -> some View {
        content
            .onPreferenceChange(AppHeaderMetrics.HeightKey.self) { height in
                guard height > 0, height != headerClearance else { return }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    headerClearance = height
                }
            }
            .onChange(of: rawSafeTop, initial: true) { _, resolvedTop in
                guard resolvedTop > layoutSafeAreaTopFloor else { return }
                layoutSafeAreaTopFloor = resolvedTop
            }
            .onChange(of: geometryHeight, initial: true) { _, height in
                let subtractedViewport = HomeOverviewLayout.viewportHeightMatchingHomeTab(from: height)
                let transitionViewport = HomeOverviewLayout.pushedHeroLayoutTransitionViewportCandidate(
                    from: height
                )
                guard subtractedViewport < transitionViewport else { return }
                guard transitionViewport > layoutViewportHeightFloor else { return }
                layoutViewportHeightFloor = transitionViewport
            }
    }
}

// MARK: - Scrollable pager page chrome inside the blue sheet

enum BlueSheetHeaderScrollPageLayout {

    /// Fills the sheet slot (stats grids, centered empty states) — matches **`TripDetailContentPager`** static pages.
    @ViewBuilder
    static func staticPage<Content: View>(
        bottomScrollInset: CGFloat,
        alignment: Alignment = .top,
        accessibilityIdentifier: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)

            Color.clear
                .frame(height: bottomScrollInset)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .homeSheetPanelBottomScrollFade()
        .optionalAccessibilityIdentifier(accessibilityIdentifier)
    }

    /// Vertically scrolling sheet body with bottom inset + material fade (lists, mosaics).
    @ViewBuilder
    static func scrollPage<Content: View>(
        bottomScrollInset: CGFloat,
        accessibilityIdentifier: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                content()
                    .frame(maxWidth: .infinity, alignment: .leading)

                Color.clear
                    .frame(height: bottomScrollInset + AppTheme.Spacing.lg)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollClipDisabled(false)
        .scrollDismissesKeyboard(.interactively)
        .ignoresSafeArea(edges: .bottom)
        .homeSheetPanelBottomScrollFade()
        .optionalAccessibilityIdentifier(accessibilityIdentifier)
    }
}

private extension View {
    @ViewBuilder
    func optionalAccessibilityIdentifier(_ identifier: String?) -> some View {
        if let identifier {
            accessibilityIdentifier(identifier)
        } else {
            self
        }
    }
}
