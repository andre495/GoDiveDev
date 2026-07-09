# Blue sheet layout — Home vs detail (measurement reference)

Use this doc when tweaking **Home** or **pushed detail** pages so you change the **right token** and keep hero/sheet seams aligned across the app.

**Related:** `blue_sheet_header_page.md` (template overview), `blue_sheet_detail_customizations.md` (per-page plug-ins)

---

## Shell entry points

| Style | Wrapper | Page examples | Layout mode |
|-------|---------|---------------|-------------|
| **Home (tab root)** | `BlueSheetTabRootPage` | `LogOverviewView` | `BlueSheetPageLayoutMode.tabRoot` |
| **Pushed detail** | `BlueSheetDetailPage` | Buddy, trip, dive site, species, reference, equipment | `BlueSheetPageLayoutMode.pushedDetail` |

Both delegate to **`BlueSheetPageShell`** → **`BlueSheetPageLayoutBuilder`** → **`BlueSheetHeaderPageLayout`**.

---

## Visual stack (shared)

```
┌──────────────────────────────────────┐  ← full screen (detail) or virtual full screen (Home tab + 49pt tab bar)
│ Status bar (hero bleeds under)       │
│ ┌──────────────────────────────────┐ │
│ │ Hero band (fixed heroHeight)     │ │  PushedHeroBand (detail) / carousel in band (Home)
│ │                                  │ │
│ ╭──────────────────────────────────╮ │  ← sheet rises over hero by panelOverlap (148pt)
│ │ HomeLifetimeStatsPanel (blue)    │ │
│ │  [top chrome overlay]            │ │
│ │  [pinned summary — detail only]  │ │
│ │  [body: stats grid | pager]      │ │
│ │  ··· page dots (detail) ···      │ │
│ ╰──────────────────────────────────╯ │
│ [root tab bar — Home only]           │
└──────────────────────────────────────┘
```

**VStack seam:** `spacing = -panelOverlap` between hero and panel (`BlueSheetHeaderPageLayout`).

---

## Shared proportion tokens (change both styles together)

These live in **`HomeOverviewLayout`** and are re-exported by **`BlueSheetPageProportions`**.  
**Changing these moves the hero band and/or sheet seam on Home and every detail page.**

| Token | Value | Role |
|-------|------:|------|
| `panelOverlap` | **148 pt** | How far the blue sheet rises over the hero; negative VStack spacing |
| `heroHeightToWidthRatio` | **0.77** | Width-based hero component |
| `heroBottomExtension` | **202 pt** | Extra hero height below ratio (media bleeds behind sheet) |
| `rootTabBarLayoutHeight` | **49 pt** | Home tab bar reserve; subtracted from pushed full-screen geometry |
| `tabBarScrollInset` | **16 pt** | Used in hero **cap** math (minimum stats band) |
| `pageIndicatorClearance` | **28 pt** | Detail pager dots above home indicator |

### Hero height formula

```text
naturalHero = screenWidth × heroHeightToWidthRatio + topSafeAreaInset + heroBottomExtension
minimumStatsBand = statsPanelContentHeight + tabBarScrollInset
maximumHero = viewportHeight - minimumStatsBand + panelOverlap
heroHeight = min(naturalHero, maximumHero)
```

**Builder:** `BlueSheetPageLayoutBuilder.heroHeight` / `heroMetrics`  
**Context:** `BlueSheetHeaderPageLayoutContext.heroHeight`

### Stats band height (seam math only)

Used to cap hero height — **not** the same as in-panel UI padding on Home.

| Config | Scroll content | + seam estimate padding | `panelContentHeight` |
|--------|---------------:|------------------------:|---------------------:|
| 2×2 grid only | **200 pt** | +40 (32 top + 8 bottom) | **240 pt** |
| 2×2 + Top buddies | **368 pt** | +40 | **408 pt** |

Source: **`HomeLifetimeStatsTilesLayout.panelContentHeight`** (seam estimates).  
Home UI padding is separate — see **Home-only content insets** below.

### Seam sync (detail ↔ Home)

