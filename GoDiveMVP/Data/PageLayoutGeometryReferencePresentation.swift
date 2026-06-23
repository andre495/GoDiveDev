import CoreGraphics
import Foundation

/// Copy + example snapshots for **`PageLayoutGeometryReferenceView`**.
enum PageLayoutGeometryReferencePresentation: Sendable {

    struct GlossaryEntry: Sendable, Identifiable {
        let id: String
        let term: String
        let definition: String
    }

    nonisolated static let pageTitle = "Layout geometry"
    nonisolated static let pageSubtitle =
        "Live region guides on a blank canvas — same overlay as Home / buddy / trip (Settings → Show page layout geometry)."

    nonisolated static let homeSectionTitle = "Home (main tab bar visible)"
    nonisolated static let homeSectionCaption =
        "GeometryReader height ends above the tab bar. tabBar.reserveBelowStack is 0 because the tab bar sits outside geometry."

    nonisolated static let pushedSectionTitle = "Buddy / trip (tab bar hidden)"
    nonisolated static let pushedSectionCaption =
        "GeometryReader fills the screen when the tab bar is hidden. layout.stack matches geometry height; hero height still uses the Home tab viewport so sheet.seamYFromScreenBottom matches Home."

    nonisolated static let seamSectionTitle = "Sheet seam distances"
    nonisolated static let seamSectionBody =
        "The red line is where the rounded blue sheet starts. Compare sheet.seamYFromScreenBottom across real pages to align all three."

    nonisolated static let exampleScreenWidth: CGFloat = 393
    nonisolated static let exampleSafeAreaTop: CGFloat = 59
    nonisolated static let exampleSafeAreaBottom: CGFloat = 34
    nonisolated static let exampleHeroHeight: CGFloat = 461
    nonisolated static let examplePushedGeometryHeight: CGFloat = 852
    nonisolated static let exampleHomeGeometryHeight: CGFloat = 803
    nonisolated static let examplePushedLayoutStackHeight: CGFloat = 852
    nonisolated static let exampleHomeLayoutStackHeight: CGFloat = 803
    nonisolated static let exampleStatsBand = HomeOverviewLayout.heroLayoutStatsPanelContentHeight

    nonisolated static var exampleHomeSnapshot: PageLayoutGeometrySnapshot {
        PageLayoutGeometryProbe.home(
            screenWidth: exampleScreenWidth,
            geometryHeight: exampleHomeGeometryHeight,
            safeAreaTop: exampleSafeAreaTop,
            safeAreaBottom: exampleSafeAreaBottom,
            layoutStackHeight: exampleHomeLayoutStackHeight,
            heroHeight: exampleHeroHeight,
            statsPanelContentHeight: exampleStatsBand
        )
    }

    nonisolated static var examplePushedSnapshot: PageLayoutGeometrySnapshot {
        PageLayoutGeometryProbe.pushed(
            pageKind: .buddyDetail,
            screenWidth: exampleScreenWidth,
            geometryHeight: examplePushedGeometryHeight,
            safeAreaTop: exampleSafeAreaTop,
            safeAreaBottom: exampleSafeAreaBottom,
            layoutStackHeight: examplePushedLayoutStackHeight,
            heroHeight: exampleHeroHeight,
            scrollBottomInset: 62
        )
    }

    nonisolated static let glossary: [GlossaryEntry] = [
        GlossaryEntry(
            id: "geometry",
            term: "geometry.height",
            definition: "Height of the page GeometryReader. Shorter on Home (above tab bar); taller when the tab bar is hidden on buddy/trip."
        ),
        GlossaryEntry(
            id: "layout.stack",
            term: "layout.stack.height",
            definition: "The hero + blue sheet VStack frame. On buddy/trip this matches full-screen geometry when the tab bar is hidden."
        ),
        GlossaryEntry(
            id: "hero",
            term: "hero.height",
            definition: "Media carousel, buddy tagged media, or trip map band at the top."
        ),
        GlossaryEntry(
            id: "sheet.seamYFromStackTop",
            term: "sheet.seamYFromStackTop",
            definition: "Distance from the top of layout.stack to the sheet seam (hero.height − panel.overlap). Same as sheet.seamY."
        ),
        GlossaryEntry(
            id: "sheet.seamYFromStackBottom",
            term: "sheet.seamYFromStackBottom",
            definition: "Distance from the bottom of layout.stack up to the sheet seam."
        ),
        GlossaryEntry(
            id: "sheet.seamYFromGeometryBottom",
            term: "sheet.seamYFromGeometryBottom",
            definition: "Distance from the GeometryReader bottom up to the sheet seam (stack is top-aligned)."
        ),
        GlossaryEntry(
            id: "sheet.seamYFromScreenBottom",
            term: "sheet.seamYFromScreenBottom",
            definition: "Distance from the physical screen bottom up to the seam. On Home, includes the 49pt tab bar below geometry."
        ),
        GlossaryEntry(
            id: "sheet.body",
            term: "sheet.body.height",
            definition: "Blue sheet area below the seam, still inside layout.stack."
        ),
        GlossaryEntry(
            id: "panel.overlap",
            term: "panel.overlap",
            definition: "Negative VStack spacing (148pt) so the sheet rides over the hero."
        ),
        GlossaryEntry(
            id: "tabBar.reserve",
            term: "tabBar.reserveBelowStack",
            definition: "Gap between layout.stack bottom and geometry bottom. 0 when layout.stack fills geometry (buddy/trip); 0 on Home (tab bar sits outside geometry)."
        ),
        GlossaryEntry(
            id: "stats.minimumBand",
            term: "stats.minimumBand",
            definition: "Minimum stats content plus 16pt breathing room used when computing hero height."
        ),
    ]
}
