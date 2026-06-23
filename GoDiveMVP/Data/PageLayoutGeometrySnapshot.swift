import CoreGraphics
import Foundation

/// Pages that share the Home-style hero + overlapping blue sheet layout.
enum PageLayoutKind: String, Sendable, CaseIterable, Identifiable {
    case home
    case buddyDetail
    case tripDetail
    case layoutReference

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .home: "Home"
        case .buddyDetail: "Buddy detail"
        case .tripDetail: "Trip detail"
        case .layoutReference: "Layout reference"
        }
    }
}

/// Named vertical regions for describing layout tweaks in chat / specs.
///
/// Example: “Raise **`sheetSeam`** by 12pt” → increase **`hero.height`** or decrease **`stats.minimumBand`**.
enum PageLayoutRegion: String, Sendable, CaseIterable, Identifiable {
    case geometry
    case layoutStack
    case hero
    case sheetSeam
    case sheetSeamFromStackTop
    case sheetSeamFromStackBottom
    case sheetSeamFromGeometryBottom
    case sheetSeamFromScreenBottom
    case sheetBody
    case statsContent
    case statsMinimumBand
    case panelOverlap
    case tabBarReserve
    case safeAreaTop
    case safeAreaBottom
    case scrollBottomInset

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .geometry: "geometry"
        case .layoutStack: "layout.stack"
        case .hero: "hero"
        case .sheetSeam, .sheetSeamFromStackTop: "sheet.seamYFromStackTop"
        case .sheetSeamFromStackBottom: "sheet.seamYFromStackBottom"
        case .sheetSeamFromGeometryBottom: "sheet.seamYFromGeometryBottom"
        case .sheetSeamFromScreenBottom: "sheet.seamYFromScreenBottom"
        case .sheetBody: "sheet.body"
        case .statsContent: "stats.content"
        case .statsMinimumBand: "stats.minimumBand"
        case .panelOverlap: "panel.overlap"
        case .tabBarReserve: "tabBar.reserveBelowStack"
        case .safeAreaTop: "safeArea.top"
        case .safeAreaBottom: "safeArea.bottom"
        case .scrollBottomInset: "scroll.bottomInset"
        }
    }
}

/// One capture of hero + sheet layout numbers for Home / buddy / trip pages.
struct PageLayoutGeometrySnapshot: Sendable, Equatable {
    let pageKind: PageLayoutKind
    let screenWidth: CGFloat
    /// Raw **`GeometryReader`** height (full screen on pushed pages; tab content on Home).
    let geometryHeight: CGFloat
    /// **`VStack`** frame height for hero + **`HomeLifetimeStatsPanel`**.
    let layoutStackHeight: CGFloat
    let safeAreaTop: CGFloat
    let safeAreaBottom: CGFloat
    let heroHeight: CGFloat
    let statsPanelContentHeight: CGFloat
    let minimumStatsBand: CGFloat
    let panelOverlap: CGFloat
    /// Y from stack top where the rounded sheet visually starts (**`heroHeight - panelOverlap`**).
    let sheetSeamY: CGFloat
    /// Distance from stack bottom to the seam (**`layoutStackHeight - sheetSeamY`**).
    let sheetSeamYFromStackBottom: CGFloat
    /// Distance from **`GeometryReader`** bottom to the seam (stack top-aligned).
    let sheetSeamYFromGeometryBottom: CGFloat
    /// Distance from physical screen bottom to the seam (geometry bottom + root tab bar on Home).
    let sheetSeamYFromScreenBottom: CGFloat
    /// Remaining blue sheet band below the seam within **`layoutStackHeight`**.
    let sheetBodyHeight: CGFloat
    let tabBarLayoutHeight: CGFloat
    /// Gap below **`layoutStackHeight`** on pushed pages (tab bar zone on Home).
    let tabBarReserveBelowStack: CGFloat
    let scrollBottomInset: CGFloat?
    let showsHeroOverlap: Bool

