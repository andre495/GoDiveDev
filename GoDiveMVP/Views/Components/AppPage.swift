import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Measured scroll insets when **`AppPage`** uses **`scrollContentUnderHeader`**.
struct AppScrollUnderHeaderInsets: Equatable, Sendable {
    let top: CGFloat
    let bottom: CGFloat
}

private struct AppScrollUnderHeaderInsetsKey: EnvironmentKey {
    static let defaultValue: AppScrollUnderHeaderInsets? = nil
}

extension EnvironmentValues {
    var appScrollUnderHeaderInsets: AppScrollUnderHeaderInsets? {
        get { self[AppScrollUnderHeaderInsetsKey.self] }
        set { self[AppScrollUnderHeaderInsetsKey.self] = newValue }
    }

    /// When set, scroll-under lists report vertical offset for collapsible inline title chrome.
    var appCollapsibleInlineTitleHeaderScrollOffset: ((CGFloat) -> Void)? {
        get { self[AppCollapsibleInlineTitleHeaderScrollOffsetKey.self] }
        set { self[AppCollapsibleInlineTitleHeaderScrollOffsetKey.self] = newValue }
    }
}

private struct AppCollapsibleInlineTitleHeaderScrollOffsetKey: EnvironmentKey {
    static let defaultValue: ((CGFloat) -> Void)? = nil
}

struct AppPage<Content: View, TrailingContent: View>: View {
    let title: String
    let showsBackButton: Bool
    let showsBrandWordmark: Bool
    let titleUsesBrandForeground: Bool
    let titleUsesLinkedSiteAccent: Bool
    let titlePlacement: AppHeaderTitlePlacement
    let scrollContentUnderHeader: Bool
    /// Logbook-style **`.largeTitle`** inline with back / trailing actions; compacts on scroll.
    let collapsibleInlineTitleHeader: Bool
    /// Rising bubbles behind scroll-under list content (Logbook-style); requires **`scrollContentUnderHeader`**.
    let showsWaterBubbleBackground: Bool
    let content: Content
    let trailingContent: TrailingContent

    @State private var headerClearance: CGFloat = AppTheme.Layout.appHeaderClearanceFallback
    @State private var isCollapsibleHeaderCollapsed = false

    init(
        title: String,
        showsBackButton: Bool = false,
        showsBrandWordmark: Bool = true,
        titleUsesBrandForeground: Bool = false,
        titleUsesLinkedSiteAccent: Bool = false,
        titlePlacement: AppHeaderTitlePlacement = .centered,
        scrollContentUnderHeader: Bool = false,
        collapsibleInlineTitleHeader: Bool = false,
        showsWaterBubbleBackground: Bool = false,
        @ViewBuilder trailingContent: () -> TrailingContent,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.showsBackButton = showsBackButton
        self.showsBrandWordmark = showsBrandWordmark
        self.titleUsesBrandForeground = titleUsesBrandForeground
        self.titleUsesLinkedSiteAccent = titleUsesLinkedSiteAccent
        self.titlePlacement = titlePlacement
        self.scrollContentUnderHeader = scrollContentUnderHeader
        self.collapsibleInlineTitleHeader = collapsibleInlineTitleHeader
        self.showsWaterBubbleBackground = showsWaterBubbleBackground
        self.trailingContent = trailingContent()
        self.content = content()
    }