| Mechanism | File |
|-----------|------|
| Default detail seam inputs | `HomeOverviewPushedLayoutPresentation.pushedPageSeamInputs()` |
| Home tab seam inputs | `HomeOverviewPushedLayoutPresentation.seamInputs(...)` in `LogOverviewView` |
| Published Home layout | `HomeOverviewLayoutAnchor.publishHomeTabRootLayout` |
| Detail hero latch | `BlueSheetPageLayoutBuilder` uses anchor when `matchingRootHeroHeight` matches |

**Rule:** Do not hand-roll hero height on any page. Read **`context.heroHeight`** only.

---

## AppTheme spacing (shared list inset)

| Token | pt |
|-------|---:|
| `AppTheme.Spacing.sm` | 8 |
| `AppTheme.Spacing.md` | 16 |
| `AppTheme.Spacing.lg` | 24 |

**Standard list / catalog horizontal inset:** **`AppTheme.Spacing.lg` (24 pt)** — logbook rows, explore lists, `AppPage` content.

---

## Home-only layout

### Files

| Concern | Primary types |
|---------|----------------|
| Tab shell | `BlueSheetTabRootPage`, `LogOverviewView` |
| Carousel | `HomeMediaCarouselSection`, `HomeMediaCarouselLayout` |
| Stats body | `HomeLifetimeStatsSection`, `HomeLifetimeStatsLayout` |
| Top chrome | `BlueSheetHomeTopChrome`, `BlueSheetTopChromePresentation.HomeHeroFade` |

### Geometry notes

| Concept | Behavior |
|---------|----------|
| Virtual full screen | Tab content height **+ 49 pt** tab bar → same coordinate space as pushed detail (803 → 852) |
| Layout frame | `HomeTabRootLayoutPresentation.stackFrameHeight` |
| Panel bottom inset | `tabBarClearance (49) + safeAreaBottom` via `panelBottomSafeAreaInset` |
| Horizontal inset | **`HomeLifetimeStatsPanel`** applies **`lg` (24 pt)** when `appliesHorizontalContentPadding == true` (tab root only) |

### Home hero / carousel (content tweaks — seam unchanged)

| Token | Value | File | Moves seam? |
|-------|------:|------|:-----------:|
| `slideChromeBottomInset` | `panelOverlap - md` → **132 pt** | `HomeMediaCarouselLayout` | No |
| `carouselContentHeight` | `heroBandHeight + topSafeAreaInset` when inside `PushedHeroBand` | `HomeMediaCarouselLayout` | No |
| `headerGradientHeight` | max(header, safe+56)+96 vs 52% hero | `HomeMediaCarouselLayout` | No |

### Home stats panel (content tweaks — seam unchanged)

| Token | Value | Notes |
|-------|------:|-------|
| `panelTopContentPaddingWhenOverlapping` | **16 pt** (`md`) | UI only |
| `panelTopContentPadding` (no overlap) | **24 pt** (`lg`) | Empty-state path |
| `panelBottomContentPadding` | **24 pt** (`lg`) | Above tab bar clearance |
| `panelTopCornerRadius` | **20 pt** | `AppTheme.Sheet.cornerRadius` |
| Stat tile height | **92 pt** | `HomeLifetimeStatsTilesLayout.statTileHeight` |
| Grid spacing | **16 pt** | |
| Buddy tile height | **152 pt** | Top buddies row |

### Home top chrome fade

| Token | Value |
|-------|------:|
| `HomeHeroFade.logbookScrimFeather` | **52 pt** |
| Uses brand status-bar scrim | yes |

---

## Detail-only layout

### Files

| Concern | Primary types |
|---------|----------------|
| Detail shell | `BlueSheetDetailPage` |
| Pager | `BlueSheetDetailPager`, `BlueSheetDetailPagerPresentation` |
| Pinned title | `BlueSheetPinnedSummary`, `BlueSheetDetailPagePinnedSummaryPresentation` |
| Top chrome | `BlueSheetDetailTopChrome`, `BlueSheetTopChromePresentation.DetailTopFade` |
| Hero fill helper | `BlueSheetDetailHeroBandFill`, `PushedDetailHeroHeaderView` |

### Pages on this shell

Buddy · Trip · Dive site · Species · Reference site — all use **`BlueSheetDetailPage`** + **`BlueSheetDetailPager`**.

### Geometry notes

