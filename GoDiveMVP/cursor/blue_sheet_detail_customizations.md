# Blue sheet page — unified architecture & per-page customizations

**Goal:** One **layered shell** (hero band + blue sheet + top chrome slot). Pages differ only in what they **plug in**, not in layout math.

**Shell code:** `BlueSheetPageShell`, `BlueSheetPageLayoutBuilder`, `BlueSheetTabRootPage`, `BlueSheetDetailPage`  
**Layout math:** `HomeOverviewLayout`, `BlueSheetPageProportions`, `HomeOverviewLayoutAnchor`  
**Home vs detail measurements:** `GoDiveMVP/cursor/blue_sheet_home_vs_detail_layout.md`  
**Living spec:** this doc + `GoDiveMVP/cursor/blue_sheet_header_page.md`

---

## Layer model

```
Layer 0 — Shell frame          [Home + all detail pages]
         hero band slot, blue sheet container, top chrome slot, seam math

Layer 1 — Hero fill            [page-specific media / map / carousel / placeholder]

Layer 2 — Blue sheet body      [Detail: pinned summary + pager | Home: stats grid]

Layer 3 — Pager page content   [Detail only: lists, media, metadata, static tiles]
```

**Layer 0 is identical** on every page (proportions, overlap, panel chrome).  
**Layers 1–3** swap content without re-measuring geometry.

---

## Locked decisions (unification)

| Topic | Decision |
|-------|----------|
| **Buddy avatar** | **Buddy detail only** — seam overlay + pinned row spacer stay on `ViewDiveBuddyDetails`; no other page gets this component. |
| **Species / reference Edit** | **Edit disabled** for species (and reference) for now. Top chrome API must support **`isEditEnabled`** (or equivalent) so Edit can be turned on later without shell changes. |
| **Trip Share** | **Not in top chrome.** Trailing row matches other detail pages (back + edit only). Remove Share from trip pinned title during unification; Share placement deferred (future sheet / pager action). |
| **Reference site** | **One-tab pager** (same `BlueSheetDetailPager` chrome as multi-tab details), not a standalone scroll body. |
| **Equipment detail** | **One-tab pager** + photo hero (same shell as reference site); migrated from legacy full-page scroll. |
| **Certification detail** | **Two-tab pager** (Details → Instructor & shop) + front/back card hero toggle (hidden unless both photos); type badge above title; ocean-gradient letterbox behind card images. |
| **Detail top fade** | **Small fade** — distinct token from Home’s full hero chrome fade (`BlueSheetTopChromePresentation.detailFade` vs `.homeHeroFade`). |

---

## Layer 0 — Shared shell

| Responsibility | Implementation |
|----------------|----------------|
| Viewport + hero height + sheet seam | `BlueSheetPageLayoutBuilder` |
| Hero band wrapper | `PushedHeroBand` in `BlueSheetHeaderPageLayout` |
| Blue sheet container | `HomeLifetimeStatsPanel` |
| Overlap / tokens | `BlueSheetPageProportions` → `HomeOverviewLayout` |
| Pushed seam sync | `HomeOverviewLayoutAnchor` when Home has settled |
| Tab root vs pushed | `.tabRoot` / `.pushedDetail` in `BlueSheetPageLayoutMode` |

### Shell wrappers & slots

| Wrapper | Pages | Slots |
|---------|-------|-------|
| **`BlueSheetTabRootPage`** | Home | `hero`, `heroOverlay`, **`topChrome`**, `panelContent` |
| **`BlueSheetDetailPage`** | Buddy, trip, site, species, reference, equipment, certification | `hero`, `heroOverlay`, **`topChrome`**, `panelOverlay`, `pinnedContent`, `panelContent` |

**Rename (Phase 1):** detail `backChrome` → **`topChrome`** to match Home vocabulary.

**Shell-owned padding:** horizontal inset for pinned summary + pager lives in the shell only — pages must not add extra `.padding(.horizontal)` on pagers.

---

## Top chrome — per page

Same **slot**; different **plug-in**. Shared helpers, not one identical view.

### Fade tokens

| Token | Used on | Behavior |
|-------|---------|----------|
| **`homeHeroFade`** | Home | Status-bar scrim + stronger fade over hero (today’s logbook-style top scrim) |
| **`detailTopFade`** | All pushed details | **Small fade** at top of screen — status bar + short gradient under header row only |

### Chrome matrix

| Page | Leading | Trailing | Edit | Fade |
|------|---------|----------|------|------|
| **Home** | — | Profile avatar → Profile | — | **`homeHeroFade`** |
| **Buddy** | Back | Edit | Enabled | **`detailTopFade`** |
| **Trip** | Back | Edit | Enabled | **`detailTopFade`** |
| **Dive site** | Back | Edit | Enabled (when editable) | **`detailTopFade`** |
| **Species** | Back | Edit (disabled) | **Disabled** (scalable flag) | **`detailTopFade`** |
| **Reference site** | Back | Edit (disabled) | **Disabled** | **`detailTopFade`** |
| **Equipment** | Back | Edit | Enabled | **`detailTopFade`** |
| **Certification** | Back | Edit | Enabled | **`detailTopFade`** |