    var body: some View {
        Group {
            if scrollContentUnderHeader {
                scrollUnderHeaderBody
            } else {
                standardBody
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            AppTheme.Colors.screenBackgroundGradient
                .ignoresSafeArea()
        }
        .onPreferenceChange(AppHeaderMetrics.HeightKey.self) { height in
            if height > 0 { headerClearance = height }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationInteractivePopGestureForHiddenNavBar()
        .goDiveLeadingEdgeSwipePopOverlay(enabled: showsBackButton)
    }

    /// Logbook-style layout: list scrolls from the window top; inset = status bar + **`AppHeader`** row.
    /// Only the **list** ignores the top safe area — **`AppHeader`** stays in the safe area (same as Explore list).
    private var scrollUnderHeaderBody: some View {
        GeometryReader { proxy in
            let safeTop = AppScrollUnderHeaderListLayout.resolvedSafeAreaTop(proxy.safeAreaInsets.top)
            let safeBottom = AppScrollUnderHeaderListLayout.resolvedSafeAreaBottom(proxy.safeAreaInsets.bottom)
            let topInset = AppScrollUnderHeaderListLayout.listTopInset(
                safeAreaTop: safeTop,
                headerClearance: headerClearance
            )
            let bottomInset = AppScrollUnderHeaderListLayout.listBottomInset(safeAreaBottom: safeBottom)

            ZStack(alignment: .top) {
                if showsWaterBubbleBackground, !GoDiveUITestConfiguration.isActive {
                    WaterBubbleBackground()
                }

                content
                    .environment(
                        \.appScrollUnderHeaderInsets,
                        AppScrollUnderHeaderInsets(top: topInset, bottom: bottomInset)
                    )
                    .environment(\.appCollapsibleInlineTitleHeaderScrollOffset) { offset in
                        guard collapsibleInlineTitleHeader else { return }
                        isCollapsibleHeaderCollapsed = CollapsibleInlineTitleHeaderPresentation
                            .isCollapsed(forScrollOffset: offset)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                LogbookTopChromeScrim(
                    topObstructionHeight: topInset,
                    featherHeight: collapsibleInlineTitleHeader
                        ? CollapsibleInlineTitleHeaderPresentation.listScrollFadeFeatherHeight
                        : 52
                )
                    .padding(.top, -safeTop)
                    .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)
                    .zIndex(0.5)

                /// Absorbs list pans/taps in the chrome band so **`AppHeader`** controls stay tappable.
                Color.clear
                    .frame(height: topInset)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .contentShape(Rectangle())
                    .accessibilityHidden(true)
                    .zIndex(0.75)

                if collapsibleInlineTitleHeader {
                    CollapsibleInlineTitleHeader(
                        title: title,
                        isCollapsed: isCollapsibleHeaderCollapsed,
                        statusBarSafeAreaTop: safeTop
                    ) {
                        if showsBackButton {
                            SecondaryDestinationBackButton()
                        } else {
                            Color.clear.accessibilityHidden(true)
                        }
                    } trailing: {
                        trailingContent
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                    .zIndex(1)
                } else {
                    AppHeader(
                        title: title,
                        showsBackButton: showsBackButton,
                        showsBrandWordmark: showsBrandWordmark,
                        titleUsesBrandForeground: titleUsesBrandForeground,
                        titleUsesLinkedSiteAccent: titleUsesLinkedSiteAccent,
                        titlePlacement: titlePlacement,
                        statusBarSafeAreaTop: safeTop,
                        statusBarUsesListChromeFeather: true
                    ) {
                        trailingContent
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                    .zIndex(1)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private var standardBody: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, headerClearance)

                AppHeader(
                    title: title,
                    showsBackButton: showsBackButton,
                    showsBrandWordmark: showsBrandWordmark,
                    titleUsesBrandForeground: titleUsesBrandForeground,
                    titleUsesLinkedSiteAccent: titleUsesLinkedSiteAccent,
                    titlePlacement: titlePlacement,
                    statusBarSafeAreaTop: proxy.safeAreaInsets.top
                ) {
                    trailingContent
                }
                .zIndex(1)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

extension AppPage where TrailingContent == EmptyView {
    init(
        title: String,
        showsBackButton: Bool = false,
        showsBrandWordmark: Bool = true,
        titleUsesBrandForeground: Bool = false,
        titleUsesLinkedSiteAccent: Bool = false,
        titlePlacement: AppHeaderTitlePlacement = .centered,
        scrollContentUnderHeader: Bool = false,
        collapsibleInlineTitleHeader: Bool = false,
        showsWaterBubbleBackground: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title: title,
            showsBackButton: showsBackButton,
            showsBrandWordmark: showsBrandWordmark,
            titleUsesBrandForeground: titleUsesBrandForeground,
            titleUsesLinkedSiteAccent: titleUsesLinkedSiteAccent,
            titlePlacement: titlePlacement,
            scrollContentUnderHeader: scrollContentUnderHeader,
            collapsibleInlineTitleHeader: collapsibleInlineTitleHeader,
            showsWaterBubbleBackground: showsWaterBubbleBackground,
            trailingContent: {
                EmptyView()
            },
            content: content
        )
    }
}

enum AppScrollUnderHeaderListLayout {
    /// Same as Logbook / Explore: status bar + measured header chrome.
    static func listTopInset(safeAreaTop: CGFloat, headerClearance: CGFloat) -> CGFloat {
        resolvedSafeAreaTop(safeAreaTop) + headerClearance
    }

    static func listBottomInset(safeAreaBottom: CGFloat) -> CGFloat {
        resolvedSafeAreaBottom(safeAreaBottom) + AppTheme.Spacing.md
    }

    /// **`GeometryReader`** on a pushed **`NavigationStack`** destination often reports **0**; fall back to the key window inset (list still **`ignoresSafeArea(edges: .top)`**).
    static func resolvedSafeAreaTop(_ geometrySafeAreaTop: CGFloat) -> CGFloat {
        geometrySafeAreaTop > 0.5 ? geometrySafeAreaTop : windowSafeAreaTop
    }

    static func resolvedSafeAreaBottom(_ geometrySafeAreaBottom: CGFloat) -> CGFloat {
        geometrySafeAreaBottom > 0.5 ? geometrySafeAreaBottom : windowSafeAreaBottom
    }

    private static var windowSafeAreaTop: CGFloat {
        #if canImport(UIKit)
        keyWindowSafeAreaInsets?.top ?? 0
        #else
        0
        #endif
    }

    private static var windowSafeAreaBottom: CGFloat {
        #if canImport(UIKit)
        keyWindowSafeAreaInsets?.bottom ?? 0
        #else
        0
        #endif
    }

    #if canImport(UIKit)
    private static var keyWindowSafeAreaInsets: UIEdgeInsets? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .safeAreaInsets
    }
    #endif

    static let listRowSpacing = AppTheme.Spacing.md

    /// Horizontal inset for scroll-under list rows (matches Logbook / Explore).
    static let horizontalListRowInset = AppTheme.Spacing.lg

    static let horizontalRowInsets = EdgeInsets(
        top: 0,
        leading: horizontalListRowInset,
        bottom: 0,
        trailing: horizontalListRowInset
    )

    @MainActor
    static func topSpacerRow(height: CGFloat) -> some View {
        Color.clear
            .frame(height: height)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .accessibilityHidden(true)
    }

    @MainActor
    static func bottomSpacerRow(height: CGFloat) -> some View {
        Color.clear
            .frame(height: height)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .accessibilityHidden(true)
    }
}

// MARK: - Scroll-under list (read insets inside **`AppPage`** content only)

/// Logbook-style **`List`** with top/bottom spacers — must be a **descendant** of **`AppPage`** when **`scrollContentUnderHeader`** is on.
struct AppScrollUnderHeaderList<Rows: View>: View {
    @Environment(\.appScrollUnderHeaderInsets) private var scrollInsets
    @Environment(\.appCollapsibleInlineTitleHeaderScrollOffset) private var collapsibleScrollOffsetHandler

    let listAccessibilityIdentifier: String
    @ViewBuilder let rows: () -> Rows

    var body: some View {
        let topInset = scrollInsets?.top ?? AppTheme.Layout.appHeaderClearanceFallback
        let bottomInset = scrollInsets?.bottom ?? AppTheme.Spacing.md

        let list = List {
            AppScrollUnderHeaderListLayout.topSpacerRow(height: topInset)
            rows()
            AppScrollUnderHeaderListLayout.bottomSpacerRow(height: bottomInset)
        }
        .listStyle(.plain)
        .listRowSpacing(AppScrollUnderHeaderListLayout.listRowSpacing)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(edges: [.top, .bottom])
        .accessibilityIdentifier(listAccessibilityIdentifier)

        if let collapsibleScrollOffsetHandler {
            list.onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { offset, _ in
                collapsibleScrollOffsetHandler(offset)
            }
        } else {
            list
        }
    }
}

/// Empty state aligned with the first list row when scroll-under header is enabled.
struct AppScrollUnderHeaderEmptyState<Content: View>: View {
    @Environment(\.appScrollUnderHeaderInsets) private var scrollInsets
    @Environment(\.appCollapsibleInlineTitleHeaderScrollOffset) private var collapsibleScrollOffsetHandler

    @ViewBuilder let content: () -> Content

    var body: some View {
        let topInset = scrollInsets?.top ?? AppTheme.Layout.appHeaderClearanceFallback

        let scroll = ScrollView {
            content()
                .frame(maxWidth: .infinity)
                .padding(.top, topInset)
                .padding(.horizontal, AppTheme.Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

        if let collapsibleScrollOffsetHandler {
            scroll.onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { offset, _ in
                collapsibleScrollOffsetHandler(offset)
            }
        } else {
            scroll
        }
    }
}

#Preview {
    AppPage(title: "Home") {
        Spacer()
    }
}