| Concept | Behavior |
|---------|----------|
| Full-screen `GeometryReader` | Tab bar hidden (`hidesBottomTabBarWhenPushed`) |
| Hero viewport | `viewportHeightMatchingHomeTab(geometry)` — same **803 pt** band as settled Home |
| Stack frame height | Full pushed geometry height (sheet to screen bottom) |
| Panel bottom inset | **0** (scroll inset handles home indicator + page dots) |
| Horizontal inset | **`BlueSheetDetailPage`** applies **`lg` (24 pt)** on pinned + pager **`VStack`** |
| Panel horizontal inset | **Off** on detail (`appliesHorizontalContentPadding: false`) — avoids double **`lg`** |

### Detail pinned summary (content — seam unchanged)

| Token | Value | File |
|-------|------:|------|
| `horizontalPadding` | **24 pt** (`lg`) | `BlueSheetDetailPagePinnedSummaryPresentation` |
| `topPadding` | **16 pt** (`md`) | **`seamTopPadding`** — seam → first pinned row |
| `bottomPadding` | **16 pt** (`md`) | |
| Row spacing | **8 pt** (`sm`) | `BlueSheetPinnedSummaryPresentation.rowSpacing` → **`pinnedRowSpacing`** |

### Detail pager (content — seam unchanged)

| Token | Value | File |
|-------|------:|------|
| `scrollPageSpacing` | **24 pt** (`lg`) | `BlueSheetDetailPagerPresentation` |
| `tripScrollBottomInsetExtra` | **24 pt** (`lg`) | Trip pages only |
| Bottom scroll inset | `safeAreaBottom + pageIndicatorClearance (28)` | From `BlueSheetPageLayoutBuilder` → `context.bottomScrollInset` |

**Do not** add `.padding(.horizontal)` on pager sections — shell owns inset. Trip planned/buddy sections had duplicate **`md`** removed for this reason.

### Detail top chrome fade

| Token | Value |
|-------|------:|
| `DetailTopFade.statusBarFeather` | **22 pt** |
| Uses list status-bar scrim | yes |

### Buddy-only overlays (content)

| Token | Value | File |
|-------|------:|------|
| `profileAvatarDiameter` | **120 pt** | `DiveBuddyDetailPresentation` |
| `avatarLeadingInset` | **24 pt** (`lg`) | Aligns with list inset |
| `heroModeToggleBottomPadding` | `panelOverlap + md` → **164 pt** | Trip/buddy/site mode toggle |

---

## Side-by-side quick reference

| Measurement | Home | Detail |
|-------------|------|--------|
| Shell wrapper | `BlueSheetTabRootPage` | `BlueSheetDetailPage` |
| Hero content | Media carousel | Media / map / 3D / placeholder |
| Panel body | Lifetime stats grid (+ optional Top buddies) | Pinned summary + `BlueSheetDetailPager` |
| Horizontal content inset | `HomeLifetimeStatsPanel` → **24 pt** | `BlueSheetDetailPage` → **24 pt** |
| Panel applies own horizontal pad | **Yes** | **No** |
| Top chrome | GoDive wordmark + profile | Back + Edit |
| Top fade feather | **52 pt** (hero scrim) | **22 pt** (status bar only) |
| Root tab bar in layout | **Yes** (+49 pt virtual height) | **No** (full screen) |
| Page dots | No | Yes (+28 pt scroll clearance) |
| `PushedHeroBand` safe-area bleed | Carousel uses `carouselContentHeight` compensation | Hero views fill band |
| Seam / hero proportions | **Shared tokens** | **Shared tokens** |

---

## How to replicate a tweak across styles

### “Move the sheet seam” (hero ↔ panel boundary)

1. Edit **`HomeOverviewLayout`** tokens (`panelOverlap`, `heroHeightToWidthRatio`, `heroBottomExtension`) **or** stats band estimates in **`HomeLifetimeStatsTilesLayout.panelContentHeight`**.
2. Keep **`HomeLifetimeStatsLayout.panelOverlap`** / **`heroBottomExtension`** in sync (they re-export `HomeOverviewLayout`).
3. Rebuild — Home and all detail pages update together.
4. Verify **`HomeOverviewLayoutAnchor`** on device (push buddy from Home, compare seam).

### “Move content inside the blue panel” (does **not** move seam)