### Target helpers (Phase 1)

- **`BlueSheetHomeTopChrome`** — GoDive `AppHeader`, profile trailing, `homeHeroFade`.
- **`BlueSheetDetailTopChrome`** — back row, trailing **`BlueSheetDetailEditAction`** (enabled/disabled), `detailTopFade`.
- **`BlueSheetDetailEditAction`** — wraps `AppEditToolbarButton`; accepts `isEnabled` + optional `disabledAccessibilityHint` for species/reference.

**No per-page trailing extras** (no Trip Share in chrome, no one-off scrim toggles).

---

## Layer 1 — Hero band

| Rule | All pages |
|------|-----------|
| Height | From `BlueSheetHeaderPageLayoutContext.heroHeight` only |
| Top bleed | `PushedHeroBand` only — no inner safe-area hacks or duplicate `.frame(height:)` |
| Missing media | **Placeholder band** (muted fill) — never `showsHero: false` for layout (missing trip record excepted) |

| Page | Hero fill | Hero overlay |
|------|-----------|--------------|
| **Home** | Carousel or `HomeMediaCarouselEmptyPlaceholder` | Dive capsule, fish/buddy chips |
| **Buddy** | `DiveBuddyDetailHeroHeaderView` | Mode toggle when media + map |
| **Trip** | Media / map / both via `PushedDetailHeroHeaderView` | Mode toggle when map exists |
| **Dive site** | `PushedDetailHeroHeaderView` (`.diveSite`) | Mode toggle when media + pin |
| **Species** | Strategy: tagged media \| catalog image \| 3D (`FieldGuideMarineLifeRealityHeroView`) | Source toggle + mode toggle |
| **Reference site** | Map or map placeholder | — |
| **Equipment** | Photo or archive placeholder | — |
| **Certification** | Front/back card photo (ocean gradient letterbox) or seal placeholder | Front/back toggle when both photos exist |

---

## Layer 2 — Blue sheet body

### Detail pages (shared skeleton)

```
BlueSheetPinnedSummary     ← shared FORMAT (accent, title, subtitle)
BlueSheetDetailPager       ← shared tab strip + swipe + insets + bottom fade
```

| Component | Notes |
|-----------|--------|
| **`BlueSheetPinnedSummary`** | Single layout; pages supply text/views for accent / title / subtitle slots |
| **`BlueSheetDetailPager`** | Extract from four pager implementations; lazy mount hook preserved |
| **`panelOverlay`** | **Buddy only** — avatar circle on seam |

**Pinned content (data only):**

| Page | Accent | Title | Secondary | Extra in pinned |
|------|--------|-------|-----------|-----------------|
| Buddy | — | Display name | Shared dive count | Spacer for avatar width |
| Trip | Date range (trip accent) | Trip title | — | No Edit/Share (moved out) |
| Dive site | Dive count | Site name | Region / country | Star rating row |
| Species | Category · subcategory | Common name | Scientific name | — |
| Reference | — | Site name | Region / country | — |
| Equipment | Retired (when set) | Manufacturer + model | Gear type | — |
| Certification | — | Certification name | — | Type badge (`topRow` above title) |

### Home (unique blue body)

- **No** pinned summary — `HomeLifetimeStatsSection` starts at sheet top.
- **No** pager.
- Dynamic seam inputs (leaderboard) + anchor publish.

---

## Layer 3 — Pager tabs & page types

### Tab counts

| Page | Tabs |
|------|------|
| Buddy | Dives together · Trips together · Tagged media |
| Trip (not started) | Planned sites · Buddies |
| Trip (started) | Stats · Activities · Marine life · Buddies · Media |
| Dive site | Dive details · Dives here · Marine life · Tagged media |
| Species | About · Size & range · Tagged dives · Tagged media |
| **Reference site** | **Details** (single tab — same pager chrome) |
| **Equipment** | **Details** (single tab — metadata sections) |
| **Certification** | **Details** · **Instructor & shop** |

### Shared page building blocks

| Type | Component |
|------|-----------|
| Scroll / metadata | `BlueSheetHeaderScrollPageLayout.scrollPage` |
| Static centered | `BlueSheetHeaderScrollPageLayout.staticPage` |
| Dive list | `LinkedDiveLogbookListRows` |
| Marine life list | `ExploreDiveSiteMarineLifeListSection` (or shared list row) |
| Media gallery | `TripDetailMediaGallerySection` |

---

## Implementation phases

### Phase 1 — Chrome contract
- [x] Rename `backChrome` → `topChrome` on `BlueSheetDetailPage`
- [x] Add `BlueSheetTopChromePresentation` (`homeHeroFade`, `detailTopFade`)
- [x] Add `BlueSheetHomeTopChrome`, `BlueSheetDetailTopChrome`, `BlueSheetDetailEditAction`
- [x] Wire Home + all detail pages through helpers
- [x] Trip: remove Share from pinned title; no Share in chrome
- [x] Species/reference: Edit present but disabled via flag

