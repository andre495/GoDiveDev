# Change Log

Keep ongoing work under **one numbered section** until you explicitly say changes have been pushed to git; then start the **next number** for new work. The user marks **`(pushed)`** and will say when to open a new section — agents do not infer push state from git.

Agents: log work in the **latest open section** and update **`cursor/app_summary.md`** in the same effort (see **`.cursor/rules/changelog-app-summary-sync.mdc`**).

---

## 01 - 2026-05-08 **(pushed)**

- Added a new headerless page: `ViewSingleActivity`.
- Reorganized SwiftUI views into `Views/Pages` and `Views/Components`.
- Updated `cursor/rules.md` — do not create page content unless explicitly requested.
- `ViewSingleActivity` top sub-tabs: Overview, Details, Sightings, More; basic Overview scaffolding.

## 02 - Mock Data + SwiftData Binding **(pushed)**

- Mock-data pipeline (DTOs, loader, mapper, seeder); `dives_sample.json` seed on empty store.
- Bound `ViewSingleActivity` to SwiftData; `SeedingLaunchOverlay` for Debug seeding.

## 03 - Tab bar, secondary navigation, Home-only header **(pushed)**

- `hidesBottomTabBarWhenPushed()` on pushed flows; `SecondaryDestinationBackButton`.
- Home-only `AppHeader`; Logbook / Field Guide `AppHeaderlessPage` + `NavigationStack`.

## 04 - 06 **(pushed)**

**Summary:** Intermediate MVP batches (04–06). Detail lives in **`cursor/app_summary.md`** and prior git history.

---

## 07 - Logbook hub, FIT upload, delete confirm & UI-test launch **(pushed)**

**Summary:** **Logbook** lists **`DiveActivity`** (newest first), saved-dive count subhead, **`ActivityUploadView`** / **`.fit`** import, **`ViewSingleActivity`** source & import details, swipe delete with confirmation, **`-GoDiveUITest`** launch stability.

---

## 08 - Logbook delete modal & minimal activity row **(pushed)**

