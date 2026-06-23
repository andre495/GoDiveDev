# Blue sheet header page template

Reusable layout for **trip detail**, **buddy detail**, and future full-screen pushed pages that mirror Home:

- **Header band** — edge-to-edge media and/or map under the status bar (`PushedHeroBand`)
- **Blue sheet** — `HomeLifetimeStatsPanel` with rounded top corners, ocean gradient fill to the screen bottom
- **Scrollable body** — lists, grids, or horizontal `TabView` pager inside the sheet

**Canonical implementations:** `TripDetailView`, `ViewDiveBuddyDetails`  
**Shared components:** `BlueSheetHeaderPageLayout`, `BlueSheetHeaderPageLayoutBuilder`, `BlueSheetHeaderScrollPageLayout`  
**Agent rule:** `.cursor/rules/blue-sheet-header-page.mdc`

---

## Visual stack

```
┌─────────────────────────────┐
│  Status bar (hero bleeds)   │
│  ┌───────────────────────┐  │
│  │  Media / map header   │  │  ← PushedHeroBand (fixed heroHeight)
│  │                       │  │
│  ╭───────────────────────╮  │  ← panelOverlap (148pt) — sheet rises over hero
│  │ Blue sheet (rounded)  │  │  ← HomeLifetimeStatsPanel
│  │  Title / chrome       │  │
│  │  ┌─────────────────┐  │  │
│  │  │ Scroll / pager  │  │  │  ← BlueSheetHeaderScrollPageLayout
│  │  └─────────────────┘  │  │
│  │  ··· page dots ···    │  │
│  ╰───────────────────────╯  │
└─────────────────────────────┘
```

**Seam alignment:** Hero height must use `HomeOverviewLayout.pushedHeroLayoutMetrics` with the same `statsPanelContentHeight` + `showsBuddyLeaderboard` as Home (`HomeOverviewPushedLayoutPresentation.seamInputs` or `pushedPageSeamInputs`).

---

## Minimal new page skeleton

```swift
struct MyFeatureDetailView: View {
    @State private var headerClearance: CGFloat = AppTheme.Layout.appHeaderClearanceFallback
    @State private var layoutSafeAreaTopFloor =
        DiveBuddyDetailPresentation.initialPushedLayoutSafeAreaTopFloor()
    @State private var layoutViewportHeightFloor =
        DiveBuddyDetailPresentation.initialPushedLayoutViewportFloor()

    private var seamInputs: HomeOverviewPushedLayoutPresentation.SeamInputs {
        HomeOverviewPushedLayoutPresentation.pushedPageSeamInputs()
    }

    var body: some View {
        AppHeaderlessPage {
            GeometryReader { proxy in
                let rawSafeTop = AppScrollUnderHeaderListLayout.resolvedSafeAreaTop(
                    proxy.safeAreaInsets.top
                )
                let geometryHeight = max(proxy.size.height, 1)
                let heroHeight = BlueSheetHeaderPageLayoutBuilder.heroHeight(
                    geometryHeight: geometryHeight,
                    screenWidth: proxy.size.width,
                    topSafeAreaInset: HomeOverviewLayout.pushedHeroTopSafeAreaInset(
                        rawGeometrySafeTop: proxy.safeAreaInsets.top,
                        transitionSafeTopFloor: layoutSafeAreaTopFloor
                    ),
                    statsPanelContentHeight: seamInputs.statsPanelContentHeight,
                    showsBuddyLeaderboard: seamInputs.showsBuddyLeaderboard,
                    transitionViewportFloor: layoutViewportHeightFloor
                )
                let layout = BlueSheetHeaderPageLayoutBuilder.make(
                    proxy: proxy,
                    headerClearance: headerClearance,
                    layoutSafeAreaTopFloor: layoutSafeAreaTopFloor,
                    layoutViewportHeightFloor: layoutViewportHeightFloor,
                    heroHeight: heroHeight,
                    showsHero: true
                )

                BlueSheetHeaderPageLayout(
                    context: layout,
                    showsHero: true,
                    hero: {
                        PushedDetailHeroHeaderView(/* … */)
                    },
                    heroOverlay: {
                        // Optional PushedDetailHeroModeToggle
                        EmptyView()
                    },
                    panel: {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                            myTitleRow
                            BlueSheetHeaderScrollPageLayout.scrollPage(
                                bottomScrollInset: layout.bottomScrollInset
                            ) {
                                myScrollContent
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    },
                    backChrome: { safeTop, topInset in
                        myBackHeader(safeTop: safeTop, topInset: topInset)
                    }
                )
                .blueSheetHeaderPageLayoutState(
                    headerClearance: $headerClearance,
                    layoutSafeAreaTopFloor: $layoutSafeAreaTopFloor,
                    layoutViewportHeightFloor: $layoutViewportHeightFloor,
                    rawSafeTop: rawSafeTop,
                    geometryHeight: geometryHeight
                )
            }
        }
        .ignoresSafeArea(edges: [.horizontal])
        .hidesBottomTabBarWhenPushed()
    }
}
```

---

## Checklist

| Step | What |
|------|------|
| Shell | `AppHeaderlessPage` + `GeometryReader` + `BlueSheetHeaderPageLayout` |
| Hero height | `BlueSheetHeaderPageLayoutBuilder.heroHeight` + seam inputs from `HomeOverviewPushedLayoutPresentation` |
| Layout context | `BlueSheetHeaderPageLayoutBuilder.make` — do not hand-roll `layoutHeight` / `bottomScrollInset` |
| Push floors | Seed `layoutSafeAreaTopFloor` / `layoutViewportHeightFloor` from `DiveBuddyDetailPresentation.initialPushedLayout*`; apply `.blueSheetHeaderPageLayoutState` |
| Hero | `PushedHeroBand` via layout; optional `PushedDetailHeroHeaderView` + `PushedDetailHeroModeToggle` |
| Sheet | `HomeLifetimeStatsPanel(overlapsMedia:showsHero, bottomSafeAreaInset: 0)` |
| Scroll | `BlueSheetHeaderScrollPageLayout.scrollPage` or `.staticPage`; pass `context.bottomScrollInset` |
| Pager | `PushedDetailContentPagerLayout.tabPage` per `TabView` page; `.homeSheetPanelBottomScrollFade()` on each page |
| Tab bar | `.hidesBottomTabBarWhenPushed()` on the page root |

---

## When to use what

- **No hero** (placeholder / loading): `showsHero: false`, `VStack` spacing `0`, use `context.headerScrollClearance` spacer in panel for back header.
- **Map-only hero:** `PushedDetailHeroHeaderView` or `TripDetailMapView` inside `hero`; defer heavy map mount after first frame (trip pattern).
- **Horizontal pager:** `TabView` inside panel body; each page uses `BlueSheetHeaderScrollPageLayout` + `PushedDetailContentPagerLayout.tabPage`.
- **Overlapping avatar** (buddy): `.overlay` on `HomeLifetimeStatsPanel`, not on the hero.

---

## Do not

- Use `AppPage` / titled `AppHeader` for this layout — back chrome floats over the hero (see `tripDetailBackChrome` / `buddyDetailBackChrome`).
- Put `homeSheetPanelBottomScrollFade` on the outer `TabView` — apply per pager **page** so dots stay visible.
- Change `panelOverlap`, `heroLayoutStatsPanelContentHeight`, or hero math per screen — adjust `AppTheme` / `HomeOverviewLayout` globally.
- Skip `bottomScrollInset` — content must clear home indicator + page dots.