| Want to adjust | Home token | Detail token |
|----------------|------------|--------------|
| Content inset from screen edge | `HomeLifetimeStatsPanel` horizontal **`lg`** | `BlueSheetDetailPagePinnedSummaryPresentation.horizontalPadding` |
| Content lower/higher in panel | `panelTopContentPaddingWhenOverlapping`, `panelBottomContentPadding` | `topPadding` / `bottomPadding` on pinned block; pager has no extra top pad |
| Dive label on carousel | `HomeMediaCarouselLayout.slideChromeBottomInset` | — (detail uses pinned summary instead) |
| Pinned title spacing | — | `BlueSheetDetailPagePinnedSummaryPresentation` |
| Scroll section spacing | `HomeLifetimeStatsLayout.gridSpacing` | `BlueSheetDetailPagerPresentation.scrollPageSpacing` |

**Important:** Home UI padding (`HomeLifetimeStatsLayout.panelTopContentPaddingWhenOverlapping`, etc.) does **not** automatically update seam math. Seam uses **`HomeLifetimeStatsTilesLayout.panelContentHeight`**. If you change tile heights or grid rows for seam purposes, update **both** UI layout and tiles estimate.

### “Match list width on a new detail section”

- Use **no** horizontal padding on the section view.
- Rely on **`BlueSheetDetailPagePinnedSummaryPresentation.horizontalPadding`** (**`lg`**) on the shell.
- Compare to logbook: **`AppTheme.Spacing.lg`** from screen edge.

### “Match Home stats tile width on trip stats grid”

- Trip **`TripDetailTripStatsSection`** uses same **`HomeLifetimeStatsTilesLayout`** grid height/spacing.
- No extra horizontal padding on the section (shell inset only).

---

## Reference device math (iPhone ~393×852, ~59 pt safe top)

Illustrative settled values — actual **`heroHeight`** comes from the builder at runtime.

```text
Tab content viewport     ≈ 803 pt  (852 − 49 tab bar)
Virtual full screen      ≈ 852 pt  (Home tab-root layout frame)

naturalHero              ≈ 393×0.77 + 59 + 202 ≈ 564 pt
stats band (2×2)         ≈ 240 pt (+ 16 tabBarScrollInset in cap)
maximumHero            ≈ 803 − 256 + 148 ≈ 695 pt  → natural wins

Sheet seam from bottom ≈ heroHeight − panelOverlap
Carousel slide height  ≈ heroHeight + topSafeAreaInset (Home, inside PushedHeroBand)
Detail scroll bottom   ≈ safeAreaBottom + 28 (page dots)
Home panel bottom pad  ≈ 24 + 49 + safeAreaBottom
```

---

## File index (edit checklist)

| If you change… | Start here |
|----------------|------------|
| Hero height / overlap / extension | `HomeOverviewLayout.swift` |
| Builder / context / modes | `BlueSheetPageLayoutBuilder.swift`, `BlueSheetHeaderPageLayoutContext.swift` |
| Panel container | `HomeOverviewSections.swift` → `HomeLifetimeStatsPanel` |
| Home carousel chrome | `HomeOverviewSections.swift` → `HomeMediaCarouselLayout` |
| Home stats UI padding | `HomeOverviewSections.swift` → `HomeLifetimeStatsLayout` |
| Detail shell / pinned / pager inset | `BlueSheetDetailPage.swift`, `BlueSheetDetailPageConfiguration.swift` |
| Pager scroll spacing | `BlueSheetDetailPagerPresentation.swift` |
| Top chrome fades | `BlueSheetTopChromePresentation.swift` |
| Seam inputs / anchor | `HomeOverviewPushedLayoutPresentation.swift`, `HomeOverviewLayoutAnchor.swift` |
| Per-page plug-ins only | `blue_sheet_detail_customizations.md` |

---

## Tests to run after proportion changes

- `blueSheetPageProportions_reexportHomeOverviewLayoutTokens`
- `blueSheetPageLayoutBuilder_tabRootMatchesPushedHeroHeightWhenViewportAligned`
- `homeOverviewLayout_pushedHeroLayoutMetrics_*` (seam parity)
- `blueSheetDetailPagePinnedSummaryPresentation_shellHorizontalPaddingMatchesPagerInset`

After token edits, verify on **Home** and one **pushed detail** (e.g. buddy) on device — seam should match when navigating from Home.