**Summary:** Centered delete modal (scrim + **Cancel** / **Delete**); minimal **`LogbookActivityRow`** (display name, **#**, date · depth · duration).

---

## 09 - UI test stability: serial scheme & merged launch test **(pushed)**

**Summary:** Test bundles not **`parallelizable`** across simulators; **`testLaunch`** merged into **`GoDiveMVPUITests.swift`**.

---

## 10 - Dive numbers, delete + renumber, logbook sort **(pushed)**

**Summary:** Persisted **`diveNumber`** with chained **`.fit`** assignment; delete + optional renumber; logbook newest-first with stable tie-break.

---

## 11 - FIT import overlay, logbook delete / renumber refinements **(pushed)**

**Summary:** **`ActivityUploadView`** import scrim + staged progress; async delete so modal dismisses before **`save()`**; **`diveNumberExplicitlyNone`** and related numbering refinements.

---

## 12 - UDDF import, post-import navigation, import overlay tuning **(pushed)**

**Summary:** **`.uddf`** decode/import alongside **`.fit`**; **`DiveFileImportOutcome`**; Logbook push to imported dive after success; import overlay timing tweaks.

---

## 13 - Dive profile **(pushed)**

**Summary:** **`DiveDepthProfileChart`** on **`DiveProfilePoint`** samples; touch-hold scrub drives overview hero row; **`DiveDepthProfileSeries`** + unit tests.

---

## 14 - Visual chrome, launch, navigation gestures **(pushed)**

**Summary:** **`WaterBubbleBackground`** (Canvas / TimelineView); **`screenBackgroundGradient`**; **`LaunchScreen.storyboard`**; Logbook header aligned with **`AppHeader`**; interactive pop + leading-edge swipe helpers.

---

## 15 - Import parity, tank/GPS, dive # setting, import & delete UX **(pushed)**

**Summary:** **`cursor/todo.md`** — UDDF ↔ FIT parity notes. **Import & models:** **`waterTempMinCelsius`**, bottom/surface times, profile **NDL / TTS / ascent**; **tank** on **`DiveActivity`** + **`DiveProfilePoint`** from **UDDF** and **FIT** (**`FitTankFieldImport`**, **`FitDecodeError`** for bad session/tank sensor counts, **SessionMesg** entry GPS when valid); **More** tab + **DTO/mapper**. **Settings** — **Automatically renumber dives** (**`AppUserSettings`**); **Logbook** — single **Delete** confirmation, **async** **`deletePermanently`** + **`Task.yield`** / list animation tweaks. **Add activity** — **`importOverlay`** set **before** the import **`Task`** so the scrim appears immediately; lighter overlay shadow. **`GoDiveMVPTests`** including **`SingleGasDiveSample.fit`**; **`cursor/app_summary.md`** updated with the same scope.

- **Data / decode:** **`DiveImportWaterTemperatureSummary`**, **`DiveImportFitUInt32Seconds`**, **`UddfDiveFileDecoder`** / **`FitDiveFileDecoder`** extensions above; **`UddfTankPressureConversion`** / volume helpers; **`FitTankFieldImport`**.
- **UI:** **`ViewSingleActivity`** (**More**), **`SettingsView`**, **`logbook.swift`**, **`activity_upload.swift`**, **`DiveActivityDeletion`**, **`DiveActivityDiveNumbering`**, **`AppUserSettings`**.
- **Tests / docs:** **`GoDiveMVPTests`** (tank XML, FIT helpers, **`fitDecoder_singleGasSample_*`**, **`applyAutomaticSequentialRenumberIfNeeded_*`**, async **`deletePermanently`**); **`cursor/app_summary.md`**.

---

## 16 - FIT profile extras, display units, top chrome **(pushed)**

**Summary:** FIT **`RecordMesg`** → **`DiveProfilePoint`**: **`heartRateBPM`**, **`po2Bars`**, **`n2Load`**, **`cnsLoad`** (+ existing depth/temp/NDL/TTS/ascent/tank PSI). JSON DTO/mapper, **More** dump, **`SingleGasDiveSample`** test for per-sample tank PSI. **Details → Gas** + logbook/chart strings use **`DiveQuantityFormatting`** and **`EnvironmentValues.diveDisplayUnitSystem`** from **Settings → Imperial** (**`AppUserSettings`** / **`ContentView`**). **Top chrome:** **`AppStatusBarEdgeScrim`** (status bar only); **`AppTopChromeBackground`** removed; Logbook uses **`AppHeader`** with **`showsBrandWordmark: false`** to match Home. **`toolbarBackground(.hidden)`** on hidden-nav roots unchanged.

- **Import / models / tests:** **`DiveProfile`**, **`DiveActivityDTO`**, **`DiveActivityMapper`**, **`FitDiveFileDecoder`**, **`view_single_activity`**, **`GoDiveMVPTests`**, **`cursor/todo.md`** (FIT table).
- **Display:** **`DiveDisplayUnitSystem`**, **`DiveQuantityFormatting`**, **`AppUserSettings`**, **`ContentView`**, **`settings`**, **`LogbookActivityRow`**, **`DiveDepthProfileChart`**, **`DiveActivity`** (gas helpers), unit tests **`diveQuantityFormatting_*`**, **`appUserSettings_*`**, **`diveActivity_gasDetailsLines_*`**.
- **Chrome:** **`AppHeader.swift`**, **`AppTheme`** (drop **`headerChromeTranslucentGradient`**), **`AppPage`**, **`log_overview`**, **`logbook`**, **`view_single_activity`**, **`AppHeaderlessPage`**; **`cursor/app_summary.md`**, **`cursor/rules.md`**, **`.cursor/rules/headerless-pages-default.mdc`**.

---

## 17 - Tab bar minimize, duplicate dive detection, delete UX **(pushed)**

**Summary:** **`tabBarMinimizeBehavior(.onScrollDown)`** on the root **`TabView`** (iOS 26, iPhone). **`DiveActivityDuplicateMatcher`** — same **`sourceDiveId`** or cross-format **fingerprint**; blocks import when a match exists; Logbook **Possible duplicate** hint. **Add activity:** import scrim set **synchronously** on file pick (**`Importing dive…`**), **`yieldForImportOverlayPaint`** + background file read before decode / **`persistImported*`** (duplicate check). **Logbook delete:** row removed **immediately** via **`optimisticallyRemovedActivityIDs`**; confirmation overlay dismissed **instantly** (**`dismissDeleteOverlayImmediately`**, no fade); optional detail pop in the same tick; **`deletePermanently`** yields before **`save()`**; **automatic renumber** runs in a separate **`.utility`** task (**`awaitPostDeleteRenumber: false`** in UI, **`true`** in tests).

- **Files:** **`ContentView.swift`**, **`DiveActivityDuplicateMatcher.swift`**, **`FitDiveFileImport`**, **`UddfDiveFileImport`**, **`activity_upload.swift`**, **`logbook.swift`** (Logbook **+** **44×44** pt tap target; **`confirmDeleteDive`** / **`visibleActivities`**), **`DiveActivityDeletion.swift`**, **`LogbookActivityRow.swift`**, **`GoDiveMVPTests`** (**`diveActivityDeletion_deferredRenumber_*`**), **`cursor/app_summary.md`**.

---

## 18 - Dive overview map (MapKit) + bottom panel **(pushed)**

**Summary:** **Map-first** single-dive screen and **Explore** tab (**muted** MapKit). Custom pin, dive/catalog coordinates, camera offset so the site stays visible above the panel. **Strava-style** bottom sheet (three detents, grabber + scroll snap rules, smoother drag/scroll). Sub-tabs on the dive screen removed for now; floating back button only. **UI tests** use a lightweight **`GoDiveUITestRootView`** so launch stays reliable on Simulator.

- **New / updated:** map + panel components, **`view_single_activity`**, **`explore`**, **`GoDiveMVPApp`** UI-test path, **`GoDiveMVPUITests`**.
- **Tests:** map presentation, coordinate resolver, panel metrics (**`GoDiveMVPTests`**).
- **Docs:** **`cursor/app_summary.md`**.

---

## 19 - Single-dive icon tabs + panel default 50% **(pushed)**

**Summary:** Default overview panel **~50%**. Transparent dive toolbar: back (**48×48** tap like Logbook **+**, **`overlay`** above map) + **equal-width** icon strip (**map** / **ScubaTankTab** / **camera**); **22** pt SF symbols; **`ScubaTankTab`** template uses **`fixedSize()`** + **`templateAssetMaxWidth`** so **`resizable()`** does not fill the tab cell (**`DiveActivityTabIcon`**). **Map** — shared sheet; **`adjustedMapCenter`** uses **live** bottom sheet height (incl. drag) + **top** dive-toolbar obstruction so the pin stays centered at **medium** and **minimized** detents. **Tank** — same sheet + reference **`DiveTankCylinderVisual`** (yellow/green, **end/start** PSI fill; **grabber** collapse animates drain, expand resets full); **`DiveActivityTankPanelSummary`** (**`profilePressureStats`**, **`remainingPressureFillFraction`**). **Swift 6 / tests:** **`DiveActivitySupportTypes`**, **`DiveLocationMapRegionSpec`**, **`DiveActivityDuplicateMatcher.Signature`** **`nonisolated`** **`==`**; **`logbook`** **`@MainActor`** **`duplicateActivityIds`**. **camera** placeholder.

- **UI / layout:** **`DiveActivityOverviewSheetLayout`** (**3-arg** `topContent`; grabber **collapse/expand** callbacks for tank animation), **`DiveOverviewPanelLayout`**, **`DiveActivityOverviewMapLayout`**, **`DiveLocationMapView`**, **`DiveLocationMapPresentation`**, **`DiveTankOverviewHeroView`**, **`DiveTankCylinderVisual`**, **`DiveActivityTankCollapsedSummary`**, **`DiveActivityTab`** / **`DiveActivityTabIcon`**, **`ScubaTankTab`**, **`view_single_activity`**, **`logbook.swift`**.
- **Data / matcher:** **`DiveActivityTankPanelSummary`**, **`DiveActivityDuplicateMatcher`**, **`DiveActivitySupportTypes`**, **`DiveLocationMapRegionSpec`**.
- **Tests / docs:** **`GoDiveMVPTests`** (map centering, tank panel summary incl. **`remainingPressureFillFraction`**, tab icon, duplicate matcher, etc.); **`cursor/app_summary.md`**.

---

## 20 - Native dive overview sheet (map + tank) **(pushed)**

**Summary:** Replaced the custom Strava-style bottom panel with a native SwiftUI **`.sheet`** on **map** and **tank** (**`presentationDetents`** ~20% / 50% / 85%). Full-bleed heroes stay behind the sheet; **`.thinMaterial`** at **0.86** opacity; detent transitions tuned for less lag.

- **`DiveActivityOverviewDetent`** + **`DiveActivityOverviewDetent+Presentation`:** app detents ↔ **`PresentationDetent`** (**`Set`**); obstruction height; **`nonisolated`** **`Equatable`** / **`Hashable`** (no SwiftUI on core enum).
- **`ViewSingleActivity`:** persistent **`.sheet`** (hidden on **camera**); **`DiveActivityOverviewSheetContent`** + **`diveActivityOverviewSheetPresentation`** (system grabber, **`presentationBackgroundInteraction`** through **medium**, **`.scrolls`**, **`interactiveDismissDisabled`**).
- **Removed:** custom drag **`DiveActivityOverviewSheetLayout`** shell, **`DiveActivityOverviewMapLayout`**.
- **Behavior kept:** scroll expand → **large** / pull-to-medium; tap minimized summary → **medium**; tank PSI drain on shorter detent.
- **Performance:** **`DiveLocationMapView`** — **`.id`** only on coordinate; **`cameraLayoutDetent`** reframes without animation; expanded panel stays mounted when minimized; debounced scroll detent callbacks; depth chart without **`drawingGroup`**; redundant detent binding updates skipped.
- **Swift 6:** **`nonisolated`** **`==`** on **`DiveCoordinate`**, **`DiveLocationMapRegionSpec`**, **`DiveActivityDuplicateMatcher.MatchReason`** / **`Match`** (**`+Equatable`**).
- **Tests:** **`diveActivityOverviewDetent_*`**; **`diveActivityOverviewPanelMetrics_*`** (unchanged).
- **Docs:** **`cursor/app_summary.md`**.