    func value(for region: PageLayoutRegion) -> CGFloat? {
        switch region {
        case .geometry: geometryHeight
        case .layoutStack: layoutStackHeight
        case .hero: heroHeight
        case .sheetSeam, .sheetSeamFromStackTop: sheetSeamY
        case .sheetSeamFromStackBottom: sheetSeamYFromStackBottom
        case .sheetSeamFromGeometryBottom: sheetSeamYFromGeometryBottom
        case .sheetSeamFromScreenBottom: sheetSeamYFromScreenBottom
        case .sheetBody: sheetBodyHeight
        case .statsContent: statsPanelContentHeight
        case .statsMinimumBand: minimumStatsBand
        case .panelOverlap: panelOverlap
        case .tabBarReserve: tabBarReserveBelowStack
        case .safeAreaTop: safeAreaTop
        case .safeAreaBottom: safeAreaBottom
        case .scrollBottomInset: scrollBottomInset
        }
    }

    /// Copy/paste report for describing layout adjustments in chat.
    func layoutReport() -> String {
        var lines: [String] = [
            "# Page layout geometry — \(pageKind.rawValue)",
            "page=\(pageKind.displayName)",
            "screen.width=\(format(screenWidth))",
            "geometry.height=\(format(geometryHeight))  // GeometryReader",
            "layout.stack.height=\(format(layoutStackHeight))  // hero + sheet VStack frame",
            "safeArea.top=\(format(safeAreaTop))",
            "safeArea.bottom=\(format(safeAreaBottom))",
            "hero.height=\(format(heroHeight))",
            "panel.overlap=\(format(panelOverlap))",
            "hero.overlap.enabled=\(showsHeroOverlap ? "true" : "false")",
            "",
            "# Sheet seam — alignment template (compare across Home / buddy / trip)",
            "sheet.seamYFromStackTop=\(format(sheetSeamY))  // from top of layout.stack",
            "sheet.seamYFromStackBottom=\(format(sheetSeamYFromStackBottom))  // from bottom of layout.stack",
            "sheet.seamYFromGeometryBottom=\(format(sheetSeamYFromGeometryBottom))  // from GeometryReader bottom",
            "sheet.seamYFromScreenBottom=\(format(sheetSeamYFromScreenBottom))  // from screen bottom incl. tab bar on Home",
            "sheet.seamY=\(format(sheetSeamY))  // alias for sheet.seamYFromStackTop",
            "sheet.body.height=\(format(sheetBodyHeight))  // layout.stack - seam from stack top",
            "",
            "stats.content.height=\(format(statsPanelContentHeight))",
            "stats.minimumBand=\(format(minimumStatsBand))  // content + tabBarScrollInset",
            "tabBar.layoutHeight=\(format(tabBarLayoutHeight))",
            "tabBar.reserveBelowStack=\(format(tabBarReserveBelowStack))  // geometry - layout.stack (Home: 0)",
        ]
        if let scrollBottomInset {
            lines.append("scroll.bottomInset=\(format(scrollBottomInset))")
        } else {
            lines.append("scroll.bottomInset=—")
        }
        lines.append("")
        lines.append("# Regions (use these names when requesting layout changes)")
        for region in PageLayoutRegion.allCases {
            guard let value = value(for: region) else { continue }
            lines.append("\(region.shortLabel)=\(format(value))")
        }
        lines.append("")
        lines.append("# Align all three pages: match sheet.seamYFromScreenBottom (or sheet.seamYFromStackTop)")
        return lines.joined(separator: "\n")
    }

    private func format(_ value: CGFloat) -> String {
        String(format: "%.1f", value)
    }
}

/// Builds **`PageLayoutGeometrySnapshot`** from live layout inputs.
enum PageLayoutGeometryProbe: Sendable {