### Phase 2 — Pinned summary
- [x] Add `BlueSheetPinnedSummary`
- [x] Migrate buddy / trip / site / species / reference pinned blocks
- [x] Remove duplicate horizontal padding from page pagers

### Phase 3 — Hero unification
- [x] Remove inner hero height frames (species, reference)
- [x] Trip always shows hero band (placeholder when no media/map)
- [x] Species hero strategies behind one band contract

### Phase 4 — Pager unification
- [x] Extract `BlueSheetDetailPager`
- [x] Reference site → one-tab pager (replace scroll-only body)
- [x] Wire existing content pagers through wrapper

### Phase 5 — Home alignment
- [x] Verify Layer 0 metrics match pushed detail on device
- [x] Anchor publish on every Home layout settle

### Phase 6 — Cleanup & tests
- [ ] Delete obsolete layout/scrim duplicates
- [ ] Tests: chrome enabled/disabled, pinned layout, hero height parity, reference single-tab pager

---

## Page reference (current → target)

### 0. Home — `LogOverviewView`

| Area | Target |
|------|--------|
| Shell | `BlueSheetTabRootPage` |
| Top chrome | `BlueSheetHomeTopChrome` — GoDive, profile, **homeHeroFade** |
| Hero | Carousel / placeholder + overlays |
| Blue body | `HomeLifetimeStatsSection` (unique) |
| Empty state | Outside shell (no hero/sheet) |

### 1. Buddy — `ViewDiveBuddyDetails`

| Area | Target |
|------|--------|
| Top chrome | Back + **Edit enabled**, **detailTopFade** |
| Panel overlay | **Avatar on seam (buddy-only)** |
| Pinned | `BlueSheetPinnedSummary` + avatar spacer |
| Pager | 3 tabs via `BlueSheetDetailPager` |

### 2. Trip — `TripDetailView`

| Area | Target |
|------|--------|
| Top chrome | Back + **Edit enabled** only (**no Share in chrome**) |
| Pinned | Title + date accent only (no inline actions) |
| Hero | Always on; placeholder when empty |
| Pager | 2 or 5 tabs via `BlueSheetDetailPager` |
| Share | **Deferred** — not in chrome or pinned row after unification |

### 3. Species — `FieldGuideMarineLifeDetailView`

| Area | Target |
|------|--------|
| Top chrome | Back + **Edit disabled** (scalable) |
| Hero | Media / catalog / 3D strategies |
| Pinned | Taxonomy + names via `BlueSheetPinnedSummary` |
| Pager | 4 tabs |

### 4. Dive site — `ExploreDiveSiteDetailView`

| Area | Target |
|------|--------|
| Top chrome | Back + Edit when editable |
| Pinned | Stars + count + name + location |
| Pager | 4 tabs |

### 5. Reference site — `ExploreReferenceSiteDetailView`

| Area | Target |
|------|--------|
| Top chrome | Back + **Edit disabled** |
| Hero | Map / placeholder |
| Pinned | Site name + location |
| Body | **One-tab pager** (Details) — metadata + reference copy |

### 6. Equipment — `ViewEquipmentDetails`

| Area | Target |
|------|--------|
| Top chrome | Back + **Edit enabled**, **detailTopFade** |
| Hero | **`EquipmentDetailHeroBand`** — photo or archive placeholder |
| Pinned | **`BlueSheetPinnedSummary`** — title, gear type, **Retired** accent when set |
| Body | **One-tab pager** — **`EquipmentDetailMetadataView`** (equipment, status, purchase, service, notes) |

### 7. Certification — `ViewCertificationDetails`

| Area | Target |
|------|--------|
| Top chrome | Back + **Edit enabled**, **detailTopFade** |
| Hero | **`CertificationDetailHeroBand`** — front/back photo letterboxed on ocean gradient, or seal placeholder |
| Hero overlay | **`CertificationDetailHeroSideToggle`** when both card faces exist |
| Pinned | **`BlueSheetPinnedSummary`** — type badge `topRow` above certification name |
| Body | **Two-tab pager** — Details (agency, number, date, dives since attained) · Instructor & shop |

---

## Cross-cutting (post-unification)

1. Extract generic **`PushedDetailContentPagerLayout`** — dedupe pager scroll chrome.
2. Unify tagged media grids where practical.
3. Keep **`blue_sheet_header_page.md`** in sync with this doc.

---

## Status

| Milestone | State |
|-----------|--------|
| Shell infrastructure (`BlueSheetPageShell`, builder, contexts) | Done |
| Pages on `BlueSheetDetailPage` / `BlueSheetTabRootPage` | Done |
| **Visual unification (this doc)** | **In progress** — Phase 1–5 done; Phase 6 next |