    nonisolated static func home(
        screenWidth: CGFloat,
        geometryHeight: CGFloat,
        safeAreaTop: CGFloat,
        safeAreaBottom: CGFloat,
        layoutStackHeight: CGFloat,
        heroHeight: CGFloat,
        statsPanelContentHeight: CGFloat,
        showsHeroOverlap: Bool = true
    ) -> PageLayoutGeometrySnapshot {
        snapshot(
            pageKind: .home,
            screenWidth: screenWidth,
            geometryHeight: geometryHeight,
            layoutStackHeight: layoutStackHeight,
            safeAreaTop: safeAreaTop,
            safeAreaBottom: safeAreaBottom,
            heroHeight: heroHeight,
            statsPanelContentHeight: statsPanelContentHeight,
            scrollBottomInset: nil,
            showsHeroOverlap: showsHeroOverlap
        )
    }

    nonisolated static func pushed(
        pageKind: PageLayoutKind,
        screenWidth: CGFloat,
        geometryHeight: CGFloat,
        safeAreaTop: CGFloat,
        safeAreaBottom: CGFloat,
        layoutStackHeight: CGFloat,
        heroHeight: CGFloat,
        statsPanelContentHeight: CGFloat = HomeOverviewLayout.heroLayoutStatsPanelContentHeight,
        scrollBottomInset: CGFloat? = nil,
        showsHeroOverlap: Bool = true
    ) -> PageLayoutGeometrySnapshot {
        snapshot(
            pageKind: pageKind,
            screenWidth: screenWidth,
            geometryHeight: geometryHeight,
            layoutStackHeight: layoutStackHeight,
            safeAreaTop: safeAreaTop,
            safeAreaBottom: safeAreaBottom,
            heroHeight: heroHeight,
            statsPanelContentHeight: statsPanelContentHeight,
            scrollBottomInset: scrollBottomInset,
            showsHeroOverlap: showsHeroOverlap
        )
    }

    nonisolated private static func snapshot(
        pageKind: PageLayoutKind,
        screenWidth: CGFloat,
        geometryHeight: CGFloat,
        layoutStackHeight: CGFloat,
        safeAreaTop: CGFloat,
        safeAreaBottom: CGFloat,
        heroHeight: CGFloat,
        statsPanelContentHeight: CGFloat,
        scrollBottomInset: CGFloat?,
        showsHeroOverlap: Bool
    ) -> PageLayoutGeometrySnapshot {
        let overlap = showsHeroOverlap ? HomeOverviewLayout.panelOverlap : 0
        let seamY = max(heroHeight - overlap, 0)
        let bodyHeight = max(layoutStackHeight - seamY, 0)
        let minimumBand = statsPanelContentHeight + HomeOverviewLayout.tabBarScrollInset
        let tabBarReserve = max(geometryHeight - layoutStackHeight, 0)
        let seamFromStackBottom = max(layoutStackHeight - seamY, 0)
        let seamFromGeometryBottom = max(geometryHeight - seamY, 0)
        let tabBarBelowGeometry = pageKind == .home ? HomeOverviewLayout.rootTabBarLayoutHeight : 0
        let seamFromScreenBottom = max(geometryHeight + tabBarBelowGeometry - seamY, 0)

        return PageLayoutGeometrySnapshot(
            pageKind: pageKind,
            screenWidth: screenWidth,
            geometryHeight: geometryHeight,
            layoutStackHeight: layoutStackHeight,
            safeAreaTop: safeAreaTop,
            safeAreaBottom: safeAreaBottom,
            heroHeight: heroHeight,
            statsPanelContentHeight: statsPanelContentHeight,
            minimumStatsBand: minimumBand,
            panelOverlap: overlap,
            sheetSeamY: seamY,
            sheetSeamYFromStackBottom: seamFromStackBottom,
            sheetSeamYFromGeometryBottom: seamFromGeometryBottom,
            sheetSeamYFromScreenBottom: seamFromScreenBottom,
            sheetBodyHeight: bodyHeight,
            tabBarLayoutHeight: HomeOverviewLayout.rootTabBarLayoutHeight,
            tabBarReserveBelowStack: tabBarReserve,
            scrollBottomInset: scrollBottomInset,
            showsHeroOverlap: showsHeroOverlap
        )
    }
}
