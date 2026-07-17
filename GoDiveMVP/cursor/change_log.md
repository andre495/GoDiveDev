# Change Log

Keep ongoing work under **one numbered section** until that batch is **`(pushed)`** to git. After a successful **commit + push** you requested, the agent marks that section **`(pushed)`** and adds the **next** numbered header (empty, for new notes) — see **`.cursor/rules/changelog-mark-pushed-on-git-push.mdc`**.

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

---

## 21 - Dive overview map, sheet, tank, gas mix **(pushed)**

**Summary:** Dive overview **map** + **tank** tabs: native **`.sheet`** with shared frosted chrome, satellite map with per-detent pin framing and zoom, animated tank hero (full + gas label on **medium**, corner mini-tank + PSI drain on **minimized**, hidden on **large**). **Gas mix** on **`DiveActivity`** from FIT/UDDF import (**`oxygenMix`**, **`gasType`** Air/Nitrox); tank hero label and yellow/green cylinder fill follow O₂ % (default **21%** air). Sheet reaches the physical bottom edge; tab switches reset to **medium** detent.

### Map (dive overview + Explore)

- **`DiveLocationMapPresentation`:** **`targetPinScreenYFraction`** (pin centered in band above sheet); **`cameraDistanceMeters(for:)`** — **~1.2 km** minimized, **~6.2 km** medium/large; **`mapCameraDetent`** keeps camera at **medium** when sheet is **large**; latitude shift via **`latitudeShiftMultiplier`** (~0.52 on **medium**).
- **`DiveOverviewMapStyle`:** satellite **`MapStyle.imagery`** (dive overview, **Explore**, warm-up).
- **`DiveLocationMapView`:** **`DiveMapCameraLayoutContext`** — camera refreshes when coordinate, layout, sheet obstruction, or detent settle; deferred apply after layout; **`activity.id`** resets map between dives (fixes missing pin on first open).
- **`MapKitWarmup`** + **`MapKitWarmupView`:** one-time MapKit init at launch (skipped for UI tests).
- **`DiveMapCoordinateResolver.isUsable`:** **`nonisolated`** for Swift 6.
- **Tests:** **`targetPinScreenYFraction_*`**, **`cameraDistanceMeters_*`**, **`adjustedMapCenter_*`**, **`diveMapCameraLayoutContext_*`**, **`mapKitWarmup_*`**.

### Sheet (map + tank tabs)

- Native **`.sheet`** via **`diveActivityOverviewSheetPresentation`** — detents **~20% / ~50% / ~85%** as **`.height`** (fraction × screen + home-indicator inset), not safe-area-only **`.fraction`**.
- **`AppTheme.Sheet`** + **`appSheetPresentationChrome()`** — **`.thinMaterial`** at **0.64** opacity; background **`ignoresSafeArea(.bottom)`**; **`.cursor/rules/swiftui-sheet-standard.mdc`** for all future sheets.
- Removed **`DiveActivityOverviewPanelChrome`** (logic moved to **`AppSheetPresentation`** / **`AppTheme`**).
- **`DiveActivityOverviewDetent+Presentation`:** height-based detents from live **`screenHeight`** + **`bottomSafeInset`** on **`ViewSingleActivity`**.
- **Tab switch** (**map** / **tank** / **camera**): sheet returns to **medium** detent.

### Gas mix (import + model)

- **`DiveActivity`:** **`oxygenMix`** (percent), **`gasType`** (**Air** at ~21% O₂, else **Nitrox**); **`DiveGasMixImport`** normalizes UDDF **`<o2>`** (fraction→percent) and FIT **`DiveGasMesg.oxygen_content`**.
- **FIT:** **`FitDiveFileDecoder`** reads first **`dive_gas`** message; **UDDF:** **`gasdefinitions/mix`** + **`tankdata/link`** ref.
- **UI:** tank hero shows **`gasType`** + **`oxygenMix`** (**`tankHeroGasMixLabel`**, e.g. **Nitrox 32%**) or **No gas specified**; cylinder yellow/green split follows **`oxygenMix`** (default **21%** yellow when unknown); **Details → Gas** rows; DTO/mapper updated.
- **Tests:** **`diveGasMixImport_*`**, UDDF tank fixture gas assertions.

### Tank tab (hero + chrome)

- **`DiveTankOverviewHeroPresentation`** + **`TankHeroLayoutMetrics`:** **medium** — full cylinder + **`tankHeroGasMixLabel`** (**`gasType`** + **`oxygenMix`**, or **No gas specified**); **`DiveTankCylinderVisual`** yellow band = O₂ % (bottom), green = remainder; **minimized** — **~50%** scale, top-trailing, **56** pt extra downshift; animated **position** + **scale** (**0.45** s); **large** — hero hidden (**`showsTankHero`**), gradient only.
- PSI drain animation when snapping to **minimized** only (not **large** → **medium**).
- Full-bleed **`screenBackgroundGradient`** behind tank hero (**`ignoresSafeArea`**).
- **`ScubaTankTab`:** RGBA-trimmed asset, **@2x/@3x**, **`DiveActivityTabIcon.templateAssetSize`**.
- **Tests:** **`diveTankOverviewHeroPresentation_*`**, **`appTheme_sheet_*`**.

### Swift 6 / misc

- **`nonisolated`** on **`DiveActivityOverviewPanelMetrics`**, **`DiveLocationMapPresentation`**, **`DiveTankOverviewHeroPresentation`**, **`DiveMapCameraLayoutContext`**, **`DiveActivityOverviewDetent`** helpers.
- **Docs:** **`cursor/app_summary.md`**.

---

## 22 - Logbook delete renumber performance **(pushed)**

**Summary:** Logbook stays responsive on delete; **Logbook** / **Field Guide** bubbles; **`AppComingSoonPlaceholder`** on Field Guide and Profile. **#** labels come from chronology (not live **`diveNumber`** while auto-renumber is on), **`Equatable`** row snapshots avoid re-layout when background persist catches up, debounced background **`renumberAllChronologically`** for multi-delete. Single-dive **map** tab drops live MapKit before pop so back to Logbook is snappier when the overview sheet is up.

- **`AppComingSoonPlaceholder`** + **Field Guide** / **Profile** tab shells: centered icon + “Coming soon” copy; **`WaterBubbleBackground`** on Field Guide (UI-test skip) and Profile (existing).
- **`logbook.swift`:** **`WaterBubbleBackground`** in the root **`ZStack`** (same as **`LogOverviewView`**, hidden for UI tests).
- **`DiveActivityOverviewEmbeddedPanel`:** map/tank overview panel lives in the navigation destination (not a separate **`.sheet`**) so it slides off with the page on back; grabber + three detents reuse **`DiveActivityOverviewSheetContent`** / panel metrics. Grabber uses **continuous** height while dragging (no detent quantization), **`liveHeightFraction`** for minimized/expanded body, one-step snap via **`snappedHeightFractionAfterDrag`** (minimized ↔ medium ↔ large only), **`interactiveSpring`** on release.
- **`DiveLocationMapPresentation.adjustedMapCenter`:** uses live **`bottomContentMargin`** (panel + safe area) for visible-band math; latitude shift from **`targetPinScreenYFraction`** offset × camera-distance scale (fixes minimized pin sitting too high).
- **`DiveActivityOverviewMapTeardown`** + **`DiveOverviewMapTeardownPlaceholder`:** **`ViewSingleActivity`** swaps **`DiveLocationMapView`** for a gradient placeholder when teardown is requested (back, leading-edge pop strip, **`onDisappear`**); reset on appear.
- **`SecondaryDestinationBackButton`** / **`goDiveLeadingEdgeSwipePopOverlay`** / **`AppHeaderlessPage`:** optional **`onWillDismiss`** / **`leadingEdgePopOnWillDismiss`** hooks.
- **Tests:** **`diveActivityOverviewMapTeardown_showsLiveMap_untilRequested`**.

- **`DiveLogbookDisplay`** + **`DiveLogbookRowDisplayData`:** chronological **#** when Settings → auto renumber; **`LogbookActivityRow`** uses equatable row data.
- **`DiveActivityDeletion`:** partial noop skip; tests await partial renumber; UI schedules **`DivePostDeleteRenumberScheduler`** (300 ms debounce → background full renumber).
- **`DiveBackgroundRenumberingWorker`** (**`@ModelActor`**) for Swift 6–safe off–main-actor persist; UI scheduler + **`DiveActivityPostDeleteRenumbering`** call the worker; **`deletePermanently(..., awaitPostDeleteRenumber: true)`** uses main-context partial renumber so tests see updated **`diveNumber`** on the same **`ModelContext`**.
- **Tests:** **`diveLogbookDisplay_*`**, delete / renumber / post-delete renumber tests.
- **Docs:** **`cursor/app_summary.md`**.

---

## 23 - Disable launch mock seeding **(pushed)**

**Summary:** Bundled **`dives_sample.json`** no longer loads on app launch; **`SeedingLaunchOverlay`** removed from startup. **`MockDataSeeder`** remains for opt-in Debug use.

- **`MockDataSeeding.isLaunchSeedingEnabled`** — default **`false`**; **`GoDiveMVPApp`** skips **`MockDataSeeder`** and shows **`ContentView`** immediately.
- **`MockData/README.md`**, **`DiveSiteReviewIndicator`** comment updated.
- **Test:** **`mockDataSeeding_launchSeedingDisabledByDefault`**.

---

## 24 - Sign in with Apple + local user profile **(pushed)**

**Summary:** Lightweight accounts: **`SignInView`** (native **Sign in with Apple**), **`UserProfile`** in SwiftData, **`AccountSession`** gates **`ContentView`**, Profile shows name + sign out; dives link via **`owner`** / **`ownerProfileID`**.

- **`UserProfile`** model; **`UserProfileStore`**, **`AccountSession`**, **`DiveActivityOwnership`**; **`AppSwiftDataSchema`** shared container schema.
- **`AppSessionRootView`** + **`SignInView`**; **`GoDiveMVP.entitlements`** (Sign in with Apple).
- **Logbook** / **`.fit`** / **`.uddf`** import scope dives and duplicate checks to the signed-in profile; unowned dives claimed on sign-in.
- **Profile** replaces coming-soon placeholder with centered large display name + **Rescue Diver** subtitle; red **Sign out** at bottom (no Apple sign-in copy).
- **`SignInView`:** **`GoDiveLogoPin`** (128×128, same asset as launch screen) above title; tagline **Log every dive. Explore marine life. Connect with buddies.**; full-screen **`surface`** scrim over bubbles for legibility.
- **Tests:** **`userProfileStore_*`**, **`diveActivityOwnership_*`**; import tests pass **`owner`** (or assert sign-in gate); **`UserProfileStore`** keeps display name on re-sign-in unless still default **Diver**.
- **Home (`LogOverviewView`):** **`AppComingSoonPlaceholder`** for upcoming dashboard features.

---

## 25 - Tank hero minimized depth + gas profile chart (pushed)

**Summary:** At the **minimized** tank sheet detent, a large centered depth + gas profile sits in the hero band; yellow gas line uses **ending PSI** as **y = 0**; touch-and-hold scrub shows depth and pressure.

- **`DiveDepthProfileOverlayChart`** + **`DiveDepthProfileOverlayChartLayout`** — depth (accent) + yellow **PSI above ending pressure**; scrub callout for depth + nearest sample pressure; gas line omitted without two PSI samples.
- **`DiveDepthProfileSeries.pressureSamples`**; centered **`minimizedProfileChartFrame`**; **`DiveTankOverviewHeroView`** passes **`pressureBaselinePSI`** (**`tankPressureEndPSI`**).
- **Tests:** **`diveDepthProfileSeries_pressureSamples_*`**, **`diveTankOverviewHeroPresentation_*`**, **`diveDepthProfileOverlayChartLayout_*`**.
- **Map panel:** **Notes** editor (shared **`notesBinding`**) when overview sheet is at **large** detent.
- **`DiveActivityOverviewPanelMetrics.panelContentTopPadding`** — space below grabber for expanded + minimized overview sheet content.
- **Tank minimized hero:** **`DiveTankMinimizedGasSummary`** — left-aligned header-style **PSI used** + **SAC** / **RMV** from **`avgSAC`** / **`avgRMV`** when import provides tank pressures, time, and depth.
- **`avgSAC`** / **`avgRMV`** on **`DiveActivity`** (**psi/min**, **L/min**); **`DiveSACRMVCalculation`** (Scuba Scribbles single-tank formulas); computed in **`.fit`** / **`.uddf`** decoders + seed mapper. **Tests:** **`diveSACRMVCalculation_*`**, import regressions.
- **`AppTheme.Colors.tankGasAccent`** — shared yellow for profile gas line, cylinder band, and minimized **PSI / SAC / RMV** values (labels stay primary).
- Minimized cylinder **`minimizedTrailingInset`** **56** (further left); gas summary uses **`HStack`** inline text (no deprecated **`Text`** **`+`**).

---

## 26 - Equipment Locker placeholder + model **(pushed)**

**Summary:** **Equipment Locker** with banner **Add new equipment**, native sheet form, and SwiftData **`EquipmentItem`** persistence.

- **`EquipmentLockerView`** — header **+** (logbook-style), elevated list rows (photo thumb, title, type, retired); destination links on Home stack.
- **`EquipmentAddSheetView`** + **`equipmentAddSheetPresentation()`** — **`.large`** sheet, **`appSheetPresentationChrome()`**, **`Form`** for all **`EquipmentItem`** fields + **`PhotosPicker`**; **Save** creates row for signed-in **`UserProfile`**.
- **`EquipmentItemFormValues`** — draft mapping + **`canSave`** (manufacturer + model required). **Tests:** **`equipmentItemFormValues_*`**, **`equipmentItem_*`**, **`equipmentItemOwnership_*`**.
- **Service schedule:** **Recurring service** toggle shows **next service date** + **Every** *n* **days/weeks/years**; off clears **`nextServiceDate`**, **`serviceRecurrenceDays`**, and **`serviceDate`**. **`EquipmentServiceSchedule`**.
- **Equipment Locker:** swipe **Delete** + confirmation modal (logbook pattern); **`EquipmentItemDeletion`**. **Tests:** **`equipmentItemDeletion_*`**.
- **`ViewEquipmentDetails`** (**`view_equipment_details.swift`**) — tap row → detail sections; **Edit** opens **`EquipmentEditSheetView`**. Shared **`EquipmentItemFormContent`**; **`EquipmentItemFormValues`** **`init()`** / **`init(from:)`** / **`apply(to:)`**.
- **Locker → detail navigation:** destination-style row **`NavigationLink`** on Home’s stack (Profile → Locker → Detail); no nested **`NavigationStack`** (nested stack caused back-to-detail to pop to Home and first-open locker glitch).
- **`EquipmentItem`** model; **`ProfileView`** link; **`EquipmentItemOwnership`**; **`AppSwiftDataSchema`**.

---

## 27 - Certifications model + list / add / edit **(pushed)**

**Summary:** SwiftData **`Certification`** with Profile → list → detail, add/edit sheets (equipment pattern), primary-card handling.

- **`Certification`** — **`certName`** (title, e.g. Rescue Diver), **`agency`**, **`certNumber`**, **`dateAttained`**, instructor fields, **`diveShop`**, **`isPrimaryCert`**, front/back **`Data?`** photos.
- **`UserProfile.certifications`** cascade; **`CertificationOwnership`**, **`CertificationDeletion`**, **`setAsPrimary`**.
- **`CertificationsListView`** — header **+** (logbook-style), rows (thumb, primary badge), swipe delete; destination links on Home stack.
- **`CertificationAddSheetView`** / **`CertificationEditSheetView`** + **`CertificationFormContent`** + **`certificationAddSheetPresentation()`**.
- **`ViewCertificationDetails`** — read-only sections + **Edit**; **`ProfileView`** **Certifications** link.
- **Tests:** **`certification_*`**, **`certificationOwnership_*`**, **`certificationDeletion_*`**, **`certificationFormValues_*`**, **`certificationPresentation_*`**.
- **Profile subtitle:** **`CertificationPresentation.profileCertificationSubtitle`** — newest primary **`certName`**, else **GoDive User** (replaces static **Rescue Diver**).
- **Profile layout:** dark bubble scrim; **Certifications** / **Equipment Locker** as square tiles anchored above **Sign out**.

---

## 28 - Profile photo **(pushed)**

**Summary:** **`UserProfile.profilePhoto`** with circular avatar on **Profile** and **Home**, crop-before-save, and dive count subtitle.

- **`UserProfile.profilePhoto`** — **`Data?`** bytes (equipment/cert photo pattern).
- **`ProfileAvatarEditor`** — 120pt circle; camera badge to add/change photo (no separate remove control).
- **Profile** dive total under certification subtitle (**`ProfilePresentation.diveActivityCountLabel`**).
- **`ProfilePhotoCropSheet`** + **`ProfilePhotoCropRenderer`** — pinch/drag position and zoom before save (circular JPEG).
- **`ProfileAvatarView`** — shared circle photo or **`person.circle.fill`** default; **Home** header profile link uses saved photo.
- **Tests:** **`userProfile_persistsProfilePhoto`**, **`profilePhotoCropRenderer_*`**.

---

## 29 - Dive equipment association **(pushed)**

**Summary:** Link gear to dives via **`DiveActivityEquipmentList`** / **`DiveEquipmentEntry`**; **`autoAdd`** gear attaches on new dive import; **`divesUsedOn`** on **`EquipmentItem`**. Data + import/delete wiring only (no UI).

- **`DiveActivityEquipmentList`**, **`DiveEquipmentEntry`** — per-dive list with equipment pointers; denormalized IDs.
- **`EquipmentItem.divesUsedOn`** — computed from **`diveEquipmentEntries`** (SwiftData does not persist **`[UUID]`** on **`@Model`**).
- **SwiftData inverses** — only the “child” side declares **`inverse:`** (**`DiveEquipmentEntry`**, **`DiveActivityEquipmentList.dive`**); parents use **`deleteRule`** only (**`DiveActivity.equipmentList`**, **`DiveActivityEquipmentList.entries`**, **`EquipmentItem.diveEquipmentEntries`**).
- **`DiveActivityEquipmentAssociation`** — link / unlink / **`applyAutoAdd`** / cleanup on dive or gear delete.
- **Import:** **`FitDiveFileImport`** / **`UddfDiveFileImport`** call **`applyAutoAdd`** after insert.
- **Tests:** **`diveActivityEquipmentAssociation_*`**.
- **`ViewEquipmentDetails`** — **Dives used on** row in **Status** (**`EquipmentItemPresentation.divesUsedOnLabel`**).
- **Tank tab** — **`DiveActivityTankEquipmentSection`**: linked gear list + **+** sheet (**`DiveActivityAddEquipmentSheet`**) for non-retired locker items not yet on the dive.

---

## 30 - Dive map pin reliability **(pushed)**

**Summary:** Fix intermittent missing dive location pin when opening or returning to the **map** tab.

- **`DiveLocationMapView`** — reset camera context on appear / coordinate change; refresh when coordinate identity updates.
- **`ViewSingleActivity`** — **`mapViewIdentity`** remounts map when dive or resolved coordinate changes; clear teardown placeholder when opening **map** tab or switching dives (removed **`onDisappear`** teardown that could leave placeholder stuck).
- **Tests:** **`diveLocationMapPresentation_mapViewIdentity_changesWithCoordinate`**.
- **Embedded overview panel** — **`AppTheme.Sheet.embeddedOverviewMaterialOpacity`** (**0.82**) on **map** / **tank** sheet (modal sheets stay **0.64**).
- **Tab switch** — **`selectActivityTab`** resets to **medium** before rendering **tank** (fixes flash of minimized depth chart when leaving **map** at low detent).
- **Dive map pin** — **`DiveLocationMapRepresentable`** (**`MKMapView`**) replaces SwiftUI **`Map`** + **`Annotation`** so the custom pin and site callout stay visible when the camera moves.
- **`DiveSiteMapAnnotationView`** — pin only (no on-map label); dive site name is the overview sheet header (**`DiveActivityOverviewPresentation.siteHeaderTitle`**).
- **`DiveLocationMapRepresentable`** — pin **`ImageRenderer`** uses **`mapView.traitCollection.displayScale`** (cached per scale) instead of deprecated **`UIScreen.main`**.
- **Tank volume** — **`DiveActivityTankDefaults`** / **`DefaultTankSize`**; imports / seed / RMV use rated surface liters; UI no longer mis-converts UDDF **80 L** or FIT **volume used** strings.
- **Settings → Default tank** — **`DefaultTankSize`** picker (**AL80**, **AL63**, **ST100**, **ST120**); material + rated **cu ft** on import and gas detail rows when the file omits them.

---

## 31 - Dive user log and profile name on sign-in **(pushed)**

**Summary:** Manual **Conditions** / **Operator** log on dives (map overview, large detent); read-only dive detail sections; profile display name from Apple sign-in with cache and fallback prompt.

- **`DiveCurrentStrength`**, **`DiveVisibilityRating`** — segmented pickers; strings for surface, entry, operator, divemaster.
- **`DiveSignaturePadView`** — **PencilKit** canvas; **`diveSignatureData`** (**`PKDrawing`** bytes).
- **`DiveActivityUserLogSection`** — map tab, **large** detent only; read-only **Your log** rows in **`DiveActivityDetailsPresentation`** when set.
- **Tests:** **`diveActivity_persistsUserLogFields`**, **`diveActivityUserFieldTypes_displayTitles`**.
- **Fix:** **`diveCurrentStrength`** is **`DiveCurrentStrength?`** (no non-optional enum default on **`@Model`**) so existing stores migrate without SIGABRT.
- **Profile name on sign-in:** Cache Apple **`fullName`** in **`UserDefaults`** (Apple only sends it once); **`resolvedDisplayName`** + **`applyCachedDisplayNameIfNeeded`** upgrade placeholder **Diver**; **`ProfileDisplayNameCaptureSheet`** when still unnamed; **`SignInWithAppleButton(.continue)`**.
- **Tests:** **`userProfileStore_cachedDisplayName_roundTrips`**, **`userProfileStore_applyCachedDisplayNameIfNeeded_upgradesPlaceholder`**, given-name-only **`displayName`**.

---

## 32 - Dive site link and map UX **(pushed)**

**Summary:** Link dives to catalog **`DiveSite`** on import; split **entry** vs **site** coordinates; map-tab prompt to add sites with draggable coordinate picker; map chrome and interaction polish.

- **`diveSite`** / **`diveSiteID`**; **`entryCoordinate`** (migrated from **`coordinate`**); **`siteCoordinate`** / **`resolvedMapCoordinate`** for map pin.
- **`DiveActivitySiteAssociation`** — GPS match first, name second, on **FIT** / **UDDF** import + mock seed; **`createSiteAndLink`**.
- **Map tab — no catalog match:** Alert **Add new site?**; **`DiveSiteAddSheet`** + **`DiveSiteCoordinatePickerMapView`** (drag map, center pin, lat/lon sync); **`DiveMapSitePromptInfoButton`** after **No**.
- **Map tab UX:** Pan/zoom only at **minimized** detent; **`DiveOverviewMapTopScrim`** under toolbar; pin shows coordinates (**3** decimals).
- **Tests:** site association, map prompt, coordinate picker, map interaction detent.

---

## 33 - Explore catalog map pins **(pushed)**

**Summary:** Plot every catalog **`DiveSite`** with valid coordinates on the **Explore** map as red pins; tap a pin to open a detail sheet.

- **`ExploreCatalogMapPresentation`** — filters plottable sites, fits **`MKCoordinateRegion`** to all pins (or single-site dive span).
- **`ExploreCatalogMapView`** / **`ExploreCatalogMapRepresentable`** — **`MKMapView`** with red **`ExploreCatalogMapPinView`** annotations; selection opens sheet.
- **`ExploreDiveSiteDetailSheet`** — sheet title is the site name; coordinates (3 decimals), rating, tags, dive count; **`appSheetPresentationChrome()`**.
- **`ExploreView`** — **`@Query`** catalog sites; replaces single-dive **`DiveLocationMapView`**.
- **Tests:** **`exploreCatalogMapPresentation_plottableSites_filtersInvalidCoordinates`**, region fitting (multi + single site).
- **`MapPushPinView`** — shared push-pin shape; **`MapPushPinImageFactory`** draws the tip on the **vertical center** of the map asset so Explore pins use **`centerOffset = .zero`** (stable when zooming); dive map label uses a one-time offset; dive map **`isPitchEnabled = false`** to avoid 3D drift.

---

## 34 - Logbook delete performance and Explore pin cleanup **(pushed)**

**Summary:** Faster, reliable dive delete off the main actor; Explore map drops pins when the last dive at a site is removed.

- **`DiveBackgroundDeletionWorker`** — batch-delete equipment only; parent dive **`modelContext.delete`** (batch dive delete fails when **`diveSite`** is linked); clears **`diveSite`** then cascade drops profile points / buddies.
- **`DivePostDeleteRenumberScheduler`** — **`schedulePartialRenumber`** (tail **#**s only) instead of full **1…n** after every delete; **500 ms** debounce.
- **Logbook** — owner-scoped **`@Query`**, cached row snapshots, optimistic hide kept until delete fails (no extra list pass on success).
- **Tests:** **`diveBackgroundDeletionWorker_batchDelete_removesProfilePointsByDiveActivityID`**, buddy removal test.
- **`DiveSiteCatalogMaintenance`** — after dive delete, removes catalog **`DiveSite`** rows with no linked dives so **Explore** drops the pin; dismisses open site sheet when the row is gone.
- **Bug fixes:** no batch-delete of dive children/parent (Core Data **`diveSite`** / profile inverse constraints); compile fixes (**`deletePermanentlyByID`**, **`import Foundation`**).

---

## 35 - Dive site place hierarchy **(pushed)**

**Summary:** Catalog **`DiveSite`** rows and the new-site sheet capture optional **country → region → body of water** labels.

- **`DiveSite`** — **`country`**, **`region`**, **`bodyOfWater`** with **`= ""` on the property** (required for SwiftData lightweight migration; init-only defaults caused **`loadIssueModelContainer`** on existing stores).
- **`DiveSiteDTO`** / **`DiveSiteMapper`**, **`divesites_sample.json`** (sample place fields on Salt Pier).
- **`DiveSiteFormDraft`** + **`DiveSiteAddSheet`** — **Place** section (Country, Region, Body of water); **`DiveActivitySiteAssociation.createSiteAndLink`** persists trimmed values.
- **`ExploreDiveSiteDetailSheet`** — **Place** section when any hierarchy field is set.
- **Tests:** **`diveActivitySiteAssociation_createSiteAndLink_persists`** (place trimming), **`diveSiteMapper_mapsOptionalPlaceFields`**, **`diveSiteFormValidation_sanitizedPlaceField_trimsWhitespace`**.
- **`DiveActivityDuplicateMatcher.Signature`** — nonisolated value **`init`** for tests; **`@MainActor init(_: DiveActivity)`** delegates to it (fixes Swift 6 **`#expect`** isolation in duplicate-matcher tests).
- **`DiveSiteCatalogMaintenance.deleteSitesWithNoLinkedDives`** — **`nonisolated`**, uses **`diveSiteID`** predicate (not **`diveActivities`**) so **`DiveBackgroundDeletionWorker`** can run catalog cleanup off the main actor.

---

## 36 - Dive activity tap-to-edit overview panels **(pushed)**

**Summary:** Map and tank overview panels reorganized with chevron rows; nearly every dive parameter is editable via field sheets.

- **`DiveActivityEditableCatalog`** / **`DiveActivityFieldEditing`** / **`DiveActivityFieldValueParsing`** — tab-specific sections (map vs tank), display values, unit-aware parse/apply.
- **`DiveActivityEditableRow`** + **`DiveActivityEditableSectionsView`** — chevron-only affordance on editable rows; read-only rows (profile sample count, record ID) without chevron. **Signature** row shows **`DiveSignaturePreview`** when **`diveSignatureData`** has ink (**`DiveSignatureDataFormatting`**).
- **`DiveActivityFieldEditSheet`** — per-field editors (text, numbers, date, coordinate, dive #, conditions, signature, notes).
- **`DiveActivityBuddiesEditSheet`** — add/rename/delete buddy tags.
- **`ViewSingleActivity`** — map panel: depth chart + editable sections (replaces read-only **`DiveActivityDetailsPresentation`** dump and large-detent-only **`DiveActivityUserLogSection`**); tank panel: gas/consumption editable sections only — **Equipment** is the chevron row (**`linkedEquipment`**) opening **`DiveActivityAddEquipmentSheet`** (removed duplicate **`DiveActivityTankEquipmentSection`** list).
- **Logbook dive #:** **`diveNumberLogbookLabel`** / **`diveNumberPlainLabel`** honor **`diveNumberExplicitlyNone`**; **`LogbookView`** row-cache signature includes hide + number so labels refresh after editing on a dive.
- **`DiveImportedLocationParsing`** — import **`locationName`** → **region** (before comma) + **country** (after); **`DiveActivityMapSitePrompt.draft`** prefills **`DiveSiteAddSheet`** (linked catalog site keeps saved place fields).
- **`deviceSource`** → **`source`** (**`DiveSource`** enum, was **`DeviceSource`**); SwiftData **`@Attribute(originalName: "deviceSource")`**; UI label **Source**; fixture JSON key **`source`** (DTO still decodes legacy **`deviceSource`**).
- **`DiveActivityManualCreation`** — **Manual entry** on **`ActivityUploadView`** inserts a blank **`DiveActivity`** (**`source: .manual`**, no **`sourceDiveId`**, no profile) and navigates to **`ViewSingleActivity`**; **`sourceDiveId`** read-only in overview; depth chart empty state **No sample data available**.
- **`ManualDiveEntrySheet`** — **New dive** sheet: date + optional **Site name**; **Create** / **Cancel**; **`ManualDiveEntryInput`** → **`siteName`** on new manual dive.
- **Swift 6:** **`DiveMapCoordinateResolver.coordinate(from:)`** **`nonisolated`**; **`DiveActivityDTO`** (+ nested DTOs) **`Sendable`** with **`nonisolated`** **`init(from:)`** for unit tests.
- **Tests:** **`diveActivityEditableCatalog_mapAndTankSectionsAreDistinct`**, **`diveActivityFieldValueParsing_depthAndPressureRespectDisplayUnits`**, **`diveActivityFieldEditing_applyDraft_updatesDuration`**, **`diveSignatureDataFormatting_emptyOrMissingIsNotDisplayable`**, **`diveActivityFieldEditing_signatureDisplayValue_usesPlaceholderWhenEmpty`**, **`diveLogbookDisplay_hiddenDiveNumber_showsHyphen_*`**, hidden-number label on **`DiveActivity`**, **`diveImportedLocationParsing_*`**, **`diveActivityMapSitePrompt_draft_*`**, **`diveActivityDTO_decodesSourceAndLegacyDeviceSourceKey`**, **`diveActivityManualCreation_*`**, **`diveActivityEditableCatalog_sourceDiveIdIsNotEditable`**.

---

## 37 - Media tab, sheet spacing, and dive overview chrome **(pushed)**

**Summary:** Shared sheet grabber spacing; full-bleed **Media** tab (photos + videos, swipe pager, embedded panel); depth profile on **tank** only; darker top gradient behind dive tab chrome.

- **`AppTheme.Sheet.contentTopSpacing`** (**`Spacing.lg`**, 24pt) — shared grabber-to-content gap.
- **`appSheetContentTopSpacing()`** + **`appSheetPresentationChrome()`** — all frosted **`.sheet`** flows (equipment, certifications, dive field editors, explore detail, manual dive, dive site add, etc.) pick up top padding automatically.
- **`DiveActivityOverviewPanelMetrics.panelContentTopPadding`** — embedded **map** / **tank** overview panel uses the same 24pt below the custom grabber row.
- **Profile sheets** — **`ProfileDisplayNameCaptureSheet`**, **`ProfilePhotoCropSheet`**: **`appSheetContentTopSpacing()`** + system grabber (no frosted chrome).
- **Test:** **`diveActivityOverviewPanelMetrics_panelContentTopPadding_matchesSheetToken`**.

**Summary (continued):** Depth profile chart only on **tank** overview panel, not **map**.

- **`ViewSingleActivity`** — removed **`DiveDepthProfileChart`** + scrub hero from **map** panel; **`tankDepthProfileSection`** on **tank** panel (minimized hero overlay unchanged). Clears scrub sample when leaving **tank** tab.

**Summary (continued):** **Photos** tab uses the shared overview sheet; dive media model for future gallery.

- **`DiveMediaPhoto`** — SwiftData row (**`imageData`**, **`sortOrder`**, cascade with **`DiveActivity`**); **`mediaPhotos`** relationship + **`sortedMediaPhotos`**.
- **`DiveActivityMediaBackgroundView`** — grid when media exists; **No media added** placeholder when empty.
- **`ViewSingleActivity`** — **Photos** tab: media hero + embedded panel (blank **`photosPanelContent`** for now); **`DiveActivityOverviewTabSelection`** includes **camera** at **medium** detent.
- **Tests:** **`diveActivityOverviewTabSelection_allTabs_useMediumDetent`**, **`diveActivityMediaPresentation_*`**.

**Summary (continued):** **Photos** picker, persistence, and swipeable full-bleed gallery.

- **`DiveActivityMediaStorage`** — **`addPhoto`** (JPEG normalize, **`sortOrder`**, SwiftData insert + save).
- **`DiveActivityPhotosPanelToolbar`** — trailing **+** **`PhotosPicker`** (up to 20 images) in the overview sheet.
- **`DiveActivityMediaBackgroundView`** — **`TabView`** page pager (one photo, swipe between); empty state unchanged.
- **`ViewSingleActivity`** — imports picker items, selects newest photo, error alert on save failure.
- **Tests:** **`diveActivityMediaPresentation_nextSortOrder_increments`**, **`resolvedSelectedPhotoID`**, **`diveActivityMediaStorage_addPhoto_persistsOrderedRows`**.

**Summary (continued):** **Photos** background hidden at **large** sheet detent.

- **`DiveActivityMediaPresentation.showsBackgroundPhotos`** — pager / empty state off when detent is **large**; gradient only behind the sheet.
- **Test:** **`diveActivityMediaPresentation_showsBackgroundPhotos_onlyWhenNotLarge`**.

**Summary (continued):** **Media** tab accepts photos and videos in one picker and pager.

- **`DiveMediaKind`** + **`mediaKind`** / **`mediaData`** (migrated from **`imageData`**) / **`mediaFileName`** on **`DiveMediaPhoto`**.
- **`DiveActivityMediaPickerImport`** — **`PhotosPicker`** images + movies; **`DiveMediaFileStore`** copies videos to Application Support.
- **`DiveActivityMediaItemView`** / **`DiveActivityVideoPlayerView`** — swipe pager plays video or shows image; tab label **Media**.
- **`DiveBackgroundDeletionWorker`** — deletes on-disk video files when a dive is removed.
- **Tests:** **`diveMediaFileStore_importVideo_writesFile`**, **`diveActivityMediaStorage_addMedia_persistsVideoRow`**, image row test updated for **`addMedia`**.

**Summary (continued):** Dive videos use aspect-fill crop in the media pager (matches photos).

- **`DiveActivityVideoPlayerView`** — **`AVPlayerLayer`** + **`resizeAspectFill`** instead of letterboxed **`VideoPlayer`**.

**Summary (continued):** **Media** background is edge-to-edge under the status bar (matches **map**).

- **`DiveActivityMediaBackgroundView`** — no top inset on pager; **`ViewSingleActivity`** applies **`ignoresSafeArea()`** on the **Media** tab.
- **`DiveOverviewMapTopScrim`** — much darker at the top (**~90%** black), easing to light/clear at the bottom of the band; shared overlay behind **`activityTopChrome`** on all overview tabs.

**Summary (continued):** **Media** pager truly edge-to-edge at the top ( **`TabView`** safe-area fix).

- **`DiveActivityMediaBackgroundView`** — extends pager height by top safe inset + **`offset`** so photos/videos draw under the status bar (same as **map**).
- Hero tab **`Group`** uses **`ignoresSafeArea(edges: [.top, .horizontal])`**.
- **`DiveActivityMediaBackgroundView`** — horizontal paging **`ScrollView`** (replaces **`TabView`** offset hack that covered the embedded sheet); media tab uses **`ignoresSafeArea()`** only on the hero layer; panel **`zIndex(1)`**.

---

## 38 - Logbook search, profile cert number, and polish **(pushed)**

**Summary:** Logbook site search inline with **+** (**Cancel** while focused); profile shows primary cert number under the name; **`nonisolated`** dive media delete for background worker.

- **`DiveLogbookSiteSearch`** — case-insensitive substring filter; empty query shows all dives.
- **`LogbookSiteSearchField`** — magnifying glass, clear button, elevated field chrome.
- **`logbook.swift`** — **`LogbookTopChrome`** search inline with **+**; **Cancel** dismisses keyboard and clears query; list inset from single chrome row.
- **`AppTheme.Layout`** — **`logbookSearchFieldHeight`** token.
- **Tests:** **`diveLogbookSiteSearch_*`**, **`appTheme_logbookSearchFieldHeight_*`**.

**Summary (continued):** Profile shows primary certification number under the cert name.

- **`CertificationPresentation.profilePrimaryCertification`** — title + optional **`certNumber`** line for the newest primary card.
- **`profile.swift`** — second subtitle line when a cert name and number are set.
- **Tests:** **`certificationPresentation_profilePrimary_*`**.

**Summary (continued):** Fix Swift 6 warning deleting dive media off the main actor.

- **`DiveActivityMediaStorage.deleteMediaFiles`** — **`nonisolated`**; passes video file names to **`DiveMediaFileStore.deleteFiles(named:)`** for **`@ModelActor`** delete.

**Summary (continued):** Logbook search inline with **+**; **Cancel** dismisses keyboard.

- **`LogbookTopChrome`** — single top row: search field; trailing **+** swaps to **Cancel** while search is focused.
- **`LogbookSiteSearchField`** — **`@FocusState`** binding; list **`scrollDismissesKeyboard(.interactively)`**.

---

## 39 - Bulk UDDF import, logbook polish, site linking **(pushed)**

**Summary:** MacDive **`.uddf`** bulk import (dives only — not media, locker gear, or other MacDive export data yet), live progress + completion alert, Add activity layout/sheet UX, duplicate + site-link fixes, and renumber/search display rules.

- **`ActivityUploadView`** — **VStack** tiles: **File upload** (**.uddf or .fit**), **Manual entry**, compact **Bulk UDDF**; **`.large`** options sheet with MacDive export instructions + **Create dive sites from import** toggle (**`AppUserSettings.bulkUddfCreateDiveSitesKey`**).
- **`UddfDiveFileImport`** — multi-dive persist with per-dive progress (**`Task.yield()`**), in-memory chained **`diveNumber`** + prefetched **`autoAdd`**; **`createdDiveSiteCount`** on **`DiveFileImportOutcome`**; **`BulkUddfImportSummary`** completion alert (imported / duplicates / sites created).
- **`UddfDiveFileDecoder`** — **`divenumber` `0`** → **`diveNumberExplicitlyNone`** (logbook **`-`**).
- **`DiveActivityDuplicateMatcher`** — cross-format FIT/UDDF fingerprint; duration/bottom tolerance fix.
- **`DiveActivitySiteAssociation`** — unique exact **`siteName`** before GPS; optional catalog site creation on bulk import.
- **`DiveLogbookDisplay`** — site search uses full logbook for **#** when auto-renumber is on (**`numberingActivities`**).
- **`DiveActivityDiveNumbering`** / **`DiveBackgroundRenumberingWorker`** — renumber skips **`diveNumberExplicitlyNone`** (**`-`**).
- **Tests:** bulk import, progress, site linking, renumber/search display, duplicate matcher, **`BulkUddfImportSummary`**.

**Scope note:** Bulk UDDF imports **`DiveActivity`** rows (profile, tank, site, buddies from UDDF). MacDive **photos, equipment locker, certifications**, and other export payloads are **not** imported yet.

---

## 40 - Profile DAN insurance number **(pushed)**

**Summary:** Optional DAN (Divers Alert Network) membership number on **`UserProfile`**, editable on **Profile** and optional on post-sign-in name capture.

- **`UserProfile.danInsuranceNumber`** — optional persisted string.
- **`UserProfileStore.sanitizedDanInsuranceNumber`** — trim, alphanumeric + spaces/hyphens, max 40.
- **`ProfileDanInsuranceEditor`** — **Profile** card with **Done** keyboard dismiss.
- **`ProfileDisplayNameCaptureSheet`** — optional **DAN member number** field at sign-up.
- **Tests:** **`userProfileStore_sanitizedDanInsuranceNumber_*`**, **`userProfile_persistsDanInsuranceNumber`**.

**Summary (continued):** Logbook scrolls under frosted tab bar.

- **`goDiveRootTabBarChrome()`** — **`.ultraThinMaterial`** on root **`TabView`** tab bar.
- **`logbook.swift`** — **`List`** **`ignoresSafeArea(edges: [.top, .bottom])`** + bottom clear inset row for tab-bar safe area.

**Summary (continued):** Stronger logbook top fade under search chrome.

- **`LogbookTopChromeScrim`** — tall **`surfaceElevated`** gradient over scrolling rows, under **`LogbookTopChrome`** (replaces narrow status-only scrim on that bar).

**Summary (continued):** Apple display name applied directly to profile when available.

- **`UserProfileStore.applyDisplayNameFromApple`** — writes fresh **`fullName`** to **`UserProfile`**; else cached name upgrades **Diver**.
- **`AccountSession`** — uses on sign-in and session restore; name sheet only when still placeholder.
- **Tests:** **`userProfileStore_applyDisplayNameFromApple_writesFreshFullName`**.

**Summary (continued):** Profile edit sheet; no sign-up name prompt.

- Removed **`ProfileDisplayNameCaptureSheet`** — no Apple name → default **Diver**; edit on **Profile** via **⋮** (**`ProfileEditSheet`**: display name + DAN).
- Removed inline **`ProfileDanInsuranceEditor`**; DAN shown on profile when set.

**Summary (continued):** Fix Add activity file import not responding.

- **`activity_upload.swift`** — single SwiftUI **`.fileImporter`** (two modifiers broke **File upload**; bulk still worked); **`PickerMode`** selects UTTypes; **`presentFileImporter`** defers **`isPresented`** one run loop; do **not** reset **`isPresented`** in **`onDisappear`**.
- **`DiveFileImporterPresentation.swift`** — **`PickerMode`**, allowed UTTypes, **`isUserCancellation`**.
- Removed temporary **`DiveFileDocumentPicker`** UIKit wrapper (same system Files UI; SwiftUI API preferred).

**Summary (continued):** Logbook top fade reaches screen top.

- **`LogbookTopChromeScrim`** — removed 14pt clear band above the gradient; Logbook offsets scrim **`padding(.top, -safeArea.top)`** so the fade covers the status-bar region (height already includes safe top).
- **Tests:** **`diveFileImporterPresentation_isUserCancellation_recognizesPickerCancel`**.

---

## 41 - Explore map / list toggle **(pushed)**

**Summary:** **Explore** tab — map/list toggle beside Trip Planner; dive-site list uses logbook-style rows.

- **`ExploreTopChrome`** — map/list toggle **leading**, Trip Planner calendar **trailing**; **`AppHeader`** padding + status scrim + **`AppHeaderMetrics`** height.
- **`ExploreViewModeToggle`** — map / list segmented control (top leading).
- **`ExploreDiveSiteListDisplay`** + **`ExploreDiveSiteRow`** — logbook card layout (name, trailing rating or dive count, place · coordinates).
- **`explore.swift`** — **`List`** with logbook insets/spacing, top scrim, tap → **`ExploreDiveSiteDetailSheet`**; **`AppHeaderlessPage`** + pin **`ExploreTopChrome`** to top (**`fixedSize`** / row height measure — fixes controls and list inset centered mid-screen).
- **Tests:** **`exploreDiveSiteListDisplay_rowData_placeRatingAndDiveCount`**, **`exploreDiveSiteListDisplay_placeSummary_omitsEmptyFields`**.

**Summary (continued):** Import site linking prefers dive **`siteName`** over nearby GPS.

- **`DiveActivitySiteAssociation`** — when import has **`siteName`**, exact catalog name match only (duplicate names disambiguate within that set); never link to a different nearby site; **`createSiteForImportNameIfNeeded`** for new catalog rows.
- **`DiveMapCoordinateResolver.exactMatchingSites`** — shared exact-name filter.
- **FIT** / single **UDDF** import always create a catalog site for unmatched import names; bulk UDDF still respects **Create dive sites** toggle.
- **Tests:** **`diveActivitySiteAssociation_namedSite_doesNotLinkToNearbyDifferentName`**, **`createSiteForImportNameIfNeeded_insertsNamedSite`**; updated ambiguous-name GPS disambiguation test.

---

## 42 - Dive media upload progress **(pushed)**

**Summary:** Progress overlay when adding photos/videos to a dive from the **Media** tab.

- **`DiveMediaImportProgressOverlay`** — scrim + progress bar, **N of M added**, stage label; failure card with **Dismiss**.
- **`DiveActivityMediaBatchImport`** (in **`DiveActivityMediaPickerImport.swift`**) — sequential picker import with **`onProgress`** callbacks.
- **`DiveMediaImportProgressPresentation`** — progress fraction + stage copy.
- **`ViewSingleActivity`** — overlay during import; **+** disabled while importing.
- **Tests:** **`diveMediaImportProgressPresentation_*`**.

**Summary (continued):** Muted looping dive videos on **Media** tab.

- **`DiveActivityVideoPlayerView`** — **`isMuted`**; loop on end while playback active; pause when tab/detent hides background or another pager item is selected.
- **`DiveActivityMediaPresentation.shouldPlayBackgroundVideo`** — **Media** tab + **minimized** / **medium** detent only.
- **Tests:** **`diveActivityMediaPresentation_shouldPlayBackgroundVideo_mediaTabAndSmallDetents`**.

**Summary (continued):** Profile edit control in top bar.

- **`profile.swift`** — **⋮** edit beside **Settings** (top trailing); display name centered without inline menu.

**Summary (continued):** Site-association tests aligned with exact-name import rules.

- **Tests:** **`diveActivitySiteAssociation_matchesExactNameWhenNoEntryGPS`**, **`diveActivitySiteAssociation_doesNotFuzzyMatchPartialCatalogName`** (partial import name no longer links to longer catalog title).

---

## 43 - Certification card type (certification vs specialty) **(pushed)**

**Summary:** Replaced **Primary** toggle with **Certification** / **Specialty** type; colored badges on list rows; profile features newest **certification**-type card only.

- **`CertificationCardType`** + **`cardTypeRaw`** on **`Certification`** (replaces **`isPrimaryCert`**).
- **`CertificationFormContent`** — segmented **Type** picker; removed **`setAsPrimary`**.
- **`CertificationTypeBadge`** — blue **Certification** pill, violet **Specialty** pill.
- **`CertificationPresentation.profileFeaturedCertification`** — newest **`certification`** type for profile subtitle (specialties ignored).
- **`CertificationPresentation.sortedForList`** — newest **`dateAttained`** first.
- **Tests:** profile featured / specialty ignored / badge styles / sorted list.

**Summary (continued):** Specialty badge color + detail header layout.

- **`CertificationPresentation`** — specialty badge uses violet palette (replaces gold); **`detailHeaderName`** for detail page title row.
- **`ViewCertificationDetails`** — cert name + type badge at top of scroll; removed bottom **Type** section and duplicate **Name** row; **`AppPage`** title **Certification**.

**Summary (continued):** Prominent certification card photos on detail page.

- **`ViewCertificationDetails`** — full-width card heroes (ID-1 aspect, shadow); front + back use paged **`TabView`**; single photo uses one large hero.

**Summary (continued):** Profile featured cert opens detail.

- **`CertificationPresentation.profileFeaturedCertificationCard`** — resolves newest certification-type row for navigation.
- **`profile.swift`** — featured cert name/number **`NavigationLink`** → **`ViewCertificationDetails`** (inactive when default **GoDive User** copy).
- **Tests:** **`certificationPresentation_profileFeaturedCertificationCard_*`**.

---

## 44 - Dive timestamps: UTC storage + timezone offset display **(pushed)**

**Summary:** Persist dive-local **`timeZoneOffsetSeconds`**; parse UDDF site **`timezone`** and **`Z`/`±HH:MM`** datetimes; MacDive naive **`datetime`** as UTC; geographic DST lookup when offset missing; format logbook and dive UI in dive-local offset.

- **`DiveActivity.timeZoneOffsetSeconds`** — optional seconds east of UTC for display.
- **`DiveDateTimeParsing`** — UDDF naive **`datetime`** (MacDive) treated as **UTC** wall time; site **`geography/timezone`** is display offset only; **`Z`** / RFC 3339 offsets on **`datetime`** when present.
- **`DiveGeographicTimeZoneLookup`** + **`DiveActivityTimeZoneResolution`** — when offset is still **`nil`**, reverse-geocode entry / site coordinates (**`MKReverseGeocodingRequest`**, cached) and set **`timeZoneOffsetSeconds`** via **`TimeZone.secondsFromGMT(for: startTime)`** (DST-aware). Runs after UDDF/FIT import and when opening a dive.
- **`UddfDiveFileDecoder`** — reads **`timezone`** on site; assigns offset on import.
- **`FitImportTimeZone`** — FIT **`ActivityMesg`** local − UTC delta when present.
- **`DiveActivityTimePresentation`** + **`formattedStartDateTime()`** / **`formattedStartDateOnly()`** on **`DiveActivity`**; **`DiveProfilePoint.formattedTimestamp(for:)`** uses the same offset (profile samples store UTC instants from FIT / UDDF **`startTime + divetime`**).
- **Map tab** — read-only **Start (UTC)** and **Timezone offset** rows in the Dive section (**`startTimeUTC`**, **`timeZoneOffset`**).
- **Tests:** **`diveDateTimeParsing_*`**, **`uddfDecoder_siteGeographyTimeZone_setsActivityOffset`**.

---

## 45 - Logbook delete performance **(pushed)**

**Summary:** Faster dive delete on and off the main actor — batch-related deletes, no full-log prefetch before delete, targeted tail renumber, single-site catalog cleanup.

- **`DiveBackgroundDeletionWorker`** — batch **`delete(model:where:)`** for equipment rows; profile points, buddies, and media cascade from parent delete (batch child delete hits Core Data mandatory-nullify on **`DiveProfilePoint.dive`**); one-site **`deleteSiteIfOrphaned`** instead of scanning the whole catalog; removed pre-delete full-log fetch for renumber noop (background tail pass exits early when nothing follows the deleted slot).
- **`DiveBackgroundRenumberingWorker`** — partial renumber uses **`chronologicallyAfterDeletedSlot`** (same partition as main-context **`renumberDivesNewerThanDeleted`**) so the deleted slot is not double-counted.
- **`DiveActivityDiveNumbering`** — shared **`applyPartialRenumberTail`** / **`maxNumberedDiveNumber`** / **`chronologicallyAfterDeletedSlot`** helpers.
- **Tests:** **`diveSiteCatalogMaintenance_deleteSiteIfOrphaned_*`**, **`diveBackgroundRenumberingWorker_partialRenumberOnlyTouchesTail`**, **`diveActivityDiveNumbering_chronologicallyAfterDeletedSlot_*`**.

**Summary (continued):** Persist dive media capture time — EXIF / file metadata first, Photos library fallback.

- **`DiveMediaPhoto.capturedAt`** — optional capture instant on import.
- **`DiveMediaCaptureDateExtraction`** — ImageIO EXIF/TIFF/IPTC/GPS/file dates; AVFoundation scans all metadata formats; **`PHAsset.creationDate`** / **`modificationDate`** (videos prefer library before temp-file metadata). **`PhotosPicker`** uses **`photoLibrary: .shared()`** so **`itemIdentifier`** resolves; **`NSPhotoLibraryUsageDescription`** added.
- **`DiveActivityMediaPickerImport.load`** — reads metadata from original picker bytes / copied video **before** JPEG re-encode.
- **`DiveActivityMediaItemView`** — bottom-leading capture timestamp (dive-local offset when the dive has one).
- **`DiveActivityPhotosPanelContent`** — **medium** sheet shows **Captured** date for the swiped item (+ position label); **Media** hero at **minimized** shows the same two-line capture overlay as profile preview (date/time + depth / minutes into dive).
- **`DiveActivityMediaCarouselView`** — thumbnail strip at **minimized** and **medium**; tap updates **`selectedDiveMediaPhotoID`** so the hero pager shows/plays that item (stays in sync when swiping the hero). **Minimized** shows carousel + **+** only (no title, count, or capture date); **medium** adds those details. **Media** minimized content does not expand the sheet on tap (use grabber).

**Summary (continued):** Media markers on tank hero depth profile (landscape, minimized only).

- **`DiveDepthProfileMediaPlotting`** — maps **`capturedAt`** to elapsed seconds on the profile axis (within dive window); interpolates depth at capture time; square marker size tokens.
- **`DiveTankOverviewHeroPresentation`** — **landscape** + **minimized** tank tab: full-width profile chart, **no** PSI-used summary or small cylinder, **embedded sheet hidden**; **portrait** minimized unchanged (chart + cylinder + gas text, no markers) + **`DiveTankRotatePhoneHintView`** (animated rotate cue above the sheet).
- **`DiveDepthProfileOverlayChart`** + **`DiveTankOverviewHeroView`** — square **media thumbnails** on the landscape minimized profile only; tap opens **`DiveDepthProfileMediaPreviewSheet`** at **large** detent (full-sheet photo / looping video; overlay adds **Captured at** depth + minutes into dive, unit-aware).
- **`DiveMediaCaptureContext`** + **`DiveDepthProfileMediaPlotting.captureContext`** — profile depth/elapsed at **`capturedAt`**; **`DiveActivityMediaPresentation.formattedCaptureAtDivePosition`**.
- **`DiveActivityMediaThumbnailView`** — shared image / video-frame thumbnails (carousel + profile markers).
- **`DiveDepthProfileChart`** (tank panel) — scrub only; markers removed from this chart.
- **Tests:** **`diveDepthProfileMediaPlotting_*`**, **`diveDepthProfileMediaPlotting_markerThumbnailMetrics_*`**.

**Summary (continued):** Muted dive video does not interrupt background music.

- **`DiveMutedVideoAudioSession`** — **`AVAudioSession`** **`.ambient`** + **`.mixWithOthers`** before **`AVPlayer`** starts (all videos stay **`isMuted`**).
- **Tests:** **`diveMutedVideoAudioSession_usesAmbientMixWithOthers`**.
- **Tests:** **`diveMediaCaptureDateExtraction_*`**, **`diveActivityMediaStorage_addMedia_persistsCapturedAt`**, **`diveActivityMediaPresentation_showsCaptureDateOnHero_*`**, **`diveActivityMediaPresentation_mediaPositionLabel_*`**.

**Summary (continued):** Profile avatar ring + crop bounds.

- **`ProfileAvatarView`** — **`accentDeep`** circular stroke on **Home** and **Profile** (replaces editor-only white ring).
- **`ProfileView`** — larger profile avatar (**168** pt) sits closer under the top chrome.
- **`ProfilePhotoCropRenderer.clampedOffset`** — pan/zoom cannot move the crop circle outside the image; **Tests:** **`profilePhotoCropRenderer_clampedOffset_keepsCropInsideImage`**.

**Summary (continued):** Compact Settings rows with info alerts.

- **`SettingsPresentation`** — titles + long descriptions for **Imperial units**, **Default tank**, **Automatically renumber dives**.
- **`SettingsToggleRow`** / **`SettingsPickerRow`** — title beside control; **`info.circle`** opens alert with full copy. **Default tank** menu shows compact codes (**AL80**, **AL63**, …) inline on the right.
- **Tests:** **`settingsPresentation_exposesSettingTitlesAndInfoCopy`**.

**Summary (continued):** Equipment Locker + Certifications scroll-under header.

- **`AppPage`** — scroll-under list only **`ignoresSafeArea(edges: .top)`**; **`AppHeader`** stays in the safe area. Key-window inset fallback when geometry reports **0**.
- **`EquipmentLockerView`** / **`CertificationsListView`** — shared scroll-under list container; first row aligns with Logbook / Explore list.
- **`AppHeader`** — **`SecondaryDestinationBackButton`** (44×44 pt); scroll-under pages add a header hit shield so the list does not steal taps from back / **+**.

**Summary (continued):** Profile destination tile counts.

- **`ProfilePresentation`** — **`certificationCountLabel`**, **`equipmentItemCountLabel`** for Certifications / Equipment Locker tiles.
- **`ProfileView`** — tiles show owned certification and gear counts (e.g. **3 certifications**, **5 items**).
- **Tests:** **`profilePresentation_certificationAndEquipmentCountLabels_pluralize`**.
- **Tests:** **`appScrollUnderHeaderListLayout_usesLogbookHorizontalInsets`**.

---

## 46 - Logbook delete, tank profile gestures, and SwiftData fixes **(pushed)**

**Summary:** Logbook delete keeps taps and bubble animation responsive; faster background delete with safe batch SQL; tank hero profile zoom/pan/scrub; duplicate panel chart removed; Swift 6 test fixes.

- **`LogbookListSurface`** + **`.equatable()`** — list and **`WaterBubbleBackground`** do not rebuild on every SwiftData merge; bubbles pause during delete (**`animationPaused`**).
- **`suppressStoreDrivenRefresh`** — skips **`onChange(of: activities.count)`** cache rebuilds while delete + background renumber run; one refresh after both finish.
- **`LogbookActivitySnapshotSeed`**, **`LogbookDisplayCacheBuilder`**, **`LogbookCacheRefreshScheduler`** — seed copy on main actor, build rows off-thread; optional **`includeDuplicateScan: false`** on post-delete refresh.
- **Dive delete rebuilt:** **`DiveActivityDeletion.Request`** (`renumberAfterDelete` from **Settings**); **`DiveBackgroundDeletionWorker.deleteDive(id:)`** — detach relationship inverses, batch-delete children by **`diveActivityID`**, batch-delete dive; orphan site cleanup; video file removal.
- **Logbook:** **`LogbookDiveDeleteProgressOverlay`** stays until **`DiveActivityDeletion.delete`** finishes (delete + site cleanup + video files + renumber + main-context visibility), then min display time before dismiss.
- **`DiveActivityChildRecordLinking`** / **`link(to:)`** — keeps **`diveActivityID`** on buddies, profile points, and media when linked after **`init`** (SwiftData ignores relationship **`didSet`**).
- **Bug fix:** batch delete no longer crashes on **`DiveBuddyTag.dive`** constraint; removed stale **`modelContext.delete(activity)`** cascade on invalidated children.
- **Bug fix:** **Media** carousel thumbnails at **medium** detent — fixed row height for nested panel **`ScrollView`**; remount carousel on detent change; stop squashing hidden expanded panel to **1pt**.
- **Logbook tab re-tap:** iOS 18+ **`TabView(selection:)`** + **`Tab(value:)`**; **`LogbookTabBarReselectForwarder`** chains tab bar delegate + UIKit scroll-to-top fallback.
- **Tank landscape profile:** **`DiveDepthProfileChartViewport`** + **`DiveDepthProfileChartGesturePolicy`** — pinch zoom, two-finger pan, one-finger scrub; UIKit gesture arbitration.
- **Tank panel:** removed duplicate **`DiveDepthProfileChart`** at **medium** detent — interactive hero overlay only.
- **Bug fixes:** logbook restores row only when delete throws; **`DiveLogbookSiteSearch`** nonisolated APIs for Swift 6 tests.
- **Tests:** delete/renumber workers, gesture policy, viewport layout, background renumber path, site-search seeds, carousel height.

---

## 47 - Dive overview perf, map pins, media UX, tank gestures **(pushed)**

**Summary:** Faster dive screen open and smoother sheet/rotation; landscape tank pinch-zoom + pan; system map markers; media carousel ordering, hold-to-pause video, and zoom-scaling profile thumbnails; equipment **Retired** at bottom in red.

- **`DiveDepthProfileOverlayChart`** — UIKit pinch + two-finger pan via iOS 18 **`UIGestureRecognizerRepresentable`** on the chart (simultaneous with one-finger scrub). Replaces background superview installer + SwiftUI **`MagnificationGesture`**.
- Removed **`DiveDepthProfileChartGesturePolicy`** (no longer needed).
- Removed on-chart pinch/pan hint capsule on **`DiveDepthProfileOverlayChart`**.
- **Landscape rotation perf:** **`DiveTankOverviewHeroView`** no longer animates on **`isLandscape`** changes; **`ViewSingleActivity`** computes depth samples / pressure samples / media markers once per tank render pass instead of repeating conversions in the same layout cycle.
- **`DiveDepthProfileMediaPlotting`** perf: compute dive time axis once per marker/context batch (instead of once per media item), then reuse it for capture interpolation.
- **`DiveDepthProfileSeries`** added sorted-point overloads so callers that already sort profile points can skip redundant sorting; tank hero + media context path now use those overloads.
- **Tests:** **`diveDepthProfileSeries_sortedOverloads_matchDefaultBuilders`**, **`diveDepthProfileMediaPlotting_captureContextsByMediaID_matchesCaptureContext`**.
- **Detent-drag perf (`ViewSingleActivity`):** added cached **`DerivedDiveData`** (**sorted profile points/media**, depth + pressure samples, markers, capture contexts, media lookup map, gas stats) refreshed on dive/profile/media changes so map/tank/camera panel transitions reuse precomputed arrays instead of rebuilding every frame.
- **Map + tank panel sections:** both now consume cached **`profileGasStats`** instead of recomputing from **`activity.profilePoints`** on each render.
- **Media hero pager:** replaced per-render comma-joined media-ID signature with lightweight **`MediaSelectionSignature`** (**count + first/last ID**) for selection-sync change detection.
- **Media tab detent transitions:** one **`photosOverviewPanelContent`** instance for **minimized** + **medium** (no swap between collapsed summary and scroll panel); removed **`carouselLayoutToken`** forced remount; **`showsPanelContentWhenMinimized`** on embedded overview sheet; scroll disabled in minimized media band; **`DiveActivityVideoThumbnailCache`** for carousel video frames.
- **Dive map pin:** **`DiveLocationMapRepresentable`** uses system **`MKMarkerAnnotationView`** (red) instead of custom accent push pin + on-map coordinate label; site name stays on the overview sheet header.
- **Explore map pins:** **`ExploreCatalogMapRepresentable`** uses the same system **`MKMarkerAnnotationView`**; removed custom push-pin annotation views.
- **Media video playback:** hold still on a hero video to pause (**`onLongPressGesture`**, **~0.22s**, **5pt** max movement — pager swipe wins if the finger moves); resume on release. Pager/tab selection restarts the visible video from the beginning (**`DiveActivityVideoPlaybackPolicy`**).
- **Open dive screen perf:** **`DiveDerivedDataBuilder`** builds profile/media chart data off the main actor; **`ViewSingleActivity`** drops always-on **`@Query`** catalog sites (lazy fetch only when map needs name lookup). MapKit still mounts immediately on the **map** tab.
- **Media carousel / pager:** **`DiveActivityMediaPresentation.sortedPhotos`** orders by **`capturedAt`** ascending (oldest left, newest right); undated items fall back to **`sortOrder`** at the end.
- **Equipment add/edit form:** **Retired** toggle moved to the bottom of **`EquipmentItemFormContent`**; label + switch tint styled **red**.
- **Tank tab portrait ↔ landscape perf:** stop animating overview panel hide on orientation (animate sheet **detent** only); remove panel **transition** during rotation; single layout pass (**`layoutSize`** into hero, no nested **`GeometryReader`**); defer landscape media markers + zoom **~120ms** after rotation; **`drawingGroup()`** on depth/pressure polylines.
- **Depth chart media markers:** thumbnail size scales with chart zoom (**`markerThumbnailScale`**, up to **2.5×** base **28pt**); corner radius scales proportionally.

---

## 48 - Swift 6 depth profile Equatable in tests **(pushed)**

**Summary:** Fix Swift 6 **`Equatable`** isolation errors in depth-profile unit tests (**`#expect`** on samples, pressure samples, and media capture context).

- **`DiveDepthProfileSample.swift`** (new): **`DiveDepthProfileSample`**, **`DiveDepthProfilePressureSample`**, and **`DiveMediaCaptureContext`** live outside SwiftData-touching files with explicit **`nonisolated`** **`==`** (same pattern as **`DiveCoordinate`**).
- **`DiveDepthProfileSeries`**: sample structs removed; keeps SwiftData profile-point builders only.
- **`DiveDerivedDataBuilder`**: repaired file structure; SwiftData snapshot helpers in **`#if canImport(SwiftData)`** extension; core builder stays SwiftData-free for off-main use.

---

## 49 - Dive map native pin and coordinate title **(pushed)**

**Summary:** Dive overview map uses Apple native markers with visible coordinate titles.

- **`DiveLocationMapRepresentable`**: **`MKMarkerAnnotationView`** (red) with **`titleVisibility = .visible`**; annotation **`title`** is **`mapMarkerCoordinateTitle`** (locale decimal separators, 3 fractional digits).
- **`DiveLocationMapPresentation`**: **`mapMarkerCoordinateTitle(for:locale:)`** for map marker titles.
- **Tests:** **`diveLocationMapPresentation_mapMarkerCoordinateTitle_usesLocaleFormatting`**.

---

## 50 - Marine life catalog, sightings, and tagged media **(pushed)**

**Summary:** Field Guide marine-life catalog + per-sighting **`SightingInstance`** framework (tag UI next).

**Marine life catalog (prior in this section):**

- **`MarineLife`** (`@Model`): catalog fields — **`uuid`**, **`commonName`**, **`featureImageURL`**, **`scientificName`**, **`category`**, **`aboutText`**, **`minSizeMeters`**, **`maxSizeMeters`**, **`avgDepthMeters`** (canonical meters).
- **`MarineLifeUserRecord`**: per-profile **`isSighted`**, **`activitiesSightedOn`**, **`sitesSightedOn`**, **`userTaggedMedia`** keyed by **`marineLifeUUID`**.
- **`MarineLifeDTO`** / **`MarineLifeMapper`**, **`MarineLifeCatalogSeeder`**, **`marine_life_sample.json`**; launch seeds catalog when empty.
- **`FieldGuideView`**: species list → pushed **`FieldGuideMarineLifeDetailView`** (**`AppPage`**, not sheet); **Activities sighted on** (dive name + date, links to **`ViewSingleActivity`**); no list checkmark; **`FieldGuidePresentation`**, **`FieldGuideMarineLifeRow`**.
- **`ExploreView`**: map/list site tap → pushed **`ExploreDiveSiteDetailView`** (**`AppPage`**); **Marine life sighted here** section + species links; list mode **search dive sites** (logbook-style).
- **Field Guide** + **Explore** list: **`CatalogSearchField`** / **`CatalogListSearchChrome`** — species and site substring filter; **No matching** empty states.
- **Tests:** mapper, catalog seed idempotency, row sighted flag.

**`SightingInstance` (child of `MarineLife`):**
- **`SightingInstance`**: **`sightingUUID`**, **`marineLifeUUID`**, **`sightingDateTime`** (UTC), **`diveActivityID`**, **`diveSiteID`**, **`sightingDepthMeters`**, **`mediaPhotoID`** + relationships.
- **`SightingInstanceDateTimeResolution`**: media **`capturedAt`** overrides dive **`startTime`**.
- **`SightingInstanceLinking`**, **`SightingInstanceCreation`** (draft + insert stub for tag flow).
- **`DiveActivity.marineLifeSightings`** cascade; dive delete batch-removes sightings.
- **Tests:** datetime resolution, insert/link smoke test.

**List search Cancel / trailing swap:**
- **`CatalogListSearchChrome`**: shared logbook-style row; **Cancel** in a trailing **`ZStack`** (hides **+** / other actions while focused); **`LogbookTopChrome`** delegates here.
- **Bug fix:** **`LogbookListSurface`** **`.equatable()`** now includes **`isSiteSearchFocused`** so focus changes refresh chrome (**+** ↔ **Cancel**); **`LogbookListSurfaceEquatableInputs`** + test.
- **Field Guide** / **Explore** list: same **`CatalogListSearchChrome`**.
- **Explore** top chrome: single logbook-height row — **map:** Trip Planner **leading**, toggle **trailing**; **list:** inline site search + toggle (**calendar** hidden).
- **Field Guide** list: same **`ZStack`** / **`WaterBubbleBackground`** / in-scroll inset / **`listRowSpacing`** / chrome scrim stack as **Logbook**; **`FieldGuideTopChrome`** wrapper.
- **Field Guide** species detail + **Explore** dive-site detail: **Your tagged photos** — large preview + **`DiveActivityMediaCarouselView`**; **`FieldGuideTaggedMediaPresentation`** + **`FieldGuideTaggedMediaGalleryView`**; dive-site detail uses **`ScrollView`** (no list row tile behind gallery).
- **Tagged media:** **`DiveActivityMediaItemView`** + **`DiveActivityMediaCarouselView`** on species / site detail; **`DiveMediaPhotoImageLoader`** (ImageIO, no cache); photos resolved by **`mediaPhotoID`** via **`resolvedTaggedMediaPhotos`**; owner-scoped dive **`@Query`**.

**Tag marine life from dive media:**
- Removed **I've seen this species** toggle from **`FieldGuideMarineLifeDetailSheet`**.
- **Camera** tab: fish control (palette icon, matches map info button) — hero **top leading** at **minimized**; sheet **top leading** at **medium**; carousel Y aligned across detents; removed **Media** / **Photo N of M** header at **medium**. (tagged species overview; toolbar **+** opens **`DiveMarineLifeTagPickerSheet`** — multi-tag with **Done**, **Cancel** dismisses) → **`MarineLifeSightingRecorder`** + **`MarineLifeMediaTagPresentation`**.
- **`DiveActivityMediaPresentation.showsMarineLifeTagOnHero`**, **`MarineLifeSightingRecorder.sightings(for:)`**.
- **Tests:** media sightings fetch, tagged-row presentation.

---

## 51 - Activity tags, logbook tag search, and explore site links **(pushed)**

- **Logbook search:** site field filters **`resolvedSiteName`** only; **Tags** section under the bar with oval outline tag buttons (tap to confirm filter); active tag + **Clear**; **`DiveLogbookSiteSearch.filtering(siteQuery:confirmedTagName:)`**.
- **Dive activity tags:** **`ActivityTag`** model (owner-scoped, reusable across dives) + **`DiveActivity.activityTags`** many-to-many; **`ActivityTagStore`** for normalize/dedupe, fetch, apply/remove.
- **Map overview sheet:** **`DiveActivityTagsSectionView`** at bottom of map panel (oval chips + **+** opens tags sheet); **`DiveActivityTagsEditSheet`** opens at **large** detent; **On this dive** uses **`DiveActivityTagChipFlow`**; **Your tags** rows use checkmarks (tap to apply/remove), not toggles.
- **Shared tag chrome:** **`ActivityTagOvalChipLabel`** + **`ActivityTagsOutlinedSection`** (tag icon header, bordered card, oval outline chips) used on logbook tag suggestions/active filter and dive map **Tags** section.
- **Tests:** normalization/dedupe, apply/remove membership; schema includes **`ActivityTag`**; dive delete detaches tags (tags persist for reuse).

- **Explore dive-site detail:** added **Activities at this site** links (newest first) with the same card/date pattern as Field Guide activity links; taps open **`ViewSingleActivity`** via **`ExploreRoute.diveDetail`**.
- **`DiveSiteMarineLifePresentation.siteActivityLinks`**: filters owner activity snapshots by **`diveSiteID`**, then reuses **`FieldGuidePresentation.sightedActivityLinks`** for shared sorting/title/date formatting.
- **Tests:** **`diveSiteMarineLifePresentation_siteActivityLinks_filtersBySiteAndSortsNewestFirst`** plus snapshot schema update (**`DiveActivitySightingLinkSnapshot.diveSiteID`**).

---

## 52 - Search chrome, placeholders, and tab scroll-to-top **(pushed)**

- **Logbook:** search field placeholder **Search Activities** (was “Search by dive site”).
- **Field Guide:** search placeholder **Search Marine Life**; species search row is full width (**`showsTrailingActions: false`** on **`CatalogListSearchChrome`**).
- **Catalog search fields:** oval **`Capsule`** shape + light **`accent`** outline (**`AppTheme.SearchField`**) on logbook, field guide, and explore (**`CatalogSearchField`**).
- **Explore list:** dive-site search no longer overlaps map/list toggle — trailing slot uses intrinsic width; full-width **`layoutPriority`** only when there are no trailing actions.
- **Tab re-tap scroll-to-top:** **Field Guide** species list and **Explore** dive-site list use the same **`RootTabBarReselectForwarder`** + **`listScrollToTopTrigger`** fallback as **Logbook** (pops navigation + scrolls list); Explore scrolls only in **list** mode.

---

## 53 - Auto-upload media and logbook row previews **(pushed)**

- **Logbook row media preview:** **`DiveLogbookRowDisplayData.previewMediaPhotoID`** (oldest gallery item); trailing **`LogbookRowMediaPreviewView`** (spacer-pinned right, height matches text column); dive **#** as top-leading **`ActivityTagOvalChipLabel`**.
- **Settings → Auto-upload media to activities:** toggles **`AppUserSettings.autoUploadMediaToActivities`**; scans Apple Photos (read access) for images/videos whose capture time falls within each dive’s **`startTime`** … end window (**`bottomTimeSeconds`**, else **`durationMinutes`**, else 90‑min fallback; ±2 min padding).
- **`DiveLibraryMediaAutoAttach`** + **`DiveLibraryMediaAssetLoader`** (PhotoKit fetch + import via **`DiveActivityMediaStorage`**); **`photosLocalIdentifier`** on **`DiveMediaPhoto`** for dedupe; runs after FIT/UDDF/manual import when the setting is on; enabling the toggle runs a logbook backfill with **`DiveLibraryMediaBackfillProgressOverlay`** (cancel + summary).
- **Performance:** per-dive **`PHFetch`** by capture-date window (not one union query across the whole logbook); progress is **Checking dive N of M** instead of iterating every library item in the date span.
- **`NSPhotoLibraryUsageDescription`** updated for library scan + manual attach.
- **Tests:** **`diveActivityMediaAttachWindow_*`**, settings key smoke test, **`diveActivityMediaPresentation_oldestGalleryPhotoID_*`**, **`diveLogbookDisplay_previewMediaPhotoID_*`**.

---

## 54 - Media pointers, timezone import fixes, add-activity & video polish **(pushed)**

- **UDDF naive `datetime` + site `timezone`:** **`DiveDateTimeParsing`** treats clock components as dive-local wall time at the site offset (UDDF **`geography/timezone`** = hours from UTC), not UTC with display-only offset.
- **MacDive without `<timezone>`:** infer hours from linked site **lat/lon** (**`DiveSiteGeographyTimeZoneInference`**) at decode; **`UddfNaiveDatetimeStartTimeCorrection`** re-parses via MapKit when still unresolved before persist (Angel City / Bonaire **15:55** local).
- **Tests:** **`diveDateTimeParsing_naiveDatetime_withSiteTimezone_*`**, **`diveDateTimeParsing_naiveWithBonaireSiteCoordinates_*`**, **`uddfDecoder_angelCityMacDiveExport_*`**.
- **Bulk UDDF import:** optional **Attach photos from library** toggle on the bulk options sheet (defaults from Settings; overrides global for that import); progress stage during PhotoKit match; note that matching may take a few minutes.
- **Import pipeline fix:** **`UddfImportedDiveNormalization`** runs before insert/save/media (bulk was skipping datetime reconcile); transient **`uddfImportDatetimeRaw`** drives re-parse; profile timestamps shift with **`startTime`**; media attach runs only after normalization.
- **MacDive watch datetime rules:** **`UddfMacDiveWatchDatetimeSemantics`** — Suunto **`divecomputer`** → naive **`datetime`** is dive-local; Garmin Descent (MacDive **`variouspieces`**) → UTC wall clock; **`equipmentused`** links drive per-dive parsing (single + bulk UDDF).
- **Bulk import fix:** Suunto dives no longer fail when site lacks **`<timezone>`** — expanded lat/lon inference (Cozumel, Belize, US mountain) + **`location`** name fallback; removed hard **`nil`** for dive-local semantics without TZ.
- **Network timezone lookup:** **`DiveGeographicTimeZoneLookup.uddfHoursFromSite`** uses **`MKReverseGeocodingRequest`** / **`MKLocalSearch`** first (cached); offline region boxes remain fallback. **`UddfMacDiveImportDatetimeNetworkNormalization`** re-parses Suunto/local naive **`datetime`** before persist (single + bulk).
- **Catalog site before geocode:** **`DiveActivitySiteAssociation.previewBestMatch`** runs during import normalization (before link persist) so timezone lookup uses existing **`DiveSite`** coordinates / place fields when the import **`siteName`** matches.
- **`DiveSite` timezone persistence:** optional **`timeZoneIdentifier`** + **`timeZoneOffsetSeconds`** on catalog sites; **`DiveSiteTimeZoneResolution`** writes them from reverse geocode and import reads persisted values before network (DST-aware via IANA id).
- **Auto-upload media window:** **`DiveActivityMediaAttachWindow`** builds bounds in dive-local timezone (site IANA or **`timeZoneOffsetSeconds`**) so PhotoKit matching aligns with logbook local times.
- **Garmin UTC datetime fix:** **`UddfNaiveDatetimeStartTimeCorrection`** no longer re-parses **`.utcWallClock`** naive **`datetime`** as dive-local (was shifting e.g. **18:07 UTC → 22:07 UTC** / **6:07 pm** local display); only fills display **`timeZoneOffsetSeconds`**. Legacy Suunto misparse path unchanged. Tests: **`uddfNaiveDatetimeStartTimeCorrection_garminUtcWallClock_*`**, **`uddfImportedDiveNormalization_garminBonaire_*`**.
- **Media attach local-time matching:** **`DiveActivityMediaAttachWindow`** anchors on dive-local wall clock, infers timezone from site / offset / GPS / place name; **`photoLibraryFetchWindow`** spans local calendar day(s); **`DiveLibraryMediaAutoAttach`** re-resolves offsets before PhotoKit; UDDF import calls **`resolveMissingOffsets`** before attach.
- **Media attach fix — dropped camera photos:** matching now uses only the Photos **`creationDate`** (timezone-correct absolute instant) via **`shouldAttachAsset(creationDate:)`**. Removed the EXIF **`capturedAt`** rejection that discarded GoPro / camera shots whose EXIF lacks **`OffsetTimeOriginal`** (parsed as UTC → hours off). EXIF time is kept for display ordering only. New **`DiveLibraryMediaAttachDebug`** (os.Logger, subsystem **`…MediaAutoAttach`**) traces per-dive window + per-asset decision (matched / outsideWindow / alreadyLinked / missingCreationDate). Test: **`diveActivityMediaAttachWindow_shouldAttachAsset_usesCreationDateNotExifWallClock`**.
- **UDDF upload consolidation:** one UDDF path for one *or* many dives. **Add activity** now shows **Garmin FIT upload** (**.fit**) + **UDDF upload** (**.uddf — one or many dives**, with the create-sites / attach-media options sheet). Removed the single-UDDF branch in the file-upload flow; UDDF is routed by extension to the consolidated **`persistImportedActivities`** path (FIT stays single-file). Renames: **`PickerMode`** **`.singleDive`→`.fit`** (FIT-only types) / **`.bulkUddf`→`.uddf`** (**`isUddf`**); **`runDiveFileImport`→`runFitImport`** (FIT only); **`runBulkUddfImport`→`runUddfImport`**; **`BulkUddfImportSummary`→`UddfImportSummary`**; overlay/sheet copy “Bulk UDDF” → “UDDF”. Tests: **`diveFileImporterPresentation_pickerMode_allowedTypes`**, **`uddfImportSummary_message_listsCounts`**.
- **Photos permission timing:** the Photos access prompt now appears during **profile setup** (**`ProfileEditSheet`** save, when auto-upload is on) and when **toggling auto-upload on** in Settings — even with no dives yet (**`attachMatchingLibraryMediaForAllOwnerDives`** requests access before the empty-log short-circuit). Pure gate **`DiveLibraryMediaAutoAttach.shouldRequestPhotoAccessForAutoUpload`** + **`hasResolvedPhotoLibraryAuthorization`** (prompts only when undecided). Test: **`diveLibraryMediaAutoAttach_shouldRequestPhotoAccess_*`**.
- **Settings default ON:** **Imperial units**, **Automatically renumber dives**, and **Auto-upload media to activities** now default **on** for new users. **`AppUserSettings.registerDefaultValues()`** runs at launch (**`UserDefaults.register(defaults:)`** — never overrides a saved choice); **`@AppStorage`** initial values updated in **`SettingsView`**, **`logbook`**, **`ContentView`**. Tests: **`appUserSettings_registerDefaultValues_*`**.
- **Logbook preview updates immediately:** adding media to a dive (manual upload *or* import auto-attach) now refreshes the logbook row thumbnail right away. **`DiveActivityMediaStorage.addMedia`** posts **`.diveActivityMediaDidChange`** after each save (single chokepoint for both paths); **`LogbookView`** observes it (delivered on **`RunLoop.main`**) and schedules a debounced, background row-cache rebuild (**`includeDuplicateScan: false`**, skipped during delete). Previously the cache only rebuilt on **`activities.count`** changes and the **`NavigationStack`** **`.onAppear`** did not re-fire on pop-back, so previews lagged. Bulk auto-attach posts coalesce via the existing 80 ms debounce. Test: **`diveActivityMediaStorage_postMediaDidChange_notifiesObservers`**.
- **Auto-attach fix — video export (`loadFailed`) for iCloud clips:** matched videos (e.g. GoPro 4K) failed to import because **`DiveLibraryMediaAssetLoader.exportVideoToTemporaryFile`** called **`PHAssetResourceManager.writeData(options: nil)`**, which cannot pull iCloud-offloaded originals. Now uses **`PHAssetResourceRequestOptions`** with **`isNetworkAccessAllowed = true`**, prefers the edited render (**`.fullSizeVideo`**) then original (**`.video`**), and the auto-attach catch logs the real error via **`DiveLibraryMediaAttachDebug.asset(..., detail:)`** (filter Console by subsystem **`GoDive.MediaAutoAttach`**) so the precise failure is visible. (Matching itself was already correct — the failing asset's **`creationDate`** was in-window.)
- **Auto-attach fix — GoPro / action-cam video time zone:** action cameras write **local** wall-clock time into the QuickTime field read as **UTC** (no embedded timezone), so once imported, **`PHAsset.creationDate`** lands one UTC offset away from a watch dive's true-UTC window and was rejected (fetched via the wide day window, but failing the precise window). **`DiveActivityMediaAttachWindow.shouldAttachAsset(creationDate:diveLocalOffsetSeconds:)`** now also accepts an asset when removing the dive-local UTC offset (**`TimeZone.secondsFromGMT(for: startTime)`**) lands its instant in the window — only ever *adds* matches. Scoped to **video** assets (**`DiveLibraryMediaAutoAttach`**) since photo **`creationDate`** is generally correctly zoned. **`photoLibraryFetchWindow`** padded a day earlier so recovery assets near local midnight are still fetched. Tests: **`diveActivityMediaAttachWindow_shouldAttachAsset_recoversGoProLocalAsUtc`**, updated **`…_photoLibraryFetchWindow_spansLocalCalendarDay`**.
- **Tap logbook thumbnail → that photo:** tapping a logbook row's media preview (when present) now deep-links straight to the dive's **Media** tab focused on that photo at the **medium** detent, instead of the default dive view. The thumbnail is a borderless **`Button`** inside the row **`NavigationLink`** (so the rest of the row still opens the dive normally); it pushes a new **`LogbookRoute.diveMedia(diveID, mediaID:)`** route → **`ViewSingleActivity(initialMediaFocusID:)`**, which on first appear selects **`.camera`** + **`.medium`** + the photo (**`selectedDiveMediaPhotoID`**), and the carousel scrolls to it. New pure helper **`DiveActivityMediaFocusPresentation.focus(forMediaFocusID:)`**. Tests: **`diveActivityMediaFocus_withID_targetsCameraTabMediumDetent`**, **`diveActivityMediaFocus_withoutID_isNil`**.
- **Photos-library media as pointers (no duplicated bytes):** media that comes from the user's Photos library is now stored as a **reference** to the original asset instead of copying its bytes/video file into the app — eliminating the disk-storage blowup (especially for 4K video). New **`DiveMediaPhoto.referencesPhotoLibraryAsset`** flag (defaults **`false`**; lightweight SwiftData add) + **`isLibraryReference`** / **`libraryAssetLocalIdentifier`** / **`videoPlaybackSource`** helpers. Reference rows keep **`mediaData`** / **`mediaFileName`** empty and load on demand via new **`DiveMediaReferenceLoader`** (PhotoKit: **`requestImage`** for photo & video-poster thumbnails / full images, **`requestPlayerItem`** for playback, all with **`isNetworkAccessAllowed = true`** for iCloud originals). A missing / offline / deleted asset falls back to the existing photo / **`video.slash`** placeholder. **`DiveActivityMediaStorage.addLibraryReference`** persists the pointer; **`shouldReferenceLibraryAsset`** gates on a non-empty identifier.
- **Auto-attach now references (also fixes iCloud `loadFailed`):** **`DiveLibraryMediaAutoAttach`** creates reference rows (**`addLibraryReference`**) instead of exporting/copying the asset, so matched Photos items attach instantly with zero added disk and no export step (supersedes the §53 **`DiveLibraryMediaAssetLoader`** video-export path, now unused).
- **Manual picker references when possible:** **`DiveActivityMediaBatchImport`** stores a reference for any picked item that has a Photos **`itemIdentifier`** (capture date read via **`DiveMediaReferenceLoader.creationDate`** — no byte copy); Files-sourced items with no identifier still copy in as before. Existing already-duplicated rows are left untouched (no migration; they keep rendering from their stored copy).
- **Video player source refactor:** **`DiveActivityVideoPlayerView`** takes a **`DiveVideoSource`** (`.file(URL)` or `.libraryAsset(localIdentifier)`) and resolves a library asset to an **`AVPlayerItem`** on demand; the **`AVPlayerLayer`** UIView now keys reloads on a stable **`identityKey`** (was the file URL) and builds **`AVPlayer(playerItem:)`**. Thumbnail (**`DiveActivityMediaThumbnailView`**) and full pager (**`DiveActivityMediaItemView`**) load reference images/posters via **`DiveMediaReferenceLoader.image`**. Tests: **`diveMediaStorage_shouldReferenceLibraryAsset_*`**, **`diveMediaPhoto_libraryReference_*`**, **`diveMediaPhoto_videoPlaybackSource_*`**, **`diveVideoSource_identityKey_*`**, **`diveMediaStorage_addLibraryReference_persistsPointerWithoutBytes`**.
- **Reference-only media (removed all byte/file storage):** since Photos (manual **`PhotosPicker`** + auto-attach) is the only dive-media source, **`DiveMediaPhoto`** is now **pointer-only** — fields reduced to **`mediaKind`** / **`sortOrder`** / **`capturedAt`** / **`photosLocalIdentifier`** (dropped **`mediaData`**, **`mediaFileName`**, and the interim **`referencesPhotoLibraryAsset`** flag). Deleted **`DiveMediaFileStore`** (on-disk video copies), **`DiveMediaPhotoImageLoader`** (inline-bytes ImageIO decode), and **`DiveLibraryMediaAssetLoader`** (PhotoKit export/copy). **`DiveActivityMediaStorage`** keeps only **`addLibraryReference`** / **`shouldReferenceLibraryAsset`** / **`nextSortOrder`** / **`postMediaDidChange`** (removed **`addMedia`** byte/file path, **`preparedImageData`**, **`deleteMediaFiles`**). **`DiveActivityMediaBatchImport`** now stores a reference for every picked item with an **`itemIdentifier`** (skips any without). **`DiveBackgroundDeletionWorker`** no longer collects/removes video files (no files exist). Rendering (**`DiveActivityMediaThumbnailView`** / **`DiveActivityMediaItemView`**) is reference-only via **`DiveMediaReferenceLoader`** (removed embedded branches + **`DiveActivityVideoThumbnailView`**).
- **Deleted Photos asset → prune the reference (no placeholder):** when an on-demand load returns nothing, **`DiveMediaReferencePruning.pruneIfAssetMissing`** deletes the **`DiveMediaPhoto`** row and posts **`.diveActivityMediaDidChange`** so the gallery/logbook drop it. Conservative gate **`shouldPrune(hasIdentifier:hasFullAuthorization:assetExists:)`** + **`DiveMediaReferenceLoader.assetExists`**: prunes **only** under **full** Photos authorization and only when the asset is truly gone (a still-existing-but-offline asset keeps the row, so transient failures don't delete). Wired into the thumbnail, full image (on `nil` load), and video player (**`onAssetMissing`** callback). Tests: **`diveMediaReferencePruning_shouldPrune_onlyWhenMissingUnderFullAuthorization`**, **`diveActivityMediaStorage_addLibraryReference_*`**.
- **FIT import options sheet (matches UDDF):** the **Garmin FIT** card now opens the same options confirmation sheet as UDDF before the file picker — **Create dive sites from import** + **Attach photos from library** toggles, then **Choose FIT file**. The shared sheet (**`importOptionsSheet`**, driven by **`importOptionsMode`**) swaps copy/title/identifiers per mode (FIT uses **`ActivityUpload.FitImport.*`**); both modes reuse the same **`importCreateDiveSitesFromImport`** (**`bulkUddfCreateDiveSitesKey`**, default on) + **`importAttachMediaFromPhotoLibrary`** (seeded from **`autoUploadMediaToActivities`** on appear) state. FIT now honors these: **`FitDiveFileImport.persistImportedActivity(createMissingDiveSites:)`** gates new-site creation (still links existing matches), and **`DiveLibraryMediaAutoAttachScheduler.attachAfterDivePersisted(attachMediaFromPhotoLibrary:)`** (+ **`attachMatchingLibraryMedia(for:requiresAutoUploadSetting:)`**) lets the per-import toggle force/skip the Photos attach instead of only following the global setting. Test: **`fitDiveFileImport_persistImportedActivity_createMissingDiveSitesFalse_doesNotCreateSite`**; updated **`diveFileImporterPresentation_pickerMode_allowedTypes`** unchanged.
- **Import pickers restricted to the right extension:** the FIT and UDDF document pickers now only allow selecting files with the matching extension. **`DiveFileImporterPresentation.PickerMode.allowedContentTypes`** returns just **`[.goDiveFit]`** / **`[.goDiveUddf]`** (extension-scoped **`UTType(filenameExtension:)`**), dropping the broad **`.data`** / **`.xml`** types that previously left every document selectable. Test updated: **`diveFileImporterPresentation_pickerMode_allowedTypes`** asserts exact single-type lists (no **`.data`** / **`.xml`**).
- **Full-resolution video playback:** referenced Photos videos now play at full quality — **`DiveMediaReferenceLoader`** requests **`PHVideoRequestOptions.deliveryMode = .highQualityFormat`** (factored into **`makeVideoRequestOptions()`**) instead of **`.automatic`**, which could hand back a lower-resolution / transcoded stream to start playback faster; iCloud originals download on demand (**`isNetworkAccessAllowed`**). Full-screen photos already request a 2048 px target, so quality there was unchanged. Test: **`diveMediaReferenceLoader_videoRequestOptions_useFullResolutionPlayback`**.
- **Featured media (manual logbook preview pick):** the logbook row preview still defaults to the **oldest** gallery item, but the user can now choose a different **featured** photo/video per dive. New persisted **`DiveActivity.featuredMediaPhotoID`** (optional; lightweight SwiftData add) + resolver **`DiveActivityMediaPresentation.featuredPhotoID(in:explicitFeaturedID:)`** / **`featuredPhotoID(on:)`** / **`isFeatured(...)`** (falls back to oldest when the chosen id is missing / pruned). On the dive **camera** tab, the media sheet adds a **star** toggle (**`star`** / **`star.fill`**, **`DiveOverview.MediaFeatureToggle`**) that features the selected item (tap the featured item to revert to default), and the carousel shows a **star badge** on the featured thumbnail (**`DiveActivityMediaCarouselView.featuredMediaID`**). **`DiveActivityMediaStorage.setFeaturedMedia`** persists + posts **`.diveActivityMediaDidChange`** so the logbook updates immediately; **`LogbookActivitySnapshot`** / **`DiveLogbookDisplay`** now seed the preview from **`featuredPhotoID`**. Tests: **`diveActivityMediaPresentation_featuredPhotoID_prefersExplicitThenFallsBackToOldest`**, **`diveLogbookDisplay_previewMediaPhotoID_usesExplicitFeaturedWhenSet`**, **`diveActivityMediaStorage_setFeaturedMedia_persistsAndClears`**.
- **Add activity page redesign:** **`ActivityUploadView`** reformatted into a scannable, grouped layout — a short intro line, then two labeled sections (**Import from a file**: *Garmin FIT* `.fit`, *UDDF* `.uddf`; **Add it yourself**: *Manual entry*). All three options now share one consistent card style (**`addActivitySourceCard`**): a gradient accent **icon badge** (**`sourceIconBadge`**), title with a monospaced file-type **pill** (**`sourceFileTypeTag`**), descriptive subtitle, and trailing chevron, with press feedback (**`AddActivityCardButtonStyle`**, scale + dim) and a softer elevated tile (18 pt radius + subtle shadow). Replaces the old mixed two-centered-tiles-plus-one-row panels (**`addActivitySourcePanel`** / **`addActivitySourceBulkPanel`** removed); content now scrolls. Accessibility identifiers (**`ActivityUpload.FileUpload`** / **`.BulkUddf`** / **`.ManualEntry`**) preserved. Cosmetic-only (no logic/test change).
- **Simplified import dialog (3 milestones):** the FIT / UDDF import overlay is now just a **loading bar + one milestone line** — **Reading File**, **Creating Dive Logs**, **Adding Media** — dropping the per-stage copy, title, "N of M dives imported" counter, and duplicate count from the progress card (final summary alert is unchanged). New internal **`DiveImportMilestone`** (label + contiguous `startFraction`/`endFraction` bar segments + `fraction(completed:total:)` interpolation); **`DiveImportOverlayState`** collapsed from **`.singleProgress`** / **`.bulkProgress`** to a single **`.importing(milestone:fraction:)`** (plus **`.hidden`** / **`.failed`**). UDDF drives the bar within **Creating Dive Logs** (dives persisted) and **Adding Media** (PhotoKit attach `completed/total`); FIT surfaces **Adding Media** by persisting with **`FitDiveFileImport.persistImportedActivity(attachMedia:)`** = `false` then running **`attachAfterDivePersisted`** under the milestone. Tests: **`diveImportMilestone_labels_*`**, **`diveImportMilestone_fractions_advanceMonotonicallyAcrossMilestones`**, **`diveImportMilestone_fraction_interpolatesWithinSegmentAndClamps`**.
- **Video load timeout + retry:** referenced Photos video playback now bounds the load — **`DiveMediaReferenceLoader.playerItem(timeoutSeconds:)`** (default **`DiveMediaVideoLoad.timeoutSeconds`** = 15s) resolves to **`nil`** if **`PHImageManager.requestPlayerItem`** hasn't produced an item by the deadline (iCloud originals can stall or never call back; the request can't be cancelled, so a late result is ignored via a thread-safe **`SingleResumeGuard`** latch that wins the load/timeout race). On failure **`DiveActivityVideoPlayerView`** classifies via new pure **`DiveMediaVideoLoad.classify(itemResolved:isLibraryAsset:assetStillExists:)`** → **`.loaded`** / **`.assetMissing`** (asset truly gone → prune via **`onAssetMissing`**) / **`.retryable`**, and a retryable failure shows an inline **Couldn't load video** error (warning glyph + "still downloading from iCloud" hint) with a **Retry** button (**`DiveActivity.Video.Retry`**) that bumps a **`reloadToken`** to re-run the load **`.task`**. New **`DiveVideoSource.isLibraryAsset`**. Tests: **`diveMediaVideoLoad_classify_distinguishesMissingFromRetryable`**, **`diveMediaVideoLoad_timeout_isPositive`**.

---

## 55 - Logbook dive delete reliability and launch I/O **(pushed)**

- **Logbook dive delete fix:** shared **`DiveActivityPersistenceDeletion`** pipeline on background **`@ModelActor`** — **`DiveActivityRelationshipDetachment`** (tags / owner / site / equipment inverses), cascade delete for profile / buddies / media / sightings (no batch delete on mandatory inverses), **`DiveActivityDeletionMarineLifeCleanup`**, orphan site via **`DiveSiteCatalogMaintenance`**. Tests: large profile cascade, sightings/tags/site inverses, marine-life cleanup, relationship detachment.
- **Logbook delete UX/perf:** optimistic row hide; **`deferRenumber`** via **`DivePostDeleteRenumberScheduler`**; delete runs only on background context (no UI **`ModelContext`** second pass).
- **Logbook delete crash fix:** no main-context fallback or **`processPendingChanges`** merge polling — reconciles optimistic hides with **`FetchDescriptor`** only (avoids **`EXC_BAD_ACCESS`** on invalidated **`@Query`** models). **`DiveDelete`** debug logging (**`DiveActivityDeletionDebug`**) off in Release.
- **Launch SwiftData I/O:** **`AppModelContainer.loadProduction()`** async background container; launch gradient until ready.

## 56 - Test compile fixes **(pushed)**

- **`diveActivityDeletionMarineLifeCleanup_removeDiveReferences_stripsActivityMediaAndSite`:** construct **`MarineLifeUserRecord`** with **`marineLife:`** catalog row (not removed **`marineLifeUUID:`** init label).
- **`DiveMediaVideoLoadOutcome`:** explicit **nonisolated** **`Equatable`** — fixes Swift 6 warning when **`#expect`** compares outcomes in **`diveMediaVideoLoad_classify_*`**.

## 57 - Home highlights and lifetime stats **(pushed)**

- **Summary:** Home tab replaces the coming-soon placeholder with a media highlight carousel and lifetime dive stats grid, with navigation into dives, sites, and field-guide species.
- **`HomeMediaHighlightPresentation`** / **`HomeLifetimeStatsPresentation`** — pure aggregation + daily-seeded shuffle for carousel picks.
- **`HomeOverviewSections`** — featured-media carousel with per-slide bottom chrome (fixed page size, **`slideChromeBottomInset`** above stats overlap; deferred **`playbackIndex`** avoids mid-swipe video/layout jumps); **`HomeLifetimeStatsPanel`** **2×2** highlight tiles (no per-tile background) sized to space between media and tab bar.
- **`HomeMediaHighlightWarmup`** / **`HomeMediaHighlightWarmupPresentation`** — **5** daily carousel picks; bootstrap loads **2** at full hero quality + **3** at **480 pt** previews before **`AppLaunchOverlay`** dismisses; remaining **3** upgrade to full quality + video assets in a background task while the app runs. Foreground re-warm uses the same tiered path. **`AppSessionBootstrapPresentation`** gates the overlay; **`HomeMediaHighlightSessionCache.bestCachedImage`** serves preview or hero frames.
- **`LogOverviewView`** — **`HomeRoute`** navigation to **`ViewSingleActivity`**, **`ExploreDiveSiteDetailView`**, **`FieldGuideMarineLifeDetailView`**. Owner-scoped **`@Query`** (same pattern as Logbook); **`lifetimeStats`** recomputes live from **`@Query`**; **`HomeOverviewRefreshToken`** + **`.id`** on stats grid when dive count/metrics/sightings/media change; carousel refresh on appear, token change, and **`scenePhase == .active`**.
- Tests: **`homeLifetimeStatsPresentation_buildsAggregatesAndLinks`**, **`homeLifetimeStatsPresentation_formattedAverageDiveSummary_joinsDepthAndDuration`**, **`homeMediaHighlightPresentation_dailySeedIsStableAndShuffleRespectsLimit`**, **`homeMediaHighlightPresentation_buildCandidates_mapsSiteAndSpecies`**, **`homeMediaHighlightPresentation_taggedSpeciesCountByMediaID_countsMultipleTags`**, **`homeMediaHighlightWarmupPresentation_bootstrapQualityAndReadiness`**, **`homeMediaHighlightWarmup_shouldStorePreviewAndHeroInSessionCache`**, **`homeOverviewRefreshToken_changesWhenDiveMetricsChange`**, **`homeMediaCarouselPresentation_nextIndex_wrapsAndRequiresMultipleSlides`**, **`appSessionBootstrapPresentation_showsLaunchOverlayUntilHomeMediaWarmCompletes`**, **`homeLifetimeStatsLayout_usesTwoColumnFlexibleGrid`**.
- **Stats ↔ media overlap:** **`panelOverlap`** **154 pt** (~20% higher than prior **128 pt**) + **`heroBottomExtension`** **168 pt** so the lifetime stats sheet rides higher on the hero; tighter **`panelTopContentPaddingWhenOverlapping`** when the panel overlaps media.
- **Home carousel dive chip:** removed trailing chevron from **`HomeMediaCarouselDiveLinkButton`**.
- **`HomeMediaHighlightWarmupPresentation.WarmupQuality`:** explicit **nonisolated** **`Equatable`** — fixes Swift 6 warning in **`homeMediaHighlightWarmupPresentation_bootstrapQualityAndReadiness`**.

## 58 - Home performance, layout, and empty hero **(pushed)**

- **Summary:** Phase A media-loading performance — faster Home bootstrap, deduped PhotoKit image loads, opportunistic thumbnails/previews, single foreground re-warm owner.
- **`HomeMediaHighlightWarmup`** — parallel bootstrap warms (full + preview tiers concurrently); **`warmFromStore`** returns when **`isBootstrapReady`** (remaining warm continues in background).
- **`DiveMediaReferenceLoader.image`** — inflight dedupe via **`DiveMediaReferenceImageCache`**; optional **`deliveryMode`** (preview/thumbnail **`.opportunistic`**).
- **`DiveActivityMediaThumbnailView`** — opportunistic thumbnail delivery.
- **`AppSessionRootView`** — removed duplicate foreground **`warmFromStore`** (Home **`LogOverviewView`** owns re-warm on **`.active`**).
- Tests: **`homeMediaHighlightWarmup_bootstrapTier_warmsFirstSlidesAtFullQuality`**.

- **Summary:** Phase B media-loading performance — app-wide video asset cache, off-main PhotoKit image decode, screen-scale full-screen photos, bounded image NSCache.
- **`DiveMediaVideoAssetSessionCache`** — session LRU (**24** entries) for shareable **`AVAsset`**; used by **`loadVideoAsset`** / **`playerItem`** app-wide.
- **`DiveMediaReferenceLoader`** — PhotoKit image fetch in **`Task.detached`**; video loads via cached **`AVAsset`** or **`requestAVAsset`** (no separate **`requestPlayerItem`** path); **`clearSessionMediaCaches`** clears video cache.
- **`DiveMediaReferenceImageCache`** — **`totalCostLimit`** 128 MB + pixel-byte **`cost`** per entry.
- **`DiveActivityMediaPresentation.fullScreenImageTargetEdge`** — screen pixel width clamped **800…2048** for pager photos (**`DiveActivityMediaItemView`**).
- **`HomeMediaHighlightSessionCache`** — hero images only (video delegates to shared cache).
- Tests: **`diveMediaVideoAssetSessionCache_evictsOldestBeyondCapacity`**, **`homeMediaHighlightSessionCache_evictsOldestImageBeyondCarouselLimit`**, **`diveActivityMediaPresentation_fullScreenImageTargetEdge_clampsToScreenAndCap`**.
- **`fetchImageFromPhotoKit`** — **`.opportunistic`** can invoke PhotoKit multiple times; skip degraded frames and resume once via **`SingleResumeGuard`** (fixes continuation misuse crash).
- **Home carousel startup cap:** videos **> 30 s** excluded from daily shuffle (**`carouselVideoMaxDurationSeconds`**); launch overlay max **5 s** (**`bootstrapOverlayMaxWaitSeconds`**) then Home continues warm; bootstrap counts hero **posters** only (video **`AVAsset`** loads in background); overlay dismisses when first slide has a poster or timeout.
- **Home stats layout:** **`panelOverlap`** **185 pt** + **`heroBottomExtension`** **202 pt** (~20% higher on hero); larger flexible tiles (**`minimumTileHeight`** **88**, height-scaled value/title fonts).
- **Home carousel:** **`carouselLimit`** **3** daily featured picks (was **5**).
- **Home hero:** **`heroHeightToWidthRatio`** **0.77** + overlap extension **162 pt** (~20% shorter media area vs prior **0.96** / **202 pt**).
- **`HomeMediaCarouselEmptyPlaceholder`** — animated ghost photo frames + copy encouraging Logbook media / Settings auto-upload when dives exist but carousel has no picks.

## 59 - Dive buddies roster, Home layout, Profile Dive Buddies **(pushed)**

**Summary:** Universal **`DiveBuddy`** roster + **`DiveBuddyTag`** dive links; Contacts picker for name/photo; legacy tag migration; Home stats/dashboard layout; Profile **Dive Buddies** manager.

- **`DiveBuddy`** — owner-scoped person (`displayName`, **`profilePhoto`**, optional **`contactsIdentifier`**); **`DiveBuddyTag`** join rows on **`DiveActivity`** (cascade on dive delete; person kept).
- **`DiveBuddyCatalog`**, **`DiveBuddyActivityAssociation`**, **`DiveBuddyTagging`**, **`DiveBuddyImportConsolidation`**, **`DiveBuddyOwnership`**, **`DiveBuddyLegacyMigration`**, **`DiveBuddyContactImport`**.
- **`ContactPickerView`** + **Buddies** sheet **Add from Contacts**; **`NSContactsUsageDescription`**; avatars on overview **Buddies** section.
- Import / seed / UDDF / **`DiveActivityOwnership`** assign buddy owner with dives.
- Tests: catalog dedupe, duplicate tag guard, contact name import, legacy migration, deletion keeps **`DiveBuddy`** row.
- **Logbook buddy search:** type in search → **Buddies** suggestion chips from roster; tap to filter dives with that buddy tagged (same UX as **Tags**); **`buddyDisplayNames`** on **`LogbookActivitySnapshotSeed`**.
- **Dive overview Buddies:** **`DiveActivityBuddyAvatarChip`** + **`DiveActivityBuddiesOverviewSection`** — avatar with first name below; horizontal strip on map overview; same chips on **Details** tab.
- **Home top buddies:** **`HomeBuddyLeaderboardPresentation`** + **`HomeBuddyLeaderboardTile`** under lifetime stats when the log has dives and at least one buddy tag — top **3** by shared dive count (avatar, first name, dive count).
- **Home stats tiles:** fixed-height bordered cards (**`homeHighlightTileChrome`**) in a **2×2** grid; buddy leaderboard in its own card below; panel scrolls when needed (no **`GeometryReader`** overlap).
- **Home layout fit:** **`homeDashboard`** — media fixed height to the top edge; stats **`maxHeight: .infinity`** fill viewport down to the tab bar (**`HomeLifetimeStatsPanel.bottomSafeAreaInset`**); **Top species** tile always shown (**`—`** + “Tag marine life on your dives” when no sightings).
- **Home stats (no scroll):** removed stats **`ScrollView`**; **`HomeLifetimeStatsTilesLayout`** sizes all **5** tiles to the fixed panel (**92 pt** stat cards, **152 pt** buddies, **368 pt** scroll content — taller stats sheet, larger **Top buddies** podium).
- **Profile → Dive Buddies:** **`DiveBuddiesListView`** (logbook-style rows + avatar); **`ViewDiveBuddyDetails`** (pushed page: name, avatar, dives-together count, linked **`LogbookActivityRow`** dives); **`DiveBuddyEditSheetView`** + **`DiveBuddyAvatarEditor`** (name + cropped photo).

## 60 - Import buddy dedupe, Home perf, buddy Contacts **(pushed)**

**Summary:** Import buddy names fuzzy-link to existing roster **`DiveBuddy`** rows when names align (UDDF/FIT consolidation path).

- **`DiveBuddyNameMatching`**: token / first-name / first+last heuristics; **`preferredDisplayName`** keeps the fuller label.
- **`DiveBuddyCatalog.findFuzzyMatch`**: used from **`findOrCreate`** after exact normalized match; skips ambiguous ties (e.g. two “Mike …” roster rows for import **Mike**).
- **Home tab performance:** cache **`HomeOverviewAggregate`** (stats + buddy leaderboard + owned media) once per data change instead of recomputing on every SwiftUI body pass; cheap **`contentFingerprint`** / **`carouselFingerprint`**; skip carousel PhotoKit rebuild when picks unchanged; cache video durations.
- **Home Top buddies:** uniform **52 pt** avatars for all three podium slots (no larger #1).
- **Profile → Dive buddy detail — Connect to Contact:** **`ViewDiveBuddyDetails`** — **Connect to Contact** (system picker), **Refresh name and photo**, **Change contact**, **Disconnect contact** when linked; **`DiveBuddyContactLinking`**, shared **`ContactsPickerAccess`**.
- **Self-name skip:** do not tag or create a dive buddy when the name fuzzy-matches the signed-in diver's profile display name (**`DiveBuddyCatalog.shouldExcludeBuddyName`** / **`DiveBuddyNameMatching.isLikelyDiverSelf`**); applies to import, manual tagging, and fixture mapping.
- **Bug fix — import duplicates:** decode pending tags no longer link **`dive`** / transient **`DiveBuddy`** rows ( **`makePendingTag`** ); **`prepareForInsert`** detaches pending tags before roster link; per-file **`rosterCache`** (preloaded + in-batch) reuses one person across dives; **`dives together`** increments via shared **`DiveBuddyTag`** on the same roster row.
- **`FitDiveFileImport`** now runs **`DiveBuddyImportConsolidation`** before insert.
- Tests: **`diveBuddyNameMatching_*`**, **`diveBuddyCatalog_fuzzy*`**, **`diveBuddyImportConsolidation_*`** (fuzzy, batch, detach).

## 61 - Home buddies nav, buddy UX, onboarding permissions **(pushed)**

**Summary:** Home Top buddies podium avatars push to the same buddy detail page as Profile → Dive Buddies.

- **`HomeRoute.diveBuddy`**: **`log_overview`** resolves owner roster row and shows **`ViewDiveBuddyDetails`**.
- **`HomeBuddyLeaderboardPodiumSlot`**: plain **`Button`** per slot; accessibility hint + **`Home.BuddyLeaderboard.Slot.{rank}`** identifiers.
- **Home layout:** reverted stats-sheet transparency / carousel clip experiments — opaque **`HomeLifetimeStatsPanelBackground`** and original carousel framing restored (bubbles remain behind the tab via **`WaterBubbleBackground`** only).
- **Bubbles on more lists:** **`AppPage.showsWaterBubbleBackground`** — **Profile → Dive Buddies**; **Explore** dive-site **list** mode (map unchanged; UI-test skip).
- **Buddy detail contacts UX:** **`ViewDiveBuddyDetails`** — contact badge on avatar (bottom-trailing) opens **`ContactPickerView`** (link / change); removed separate refresh / change / disconnect buttons; **`.task`** refreshes name + photo from Contacts on load when linked.
- **Dive buddies sheet:** compact roster rows; trailing **+** and **Done** toolbar buttons; **+** opens **`DiveActivityAddBuddySheet`** (name + **Connect to Contact**).
- **New-account permissions:** first Sign in with Apple profile creation triggers **`AppOnboardingPermissions`** — Contacts then Photos (only while **`.notDetermined`**; skipped in UI tests); **`ContactsPickerAccess.requestAccessIfNeeded`** shared with buddy contact picker.

## 62 - Field Guide taxonomy browse and sightings heat map **(pushed)**

**Summary:** Field Guide tab split + Caribbean taxonomy browse (category bento hub, trail index, species mosaic); catalog model gains **`subcategory`**.

- **`FieldGuideSection`** + **`FieldGuideSectionToggle`** — book / camera icons (Explore-style segmented control).
- **`FieldGuideTopChrome`** — full-width **`FieldGuideSectionToggle`** above species search (search on **Field Guide** only); status-bar scrim.
- **`FieldGuideSightingsOverviewView`** — satellite heat map hero + **`DiveActivityOverviewEmbeddedPanel`** (minimized / medium / large detents, grabber drag) matching dive map tab; map pan/zoom at minimized only; **`FieldGuideSightingsCollapsedSummary`** minimized strip.
- **`FieldGuideSightingsHeatPresentation`** + **`FieldGuideSightingsHeatMapRepresentable`** — owner **`SightingInstance`** rows grouped by **`DiveSite`** region/country; **`MKCircle`** overlays with teal→coral intensity.
- **`FieldGuideTaxonomy`** — 11 top-level categories + fish / invert subgroups (Humann-style); legacy label inference (`Ray` → fish / sharks-and-rays, etc.).
- **`FieldGuideCatalogIndex`** — per-category / per-subcategory species counts from catalog snapshots.
- **`FieldGuideCatalogBrowseViews`** — bento **category hub** (featured Fish tile), **category header** (hero placeholder, title, description) + **Groups** subcategory list, **photo mosaic** grid on subcategory; search still flattens to species rows.
- **`field_guide.swift`** — **`FieldGuideRoute`** `.category` / `.subcategory` / `.speciesDetail`; hub when search inactive.
- **`MarineLife.subcategory`**, **`MarineLifeDTO.subcategory`**, **`marine_life_sample.json`** taxonomy slugs; **`MarineLifeCatalogSeeder`** upserts bundled rows by UUID (refreshes taxonomy on relaunch). **`subcategory`** uses **`= ""` on the property** for SwiftData lightweight migration (fixes **`loadIssueModelContainer`** on existing stores).
- Tests: **`fieldGuideTaxonomy_resolvesLegacyCategoryLabels`**, **`fieldGuideCatalogIndex_countsSpeciesPerCategoryAndSubcategory`**, **`fieldGuideSightingsHeat_groupsSightingsByRegion`**, **`fieldGuideSightingsHeat_ignoresNonOwnerSightings`**; search / presentation snapshots updated.

## 63 - Marine life catalog, buddies add, My Sightings panel **(pushed)**

**Summary:** Expand **`MarineLife`** catalog fields from **`marine_life_source.csv`** and add bundled **Queen Angelfish** record.

- **`MarineLife`** — **`familyName`**, **`minDepthMeters`**, **`maxDepthMeters`**, **`distinctiveFeatures`**, **`abundance`**, **`habitatBehavior`**, **`diverReaction`** (property defaults for SwiftData migration).
- **`MarineLifeDTO`** / **`MarineLifeMapper`** — snake_case JSON mapping; normalizes display category/subcategory to taxonomy slugs; derives **`avgDepthMeters`** from min/max when omitted.
- **`marine_life_sample.json`** — **Queen Angelfish** row from CSV; French Angelfish gains **`family_name`**.
- **`MockData/marine_life_source.csv`** — attached source spreadsheet (placeholder angelfish rows for future fill-in).
- **`FieldGuidePresentation`** — depth range line when min/max depth present; snapshot + search include new text fields.
- **`FieldGuideMarineLifeDetailView`** — family, depth range, distinctive features / abundance / habitat / diver reaction sections.
- Tests: **`marineLifeMapper_mapsQueenAngelfishExtendedCatalogFields`**, **`fieldGuidePresentation_depthLine_prefersMinMaxRange`**, **`marineLifeCatalogSeeder_seedsQueenAngelfish`**.
- **`FieldGuideSectionToggle`** — sightings segment label **My Sightings** (was **Sightings**).
- **`DiveBuddiesListView`** — trailing **+** opens **`DiveActivityAddBuddySheet`** (roster-only); **`DiveBuddyRosterCreation`** helper; empty state mentions **+**.
- **My Sightings** — static **`HomeLifetimeStatsPanel`** over heat map (Home-style rounded sheet, no detents/grabber); **`FieldGuideSightingsOverviewLayout`**; scrollable stats body.

## 64 - Home perf, logbook density, buddy Contacts auto-link **(pushed)**

**Summary:** Home featured-media performance — decouple launch from PhotoKit warm, warm slide **0** only at startup, lighter carousel video, lazy slide loads.

- **`AppSessionBootstrapPresentation`** / **`AppSessionRootView`** — launch overlay ends after session restore only; Home warms on **`LogOverviewView`**.
- **`HomeMediaHighlightWarmup`** — bootstrap warms first slide only; deferred preview/full for slides **1…n**; no background **`AVAsset`** warm; **`PHCachingImageManager`** preheat for first asset only; opportunistic poster delivery.
- **`HomeMediaHighlightWarmupPresentation`** — **`startupFullQualityCount = 1`**; display-sized hero edge (**2×**, cap **900**); **`deferredCarouselWarmDelaySeconds`**.
- **`DiveMediaVideoRequestQuality`** — Home carousel **`.automatic`** (no session cache); dive detail **`.highQualityFormat`** unchanged.
- **`HomeMediaCarouselMediaView`** — lazy load for selected/playback slide only; container-width hero requests.
- Tests: **`homeMediaHighlightWarmupPresentation_bootstrapQualityAndReadiness`**, **`diveMediaVideoRequestQuality_homeCarouselDoesNotCacheInSession`**, **`appSessionBootstrapPresentation_showsLaunchOverlayOnlyWhileRestoringSession`**.
- **Logbook** — denser **`LogbookActivityRow`** tiles (smaller type, **8 pt** card padding / list spacing, compact **#** chip, **48 pt** media preview min).
- **Certifications list** — row tile shows title, type badge, and agency/number + date only (instructor removed from list; instructor & shop remain on detail / edit).
- **Dive buddy auto-link** — after **FIT** / **UDDF** import, unlinked roster buddies fuzzy-match Apple Contacts when access is **authorized** or **limited** (**`DiveBuddyContactAutoLink`**); skips ambiguous matches and contacts already linked to another buddy.
- **`DiveBuddyContactsAuthorization`**, **`DiveBuddyContactLinking.applyIdentifier`**; contact enumeration off main thread; tests **`diveBuddyContactAutoLink_*`**.

## 65 - Field Guide category art and My Sightings reset **(pushed)**

**Summary:** Field Guide category background line art (fish, coral, anemone, tube sponge, mollusk) in **`Assets.xcassets`**; hub tiles + category hero use **`.screen`** blend over gradients.

- **`FieldGuideCategoryFish`**, **`Coral`**, **`Anemone`**, **`TubeSponge`**, **`Mollusk`** imagesets; **`FieldGuideCategoryBackgroundArt`**; **`heroImageName`** on five taxonomy categories.
- **`FieldGuideCategoryCrab`**, **`SeaStar`**, **`ChristmasTreeWorm`** (twin spiral crowns), **`SeaTurtle`**, **`Whale`** — remaining hub/hero categories.
- **`FieldGuideCategoryTunicateChain`** — colonial invertebrates (chain tunicate double-row zooids).
- **`Scripts/stylize_field_guide_category_art.py`** — batch pass on all **11** category PNGs (higher threshold, thicker **`MaxFilter`** strokes, pure black/white).
- **`FieldGuideCategoryBackgroundArt`** — **0.7** scale, **10°** rotation anchored top-trailing, tighter corner padding on hub + hero.
- **My Sightings heat map** — Gaussian KDE raster overlay (continuous teal→coral); aggregation per **dive site** (not region); stats panel **Sites** / **By dive site**.
- **Heat map zoom** — raster rebuilds from **`visibleMapRect`** after **~140 ms** debounced pan/zoom; grid cell size ~**1800** map points; tighter **`heatmapSigmaCellFactor`** (**0.72**); **`OverviewData`** holds **`plottedSightings`** only (no pre-baked raster).
- **Heat map initial render** — **`heatmapSamplingMapRect`** falls back to fit region / plot bounds when **`visibleMapRect`** is not ready; layout + **`mapViewDidFinishLoadingMap`** refresh; failed builds do not cache **`none`** (retry after map lays out).
- **Heat map render (reliable)** — Restored per-site **`MKCircle`** + **`MKCircleRenderer`** (same pattern as initial shipped map); removed fragile KDE **`UIImage`** **`MKOverlay`** path.
- **Heat map blend** — **5** concentric rings per site (soft alpha falloff, no stroke); peak radius **900 m–3.5 km** so neighboring sites merge.
- **My Sightings panel** — stats sheet shows only **Sightings** count and **Most productive site** (name + count); removed species/sites row and per-site list.
- **My Sightings reset** — **`FieldGuideSightingsOverviewView`** is a blank placeholder; removed heat map / layout / presentation / canvas / collapsed-summary components and related unit tests (rebuild from scratch later).
- **Heat map plot resolution** — Backfill **`diveSiteID`** / GPS from owner **`DiveActivity`** entry when catalog site coords are missing; match catalog site by **`resolvedSiteName`** when needed.
- **Heat map render fix** — transparent below density threshold; premultiplied RGBA; no full-rect teal wash from zero-alpha cells.
- **Launch responsiveness** — **`AppLaunchMaintenance`** runs dive # backfill, buddy migration, and marine catalog seed off the main actor; MapKit warm-up deferred **400 ms** (no launch **`Map`** mount).

## 66 - Map overview, Home cache, light mode, and launch parity **(pushed)**

**Summary:** Home featured media re-warms from session cache when returning to the tab; carousel assets stay pinned in **`HomeMediaHighlightSessionCache`**.

- **`LogOverviewView`** — re-warm when slides are not displayable (e.g. after background cache clear); keep carousel visible after first session warm.
- **`HomeMediaHighlightWarmup`** — immediate preview warm for all carousel slides on Home (no 1.5s defer); **`carouselHighlightsAreDisplayable`** + pin active library ids in session cache.
- **`HomeMediaHighlightSessionCache`** — pinned carousel identifiers skip LRU eviction; **`HomeMediaCarouselMediaView`** stores loaded hero frames into session cache.
- Tests: **`homeMediaHighlightSessionCache_pinsCarouselIdentifiersDuringTrim`**.
- **Expandable dive lists** — **`ExpandableDetailSection`** (collapsed by default) on buddy **Dives together**, Explore **Activities at this site**, Field Guide **Activities sighted on**; **`ExpandableDetailSectionPresentation`**.
- Tests: **`expandableDetailSectionPresentation_collapsedByDefaultWithItems`**.
- **Dive overview panel chrome** — map / tank / camera embedded sheet uses opaque **`AppOverviewSheetPanelBackground`** (same blue gradient as **`HomeLifetimeStatsPanel`**); removed frosted **`thinMaterial`** on **`diveActivityOverviewEmbeddedPanelChrome`** (top-edge fade reverted — panels stay fully opaque).
- **Map tab panel detents** — **minimized**: header only; **medium**: header + stats box; **large**: editable sections, tags, coordinate note.
- **Map detent transitions** — single mounted panel body with progressive stats/details reveal; **large** detent always mounts editable sections + tags under the stats box (**`mapPanelShowsDetails`**); shared **`.diveOverviewPanelDetent`** spring. **`DiveActivityMapOverviewPanelContent`** reads panel height fraction inside the sheet subtree.
- **Editable section tab split** — **Location** removed from map; **Operator**, **Source & import**, and **Record** moved to **tank** tab (**large** detent only). Map **Water temperature** + **Conditions** merged into **Dive Conditions**.
- Tests: **`diveActivityOverviewPanelMetrics_mapPanelVisibility_followsRestingDetent`**, **`diveActivityEditableCatalog_tankLargeDetentSections_filterAtMedium`**, updated **`diveActivityEditableCatalog_mapAndTankSectionsAreDistinct`**.
- **Field Guide hub tiles** — category titles reserve a two-line block (**`FieldGuideHubTileLayout`**) so short names align with wrapped titles in the bento grid.
- **Light mode readability** — dark header/list scrims; deeper ocean teal page + bubble backdrop.
- **Map stats box** — surface interval **> 60 min** shows **`N Hr(s)`** / **`M Min(s)`** (**`formattedMapSurfaceIntervalParts`**).
- Tests: **`appLaunchLayout_matchesStoryboardConstraints`**, **`fieldGuideHubTileLayout_titleReservesTwoLines`**, **`diveActivityOverviewPresentation_mapOverviewStatsLayout`**, panel metrics and editable-catalog tests.
- **Map overview header + stats box** — dive chip, site, region/date line, duration + surface interval + depth gauge on **medium** detent.
- **Launch branding** — fixed **dark** system launch screen + matching **`AppLaunchOverlay`** (**`AppLaunchLayout`**).

## 67 - Google Maps experiment: Explore, dive overview, site picker **(pushed)**

**Summary:** **`experiment/google-maps`** branch — Google Maps SDK SPM + Explore map spike behind **`GoDiveMapEngine`**.

- Branch **`experiment/google-maps`** from **`main`**.
- **SPM:** **`googlemaps/ios-maps-sdk`** (**`GoogleMaps`** product) on the app target.
- **`GoDiveMapEngine`** — default **MapKit**; launch arg **`-GoDiveMapEngineGoogle`** opts into Google Maps.
- **`GoogleMapsBootstrap`** + **`GoDiveGoogleMapsAppDelegate`** — **`GMSServices.provideAPIKey`** from gitignored **`Config/GoogleMapsSecrets.plist`** (see **`GoogleMapsSecrets.example.plist`**).
- **`ExploreCatalogGoogleMapRepresentable`** — satellite **`GMSMapView`** with red markers; **`ExploreCatalogMapView`** switches when engine + API key are set.
- **`ExploreCatalogMapPresentation.boundingRegion`** — vendor-neutral camera bounds shared with MapKit **`region(for:)`**.
- Tests: **`goDiveMapEngine_*`**, **`exploreCatalogMapPresentation_boundingRegion_matchesMapKitRegion`**.
- **`app_summary.md`** — **External dependencies** section (FIT, Google Maps SDK, Apple frameworks); **`todo.md`** — Google Cloud / OAuth consent evaluation item.
- Swift 6: **`nonisolated`** on map-engine / region-spec helpers; **`GMSMapView()`** replaces deprecated frame initializer.
- **Explore map (hybrid + labels):** **MapKit** **`MKHybridMapConfiguration`** + **`MKMarkerAnnotationView.titleVisibility = .visible`**; **Google** **`.hybrid`** + labeled pin assets (**`ExploreCatalogGoogleMapMarkerImageFactory`**).
- **Explore zoom-aware labels:** **`ExploreCatalogMapLabelVisibility`** — per-site staggered reveal (nearest first); labels begin after tighter zoom (**`pinOnlyLatitudeSpan`** **7.5°**, **`firstLabelRevealProgress`** **0.32**).
- **Third-party POI suppression:** **`GoDiveMapPointOfInterestSuppression`** — **MapKit** **`pointOfInterestFilter = .excludingAll`**; **Google** JSON **`mapStyle`** + optional Cloud **Map ID** in secrets.
- **Dive overview Google map:** **`DiveLocationGoogleMapRepresentable`** — hybrid **`GMSMapView`**, entry **`mapMarkerCoordinateTitle`** label on pin, detent-aware camera via **`DiveLocationMapGoogleCameraPresentation`**; **`DiveLocationMapView`** switches with **`GoDiveMapEngine`**.
- **Dive Google map framing:** **`GMSMapView.padding`** (top chrome + sheet) centers the pin in the visible band; camera targets the dive coordinate (MapKit still uses **`adjustedMapCenter`** latitude shift).
- **Site coordinate picker Google map:** **`DiveSiteCoordinatePickerGoogleMapRepresentable`** — hybrid inlay, drag-to-set lat/lon under fixed center pin; **`DiveSiteCoordinatePickerMapView`** switches with **`GoDiveMapEngine`**.
- Tests: **`diveLocationMapGoogleCameraPresentation_*`**, **`diveSiteCoordinatePickerPresentation_approximateZoomLevel_*`**, **`goDiveMapPointOfInterestSuppression_googleStyleJSON_parses`**.

## 68 - Welcome flow, Field Guide 3D hero, nav perf, equipment locker **(pushed)**

**Summary:** First-login welcome screen before Contacts + Photos permission prompts.

- **`NewAccountWelcomeView`** — **`AppPage`** with **GoDive** **`AppHeader`**, welcome copy, Contacts + Photos explainer, bottom **Continue**.
- **`AppNewAccountWelcomePresentation`** — copy + **`shouldPresentWelcome(forNewAccount:)`** (skipped under UI tests).
- **`AccountSession.showsNewAccountWelcome`** — set on brand-new Sign in with Apple; **`completeNewAccountWelcome()`** runs **`AppOnboardingPermissions`**.
- **`AppSessionRootView`** — welcome gates **`ContentView`** until Continue.
- **`NewAccountWelcomeView`** layout — Home-style **`GeometryReader`** + overlaid **`AppHeader`**; full-bleed gradient; permissions card fills space above Continue.
- Tests: **`appNewAccountWelcomePresentation_*`**, **`accountSession_completeNewAccountWelcome_*`**.
- **Equipment locker avatar hero:** replaced PNG with **simple line outline** (programmatic, transparent); no wireframe mesh fill.
- **Equipment locker avatar hero (fix):** **`EquipmentLockerAvatarHero.png`** now uses the smooth continuous white outline (green keyed to alpha); removed prior angular stick-figure art. Layout constants no longer stretch the figure artificially.
- **Equipment locker hero polish:** removed perspective/background grid overlay; thickened outline in **`EquipmentLockerAvatarHero.png`**; dropped **`EquipmentLockerAvatarHeroGridOverlay.swift`** (glow tuning lives in **`EquipmentLockerDiverAvatarPresentation`**).
- **Equipment locker hero asset:** **`EquipmentLockerAvatarHero.png`** from user green-screen art (transparent bg + thickened stroke only); hero shows asset at 1× scale with no glow/shadow.
- **Equipment locker hero asset:** thinned outline stroke (minimal dilation from source art).
- **Equipment locker hero layout:** figure centered in the top hero band above the gear list (removed bottom alignment + downward offset).
- **Equipment locker gear panel:** Strava-style **`DiveActivityOverviewEmbeddedPanel`** (default **medium**, drag to **minimized** / **large**); full-bleed hero behind panel; figure **zooms in** at **minimized** via **`EquipmentLockerDiverAvatarPresentation.heroScale`** + shared **`.diveOverviewPanelDetent`** spring.
- **Equipment locker gear panel:** opens at **minimized** (**`EquipmentLockerGearPanelPresentation.defaultDetent`**); hero stays centered in the visible band at every detent (**`heroVerticalOffset = −margin × 0.5`**) with scale + position interpolated while dragging.
- **Equipment locker large detent:** avatar hidden (**`heroOpacity`** fades **medium → large**); **+** add control moved from **`AppHeader`** to gear sheet toolbar / minimized summary.
- **`EquipmentGearType`** + **`EquipmentItem.gearType`:** menu picker on add/edit (**BCD**, **Mask**, **Snorkel**, **Fins**, **Wetsuit**, **Camera**, **Regulator**, **Octopus**, **Other**); legacy **`type`** text mapped on load; tests **`equipmentGearType_*`**, **`equipmentItemPresentation_gearTypeLabel_*`**.
- **Equipment locker BCD hero overlay:** when locker owns **BCD** gear, **`EquipmentLockerBCDOverlay`** line art layers on the figure chest (separate asset + **`showsBCDOverlay`**); tests **`equipmentLockerGearOverlayPresentation_ownsBCD_*`**.
- **Equipment locker gear overlay fill:** BCD silhouette asset filled (template) and tinted with **`AppTheme.Colors.accent`** (**`gearOverlayFillOpacity`**).
- **Equipment locker BCD overlay art:** front-facing white-filled BCD from user reference sketch (shoulder straps, chest strap, waist belt, inflator); overlaid on hero torso.
- Tests: **`equipmentLockerDiverAvatarPresentation_heroHeight_*`**, **`equipmentLockerDiverAvatarPresentation_heroImageName_*`**, **`equipmentLockerDiverAvatarPresentation_heroFigureScale_*`**.
- **`GoDiveMapEngine`:** uses **Google Maps** whenever **`GoogleMapsSecrets.plist`** loads a valid API key (launch arg **`-GoDiveMapEngineGoogle`** still supported); tests **`goDiveMapEngine_googleMapsSecretsFile_*`**.
- **Field Guide 3D hero:** **French Angelfish** bundled **`FrenchAngelfish.usdz`** (Meshy export) on **`FieldGuideMarineLifeDetailView`** via **`FieldGuideMarineLifeRealityHeroView`** (**RealityKit**, virtual camera, **`SceneEvents.Update`** spin + drag overlay); catalog **`feature_model`** + **`featureModelResourceName`**; tests **`fieldGuideMarineLifeHeroPresentation_*`**, **`marineLifeCatalogSeeder_seedsFrenchAngelfishModel`**.
- **Field Guide pushed chrome:** **`AppHeader`** shows page **`title`** (species common name, category, subcategory) instead of **GoDive** when **`showsBrandWordmark: false`** on **`FieldGuideMarineLifeDetailView`** and catalog browse pages.
- **Equipment locker:** list-only **`EquipmentLockerView`** (Logbook-style scroll-under header, swipe delete); removed diver hero, BCD overlay, and embedded gear panel.
- **`GoogleMapsWarmup`:** hidden **hybrid** **`GMSMapView`** warm-up ~400 ms after launch (with **`MapKitWarmup`**) when Google Maps is active; test **`googleMapsBootstrap_shouldWarmUpAtLaunch_*`**.
- **Field Guide category navigation perf:** hub **`CategorySummary`** cached in **`@State`** (refresh on catalog change); route carries precomputed summary (no hub lookup on push); **`WaterBubbleBackground`** removed while catalog stack is pushed; hub grid **`.equatable()`**; category hero line art **`.drawingGroup()`**; test **`fieldGuideCatalogIndex_categorySummaryIsHashable`**.
- **Field Guide species detail:** **`FieldGuideMarineLifeDetailView`** uses **`AppHeaderlessPage`** — full-bleed hero under the status bar, **`LogbookTopChromeScrim`** + floating back chevron (no pinned title bar); natural-history / about copy above tagged media and **Activities sighted on**.
- **Field Guide 3D hero:** French Angelfish **`fitExtent`** **0.48** (was **0.58**) and **`modelVerticalOffset`** **−0.09** so the model reads smaller and sits lower in the hero band.
- **Field Guide subcategory navigation perf:** cached **`subcategorySpeciesIndex`** + **`SubcategoryBrowsePayload`** in route (no catalog re-filter on push); **`FieldGuideCategoryDetailView`** / **`FieldGuideSubcategorySpeciesView`** **`.equatable()`**; mosaic cards **`.equatable()`**; test **`fieldGuideCatalogIndex_subcategorySpeciesIndex_lookup`**.
- **Field Guide species detail chrome:** back chevron via shared **`AppHeader`** (same vertical alignment as other pushed pages); test **`fieldGuideTaxonomy_fishCategoryHasDetailHeaderCopy`** expects **`FieldGuideCategoryFish`** hero asset.

## 69 - Buddies delete, dive sheet UX, Field Guide, media marine life **(pushed)**

**Summary:** Delete dive buddies from the edit sheet; roster row untags all dives.

- **`DiveBuddyDeletion`** — removes roster row and **`DiveBuddyTag`** participations on owned dives.
- **`DiveBuddyEditSheetView`** — red **Delete buddy** at bottom + confirmation; pops detail on success.
- Test: **`diveBuddyDeletion_deletePermanently_removesBuddyAndUntagsDives`**.
- **`DiveActivityBuddiesEditSheet`** — **+** (new buddy) **top-leading**, **Done** **top-trailing** (separate toolbar items); accent **`tabSelected`** on both.
- **`DiveActivityTagsEditSheet`** — same toolbar chrome (**+** create tag sheet, **Done**); inline create section removed.
- **`DiveActivityFieldEditSheet`** — **Done** only (top-trailing, accent) on every dive field editor; swipe-to-dismiss discards draft (no **Cancel**).
- **`DiveActivityEditableRow`** / **`DiveActivityBuddiesOverviewSection`** — accent **`ellipsis`** (⋯) instead of chevron on editable overview fields.
- **Dive overview notes row** — section title only; inline **Notes** caption hidden (no duplicate label above preview text).
- **Field Guide** — removed **Field Guide** / **My Sightings** segmented toggle; deleted **`FieldGuideSectionToggle`**, **`FieldGuideSightingsOverviewView`**, and **`FieldGuideSection`**; **`FieldGuideTopChrome`** is species search only; tab reselect always scrolls catalog to top.
- **Dive Media sheet (medium)** — **`DiveActivityPhotosPanelContent`** shows tagged species names as oval chips on the selected item, or a tappable **Tag marine life spotted in this photo.** prompt when none; marine life row sits **above** the thumbnail carousel; **`MarineLifeMediaTagPresentation`** copy + accessibility helpers.
- **Dive Media sheet (large)** — tagged species at top: horizontal chip picker when multiple; **`DiveActivityMediaTaggedSpeciesDetailContent`** shows bundled **USDZ** hero (or photo / placeholder), common + scientific name, and natural-history sections; fish + **+** chrome actions; untagged prompt when empty.

## 70 - AI fish identification **(pushed)**

**Summary:** Fishial.AI credentials scaffold for manual fish ID (plist-only for now).

- Gitignored **`Config/FishialSecrets.plist`** (**`ClientID`**, **`ClientSecret`** from [portal.fishial.ai](https://portal.fishial.ai)).
- **`FishialSecretsBootstrap`** — loads credentials when placeholders are replaced; test **`fishialSecretsBootstrap_validatedCredentials_rejectsPlaceholders`**.
- **Fishial Phase 1** — **`FishialAPIClient`** (v2 auth + binary **`/v2/recognize`**, optional **`Fishial-Location-Lat-Lon`** from dive map coordinate), **`FishialImageBlobMetadata`**, **`FishialRecognitionPresentation`**, **`FishialObservationLocation`**, **`DiveMediaFishialFrameExport`** (photo JPEG export; video scrub context with preview + full-quality still on Identify); mock-session tests in **`FishialAPITestSupport`**.
- **Fishial identify UI** — sparkles control on **Media** sheet chrome (and minimized carousel); **`DiveMediaFishialIdentifySheet`**: photos show one still; videos open a **large** full-bleed **`FishialVideoScrubPlayerView`** (**PhotoKit `AVAsset` + native **`AVPlayer`** seek) with a bottom scrub bar → user picks the moment → one Fishial API call; progress + plain-text results; **`DiveMediaFishialIdentification`**, **`FishialVideoScrubPresentation`**, **`FishialIdentificationResultPresentation`**.
- **Media tab medium/large detent** — **`DiveActivityPhotosPanelContent`** pins the thumbnail carousel to the same on-screen slot at every detent; **medium** shows marine-life chips + top chrome (fish / Fishial / featured / **+**); **large** is chrome-free — tagged-species detail (scrollable) + carousel, or **`largeDetentUntaggedPrompt`** when empty.
- **Fishial confirm + persist** — after **`/v2/recognize`**, one match prompts **Yes / Not accurate**; multiple matches show a picker + **Save**; confirmed scientific name stored on **`DiveMediaPhoto.fishialConfirmedSpeciesName`** via **`DiveMediaFishialIdentificationStorage`**; **medium** detent shows a **Fish ID** row (**`FishialIdentificationReviewPresentation`**). Tests: **`fishialIdentificationReviewPresentation_reviewMode_branchesByResultCount`**, **`diveMediaPhoto_resolvedFishialConfirmedSpeciesName_trimsBlankValues`**, **`diveMediaFishialIdentificationStorage_saveConfirmedSpecies_persistsOnMedia`**.

## 71 - Next batch **(pushed)**

**Summary:** Swift 6 test/build hygiene — nonisolated conformances, hoisted value types, and an agent rule to xcodebuild on run/test requests.

- **Swift 6 actor isolation** — top-level **`FieldGuideCategorySummary`**, **`FishialRankedSpecies`**, **`FishialIdentificationReviewMode`**, **`FishialAPICredentials`**, **`DiveActivityMapOverviewStatIcon`** with explicit **nonisolated** **`Equatable`** / **`Hashable`**; **`FishialAPIClient`** **nonisolated** inits; **`FieldGuideMarineLifeHeroPresentation.HeroKind`** **nonisolated** **`==`**; test fixes (**`MarineLife`** init order, **`@MainActor`** Hashable test, whole-value Fishial rank asserts).
- **Cursor rule** — **`.cursor/rules/xcode-run-test.mdc`**: on *run* / *test* requests, agent runs **`xcodebuild`** (Dre's Phone or iPhone 17 sim), reports errors/warnings, rebuilds after fixes.

## 72 - Next batch **(pushed)**

**Summary:** xcode run/test rule always cleans before build.

- **`.cursor/rules/xcode-run-test.mdc`** — **`xcodebuild clean`** for the target destination, then **`clean build`** / **`clean build-for-testing`** on every run/test request.

## 73 - Caribbean catalog, Field Guide images, Fishial catalog match **(pushed)**

**Summary:** Caribbean FishBase facts pipeline — staging CSV + extract/sync scripts.

- **`Scripts/extract_fishbase_caribbean.py`** — FishBase v24.07 parquet (Caribbean saltwater fish) → **`MockData/marine_life_caribbean_staging.csv`** (1,677 species); fills names, science name, family, depth, max size, subcategory where mapped; leaves user prose + images empty.
- **`Scripts/sync_marine_life_staging_to_json.py`** — merges rows with **`aboutText`** into **`marine_life_sample.json`** (preserves existing UUID prose).
- **`Scripts/fishbase_caribbean_config.json`**, **`fishbase_catalog_utils.py`**, **`MARINE_LIFE_CARIBBEAN_WORKFLOW.md`**, Python **`unittest`** helpers.
- **Diver visibility filter** — staging extract keeps reef/demersal/neritic habitats + `ecology.CoralReefs` (FishBase **-1** flag) and `maxDepth <= 130 m`; drops bathypelagic / deep-demersal obscurities (~601 species vs 1,677).
- **FishBase placeholder descriptions** — `include_fishbase_descriptions` fills `aboutText` from `species.Comments` (+ ecology `AddRems` fallback) and `distinctiveFeatures` from `BodyShapeI`; sync to **`marine_life_sample.json`** for in-app Field Guide testing (replace with original GoDive prose later).
- **Marine life hero images** — **`fetch_marine_life_images.py`** + **`marine_life_image_utils.py`**: Wikimedia Commons + Openverse, CC0-first then CC BY, scientific-name scoring, `imageNeedsReview` flags, JSON cache; unittest coverage.
- **Underwater image pass** — search suffixes (`underwater`, `diver`, `scuba`), undesirable-artifact penalties (maps/sketches/fishing), **`--refetch-gaps`** for misses + review rows, cache v2.
- **Field Guide catalog image layout** — **`FieldGuideMarineLifeCatalogImage`**: fixed 4:3 mosaic crops + uniform label block; capped detail/media heroes so remote photos cannot resize pages or clip body text.
- **Field Guide image crop fix** — reserve bounds with `Color.clear` + `GeometryReader` fill so `AsyncImage` cannot expand mosaic/detail layouts past the clipped frame.
- **Fishial → catalog fuzzy match + tag** — **`FishialMarineLifeCatalogMatching`** maps Fishial scientific names onto Field Guide **`MarineLife`** rows (normalize + token/Levenshtein similarity); review UI shows catalog thumbnails via **`FieldGuideMarineLifeCatalogImage`**; confirming a match calls **`MarineLifeSightingRecorder.tagSpecies`** + persists **`fishialConfirmedSpeciesName`** via **`DiveMediaFishialIdentificationStorage.saveConfirmedCatalogMatch`**. Tests: **`fishialMarineLifeCatalogMatching_*`**, **`diveMediaFishialIdentificationStorage_saveConfirmedCatalogMatch_*`**.

## 74 - Bundled marine life photos, media UX, landscape **(pushed)**

**Summary:** Offline bundled marine life hero photos pipeline.

- **`download_marine_life_images.py`** + **`marine_life_bundle_image_utils.py`** — download staging URLs, center-crop 4:3 at 960×720, write **`Resources/MarineLifePhotos/{uuid}.jpg`**, set **`featureImageResourceName`**, manifest JSON.
- **`feature_image_resource`** in JSON + **`featureImageResourceName`** on **`MarineLife`**; **`FieldGuideMarineLifeBundledImagePresentation`** resolves bundled JPEG before remote URL.
- **`FieldGuideMarineLifeCatalogImage`** loads bundle files offline; hero/detail/mosaic/Fishial review updated.
- Tests: **`test_marine_life_bundle_image_utils.py`**, **`fieldGuideMarineLifeBundledImagePresentation_*`**, hero presentation signature updates.
- **Bundle download pass** — **`download_marine_life_images.py --only-missing`** materialized **510/510** staging URLs into **`Resources/MarineLifePhotos/`** (~58 MB); JSON synced with **`feature_image_resource`** on all bundled species. Commons 400 thumb-size failures resolved via full-original URL fallback in **`marine_life_bundle_image_utils.py`**.
- **Marine life image review UI** — **`serve_marine_life_image_review.py`** + **`marine_life_image_review.html`**: local grid to inspect bundled photos, paste replacement URLs into staging CSV, optional per-species bundle re-download. Tests: **`test_marine_life_image_review_store.py`**.
- **Review UI: mark for dataset removal** — **`markForDeletion`** staging column; modal danger zone + filter; **`apply_marine_life_staging_deletions.py`** purges marked rows from CSV/photos/manifest/JSON. Tests: **`test_marine_life_staging_deletions.py`**, **`test_apply_marine_life_staging_deletions.py`**.
- **Deletion apply batch (14 species)** — croakers, angelfish, midshipman, moonfish, Venezuelan grouper removed from staging (**538** rows), JSON (**541** catalog entries), and bundled photos/manifest. Re-ran fetch (67 no-URL gaps; 0 Commons/Openverse hits), bundle download (0 new), and **`sync_marine_life_staging_to_json.py --all`**.
- **Staging-only catalog sync + SwiftData prune** — **`sync_marine_life_staging_to_json.py`** no longer preserves legacy JSON uuids outside staging; **`MarineLifeCatalogSeeder`** deletes catalog rows absent from bundled JSON (nullifies sighting links). Tests: **`marineLifeCatalogSeeder_prunesSpeciesRemovedFromBundledJSON`**, updated **`test_marine_life_staging_deletions.py`**.
- **Dive tag marine life search** — **`DiveMarineLifeTagPickerSheet`** search field filters catalog by common name or Field Guide subcategory group via **`DiveMarineLifeTagPickerPresentation`** + **`FieldGuideMarineLifeSearch`**. Test: **`diveMarineLifeTagPickerPresentation_filtersByCommonNameOrSubcategory`**.
- **Dive overview preview video** — **`DiveActivityMediaItemView`** uses **`DiveMediaVideoRequestQuality.homeCarousel`** (PhotoKit **`.automatic`**) for hero playback, matching Home carousel; Fishial export keeps **`.fullQuality`**. Test: **`diveActivityMediaPresentation_overviewUsesPreviewVideoQuality`**.
- **Dive media fish + Fishial icon colors** — **`DiveActivityMediaMarineLifeTagButton`** and **`DiveActivityMediaFishialIdentifyButton`** default to gray (**`tabUnselected`**); fish turns accent when species are tagged on that media; sparkles turns accent after Fishial confirm (**`fishialConfirmedSpeciesName`**). Helpers: **`DiveActivityMediaPresentation.marineLifeTagControlIsActive`**, **`fishialIdentifyControlIsActive`**, **`MarineLifeMediaTagPresentation.hasTaggedSpeciesOnMedia`**. Tests: **`diveActivityMediaPresentation_mediaControlActiveState_reflectsTagsAndFishialConfirm`**, **`marineLifeMediaTagPresentation_hasTaggedSpeciesOnMedia_countsUniqueSpecies`**.
- **Fishial zoom + crop before identify** — **`FishialImageCropEditorView`** + **`FishialImageCropRenderer`**: pinch/drag square crop on photos and exported video stills before **`/v2/recognize`**; video flow is scrub → **Continue** → crop → **Identify** (with **Back** to re-scrub). Tests: **`fishialImageCropPresentation_squareCropViewportSize_fitsContainer`**, **`fishialImageCropRenderer_*`**.
- **Dive marine life tag sheet species thumbnails** — **`DiveMarineLifeTagSpeciesRow`** adds bundled/remote catalog thumbnails on tagged + picker lists (**`DiveMarineLifeMediaTagsSheet`**, **`DiveMarineLifeTagPickerSheet`**).
- **Dive marine life tag sheet chrome trim** — removed **`DiveMarineLifeTagMediaPreviewHeader`** (dive photo/video thumbnail + subtitle) from tagged and picker sheets.
- **Fishial fast media selection** — **`FishialMediaSelectionPresentation`**: photos open crop UI on **`.fastFormat`** preview (**1024** edge); videos scrub with **`.homeCarousel`** / PHAsset duration (no full original download); full-quality export deferred until **Identify** / **Continue**. Tests: **`fishialMediaSelectionPresentation_usesPreviewForSelectionAndFullQualityForExport`**, **`fishialStillCropContext_isPhotoSelection_whenNoVideoScrubContext`**.
- **Fishial entry on marine life tag sheet** — removed sparkles from **Media** sheet chrome + minimized carousel; **`DiveMarineLifeMediaTagsSheet`** toolbar **sparkles** (leading **`plus`**, icon-only, gray/accent) opens **`DiveMediaFishialIdentifySheet`** when Fishial is configured. **`DiveMarineLifeTagSheetPresentation`**. Test: **`diveMarineLifeTagSheetPresentation_fishialIdentifyIsActive_whenSpeciesNameConfirmed`**. Deleted **`DiveActivityMediaFishialIdentifyButton`**.
- **Media minimized detent layout** — fish tag moved from hero to carousel row (leading **+**); hero is full-bleed (**`usesFullBleedMediaHero`**); embedded panel uses frosted translucent chrome (**`embeddedOverviewTranslucentOpacity`**); selected carousel thumb **1.4×** base size. Tests: **`diveActivityMediaPresentation_showsMarineLifeTagInCarousel_onlyAtMinimized`**, **`carouselThumbnailExtent_scalesSelectedItem`**, **`mediaTab_usesFullBleedHeroAndTranslucentPanelAtMinimizedAndMedium`**.
- **Media medium detent polish** — full-bleed hero + same translucent panel as minimized; add-media + unfilled star icons gray (**`tabUnselected`**); featured star accent + filled; tagged-species oval chips tap through to **large** detail (**`opensMarineLifeDetailOnTaggedChipTap`**). Test: **`diveActivityMediaPresentation_opensMarineLifeDetailOnTaggedChipTap_onlyAtMediumWithTags`**.
- **Media large detent polish** — dive media stays full-bleed + playing behind a frosted translucent sheet (same height); carousel removed; **Marine life** section title removed — oval tag chips + species copy; background video plays at **large**. Tests: **`mediaTab_usesFullBleedHeroAndTranslucentPanelAtAllDetents`**, **`showsBackgroundPhotos_atAllDetents`**, **`shouldPlayBackgroundVideo_mediaTabAtEveryDetent`**, **`showsMediaCarouselInSheet_atMinimizedAndMediumOnly`**.
- **Media sheet UX tweaks** — capture-date oval lifted above the minimized sheet (**`captureOverlayBottomInset`**); frosted panel opacity **0.52 → 0.62** (**`embeddedOverviewTranslucentOpacity`**); species catalog hero restored at **large** tagged-species detail. Test: **`captureOverlayBottomInset_sitsAboveSheetAtMinimized`**.
- **Media medium chip → large detail** — each tagged-species oval at **medium** sets **`selectedTaggedSpeciesUUID`** before expanding to **large** so the tapped species opens in detail (**`resolvedTaggedSpeciesUUID`**). Test: **`resolvedTaggedSpeciesUUID_prefersChipSelection`**.
- **Media large scroll fade** — tagged-species detail scroll content feathers out at the panel top (**`overviewPanelTopScrollFade`**, **`mediaLargeDetentTopScrollFadeHeight`**) instead of a hard clip. Test: **`panelTopScrollFadeHeight_onlyAtLargeOnMediaTab`**.
- **Marine life tag sheet chrome** — **`DiveMarineLifeMediaTagsSheet`**: **+** leading, Fishial **sparkles** + **Done** trailing (matches buddies/tags sheets); **`DiveMarineLifeTagPickerSheet`**: **Done** only (no **Cancel**).
- **Media medium carousel alignment** — pinned stack uses zero spacing + **`mediaCarouselPinnedStackHeight`**; panel scroll disabled at **minimized** / **medium** so the carousel stays on the minimized on-screen slot (no clip). Tests: **`mediaCarouselPinnedStackHeight_alignsCarouselSlot`**, **`disablesPanelScroll_mediaTabUntilLarge`**.
- **Marine life oval chip titles** — **`MarineLifeMediaTagPresentation.chipDisplayTitle`** caps visible text at **25** characters with **…**; full names kept for accessibility. Test: **`chipDisplayTitle_truncatesAtMaxLength`**.
- **Dive activity landscape** — map / tank / media tabs hide the embedded sheet at every detent; map full-screen + interactive; tank full-screen depth profile (all detents); media full-bleed. **`DiveActivityOverviewLandscapePresentation`**. Tests: **`hidesSheetAndUnlocksMapAtEveryDetent`**, **`landscapeProfileChart_atEveryDetent`**.
- **Portrait lock on catalog / list tabs** — Home, Logbook list, Field Guide (all browse + species detail), and Explore dive-site **list** root stay portrait-only via **`AppPortraitOrientationLock`** + **`AppPortraitOrientationLockPolicy`**; dive activity, Explore map, and pushed site/dive destinations still rotate. **`GoDiveGoogleMapsAppDelegate`** consults **`AppPortraitOrientationLockController`**. Test: **`appPortraitOrientationLockPolicy_listScreensStayPortrait`**.

## 75 - Progressive dive media + pager playback fix **(pushed)**

**Summary:** Progressive dive media fidelity — poster, preview video, silent full upgrade.

- **`DiveMediaProgressivePresentation`** + **`DiveMediaProgressivePrefetch`** — poster edge, full-upgrade policy, neighbor warm for pager.
- **`DiveMediaReferenceLoader.loadImageProgressive`** — opportunistic degraded → final frames for dive photos.
- **`DiveMediaVideoAssetSessionCache`** — quality-keyed session entries (**`full`** / **`preview`**).
- **`DiveActivityVideoPlayerView`** — poster under player, preview stream, seamless **`replaceCurrentItem`** full upgrade with time preservation.
- **`DiveActivityMediaItemView`** — progressive photos + **`usesProgressiveFidelity`** overview videos.
- Tests: **`diveMediaProgressivePresentation_posterAndUpgradePolicy`**, **`diveMediaVideoRequestQuality_sessionCacheKeySuffix_isDistinct`**.
- **Media pager playback freeze** — mount **`DiveActivityVideoPlayerView`** only when the page is active (Home carousel pattern); poster stays on **`DiveActivityMediaItemView`**; fix progressive cache hit leaving **`isPlayerDisplayReady`** false; quality upgrade keyed off **`|preview` → `|full`**; clear cancelled full-upgrade tasks.

## 76 - Next batch **(pushed)**

**Summary:** Snappier Home return + Field Guide category detail hero chrome.

- **`HomeRoute.profile`** — Profile pushed on Home stack path (replaces **`NavigationLink`**) so root depth is tracked.
- **`restoresRootTabBarWhenStackIsEmpty`** — SwiftUI **`.visible`** + UIKit tab-bar unhide when Home stack pops to root.
- **`HomeReturnNavigationPresentation`** — skip full **`rebuildHomeOverview`** on return when carousel already ready; light warm only.
- Tests: **`homeReturnNavigationPresentation_skipsRedundantRebuildWhenCarouselReady`**.
- **Field Guide category detail hero** — **`FieldGuideCategoryDetailView`** uses **`AppHeaderlessPage`** + full-bleed category hero (extends under status bar); floating back-only **`AppHeader`**; **`LogbookTopChromeScrim`** scroll fade; title/description/species count in scroll body below hero (**`FieldGuideCategoryDetailCopy`**). **`FieldGuideCategoryPresentation`** + **`FieldGuideCategoryHeroImage`** **`fullBleed`** mode.
- **Field Guide subcategory detail layout** — **`FieldGuideSubcategorySpeciesView`**: subcategory title in **`AppHeader`** (leading after back via **`AppHeaderTitlePlacement.leadingAfterBack`**); pinned hint + species count (**`FieldGuideSubcategoryDetailCopy`**, **`showsTitle: false`**); **`ScrollView`** is species mosaic tiles only. **`FieldGuideSubcategoryPresentation.fixedSummaryTopInset`**.
- Tests: **`fieldGuideCategoryPresentation_detailHeroHeight_includesSafeAreaInset`**, **`fieldGuideSubcategoryPresentation_scrollCopyTopInset_accountsForHeaderChrome`**, **`fieldGuideCatalogIndex_browsePayload_usesTaxonomySubcategoryTitle`**.
- **Buddy detail fixed layout** — **`ViewDiveBuddyDetails`** drops outer **`ScrollView`**; header + collapsible **Dives together** pin to the top of **`AppPage`** (Profile or Home push). **`DiveBuddyRosterPresentation.buddyDetailUsesScrollContainer`**. Test: **`diveBuddyRosterPresentation_labels`**.
- **Tab stack pop performance** — **`restoresRootTabBarWhenStackIsEmpty`** + **`animation(nil, value: path.count)`** on Field Guide, Logbook, and Explore (same as Home). **`RootStackReturnNavigationPresentation`**; Logbook skips redundant cache rebuild on root return when rows are cached; Field Guide keeps **`WaterBubbleBackground`** mounted (paused while browsing catalog); Explore Trip Planner uses **`ExploreRoute.tripPlanner`** + stack path (not **`NavigationLink`**). Test: **`rootStackReturnNavigationPresentation_tabBarRestoreAndLogbookSkip`**.
- **Offline media policy** — **`AppNetworkConnectivityMonitor`** (**`NWPathMonitor`** at launch) + **`AppNetworkConnectivitySnapshot`** for PhotoKit; offline uses local previews only (**`isNetworkAccessAllowed = false`**), skips full-res Home warm + video upgrade; **`OfflineMediaUnavailableIndicator`** (**`wifi.slash`**) instead of dive video retry error when offline. Tests: **`appNetworkConnectivityPresentation_offlineSkipsCloudMedia`**, **`diveMediaVideoLoad_classify_*`**.
- **Home featured media deep link** — tapping the carousel opens **`HomeRoute.diveMedia`** with the highlight’s **`mediaID`**; **`DiveActivityMediaPresentation.resolvedSelectedPhotoID`** preserves a pending selection while derived media is still loading so **`DiveActivityMediaCarouselView`** scrolls to the same item (not the first photo). Test: **`diveActivityMediaPresentation_resolvedSelectedPhotoID`** (empty-list pending ID).

## 77 - Next batch **(pushed)**

**Summary:** Add activity fixed layout; Media tab hero scrim; remove hung UDDF import integration test from preflight suite.

- **Add activity fixed layout** — **`ActivityUploadView`** drops outer **`ScrollView`**; intro + import cards pin to the top of **`AppPage`** (Logbook → **Add activity**).
- **Media tab hero chrome** — **`DiveOverviewMapTopScrim`** hidden on **Media** (map/tank only); **large** tagged-species scroll still feathers into opaque panel surface (**`panelTopScrollUsesOpaqueFadeBackground`**, **`overviewPanelTopScrollFade`**).
- **Field Guide subcategory header** — **`FieldGuideSubcategorySpeciesView`**: subcategory title pinned in **`AppHeader`**; hint, species count, and mosaic scroll underneath with **`LogbookTopChromeScrim`** (**`scrollContentTopInset`**). **`AppHeaderTitlePlacement.leadingAfterBack`** uses a full-width title row (**.title3.bold**, 2 lines) instead of the compressed 1/3 leading column.
- **Swift 6 actor isolation** — **`AppNetworkConnectivitySnapshot`** members explicitly **`nonisolated`** for NWPath / PhotoKit off-main access; **`FishialCatalogReviewOption`** **`nonisolated`** initializer for catalog matching tests.
- **Dive map detent zoom** — swapped **`cameraDistanceMeters(for:)`**: **minimized** ~**6.2 km** (zoomed out, pan/zoom), **medium** / **large** ~**1.2 km** (tighter framing); pin-shift tuning follows (**`latitudeShiftTuning`**).
- **Swift 6 test Equatable** — **`nonisolated`** **`==`** on **`DiveMediaVideoRequestQuality`** and **`FieldGuideMarineLifeBundledImagePresentation.ImageSource`** for **`#expect`** in nonisolated tests.

- Removed **`uddfImport_createMissingDiveSites_linksNewAndExisting`** — full **`UddfDiveFileImport.importUddfData`** path blocked on live **`MapKitGeocodingTimeZoneResolver`** network calls in simulator; site-link behavior remains covered by decoder/unit tests elsewhere.
- **Test fixes** — **`fieldGuideMarineLifeImageLayout_*`** uses **`4.0 / 3.0`** (not integer **`4/3`**); French/Queen angelfish seeder expectations match bundled **`marine_life_sample.json`**.

## 78 - Next batch **(pushed)**

**Summary:** Buddy detail scrolls shared dives inside **Dives together** section only.

- **Buddy detail dive list scroll** — **`ViewDiveBuddyDetails`**: avatar header pinned; **`ExpandableDetailSection`** **`scrollsExpandedContent`** wraps expanded logbook rows in a **`ScrollView`** filling remaining **`AppPage`** height (**`ExpandableDetailSectionPresentation.buddyDetailScrollsExpandedDiveList`**). Test: **`diveBuddyRosterPresentation_labels`**.
- **Buddy detail expand snappiness** — pre-cached logbook rows (**`DiveBuddyRosterPresentation.sharedDiveRowDisplayData`**), **`NavigationLink(value:)`** + **`BuddySharedDiveListRows`**, pre-warm/mount expanded list (**`buddyDetailKeepsExpandedContentMounted`**), snappy chevron-only animation (**`expandCollapseAnimationDuration`**). Tests: **`diveBuddyRosterPresentation_sharedDiveRowDisplayData_ordersNewestFirst`**, **`diveBuddyRosterPresentation_labels`**.
- **Profile destination tiles** — Certifications, Equipment Locker, and Dive Buddies use compact landscape cards (icon leading, copy trailing, fixed **`tileHeight`**); stacked in one column instead of 2+1 grid. Test: **`profileDestinationTilePresentation_usesUniformTileHeight`**.
- **Profile destination tile uniformity** — shared label builder, fixed **`tileHeight`**, full-width **`NavigationLink`** frames; titles truncate instead of scaling so font size matches across all three.
- **Field Guide category hero** — **`FieldGuideCategoryImageLayout.detailHeroBaseHeight`** **280 → 200** (Fish, Coral, etc.); species detail unchanged at **280**.
- **Field Guide subcategory header** — **`FieldGuideSubcategorySpeciesView`** matches category detail: full-bleed parent-category hero (**`FieldGuideCategoryHeroImage`**, **200** pt + safe area), floating back-only **`AppHeader`**, **`LogbookTopChromeScrim`**, title + hint + species count in scroll (**`FieldGuideSubcategoryDetailCopy`**). Test: **`fieldGuideSubcategoryPresentation_matchesCategoryDetailHeroChrome`**.
- **Dive overview section edit** — per-section **ellipsis** on **Dive**, **Dive Conditions**, tank groups, etc. opens **`DiveActivitySectionEditSheet`** with all editable fields in that section; field rows are read-only. **Buddies** + **Tags** use header **+** (add) instead of ellipsis. **`DiveActivityFieldEditorRows`** shared by section and legacy single-field sheet. Tests: **`diveActivityEditableCatalog_sectionHeaderActions`**, **`diveActivitySectionEditContext_resolvesSectionFromTabAndDetent`**.
- **Media tab Fishial + sheet chrome** — Fishial-confirmed species show **sparkles** inside the marine-life oval chip (not a separate **Fish ID** row at **medium**); thumbnail carousel regains pinned slot. **Large** detent keeps frosted translucent panel (no opaque scroll fade fill). Tests: **`diveActivityMediaPresentation_panelTopScrollKeepsTranslucentChromeAtLargeMediaTab`**, **`diveActivityMediaPresentation_speciesWasFishialIdentified_matchesScientificName`**.
- **Media tab video poster** — dive hero videos use **`loadImageProgressive`** for the poster (degraded frame first, no camera icon flash); poster loads before layout width is known; **`DiveActivityVideoPlayerView`** accepts **`initialPosterImage`** from the parent. Test: **`diveMediaProgressivePresentation_posterTargetSize_beforeLayoutUsesFastEdge`**.
- **Media tab species ovals** — **medium** detent uses the same horizontal chip row as **large** (natural width + **`chipTitleMaxLength`** truncation), not a wrapping **88 pt** grid.

## 79 - Next batch **(pushed)**

**Summary:** Trip Planner from Explore — trip list, add-trip sheet, and detail.

- **Trip Planner** — Explore map chrome **calendar → airplane**; pushed **`TripPlannerView`** **`AppPage`** title **Trips** (owned trip list). **`TripPlannerPresentation`**. Test: **`tripPlannerPresentation_pageTitleAndExploreIcon`**.
- **Trip Planner data model** — **`DiveTrip`** (date range, countries, optional **`plannedSites`**, owner), **`DiveTripActivityLink`** (post-trip dive association), **`DiveTripDateRange`**, **`DiveTripAggregateBuilder`** (total time, longest/deepest dive, buddies, marine life, sites). Tests: **`diveTripDateRange_*`**, **`diveTripAggregateBuilder_*`**, **`diveTripActivityLinking_*`**.
- **Trip Planner UI** — Explore map chrome **airplane** icon button (default SwiftUI **`Button`**, **`accessibilityLabel`** **Plan a trip**); **`TripPlannerView`** lists owned **`DiveTrip`** rows in **Upcoming**, **Active**, and **Past** sections (**`TripPlannerPresentation.listSections`**, **`TripPlannerListPhase`**) — each row shows title, date range, countries, and linked dive count in accent blue for active/past trips (**`TripPlannerListRowDisplayData`**); soonest-upcoming first, active trips by end date, past trips newest-first (**`Trips`** **`AppPage`**, **+** opens **`TripAddSheetView`** sheet) → destination **`NavigationLink`** pushes **`TripDetailView`** (works inside Explore’s **`ExploreRoute`** stack). **`TripPlannerFormContent`**, **`TripPlannerSheetPresentation`**, **`DiveTripFormValues`**, **`DiveTripOwnership`**, **`DiveTripPresentation`**, **`TripPlannedSitePickerSheet`**. Tests: **`diveTripFormValues_*`**, **`diveTripPresentation_*`**, **`tripPlannerPresentation_*`**, **`tripPlannerPresentation_lifecyclePhase_classifiesUpcomingActiveAndPast`**, **`tripPlannerPresentation_listSections_*`**, **`tripPlannerPresentation_listRowDisplayData_splitsTitleDatesCountriesAndDiveCount`**.
- **Trip date validation** — **`DiveTripDateRange.isValidOrderedRange`**; **`DiveTripFormValues.canSave`** requires start on/before end (same-day OK); form footer shows **`invalidDateRangeMessage`**. Tests: **`diveTripDateRange_rejectsEndBeforeStart`**, **`diveTripDateRange_allowsSameDayTrip`**.
- **Trip dive auto-link** — once a trip has started (**`DiveTripActivityLinking.hasStarted`**), **`applyAutoLink`** / **`applyAutoLinkForOwner`** link owner dives whose start falls in the trip window; runs on trip list/detail, trip save, and dive import / manual add. Test: **`diveTripActivityLinking_autoLinksStartedTripsOnly`**.
- **Trip detail linked dives** — **`ExpandableDetailSection`** + shared **`LinkedDiveLogbookListRows`**; rows built live from **`DiveTripPresentation.linkedDiveRowDisplayData`** (no stale **`@State`** cache); scroll-hosted sections use direct **`if isExpanded`** reveal (**`ExpandableDetailSection`**) instead of opacity lazy-mount. Tests: **`diveTripPresentation_linkedDiveRowDisplayData_ordersNewestFirst`**, **`diveTripPresentation_linkedDivesSummary_formatsDuration`**.
- **Trip detail stats** — when the trip has started (**`DiveTripStatsPresentation.shouldShowStats`** / **`DiveTripActivityLinking.hasStarted`**), **`TripDetailTripStatsSection`** shows a 2×2 grid (**dives**, **underwater**, **deepest**, **longest**) from **`DiveTripAggregateBuilder`**. Tests: **`diveTripStatsPresentation_showsStatsWhenTripHasStarted`**, **`diveTripStatsPresentation_buildsHighlightTilesFromAggregate`**.
- **Trip detail map** — top **`TripDetailMapView`** on **`AppHeaderlessPage`**: Home-sized map hero (**`TripDetailMapPresentation.mapHeroHeight`** / **`HomeOverviewLayout.metrics`**); full-bleed under the status bar; back chevron matches **`AppPage`** spacing; trip **`displayTitle`** as **`.title.weight(.bold)`** in the overlapping sheet; blue planned / red completed pins (**`TripDetailMapPresentation`**, MapKit + Google); tap a pin with a catalog **`siteID`** → pushed **`ExploreDiveSiteDetailView`**; camera fits all pins with wider padding (**`boundingRegionPaddingMultiplier`**, **`showAnnotations`** / Google **`fit`** + bottom inset for the overlapping sheet); pin labels match Explore (**`ExploreCatalogMapLabelVisibility`**, **`ExploreCatalogMapMarkerPresentation`**, Google labeled pin assets). Tests: **`tripDetailMapPresentation_plannedBlueAndCompletedRedPins`**, **`tripDetailMapPresentation_boundingRegion_zoomsOutToFitSpreadPins`**, **`exploreCatalogMapLabelVisibility_labeledTripPinIDs_matchExploreRules`**, **`tripDetailMapPresentation_mapHeroHeight_matchesHomeOverviewLayout`**.
- **Logbook trip grouping** — linked dives (2+) render under a trip title link (**`LogbookRoute.tripDetail`**) with dive count (**`LogbookTripGrouping.formattedGroupHeaderTitle`**, e.g. **Bonaire 2026 · 2 dives**); **`LogbookTripGroupAccentPalette`** cycles bright accent colors on title + trailing rail so neighboring trip groups differ; same **`LogbookActivityRow`** tiles. Trip create / auto-link posts **`.diveTripLogbookGroupingDidChange`** so **`LogbookView`** rebuilds grouping without a dive-count change (**`DiveTripLogbookSync`**). Tests: **`logbookTripGrouping_groupsTwoLinkedDivesUnderTripTitle`**, **`logbookTripGrouping_assignsDistinctAccentColorsToNeighboringTripGroups`**, **`diveTripLogbookSync_notifyGroupingDidChange_notifiesObservers`**.
- **Trip detail map layout** — map hero height matches Home featured media (**`HomeOverviewLayout.metrics`**); overlaps **`HomeLifetimeStatsPanel`** sheet chrome (**`AppOverviewSheetPanelBackground`**, rounded top corners, Home-style **148 pt** overlap); **`GeometryReader`** ignores horizontal safe area only so **`AppHeader`** back chevron aligns with **`AppPage`** / **`AppScrollUnderHeaderListLayout.resolvedSafeAreaTop`**.
- **Logbook trip refresh** — **`DiveTripLogbookSync`** defers notification one main run loop; **`LogbookView`** watches **`LogbookTripGroupingSync.syncToken`** in addition to **`.diveTripLogbookGroupingDidChange`**.
- **Logbook trip search** — typing in the logbook search bar surfaces **Trips** oval suggestion chips (**`LogbookTripSearchPresentation`**, **`LogbookSearchTripSuggestionsView`**) from owner **`DiveTrip.displayTitle`**; tap confirms a trip filter (**`DiveLogbookSiteSearch.filtering`**, **`confirmedTripID`**) with the same bordered section + emphasized chip + **Clear** pattern as tags/buddies. Tests: **`logbookTripSearchPresentation_suggestions_onlyWhileTypingWithoutActiveFilter`**, trip branch in **`diveLogbookSiteSearch_*`**.
- **Logbook upcoming trip banner** — when an owner trip has not started yet, **`LogbookUpcomingTripBannerView`** shouts out the soonest upcoming trip at the top of the logbook (hidden while search filters are active); tap opens **`LogbookRoute.tripDetail`**. Test: **`logbookUpcomingTripPresentation_nearestUpcomingBanner_picksSoonestStart`**.
- **Trip edit / delete** — **`TripDetailView`** **Edit** opens **`TripEditSheetView`** (shared **`TripPlannerFormContent`**); **Delete trip** confirmation removes the trip and dive links (**`DiveTripDeletion`**, logbook grouping refresh). Tests: **`diveTripFormValues_initFromTripAndApply`**, **`diveTripDeletion_deletePermanentlyRemovesTrip`**.
- **Trip detail overview layout** — trip **`displayTitle`** with formatted date range as subtitle; **Planned dive sites** tappable section opens **`TripPlannedSitesListView`** (**Explore**-style **`ExploreDiveSiteRow`** list + search → **`ExploreDiveSiteDetailView`**). **Edit** moved to a vertical **⋯** menu beside the title (header trailing **Edit** removed). **`TripDetailView`** portrait-locked (**`AppPortraitOrientationLockPolicy.locksTripDetail`**, releases for linked dive detail). Tests: **`diveTripPresentation_plannedSitesOverviewSummary_formatsSiteCount`**, **`appPortraitOrientationLockPolicy_listScreensStayPortrait`** (trip detail branch).
- **Trip detail media + marine life** — **`TripDetailMediaGallerySection`** (rounded full-bleed preview across linked dives — no section card or thumbnail carousel; swipe up/down for next/previous with slide transition, tap opens linked dive **Media** tab via **`ViewSingleActivity`**; position badge **# of #** upper-right; accent **fish.fill** lower-right when species are tagged on that item); **`TripDetailMarineLifeSection`** horizontal carousel of **`FieldGuideMarineLifeRow`** cards (frequency-ordered **`DiveTripAggregate`** tags, sighting count footer, tap → **`FieldGuideMarineLifeDetailView`**). Tests: **`tripDetailMediaPresentation_collectsMediaFromLinkedDivesNewestFirst`**, **`tripDetailMediaGalleryPresentation_browseAccessibilityLabel_mentionsSwipeWhenMultipleItems`**, **`tripDetailMediaGalleryPresentation_mediaPositionLabel_usesNumericOnlyFormat`**, **`tripDetailMediaGalleryPresentation_showsMarineLifeTagIndicator_whenSpeciesTagged`**, **`tripDetailMediaGalleryPresentation_browseOffset_mapsVerticalSwipeToGalleryStep`**, **`diveActivityMediaPresentation_adjacentPhotoID_stepsThroughGalleryOrder`**, **`tripDetailMarineLifePresentation_carouselItems_useFieldGuideRowFormat`**, existing **`diveTripAggregateBuilder_totalsLongestDeepestBuddiesAndMarineLife`**.
- **Trip detail sheet scroll** — horizontal **⋯** edit menu; blue panel scroll inset moved in-content so sections reach the bottom of the screen (panel **`ignoresSafeArea(edges: .bottom)`**).
- **Trip detail linked dives title** — expandable section header **`View Activities`** (**`DiveTripPresentation.linkedDivesSectionTitle`**).
- **Trip detail stats layout** — 2×2 stat tiles sit directly under the trip title (no outer section card or **Trip stats** header); individual stat tiles unchanged.
- **Trip detail stat links** — **Deepest** and **Longest** tiles (when they have data) show a chevron and push **`ViewSingleActivity`** for the linked dive via **`DiveTripStatTile.linkedDiveID`**; tests **`diveTripStatsPresentation_buildsHighlightTilesFromAggregate`**, **`diveTripStatsPresentation_omitsLinkedDiveWhenStatEmpty`**.
- **Trip detail content pager** — map + title + date subtitle stay fixed; **`TripDetailContentPager`** (**`TabView`**, **`.page(indexDisplayMode: .automatic)`**) swipes **stats → marine life → activities → buddies → media**. **`TripDetailContentPage`** / tests **`tripDetailContentPager_pageOrderAndCount`**, **`diveTripAggregateBuilder_buddySummariesCountDistinctLinkedDives`**.
- **Trip detail pager UX** — started trips: stats page is dive tiles only (static layout — no vertical scroll); marine life page uses Field Guide **`FieldGuideSpeciesMosaicCard`** 2-column grid (+ sighting count line); activities page is always-expanded **`LinkedDiveLogbookListRows`** (no **`ExpandableDetailSection`**); media page is full-bleed with swipe browse (**`TripDetailContentPagerPresentation.usesStaticPagerLayout`**). Test: **`tripDetailMarineLifePresentation_carouselItems_useFieldGuideMosaicFormat`**, **`tripDetailContentPager_usesStaticLayoutForStatsAndMedia`**.
- **Trip detail buddies grid** — active-trip **`TripDetailBuddiesSection`**: 3-wide avatar grid (name + accent dive count); scrolls via pager **`ScrollView`** when the roster exceeds the viewport. **`TripDetailBuddiesPresentation`**. Test: **`tripDetailBuddiesPresentation_usesThreeColumnGrid`**.
- **Trip detail planned pager** — before trip start: two pages only (**`TripDetailPlannedSitesSection`** Explore rows with **Saved Dive Sites** subtitle — **`DiveTripPresentation.plannedSitesPageSavedSitesSubtitle`**; empty copy unchanged — then **`TripDetailPlannedBuddiesSection`**); active trips use the five-page pattern (**`TripDetailContentPagerPresentation.pages(hasStarted:)`**). Tests: **`tripDetailContentPager_plannedTripPages`**, **`tripDetailContentPager_activeTripPages`**, **`diveTripPresentation_plannedSitesPageSubtitle_formatsSiteCount`**.
- **Trip planned buddies + share** — **`DiveTripBuddyLink`** persists roster buddies on planned trips; **`TripDetailPlannedBuddiesSection`** (**Add buddy** → **`TripPlannedBuddyPickerSheet`**). **Share** (**`square.and.arrow.up`**) lives in the trip title row beside **Edit** (**`TripDetail.Share`**) → **`TripShareCardRenderer`** PNG + **`AppShareSheet`**. Share PNG uses **Google Maps Static API** hybrid snapshot when an API key is configured (**`TripShareGoogleStaticMapPresentation`**, MapKit fallback), blue planned / red completed markers, buddy avatar grid (**planned roster + “You” / “On this trip”** before start; **tagged buddies + dive counts** once the trip has started — **`TripShareCardPresentation.members`**), and **`GoDiveLogoPin`** footer. Tests: **`diveTripPlannedBuddyLinking_addsAndRemovesBuddies`**, **`tripDetailPlannedBuddyPresentation_ordersOwnerFirst`**, **`tripShareCardPresentation_members_usesPlannedBuddiesBeforeTripStarts`**, **`tripShareCardPresentation_members_usesTaggedBuddiesWithDiveCountsAfterStart`**, **`tripShareCardPresentation_buildsTemporaryPNGFileName`**, **`tripShareCardPresentation_includesLogoAssetName`**, **`tripShareGoogleStaticMapPresentation_buildsHybridStaticMapURL`**, **`tripShareMapSnapshotPresentation_mapSnapshotSize_fitsCardContentWidth`**, **`tripShareMapSnapshotPresentation_accessibilityLabel_matchesTripDetailMap`**.
- **Trip detail edit affordance** — title-row **⋯** opens **`TripEditSheetView`** directly (no intermediate pop-up menu).
- **Buddy detail trips together** — **`ViewDiveBuddyDetails`** shows a collapsible **Trips together** section when the buddy is on a trip planned roster (**`DiveTripBuddyLink`**) or tagged on a linked trip dive; rows use trip-planner copy + lifecycle phase (**`DiveBuddyTripPresentation`**, **`DiveBuddyTripListRows`**) and push **`TripDetailView`**. Test: **`diveBuddyTripPresentation_associatedTrips_includesPlannedAndTaggedLinkedDives`**.
- **Profile Trips link** — **`ProfileView`** destination tile **Trips** (**`Profile.TripsLink`**, airplane icon, **`ProfilePresentation.tripCountLabel`**) pushes **`TripPlannerView`**. Test: **`profilePresentation_certificationAndEquipmentCountLabels_pluralize`** (trip count assertions).
- **Trip list compact rows** — **`TripPlannerListRow`** matches **`LogbookActivityRow`** typography and card chrome (subheadline title; accent **linked dive count** on its own caption line for active/past trips; dates/countries below; optional trailing **`LogbookRowMediaPreviewView`** when linked trip media exists — tap opens **`TripDetailView`** **media** pager on the first gallery item via **`TripDetailTripMediaLaunch`**). **`TripPlannerPresentation.listRowPreviewMediaPhotoID`**. Tests: **`tripPlannerPresentation_listRowSecondaryDetail_joinsDatesAndCountries`**, **`tripPlannerPresentation_listRowPreviewMediaPhotoID_usesFirstLinkedTripMedia`**, **`tripDetailContentPager_resolvedInitialPage_opensMediaWhenStarted`**, updated **`tripPlannerPresentation_listRowDisplayData_splitsTitleDatesCountriesAndDiveCount`**.
- **Trip media browse UX** — **`TripDetailMediaGallerySection`** removes full-preview tap-to-open (swipe-only browse with lower threshold + **`highPriorityGesture`**); **View on dive** capsule (**`DiveTripPresentation.tripMediaOpenOnDiveButtonTitle`**, upper-left) opens linked dive **Media** tab; stronger slide + scale + opacity transition (**`TripDetailMediaGalleryPresentation.browseTransitionOffset`**). Tests: updated **`tripDetailMediaGalleryPresentation_browseAccessibilityLabel_*`**, **`tripDetailMediaGalleryPresentation_browseOffset_mapsVerticalSwipeToGalleryStep`**.
- **Trip media marine life overlay** — tap accent **fish.fill** on tagged media → full-bleed **`TripDetailMediaMarineLifeOverlay`** (hides **View on dive**, position counter, and fish icon; compact feature image; accent common-name row with trailing chevron → **`FieldGuideMarineLifeDetailView`**; species chips when multiple); dismiss via close or changing media. Tests: **`tripDetailMediaGalleryPresentation_taggedSpecies_resolvesFromSightings`**.
- **Trip detail map framing** — **`TripDetailMapFitLayout`** drives hero-aware **`uiMapFitEdgeInsets`** (measured top chrome + panel overlap + marker clearance) so all pins center in the visible map band; removed upward lift bias and post-fit latitude nudge. Test: **`tripDetailMapPresentation_mapFitEdgeInsets_centerPinsInVisibleHeroBand`**.
- **Trip stat tile footnotes** — dive count **activities**; underwater **total bottom time**; deepest **max depth**; longest **bottom time** (**`DiveTripStatsPresentation`**). Test: **`diveTripStatsPresentation_buildsHighlightTilesFromAggregate`** footnote assertions.
- **Trip map site navigation** — map pin taps call tab-root **`openCatalogDiveSiteDetail`** on the **`NavigationStack`** so pushed **`TripDetailView`** inherits the hook; stacks append site routes after **`tripDetail`** on the path. **`TripDetailStackNavigation`** (**`openTripDetail`**, **`openTripPlanner`**) replaces trip-list **`NavigationLink`** pushes so back from site detail returns to trip overview (Explore **`tripDetail`** / **`tripDetailMedia`**, Home **`tripPlanner`** + trip routes, Logbook **`tripDetail`**). Tests: **`tripStackNavigationRoutes_tripDetailPrecedesSiteOnStack`**, **`logbookRoute_includesCatalogSiteDetail`**.
- **Trip media interactive browse** — **`TripDetailMediaGallerySection`** tracks vertical drag in real time: current frame follows the finger, adjacent item reveals underneath with shared scale/opacity (**`TripDetailMediaGalleryPresentation.interactiveBrowse*`**); commit/snap-back spring (**`0.32s`**). Test: **`tripDetailMediaGalleryPresentation_interactiveBrowse_followsVerticalDrag`**.
- **Trip share buddy grid** — **`TripShareCardPresentation.members`** picks **planned roster** (owner + **You** / **On this trip**) before the trip starts, then **owner + linked dive count** plus **tagged buddies + dive counts** once started; **`TripShareCardView`** shows subtitle under each avatar, **species spotted** fish callout when tagged, **`GoDiveLogoPin`** pinned to the card footer. Tests: **`tripShareCardPresentation_members_usesPlannedBuddiesBeforeTripStarts`**, **`tripShareCardPresentation_members_usesTaggedBuddiesWithDiveCountsAfterStart`**, **`tripShareCardPresentation_marineLifeCalloutLabel_formatsUniqueSpeciesCount`**, **`tripShareCardPresentation_ownerShareSubtitle_usesDiveCountWhenTripStarted`**.
- **Planned buddy removal** — **`DiveTripPlannedBuddyLinking.removeBuddy`** clears deleted links from **`trip.buddyLinks`** so toggle/remove updates the roster immediately.

## 80 - Trip detail polish and dive field edit rules **(pushed)**

**Summary:** Logbook upcoming-trip banner no longer flashes before dive rows load.

- **Logbook banner timing** — **`LogbookUpcomingTripPresentation.shouldShowInLogbookList`** defers the **Trip on the horizon** tile until async **`LogbookDisplayCacheBuilder`** rows are ready (stored empty state still shows banner immediately); first appear uses **`refreshLogbookCacheNow`** instead of debounced scheduler. Test: **`logbookUpcomingTripPresentation_shouldShowInLogbookList_waitsForDisplayItems`**.
- **Trip map debug** — **`TripDetailMapNavigationDebug.isEnabled`** defaults to **`false`** (silences **`TripMapNavigation`** console tracing).
- **Planned trip buddies grid** — **`TripDetailPlannedBuddiesSection`** matches active-trip **`TripDetailBuddiesSection`** (3-column avatar grid, accent subtitles **You** / **On this trip**); keeps **Add buddy** at the top. Test: **`tripDetailPlannedBuddyPresentation_usesActiveTripBuddyGridMetrics`**.
- **Trip stats pager layout** — active/past trip **stats** pager page vertically centers the 2×2 tile grid in the free area above page dots (**`TripDetailContentPagerPresentation.staticPagerContentAlignment`**, same horizontal inset as media). Test: **`tripDetailContentPager_usesStaticLayoutForStatsAndMedia`**.
- **Trip media overlay chrome** — **View Dive** (accent label + arrow) and **# of #** counter share one top row (**`mediaOverlayChip`**, **`black.opacity(0.55)`** like dive capture timestamp); **`tripMediaOpenOnDiveButtonTitle`** → **View Dive**.
- **Planned trip saved sites** — **`TripDetailPlannedSitesSection`** trailing **+** opens **`TripPlannedSitePickerSheet`** (check/uncheck catalog sites, persists on dismiss); site rows use **`ExploreDiveSiteRowTrailingStyle.plannedTrip`** (no dive count on tiles). Test: **`exploreDiveSiteListDisplay_plannedTripRow_omitsDiveCount`**.
- **Trip add / edit sheets** — **`tripPlannerAddSheetPresentation`** uses **`.medium`** detent only; **`TripPlannerFormContent`** drops planned-sites row (saved sites edited on trip detail **+**).
- **Imported dive metrics read-only** — **`DiveActivityEditableCatalog.manualEntryOnlyFieldIDs`** (duration, max/average depth, bottom time, surface interval, avg ascent rate) editable only when **`source == .manual`**; section edit sheet and **`applyDraft`** honor the rule. Tests: **`diveActivityEditableCatalog_manualEntryOnlyFields_blockedForImports`**, **`diveActivityFieldEditing_applyDraft_skipsManualEntryOnlyFieldsOnImports`**; **`diveActivityEditableCatalog_sectionHeaderActions`** updated for manual vs imported.
- **SAC / RMV read-only** — **`avgSAC`** / **`avgRMV`** removed from editable catalog; **Consumption rates** section has no edit control. **`tankHeroSACRateLine`** / **`tankHeroRMVRateLine`** compute from start/end PSI + default tank (**`DiveSACRMVCalculation`**); without both pressures, overview rows show **—**. Tests: **`diveActivityEditableCatalog_sacAndRmvAreNotEditable`**, **`diveActivity_tankHeroConsumptionLines_requireCylinderPressures`**.
- **Source & import read-only** — **`source`**, **`sourceDiveId`**, and **`rawImportVersion`** are never editable (set at dive creation / import only). **Source & import** section has no edit control. Tests: **`diveActivityEditableCatalog_sourceAndImportFieldsAreNotEditable`**, **`diveActivityFieldEditing_applyDraft_doesNotChangeSourceOrImportVersion`**.
- **Build** — **`TripDetailContentPage`** imports **SwiftUI** for **`Alignment`** in stats pager layout helper.

## 81 - Home overlay, linked site title, portrait lock **(pushed)**

**Summary:** Home carousel fish icon opens an in-hero marine-life overlay (trip-style condensed card).

- **Home media marine-life overlay** — **`HomeMediaCarouselSection`** replaces **`DiveMarineLifeMediaTagsSheet`** with **`TripDetailMediaMarineLifeOverlay`** sized to the hero (**`HomeMediaCarouselPresentation.marineLifeOverlaySize`**); species chips + Field Guide link; closes on swipe or **×**; pauses carousel playback while open. **`TripDetailMediaMarineLifeOverlay`** accepts configurable feature-image dimensions. Test: **`homeMediaCarouselPresentation_marineLifeOverlaySizing_fitsHeroArea`**.
- **Dive site overview title** — **`ExploreDiveSiteDetailView`** shows **`site.siteName`** in **`AppHeader`** (no **GoDive** wordmark) via **`titleUsesBrandForeground`** — **`.title.bold`** + blue **`headerTitleForegroundGradient`**.
- **Linked dive site title on dive overview** — When **`DiveActivity.diveSite`** is set, the map header + minimized collapsed summary use **`DiveActivityLinkedSiteTitle`** (flat **`linkedSiteTitleAccent`**, tappable, up to three lines, full header width below the **#** chip) → **`openCatalogDiveSiteDetail`** (**`ExploreDiveSiteDetailView`** on Home, Logbook, Explore, Field Guide stacks). Import-only site names without a catalog link stay plain text. Test: **`diveActivityOverviewPresentation_siteTitleLinksToCatalogOverview_requiresLinkedSiteID`**.
- **Portrait lock expansion** — **`AppPortraitOrientationLockPolicy`** documents portrait destinations; runtime defaults to portrait-only with **`diveActivityLandscapeOrientation()`** on **`ViewSingleActivity`** only (fixes per-screen **`onDisappear`** unlocking landscape). Tests: **`appPortraitOrientationLockPolicy_listScreensStayPortrait`**, **`supportedInterfaceOrientations`** mask cases.

## 82 - Media previews, stacked titles, dive site cards **(pushed)**

**Summary:** Media preview cache, stacked page titles, and unified dive-site list cards.

- **Dive media preview cache** — **`DiveMediaPhoto.previewJPEGData`** stores a **256 px** JPEG (**`DiveMediaPreviewPersistence`**) on attach, first PhotoKit frame, and launch backfill (**`DiveMediaPreviewStorage`** / **`AppLaunchMaintenance`**). Stored previews seed **`HomeMediaHighlightSessionCache`** and count as displayable before PhotoKit warm; Home carousel mounts immediately (no full-hero **`ProgressView`** gate). Carousel picks **`ensureStoredPreviews`** on refresh. **`DiveActivityMediaItemView`**, **`DiveActivityMediaThumbnailView`**, and Home carousel read stored previews synchronously; loading states use a muted fill until PhotoKit resolves or the asset is missing. Tests: **`diveMediaPreviewPersistence_encodeDecode_roundTrip`**, **`diveMediaPreviewPersistence_shouldPersistPreview_onlyWhenMissing`**, **`diveMediaPreviewPersistence_showsMissingPlaceholder_onlyAfterLoadFinishes`**, **`diveMediaPreviewStorage_hasStoredPreview_reflectsJPEGData`**, **`homeMediaHighlightSessionCache_hasDisplayableImage_usesStoredPreview`**.
- **Stacked page titles** — **`ExploreDiveSiteDetailView`**, **`EquipmentLockerView`**, and **`CertificationsListView`** use **`AppHeaderStackedTitleChrome`** (centered **`textPrimary`** **`.title.bold`** below back chevron). Test: **`appHeaderStackedTitleChrome_usesCenteredPrimaryTextBelowBackRow`**.
- **Dive site list cards** — **`ExploreDiveSiteRow`**: title (leading) + dive count (trailing **`accent`**); coordinates line; **region, country** line (**`ExploreDiveSiteListDisplay.cityCountryLine`**). Planned-trip surfaces (**`TripDetailPlannedSitesSection`**, **`TripPlannedSitesListView`**, **`TripPlannedSitePickerSheet`**) use **`trailingStyle: .plannedTrip`** (no dive count). Tests: **`exploreDiveSiteListDisplay_rowData_coordinatesPlaceAndDiveCount`**, **`exploreDiveSiteListDisplay_plannedTripRow_omitsDiveCount`**, **`exploreDiveSiteListDisplay_cityCountryLine_formatsRegionAndCountry`**.

## 83 - Trip and buddy overhaul **(pushed)**

**Summary:** Buddy detail hero plays selected tagged videos automatically; bottom sections use a trip-style horizontal pager.

- **Buddy detail video autoplay** — **`DiveBuddyDetailHeroHeaderView`** auto-plays looping video for the selected tagged-media row; **`FieldGuideTaggedMediaGalleryView`** accepts an optional **`selectedMediaID`** binding and **`showsLargePreview`** (buddy page uses hero only — carousel drives selection). Test: **`diveBuddyDetailPresentation_layoutAndHeroSelection`** (**`shouldAutoPlaySelectedVideo`**).
- **Buddy detail content pager** — **`DiveBuddyDetailContentPager`** replaces collapsible **`ExpandableDetailSection`** blocks with a native **`TabView`** page control: **Dives together** → **Trips together** → **Your tagged photos** (carousel only; hero is the preview). **`DiveBuddyDetailContentPage`** / **`DiveBuddyDetailContentPagerPresentation`**. Tests: **`diveBuddyDetailContentPager_pages`**, **`diveBuddyRosterPresentation_labels`**.
- **Buddy detail Home-style panel** — tagged-media hero height uses **`HomeOverviewLayout.metrics`**; identity + pager sit in overlapping **`HomeLifetimeStatsPanel`** (**`AppOverviewSheetPanelBackground`**, rounded top corners, **`panelOverlap`**). Test: **`diveBuddyDetailPresentation_layoutAndHeroSelection`**.
- **Progressive video upgrade** — preview → full quality no longer remounts the player or restarts from **0**: stable representable identity keyed by source asset, **`upgradePlayerItem`** preserves **`currentTime`**, and **`mediaIdentityChanged`** ignores fidelity-only key changes. Tests: **`diveMediaProgressivePresentation_posterAndUpgradePolicy`**, **`diveActivityVideoPlaybackPolicy_mediaIdentityChanged_ignoresPreviewToFullUpgrade`**.
- **Buddy detail blue panel alignment** — hero metrics now use raw **`GeometryReader`** top inset (same as Home), Home default stats band height (**240**), and **`HomeOverviewLayout.viewportHeightMatchingHomeTab`** so the overlapping panel sits at the same Y as **`LogOverviewView`**. Test: **`diveBuddyDetailPresentation_layoutAndHeroSelection`**.
- **Buddy detail pager layout** — page titles (**Dives together**, etc.) stay pinned above scrollable body content; bottom lists/carousel clear the home indicator + page dots via **`scrollBottomInset`** (panel no longer double-pads safe area — matches trip detail). Tests: **`diveBuddyDetailContentPager_pages`**.
- **Buddy detail panel + avatar alignment** — buddy hero uses the same **`HomeOverviewLayout.metrics`** seam as Home (tab-bar viewport adjustment only — no extra hero extension); avatar **`overlay`** on **`HomeLifetimeStatsPanel`** (above clip) offset half onto media / half onto blue. Tests: **`diveBuddyDetailPresentation_layoutAndHeroSelection`**.
- **Buddy detail blue panel bottom** — **`bottomSafeAreaInset: 0`** + **`ignoresSafeArea(edges: .bottom)`** so the sheet and pager content extend to the screen edge (page-dot clearance only in scroll inset).
- **Buddy detail tagged media** — **Your tagged photos** pager uses **`DiveBuddyTaggedMediaGridSection`** → **`LinkedMediaGridSection`** (3-column still previews; tap → **`LinkedMediaFullscreenView`**: landscape unlock, horizontal swipe, vertical dismiss or **X**, **View on dive**, **# of #**, star). **`LinkedMediaGridPresentation`** / **`LinkedMediaFullscreenPresentation`**. Tests: **`linkedMediaGridPresentation_*`**, **`diveBuddyTaggedMediaPresentation_*`**, **`diveBuddyTaggedMediaFullscreenPresentation_*`**.
- **Buddy featured header media** — **`DiveBuddy.featuredTaggedMediaPhotoID`** + star toggle on tagged media (**`DiveBuddyDetails.TaggedMedia.FeatureToggle`**, bottom-trailing; no marine-life fish button on buddy gallery); one starred item per buddy drives the hero, otherwise **`DiveBuddyHeroMediaSession`** session random (gallery browse no longer updates header). **`DiveBuddyFeaturedMediaStorage`**, **`DiveBuddyTaggedMediaPresentation.resolvedHeroMediaPhotoID`**. Tests: **`diveBuddyTaggedMediaPresentation_resolvedHeroMediaPhotoID_*`**, **`diveBuddyHeroMediaSession_reusesRandomPickForBuddy`**, **`diveBuddyDetailPresentation_layoutAndHeroSelection`**.
- **Home interactive-pop layout** — **`LogOverviewView`** uses **`HomeOverviewLayout.homeRootViewportHeight`** so peek-through during back swipe matches settled root layout (single home view; tab bar hidden while **`path.count > 0`** no longer inflates hero / drops stats panel). Test: **`homeOverviewLayout_homeRootViewportHeight_matchesSettledRootDuringPush`**.
- **Buddy hero pager** — **`DiveBuddyDetailHeroHeaderView`**: tagged media or dive-site map toggled via **`DiveBuddyDetailHeroModeToggle`** (**`ExploreSiteScopeToggle`**-style segmented control — icon-only **camera** / **map** above stats sheet overlap); reuses **`TripDetailMapView`** / **`DiveBuddyDetailMapPresentation`**. Pin tap opens catalog site via **`openCatalogDiveSiteDetail`** or local push. Test: **`diveBuddyDetailMapPresentation_pinsUniqueCoordinatesFromSharedDives`**, **`diveBuddyDetailPresentation_layoutAndHeroSelection`** (**`heroModeToggleBottomPadding`**, mode titles).
- **Buddy blue panel seam** — hero layout uses **`HomeOverviewLayout.pushedHeroLayoutMetrics`** (2×2 stats band, no extra safe-area shift). Test: **`diveBuddyDetailPresentation_layoutAndHeroSelection`**, **`homeOverviewLayout_pushedHeroLayoutMetrics_*`**.
- **Trip detail blue panel seam** — map hero uses the same **`pushedHeroLayoutMetrics`**. Test: **`tripDetailMapPresentation_mapHeroHeight_matchesHomeAndBuddySeam`**.
- **Buddy/trip sheet seam regression** — pushed pages had used the taller **Top buddies** stats band (~408pt); restored default Home 2×2 band via shared **`HomeOverviewLayout.heroLayoutStatsPanelContentHeight`** so blue sheets align with **`LogOverviewView`** again.
- **Buddy/trip sheet height + scroll** — hero seam uses **`HomeOverviewLayout.pushedHeroLayoutMetrics`** (same **`metrics`** + 2×2 stats band as settled Home tab); removed extra **`-topSafeArea`** hero padding that raised the sheet; pushed layout still fills full screen (**`pushedPageLayoutHeight`**) with pager scroll inset (**`pushedPageScrollBottomInset`**). Tests: **`homeOverviewLayout_pushedHeroLayoutMetrics_*`**, **`diveBuddyDetailPresentation_layoutAndHeroSelection`**, **`tripDetailMapPresentation_mapHeroHeight_matchesHomeAndBuddySeam`**.
- **Buddy/trip sheet seam + tab menu spacing** — pushed hero still uses **`viewportHeightMatchingHomeTab`** + settled-tab **`pushedPageLayoutHeight`** / tab-menu scroll inset; **Home **`metrics`** reverted** to stats band + **`tabBarScrollInset`** only (no **`rootTabBarLayoutHeight`** in Home hero math). Tests: **`homeOverviewLayout_pushedPageLayoutHeight_usesSettledHomeTabViewport`**, **`homeOverviewLayout_pushedHeroLayoutMetrics_*`**.
- **Buddy/trip layout matches Home** — pushed hero + sheet stack use full settled Home tab viewport (**`settledHomeTabLayoutViewportHeight`**, same as **`LogOverviewView`** at stack root); **`HomeLifetimeStatsPanel`** uses Home **`bottomSafeAreaInset`** again (no bottom **`ignoresSafeArea`**). Tests: **`homeOverviewLayout_pushedPageLayoutHeight_matchesSettledHomeTabViewport`**, **`homeOverviewLayout_pushedHeroLayoutMetrics_*`**, **`diveBuddyDetailPresentation_layoutAndHeroSelection`**, **`tripDetailMapPresentation_mapHeroHeight_matchesHomeAndBuddySeam`**.
- **Buddy/trip tab-bar geometry adjustment** — **`settledHomeTabLayoutViewportHeight`** / **`pushedHeroLayoutMetrics`** subtract **`rootTabBarLayoutHeight`** (49pt) from pushed full-screen **`GeometryReader`** height so hero seam + stack match Home tab content above the main menu; Home **`metrics()`** unchanged. Tests: **`homeOverviewLayout_pushedPageLayoutHeight_matchesSettledHomeTabViewport`**, **`homeOverviewLayout_pushedHeroLayoutMetrics_*`**, **`diveBuddyDetailPresentation_layoutAndHeroSelection`**, **`tripDetailMapPresentation_mapHeroHeight_matchesHomeAndBuddySeam`**.
- **Page layout geometry probe** — **`PageLayoutGeometrySnapshot`** / **`PageLayoutGeometryProbe`** + on-screen **`PageLayoutGeometryOverlay`** (Settings → **Show page layout geometry**, DEBUG): region guides + copyable report (`sheet.seamYFromStackTop` / `FromStackBottom` / `FromScreenBottom`, `tabBar.reserveBelowStack`, etc.) on Home, buddy, and trip. **`PageLayoutGeometryReferenceView`** (Settings → **Layout geometry guide**) — blank live canvas with the same full-bleed region guides + report (pushed buddy/trip layout math on device). Test: **`pageLayoutGeometryProbe_homeAndPushedTabBarReserve`**, **`pageLayoutGeometryReferencePresentation_*`**.
- **Layout geometry reference page** — replaced scrollable diagrams/glossary with blank **`AppHeaderlessPage`** canvas + live **`PageLayoutGeometryOverlay`** (hero / sheet / seam / tab-bar reserve bands at real device positions). **`PageLayoutGeometryDiagramView`** overlay style is full-bleed (no miniature card chrome).
- **Blue sheet **`sheet.seamYFromScreenBottom`** alignment** — pushed buddy/trip hero metrics cap with Home **Top buddies** stats band on wide phones so **`screenBot`** matches **`LogOverviewView`** when the leaderboard is visible (2×2-only band allowed taller heroes → sheet ~90pt low). Test: **`homeOverviewLayout_pushedHeroLayoutMetrics_capsToHomeLeaderboardSeamOnWidePhones`**, **`pageLayoutGeometryProbe_pushedScreenBottomSeam_matchesHomeWithLeaderboard`**.
- **Buddy detail sheet settle glitch** — first pushed layout pass used raw **`GeometryReader`** safe top (0) + tab-content height (803) before tab bar hide (852), recomputing a shorter hero and higher sheet; **`pushedHeroLayoutViewportHeight`** stabilizes viewport, buddy/trip use **`resolvedSafeAreaTop`** for hero metrics, and layout updates disable implicit animation. Test: **`homeOverviewLayout_pushedHeroLayoutMetrics_stableHeroOnFirstAndSettledGeometry`**.
- **Buddy/trip layout geometry jump (viewport)** — corrected **`pushedHeroLayoutViewportHeight`**: tab-content first frame (803) latches via **`layoutViewportHeightFloor`**; settled full-screen geometry (852) subtracts the hidden tab bar (803) instead of keeping 852 and dropping the sheet. **`pushedHeroLayoutTransitionViewportCandidate`** + **`transitionViewportFloor`** on buddy/trip. Tests: **`homeOverviewLayout_pushedHeroLayoutMetrics_firstFrameTabContentHeight_matchesSettledHeroOnWidePhone`**, **`homeOverviewLayout_pushedHeroLayoutTransitionViewportCandidate_onlyLatchesTabContentGeometry`**, **`homeOverviewLayout_pushedPageLayoutHeight_fillsFullScreenGeometry`**.
- **Buddy/trip sheet seam realigned with Home** — pushed hero uses **`HomeOverviewPushedLayoutPresentation.statsPanelContentHeightMatchingHome`** (same **Top buddies** visibility as **`LogOverviewView`**); **`pushedPageLayoutHeight`** fills full-screen geometry again while hero math keeps the Home tab viewport. Tests: **`homeOverviewLayout_pushedHeroLayoutMetrics_capsToHomeLeaderboardSeamOnWidePhones`**, **`homeOverviewPushedLayoutPresentation_statsPanelContentHeightMatchingHome_usesLeaderboardBandWhenVisible`**, **`pageLayoutGeometryProbe_pushedScreenBottomSeam_matchesHomeWithLeaderboard`**.
- **Buddy/trip **`screenBot`** alignment (physical screen edge)** — **`pushedPageLayoutHeight`** frames hero + sheet at the Home tab viewport (803pt) with **49pt** **`tabBar.reserveBelowStack`** below the stack inside full-screen geometry (852pt) so **`sheet.seamYFromScreenBottom`** matches Home; hero seam math uses raw **`GeometryReader`** safe top via **`pushedHeroTopSafeAreaInset`** (same input as **`LogOverviewView`**). Home unchanged. Tests: **`homeOverviewLayout_pushedPageLayoutHeight_matchesHomeTabViewport`**, **`homeOverviewLayout_pushedHeroTopSafeAreaInset_usesRawGeometryWithOptionalFloor`**, **`homeOverviewLayout_sheetSeamYFromScreenBottom_matchesHomeTabBarReserve`**, **`pageLayoutGeometryProbe_homeAndPushedTabBarReserve`**.
- **Buddy/trip **`screenBot`** 473 vs 383 fix** — pushed pages read **Top buddies** visibility from denormalized **`DiveBuddyTag`** rows (not faulted **`DiveActivity.buddies`**) and exclude the self buddy like **`HomeOverviewAggregate`**; **`showsBuddyLeaderboard`** drives the leaderboard stats band + wide-phone hero cap so **`screenBot`** matches Home (~473 on wide phones). Tests: **`homeOverviewPushedLayoutPresentation_statsPanelContentHeightMatchingHome_usesDiveBuddyTagsWhenRelationshipsUnset`**, **`homeOverviewLayout_pushedHeroLayoutMetrics_widePhoneLeaderboardSeam_matchesHomeScreenBot`**.
- **Buddy hero media progressive load** — resolve header media from tag relationships before async gallery hydration; **`DiveActivityMediaItemView`** reads session + stored previews (Home carousel pattern); muted loading band instead of person icon while tagged media resolves; **`ensureStoredPreviews`** warms hero **`previewJPEGData`**. Test: **`diveBuddyTaggedMediaPresentation_photosAvailableFromTagRelationships_*`**.
- **Buddy tagged media fullscreen gestures** — **`LinkedMediaFullscreenView`**: horizontal swipe between items, Photos-style vertical dismiss, upper-left **X** close, **View on dive** upper-right. **`LinkedMediaFullscreenPresentation`**. Tests: **`diveBuddyTaggedMediaFullscreenPresentation_*`**, **`linkedMediaGridPresentation_*`**.
- **Trip detail media grid** — **`TripDetailMediaGallerySection`** reuses **`LinkedMediaGridSection`** + **`LinkedMediaFullscreenView`** (3-column still previews, tap → full-screen browse/dismiss; marine-life fish badge on grid + overlay in fullscreen). Media pager page scrolls like buddy tagged photos. Tests: **`linkedMediaGridPresentation_*`**, **`tripDetailContentPager_usesStaticLayoutForStatsAndMedia`**, existing **`tripDetailMediaGalleryPresentation_*`** overlay helpers.
- **Buddy detail loading layout** — **`ViewDiveBuddyDetails`** drops deferred **`showsSecondarySections`** gate; dives/trips/tagged-media + map pins resolve synchronously from **`@Query`** (trip-detail pattern) so hero + pager mount on first frame; async **`.task`** only warms hero **`previewJPEGData`**. **`buddyDetailBackChrome`** + horizontal **`ignoresSafeArea`** match **`TripDetailView`**. Test: **`diveBuddyRosterPresentation_sharedDiveActivitiesFromTags_ordersNewestFirst`**.
- **Buddy detail open performance + layout flash** — stop per-frame SwiftData fetches: pager/hero inputs rebuild once per **`buddyDetailContentToken`** (relationship fallbacks + owner-scoped activity/trip queries); hero media + dive count seed from pushed **`DiveBuddy`** relationships in **`init`**; layout floors seed from **`HomeOverviewLayoutAnchor`**; Contacts refresh deferred **2s**; preview warm **`.utility`**. **`DiveBuddyDetailPresentation.effective*Tags`**, **`initialHeroTaggedMediaPhotoID`**. Tests: **`diveBuddyDetailPresentation_initialPushedLayoutFloors_defaultWhenHomeAnchorUnset`**, **`diveBuddyDetailPresentation_effectiveTagMerging_prefersQueryRows`**.
- **Buddy/trip detail open performance** — drop store-wide **`@Query`** loads (sightings, marine catalog, all dive sites, all buddy tags); **`HomeOverviewLayoutAnchor.publish`** from Home + **`pushedPageSeamInputs()`** for instant hero seam; **`TripDetailContentSnapshot`** light build + deferred map/marine-life enrich; owner-scoped activity/roster queries; lazy pager pages mount on first visit; **`AccountSession.resolvedSelfBuddyID`** session cache. Tests: **`homeOverviewPushedLayoutPresentation_pushedPageSeamInputs_usesDefaultBandWithoutStoreScan`**.
- **Buddy/trip push snappiness** — buddy detail uses a three-phase rebuild (dives + hero shell → trips/map/media → marine-life enrich) with no duplicate **`onChange`** pass; trip/buddy marine-life enrichment fetches sightings per linked dive or tagged media (**`MarineLifeSightingRecorder.sightings(forDiveActivityIDs:)`** / **`forMediaPhotoIDs:`**) instead of the full sighting table. Test: **`marineLifeSightingRecorder_batchFetch_scopesByDiveAndMediaIDs`**.
- **Buddy/trip full-bleed safe areas** — pushed hero (map/media) bleeds to the screen top (**`.ignoresSafeArea(edges: .top)`**, Home carousel pattern); blue sheet fills to the screen bottom (**`pushedPageLayoutHeight`** = full geometry, panel **`ignoresSafeArea(edges: .bottom)`**); hero height still uses Home tab viewport math so **`sheet.seamYFromScreenBottom`** is unchanged. Tests: **`homeOverviewLayout_pushedPageLayoutHeight_fillsFullScreenGeometry`**, **`pageLayoutGeometryProbe_homeAndPushedTabBarReserve`**.
- **Buddy/trip sheet seam regression** — **`PushedHeroBand`** applies top bleed after content expansion but before the layout **`frame(height:)`** (Home carousel order) so the blue sheet seam (**`screenBot`**) no longer shifts up when hero draws under the status bar.
- **Buddy/trip pager bottom fade** — **`HomeSheetPanelBottomScrim`** feathers scrolling pager content into the blue sheet at the screen bottom (logbook tab-bar role); **`homeSheetPanelBottomScrollFade`**. Test: **`homeOverviewLayout_pushedPageLayoutHeight_fillsFullScreenGeometry`** (**`pushedPanelBottomScrollFadeHeight`**).
- **Buddy/trip hero map camera fit** — **`TripDetailMapPresentation.fittingRegion`** / **`mkMapRect`** (modest pin padding + minimum single-pin span) drive MapKit **`mapRectThatFits`** and Google **`GMSCameraUpdate.fit`**; representables re-apply when map bounds become valid (deferred mount / layout settle). Tests: **`tripDetailMapPresentation_fittingRegion_*`**, **`tripDetailMapPresentation_fittingRegion_singlePin_usesMinimumSpan`**.
- **Buddy hero mode toggle** — **`DiveBuddyDetailHeroModeToggle`** shows **camera** / **map** icons only (same segmented chrome; accessibility labels unchanged).
- **Trip hero media/map toggle + featured media** — **`TripDetailView`** reuses **`PushedDetailHeroHeaderView`** / **`PushedDetailHeroModeToggle`** (icon-only camera / map when dive sites exist); linked dive media can star in the media pager (**`DiveTrip.featuredTripMediaPhotoID`**, **`DiveTripFeaturedMediaStorage`**, **`TripHeroMediaSession`**). Tests: **`tripDetailMediaPresentation_resolvedHeroMediaPhotoID_*`**, **`tripHeroMediaSession_reusesRandomPickForTrip`**, **`tripDetailMediaPresentation_toggledFeaturedMediaPhotoID_*`**.
- **Shared pushed hero chrome** — **`PushedDetailHeroHeaderView`** / **`PushedDetailHeroModeToggle`** (buddy typealiases preserved); **`DetailHeroMediaPresentation`** shared hero pick + star rules.
- **Buddy/trip pager swipe alignment** — **`PushedDetailContentPagerLayout.tabPage`** pins each **`TabView`** page to one horizontal slot (**`containerRelativeFrame`**); removed lazy **`Color.clear`** placeholders that let pages settle off-center; **`TabView`** clipped. Test: **`diveBuddyDetailContentPager_pages`**.
- **Buddy/trip pager chrome** — bottom scroll fade clears **`pageIndicatorClearance`** so **`TabView`** page dots stay bright above **`HomeSheetPanelBottomScrim`**; buddy pager drops visible page headers (accessibility labels unchanged). Test: **`diveBuddyDetailContentPager_pages`** (**`showsPinnedPageHeaders`**).
- **Buddy/trip bottom fade (logbook parity)** — **`HomeSheetPanelBottomScrim`** uses **`ultraThinMaterial`** (same as **`goDiveRootTabBarChrome()`**) pinned to the physical screen bottom; **`homeSheetPanelBottomScrollFade`** on **`HomeLifetimeStatsPanel`** (full-bleed). Band height = **`rootTabBarLayoutHeight`** + home indicator only (no tall feather). Test: **`homeOverviewLayout_pushedPageLayoutHeight_fillsFullScreenGeometry`**.
- **Buddy/trip bottom fade height** — removed extra 52pt feather + gradient mask that lifted opacity too high; scrim band matches logbook tab-bar height (**`rootTabBarLayoutHeight`** + safe area) at the screen bottom.
- **Buddy/trip bottom fade anchor** — fade moved from **`HomeLifetimeStatsPanel`** (laid out above the home indicator) to the hero + sheet stack after **`.ignoresSafeArea(edges: .bottom)`** (logbook list pattern) so it pins where scroll content actually reaches the physical screen bottom.
- **Buddy/trip bottom fade bottom anchor** — **`HomeSheetPanelBottomScrimPresentation.screenBottomAnchoredBandCenterY`** positions the band by its **bottom edge** on **`layoutHeight + safeAreaBottom`** (physical screen); feather mask is opaque at the band bottom and clears toward the top. Fade lives on **`TabView`** **`.background`** (behind pages) so page dots stay on top; **`screenLayoutHeight`** preserves screen-bottom alignment. Test: **`homeSheetPanelBottomScrim_screenBottomAnchoredBandCenterY_pinsBandBottomToPhysicalScreen`**.
- **Buddy/trip fullscreen media** — **`LinkedMediaFullscreenView`** **`ignoresSafeArea()`** + explicit media frame for edge-to-edge photos/videos; **View on dive** presents **`ViewSingleActivity`** in a nested **`fullScreenCover`** over the gallery (no stack push beneath). Test: **`linkedMediaFullscreenPresentation_linkedDiveCoverIdentity_isStablePerDiveAndMedia`**.
- **Buddy/trip hero map 0,0 fix** — **`TripDetailMapPresentation.effectiveMapHeight`** uses SwiftUI hero height when UIKit map bounds are still zero; MapKit applies a provisional **`setRegion`** then **`mapRectThatFits`** once measured; Google **`GMSCameraUpdate.fit`** runs on first mount (Explore pattern) and re-fits on layout delegate callbacks. Test: **`tripDetailMapPresentation_effectiveMapHeight_usesHeroHeightBeforeUIKitLayout`**.
- **Buddy/trip bottom fade visibility** — fade was positioned with full-screen **`screenLayoutHeight`** inside the shorter pager **`TabView`** (off-screen) and sat behind scroll content as a **`TabView`** **`.background`**. **`HomeSheetPanelBottomScrollFadeBand`** bottom-anchors in each pager page’s local geometry; **`homeSheetPanelBottomScrollFade()`** is a per-page **`.overlay`** so lists scroll under the material (logbook tab-bar role) while **`TabView`** page dots stay above page content.
- **Buddy/trip fullscreen portrait chrome** — **`LinkedMediaFullscreenPresentation.topChromeRowOffset`** lowers **X**, **#/#**, and **View on dive** together in portrait (**`portraitTopChromeExtraInset`** 40pt); landscape unchanged. Test: **`linkedMediaFullscreenPresentation_topChromeInset_addsPortraitBumpOnly`**.
- **Buddy/trip fullscreen close snappiness** — **X** / accessibility **Close** call **`dismiss()`** immediately (no pre-slide); swipe dismiss uses faster spring (**`gestureDismissAnimationDuration`** 0.22s). Test: **`linkedMediaFullscreenPresentation_gestureDismiss_isSnappierThanBrowse`**.
- **Buddy/trip bottom fade hue** — **`HomeSheetPanelBottomScrim`** uses **`AppOverviewSheetPanelBackground`** (same ocean gradient as the stats sheet) with the existing bottom feather mask instead of **`ultraThinMaterial`**.
- **Buddy detail identity row** — name + dives-together lift **`identityTextLift`** (12pt) beside the overlapping avatar; dives-together uses **`AppTheme.Colors.accent`** (trip buddy grid parity). Test: **`diveBuddyDetailPresentation_layoutAndHeroSelection`**.
- **Trip buddy grid avatar alignment** — **`TripDetailBuddyAvatarGridCell`** top-anchors cells in **`LazyVGrid`** rows (fixed caption min-heights) so profile images line up when names wrap to two lines; shared by active + planned buddy grids. Test: **`tripDetailBuddiesPresentation_usesThreeColumnGrid`** (**`gridCaptionMinHeight`**).
- **Buddy/trip map pin callouts** — hero maps use Explore all-sites labeling: pin-only by default; site name callout on pin tap; **entire callout label** opens site detail (**`ExploreCatalogMapSiteCallout.makeMapKitCalloutAccessory`** / Google tap handler). Trip map no longer blocks navigation when a pin’s site is missing from the local catalog cache. Tests: **`tripDetailMapPresentation_usesPinCalloutLabeling`**, **`tripDetailMapAnnotation_suppressesDefaultCalloutTitle`**.
- **Buddy avatar initials** — buddies without a profile photo show name initials (**`DiveBuddyPresentation.initials`**, **`ProfileAvatarView.placeholderInitials`**) instead of the person icon (list, detail, trip grids, media tags, leaderboard). Test: **`diveBuddyPresentation_initials_usesFirstAndLastToken`**.
- **Trip detail pager order** — active trips swipe **stats → tagged dives → marine life → buddies → media** (**`TripDetailContentPagerPresentation.pages`**). Test: **`tripDetailContentPager_activeTripPages`**.
- **Buddy detail open performance** — drop live owner-wide **`@Query`** dives/trips; on-demand **`fetchOwnerDiveIndex`** / **`fetchOwnerTrips`**; seed shared dive rows from pushed relationships; defer hero video/map + **`TabView`** pager until after navigation (**`showsDeferredBuddyChrome`**); lazy-mount non-default pager tabs; buddy list uses **`navigationDestination(for:)`**. Tests: **`diveBuddyDetailPresentation_initialSharedDiveContent_seedsRelationshipRows`**.
- **Trips list date range** — **`TripPlannerListRow`** date range uses secondary caption color; linked dive count stays accent. **`TripDetailView`** title block shows accent date range.

## 84 - Next batch **(pushed)**

**Summary:** Blue sheet header page template; remove Settings layout geometry debug; Field Guide hub tiles match Home stat grid.

- **Blue sheet header page** — renamed trip-style layout template from pushed-hero-sheet: **`BlueSheetHeaderPageLayout`**, **`BlueSheetHeaderPageLayoutBuilder`**, **`BlueSheetHeaderScrollPageLayout`**, **`.blueSheetHeaderPageLayoutState`**. Agent rule **`.cursor/rules/blue-sheet-header-page.mdc`** + **`GoDiveMVP/cursor/blue_sheet_header_page.md`**. Test: **`blueSheetHeaderPageLayoutBuilder_heroHeight_matchesPushedHeroLayoutMetrics`**.
- **Removed layout geometry debug** — Settings **Show page layout geometry** toggle, **Layout geometry guide**, **`PageLayoutGeometryOverlay`** / probe / reference page; overlays removed from Home, buddy, and trip.
- **Field Guide hub category tiles** — **`FieldGuideCatalogHubView`** full-width list rows with **`LogbookActivityRowLayout`** spacing (**8** pt list gap, **8** pt padding, **10** pt radius) and **92** pt opaque gradient banners (category art + line-art styling preserved). Test: **`fieldGuideHubTileLayout_matchesLogbookActivityRowSpacing`**.
- **Field Guide hub header** — intro is **Reef Life Field Guide** only; removed Caribbean browse subtitle; title in **`FieldGuideTopChrome`** above species search (scroll-under scrim covers title + search); category tiles scroll beneath.
- **Field Guide category pages** — **`FieldGuideCategoryDetailView`** + **`FieldGuideSubcategorySpeciesView`** use **`FieldGuideCategoryBlueSheetPage`** / shared **`FieldGuideBlueSheetPage`** (**`BlueSheetHeaderPageLayout`**: category gradient hero + line art, overlapping blue sheet, scroll fade; no map/toggle). **`FieldGuideBlueSheetSearchBackChrome`** — back chevron + **`CatalogSearchField`** on one row (groups / species placeholders). Title, description/hint, and species count pinned above scroll (no extra panel fill behind summary); **Groups** subheader removed. Category accent colors preserved on species counts and group rows. Tests: **`fieldGuideCategoryBlueSheetPage_heroHeight_matchesPushedLayoutMetrics`**, **`fieldGuideMarineLifeDetailView_heroHeight_usesPushedLayoutMetrics`**, **`fieldGuideSubcategorySearchPresentation_filtersByTitleOrHint`**.
- **Field Guide species detail** — **`FieldGuideMarineLifeDetailView`** uses **`FieldGuideBlueSheetPage`**: catalog photo / 3D hero with optional map toggle; pinned taxonomy + name block; four-page content pager (see below).
- **Field Guide species detail pager** — pinned summary is category · subcategory (category accent), common name, and scientific name; **`FieldGuideSpeciesDetailContentPager`** swipes **about → size & range → tagged dives → tagged media** (trip-style **`LinkedDiveLogbookListRows`** + **`TripDetailMediaGallerySection`**). **`FieldGuideBlueSheetPage`** accepts generic **`panelContent`** + optional **`heroOverlay`**; category pages wrap scroll in **`BlueSheetHeaderScrollPageLayout`**. Tests: **`fieldGuideSpeciesDetailContentPager_pages`**, **`fieldGuidePresentation_sightedDiveRowDisplayData_ordersNewestFirst`**, **`fieldGuideTaggedMediaPresentation_linkedMediaItems_mapsPhotosToParentDives`**.
- **Field Guide species detail map hero** — **`FieldGuideMarineLifeDetailView`** restores buddy/trip-style **`PushedDetailHeroModeToggle`** (catalog photo / 3D ↔ **`TripDetailMapView`**) when tagged dives have map coordinates; pins from **`FieldGuideSpeciesDetailMapPresentation`** (unique sighting sites); pin callout opens **`ExploreDiveSiteDetailView`** via **`openCatalogDiveSiteDetail`**. Test: **`fieldGuideSpeciesDetailMapPresentation_pinsUniqueCoordinatesFromTaggedDives`**.
- **Dive Buddies list navigation** — **`DiveBuddiesListView`** uses inline **`NavigationLink`** to **`ViewDiveBuddyDetails`** (same pattern as Equipment Locker / Certifications); removed conflicting **`navigationDestination(for: UUID.self)`**. Buddy detail shared dives open via **`openSharedDive`** → **`buddyDiveNavigationID`** instead of raw UUID routes.
- **Trip list row third line** — **`TripPlannerListRow`** shows date range only (countries removed from visible caption; still included in VoiceOver via **`listRowAccessibilityLabel`**).
- **Trip planner upcoming rows** — **`TripPlannerView`** **Upcoming** section uses **`LogbookUpcomingTripBannerView`** (**Trip on the horizon** eyebrow, airplane icon, accent stroke, chevron) — same tile as the logbook banner. Test: **`logbookUpcomingTripPresentation_bannerData_mapsTripPlannerHorizonRow`**.
- **Explore trip planner icon** — **`ExploreTopChrome`** map-mode airplane button uses white foreground over the satellite map.
- **Field Guide subcategory search** — multi-word queries match when every token appears in title/hint (e.g. **Caribbean Gobies**).

## 85 - Explore, Field Guide, and home leaderboards **(pushed)**

**Summary:** Explore dive-site search, country grouping, and unified catalog/OpenDiveMap display model.

- **Explore dive-site search** — list + map suggestions filter on country, region, and sea name via **`searchHaystacks`** on **`ExploreDiveSiteRowDisplayData`** (**`ExploreDiveSiteListSearch`**, **`ExploreReferenceSiteListSearch`**, **`ExploreSiteScopeCache.filteringListRows`**). Tests: updated **`exploreDiveSiteListSearch_matchesNameAndPlace`**, **`exploreReferenceSiteListSearch_matchesNameAndCountry`**, **`exploreSiteScopeCache_filteringListRows_matchesDisplayFields`**.
- **Explore dive-site list by country** — list mode groups rows under country section headers (**`ExploreDiveSiteListPresentation`**). Catalog and OpenDiveMap rows share **`DiveSitePresentation.listPlaceLine`** (**Country · Region · Body of water**). Tests: **`exploreDiveSiteListPresentation_sections_groupsByCountryAndSortsTitles`**, **`exploreDiveSiteListPresentation_referencePlaceLine_usesUnifiedPlaceFields`**.
- **Dive-site country aliases** — **`DiveSiteCountryPresentation`** maps **Dutch Caribbean** (and related labels) to **Caribbean Netherlands** for list sections, search, import, and catalog backfill. Tests: **`diveSiteCountryPresentation_canonicalDisplayName_mergesDutchCaribbean`**, **`exploreDiveSiteListPresentation_sections_mergesDutchCaribbeanWithCaribbeanNetherlands`**, **`exploreDiveSiteListSearch_matchesDutchCaribbeanAlias`**.
- **Unified dive-site display model** — **`DiveSiteDisplayRecord`** + **`DiveSitePresentation`** map catalog **`DiveSite`** and OpenDiveMap reference rows to the same list/detail fields (**`-`** for missing); **`DiveSite`** gains **`entry`**, **`environment`**, **`maxDepthMeters`**; shared **`ExploreDiveSiteDetailMetadataView`**. Tests: **`diveSitePresentation_listRecord_usesDashForMissingValues`**.
- **Explore site scope toggle** — **`ExploreSiteScopeToggle`** segments renamed **My Sites** / **All Sites** (was Logbook / All sites); empty-state copy updated.
- **Explore top chrome** — **`ExploreTopChrome`**: map/list flip **leading**, **Add dive site** (**+**) **trailing** (**`ExploreCatalogDiveSiteAddSheet`** → **`DiveActivitySiteAssociation.createCatalogSite`**); Trip Planner airplane removed (Trips remain on **Profile**). Tests: **`exploreDiveSiteAddPresentation_chromeCopy`**, **`diveActivitySiteAssociation_createCatalogSite_persistsWithoutDiveLink`**.
- **Dive site detail blue sheet** — **`ExploreDiveSiteDetailView`** + **`ExploreReferenceSiteDetailView`** use **`FieldGuideBlueSheetPage`** (media/map hero, overlapping blue sheet). Pinned header: site name, **Region, Country** (or country only), accent dive count, and accent **5-star** rating (**`DiveSitePinnedStarRatingView`**, upper trailing when rated). **`ExploreDiveSiteDetailContentPager`** swipes **Dive details** → **Dives here** → **Marine life here** → **Tagged media**; **Water type** is read-only in **Details** metadata (segmented picker removed). Catalog sites: **map-only** when no tagged media; **media + map toggle** (default **media**) when both exist; waits for owner dive query before map-only default. Tests: **`diveSitePresentation_pinnedHeader_formatsLocationAndDiveCount`**, **`diveSitePresentation_pinnedStarRating_acceptsOneThroughFiveOnly`**, **`exploreDiveSiteDetailContentPager_pages`**, **`exploreDiveSiteDetailPresentation_*`**.
- **Logbook trip planner** — **`LogbookTopChrome`** airplane (**leading** of **Search Activities**) pushes **`TripPlannerView`** via **`LogbookRoute.tripPlanner`**; **`CatalogListSearchChrome`** supports optional leading actions.
- **Segmented toggle selection color** — **`ExploreSiteScopeToggle`** + **`PushedDetailHeroModeToggle`**: selected segment icon (and label) use **`accent`** blue; unselected stays **`tabUnselected`**.
- **Explore site media grid** — **`ExploreDiveSiteMediaPresentation`** aggregates **all** owner **`DiveActivity.mediaPhotos`** linked to the catalog site (newest dive first, gallery order within each dive — same rules as trip media); no longer limited to photos referenced by **`SightingInstance.mediaPhotoID`**. Hero + **Tagged media** pager page use the same source. Test: **`exploreDiveSiteMediaPresentation_includesAllDiveMediaAtSite_notOnlySightingLinked`**.
- **Field Guide hub chrome** — removed **Reef Life Field Guide** title; **`FieldGuideTopChrome`** uses **`CatalogListSearchChrome`** (same top row alignment as Logbook); **`LogbookTopChromeScrim`** always when species search is shown.
- **Dive site star ratings** — pinned header always shows **5** accent stars (empty when unrated); owner-rated value persists on **`DiveSite.siteRating`**. Stars are tappable after the signed-in user logs a dive at the catalog site (tap same star again clears to unrated). Reference-only sites show empty stars (read-only). Tests: **`diveSitePresentation_displayPinnedStarRating_defaultsToZero`**, **`diveSitePresentation_starRatingEditing_requiresVisitAndTogglesOff`**.
- **Dive site detail pinned header layout** — compact **5-star** row above site name (tighter inter-star spacing); accent **dives here** count on the same row, trailing; **Region, Country** (or country only) capped at **2** lines with tail **…** truncation.
- **Field Guide category / subcategory browse** — **`FieldGuideCatalogBrowseListPage`** replaces blue-sheet heroes with logbook-style **`List`** under back + search chrome (**`WaterBubbleBackground`**, **`LogbookTopChromeScrim`**); title/description summary as first row, subcategory cards use **`LogbookActivityRowLayout`**. Species detail keeps **`FieldGuideBlueSheetPage`**. Test: **`fieldGuideCatalogBrowseListPresentation_matchesHubListSpacing`** (replaces **`fieldGuideCategoryBlueSheetPage_heroHeight_matchesPushedLayoutMetrics`**).
- **Field Guide global species search** — hub, category, and subcategory browse share one **`speciesSearchQuery`** + focus binding from **`FieldGuideView`**; **`FieldGuideTopChrome`** / **`FieldGuideBrowseSearchChrome`** use **`CatalogListSearchChrome`** with **`reservesCancelSlotWhenUnfocused`** (fixed **Cancel** slot — no layout jump on focus). Placeholder **Search Marine Life** everywhere; active search lists matching species from the **full catalog** via **`FieldGuideSpeciesSearchResultsRows`** (not scoped to the current category/subcategory). Test: **`fieldGuideSpeciesSearchResultsPresentation_searchesFullCatalog`**.
- **Home lifetime stat leaderboards** — **Deepest**, **Longest**, **Top site**, and **Top species** tiles push ranked **top 5** lists (**`HomeLifetimeStatsLeaderboardView`**); **Top buddies** unchanged. Tests: **`homeLifetimeStatsLeaderboardPresentation_*`**.
- **Field Guide species search chrome** — hub + browse lists use logbook-style list spacers (removed **`safeAreaInset`**), **`ignoresSafeArea(.keyboard)`** so focus does not shove chrome off-screen, status-bar scrim on **`FieldGuideTopChrome`**, and simplified browse chrome layer.
- **Field Guide add species** — trailing **+** on hub + category/subcategory search chrome opens **`FieldGuideMarineLifeAddSheet`** (common/scientific name, category, group, family, about); user rows use **`user-marine-life-`** UUIDs and survive catalog reseed. Tests: **`fieldGuideMarineLifeAddPresentation_validatesAndBuildsSpecies`**, **`marineLifeCatalogSeeder_preservesUserCreatedSpeciesOnReseed`**.
- **Field Guide species hero source toggle** — when owner tagged media exists, **`FieldGuideMarineLifeDetailView`** defaults the media hero to user tagged video/photo; bottom-leading **60** pt circle (**`FieldGuideSpeciesHeroSourceToggle`**, half profile avatar size) previews catalog image/3D or looping tagged media and swaps sources on tap — hidden on **map** hero; media/map toggle stays trailing. Catalog hero defaults to dataset **image** when both image and 3D exist; tap header toggles image ↔ 3D. Tests: **`fieldGuideSpeciesHeroPresentation_prefersTaggedVideoAndTogglesSource`**, **`fieldGuideSpeciesHeroPresentation_catalogHeroDisplay_defaultsToImageAndToggles`**, **`fieldGuideMarineLifeHeroPresentation_catalogImageKind_ignoresModelName`**.
- **French Angelfish 3D catalog link** — **`marine_life_sample.json`** sets **`feature_model`: `FrenchAngelfish`** for **`marine-life-french-angelfish`** (bundled **`Resources/MarineLife3D/FrenchAngelfish.usdz`**); seeder test expects **`featureModelResourceName`**. Existing installs upsert on next catalog seed.
- **Explore list dedupe** — **`ExploreDiveSiteListPresentation.sections`** drops duplicate rows within a country section (by **`referenceID`** or **`id`**) so catalog/OpenDiveMap merges do not repeat the same site.

## 86 - Next batch **(pushed)**

**Summary:** MacDive UDDF import walkthrough before file picker; Home buddy avatars refresh when roster photos change.

- **MacDive import guide** — UDDF sheet **MacDive Import** pushes **`MacDiveUddfImportGuideView`** on the logbook **`NavigationStack`** (**`AppPage`**, not in-sheet; no nested stack). Swipeable steps use **600pt** screenshots (no swipe hint copy); step 6 **Import MacDive Data** opens the UDDF picker. Assets **`MacDiveImportStep01`–`05`**. **FIT / UDDF import options** — **`DiveFileImportOptionsView`** pushed pages (replaces options sheet). **File picker fix** — **`requestFileImporter`** waits for sheet/nav dismiss before **`.fileImporter`** (no double-tap). Tests: **`macDiveUddfImportPresentation_steps_endOnImportButtonPage`**, **`diveFileImportOptionsPresentation_copyForFitAndUddf`**.
- **Home buddy avatars refresh** — **`DiveBuddyRosterChangeNotification`** posts after buddy photo/name/contact save or delete; **`LogOverviewView`** rebuilds **`HomeOverviewAggregate`** on that signal and when roster **`profilePhoto`** changes (**`HomeBuddyRosterRefreshToken`**). **`HomeOverviewRefreshToken`** fingerprints include buddy photos so Top buddies + carousel overlays update without restarting. Tests: **`homeBuddyRosterRefreshToken_fingerprint_changesWhenProfilePhotoChanges`**, **`homeOverviewRefreshToken_contentFingerprint_changesWhenBuddyProfilePhotoChanges`**.
- **Header scrim color** — **`statusBarEdgeScrimGradient`**, **`logbookTopChromeScrimGradient`**, and **`statusBarEdgeScrimSolid`** feather through **`surfaceGradientBottom`** (deep ocean blue) instead of black so **`AppHeader`** / list chrome blends with the page background.

## 87 - Next batch **(pushed)**

**Summary:** Light-mode color tuning — surfaces, GoDive wordmark, header scrim, Explore chrome.

- **`AppTheme`** — light **`surfaceElevated`** → gray-blue; light **`surfaceMuted`** → medium dark blue; darker light **`accentLight`** (GoDive wordmark leading stop); **`headerScrimBase`** dark-navy status-bar feather in light mode (**`statusBarEdgeScrimGradient`** / solid).
- **Explore** — **`exploreChromeControlFill`** semitransparent slate for map/list search field (**`CatalogSearchField.fill`**).
- **`AppButtonChrome`** — Liquid Glass per [Adopting Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass): **`.glass`** toolbar buttons, **`glassEffect(.regular.interactive())`** search capsules, **`GlassEffectContainer`** on chrome rows, standard **`.segmented`** pickers (dive tabs, hero toggle, Explore scope with icon + title).
- **Transparent highlight tiles** — **`AppHighlightTileChrome`** / **`AppListTileCardChrome`**: **`surfaceElevated`** fill + logbook row stroke in **both** appearances (was transparent + **`highlightTileOutline`** in dark mode); Home stats, trip stats, dive map stats box share the same tokens as **`LogbookActivityRow`**.
- **Search Cancel vs trailing actions** — **`CatalogListSearchChrome`** and **`ExploreTopChrome`** swap trailing chrome with **`CatalogSearchDismissButton`** (**×**, not **Cancel** text) via conditional layout so Liquid Glass controls do not stack over **+** / add-site actions.
- **Explore site scope toggle** — **`ExploreSiteScopeToggle`** compact intrinsic width (**`fixedSize`**) with book / globe icons + **My Sites** / **All Sites** labels inside a Liquid Glass shell (system **`.segmented`** picker does not show icon + title together); **`ExploreSiteScopeBottomChrome`** pins the control centered just above the root tab bar (**`ExploreSiteScopeChromePresentation`**) on map and list at stack root; list scroll reserves extra bottom inset. Bottom inset uses tab-content geometry only (no double-counted tab-bar + home-indicator padding).
- **Profile bubble scrim** — light mode **`profileBubbleScrim`** semitransparent ocean blue over **`WaterBubbleBackground`** (darker than prior light blue-gray); dark mode unchanged.
- **Home empty media placeholder** — **`HomeMediaCarouselEmptyPresentation.contentDownshift`** (**80 pt**) lowers animated ghost frames + copy when the carousel has no featured media; pulsing hero icon removed (bouncing photo/video tiles only).
- **Back button color** — **`SecondaryDestinationBackButton`** uses **`backButtonForeground`** (dark slate light / white dark) on Liquid Glass **`.glass`** chrome.
- **Edit toolbar** — **`AppEditToolbarButton`** (**Edit** + Liquid Glass) replaces ellipsis / plain text on Profile, trip detail, certification, equipment, and buddy detail; dive overview section headers keep ellipsis.
- **List page top fade (light mode)** — **`listTopChromeScrimBase`** / **`listStatusBarEdgeScrimGradient`**: certifications, buddies, equipment locker, and all **`LogbookTopChromeScrim`** list fades feather to pale ocean blue (not deep **`surfaceGradientBottom`** / dark navy).
- **Dive activity tank tab icon** — **`DiveActivityTabAssetSegmentLabel`**: uniform scale from **`ScubaTankTab`** catalog pixels (**35×72**) to **16 pt** height with **`scaledToFit`** + **`fixedSize`** so the glass segmented cell does not squash aspect ratio.
- **Dive activity tab bar** — **`DiveActivityIconTabBar`** compact intrinsic glass strip (**`PushedDetailHeroModeToggle`**-style **44×44** segments, **`fixedSize`**, centered in top chrome so it clears the back button); replaces full-bleed layout that collided with back.
- **Home → buddy detail performance** — **`restoresRootTabBarWhenStackIsEmpty`** hides the root tab bar immediately on push (**`.hidden`**, not **`.automatic`**); **`HomeRootViewportPresentation`** freezes Home hero/stats height while pushed so the root stack does not relayout under the transition; **`ViewDiveBuddyDetails`** mounts the content pager on frame one and defers only hero MapKit (**`showsDeferredHeroMap`**, trip-detail pattern) instead of gating the whole chrome.
- **Glass chrome height** — **`AppTheme.Layout.glassChromeControlHeight`** (**44 pt**) shared by **`CatalogSearchField`**, **`appStandaloneIconButtonStyle`** (circular **44×44**), **`appGlassToolbarTextButtonStyle`**, and **`CatalogListSearchChrome`** rows.
- **GoDive header scrim (light mode)** — **`headerScrimBase`** pale ocean blue (**`surfaceGradientTop`**) for **`statusBarEdgeScrimGradient`** on Home / Logbook **`AppHeader`** (was dark navy).
- **Pushed hero media/map toggle** — **`PushedDetailHeroModeTogglePresentation`**: **44×44** segments (**`AppToolbarIconButtonMetrics.tapDimension`**), **`.body`** icons, **`contentShape(Rectangle())`** on each segment for full-cell taps; chrome width **~100 pt**.
- **Home featured-media slide chrome** — dive link capsule + fish / buddy icon chips use Liquid Glass (**`appLiquidGlassSearchFieldChrome`** / **`appLiquidGlassCircleChrome`**) instead of dark **`ultraThinMaterial`** fills.
- **Stat / highlight tile fill** — **`AppListTileCardChrome`** unifies **`surfaceElevated`** + logbook stroke for Home **2×2** stats, trip rollup tiles, dive overview map stats box, and **`LogbookActivityRow`**.
- **Home stats tile taps** — **`HomeStatTile`** fills each **2×2** grid cell (**`contentShape(Rectangle())`**, **`minHeight: statTileHeight`**) so the whole card opens the top-five leaderboard (not just the text).
- **Catalog search performance** — in-memory substring search (not SwiftData SQL indexes): precomputed lowercase haystacks + **80 ms** debounce + off-main filtering. **Field Guide** — **`FieldGuideSpeciesSearchResultsPresentation.searchableTextByUUID`** + **`filteringIndexed`** in **`FieldGuideSpeciesSearchResultsRows`** (hub + category browse). **Explore** — **`DiveSiteDisplayRecord.searchHaystackLowercased`** at row build; debounced **`scheduleDisplayedListRowsRefresh`** filters off main actor. **Logbook** — site search refresh skips duplicate-ID scan (**`includeDuplicateScan: false`**). **`CatalogSubstringSearch.matchesPrelowercased`**, **`CatalogSearchPresentation`**. Tests: **`fieldGuideSpeciesSearchResultsPresentation_indexedRowData_matchesUnindexedFilter`**, **`catalogSubstringSearch_matchesPrelowercasedHaystack`**, **`exploreSiteScopeCache_filteringListRows_usesPrecomputedHaystack`**.
- **Home featured-media overlays** — tagged-buddy popup caps at **two** full avatars + scroll-aware circle fade on the third (**`buddyRowFadeMask`**, **`scrollClipDisabled`**, **`taggedBuddyThirdProfilePeekHeight` 28 pt**). Marine-life **full-bleed** frosted scrim (**`0.38`**) + Liquid Glass **×** close. Tests: **`homeMediaCarouselPresentation_taggedBuddyExpandedListHeight_capsAtTwoFullProfiles`**, **`homeMediaCarouselPresentation_buddyRowFadeMask_peekAndScrollZones`**.

## 88 - Navigation performance, buddy tagging, Fishial toolbar **(pushed)**

**Summary:** Faster Home → buddy detail and Explore → dive site detail — init-seeded chrome on frame one; MapKit + SwiftData refresh deferred until after push.

- **Owner dive index session cache** — **`OwnerDiveIndexSessionCache`** publishes from **`LogOverviewView.rebuildHomeOverview`** so **`ViewDiveBuddyDetails`** reuses owner-wide logbook numbering without **`fetchOwnerDiveIndex`** on every push; fallback fetch after **`PushedNavigationDeferralPresentation.afterPushDelay`** (300 ms) when cache is cold (e.g. Profile → Buddies).
- **Buddy detail open task** — first frame uses init-seeded dive rows + hero; dive **#** refresh from cache/fetch; map pins + tagged-media offsets deferred until post-push delay; marine-life enrichment stays last phase.
- **Buddy detail push stutter fix** — stable **`buddyDetailContentToken`** (no **`@Query`** hydration restarts); **`mediaScopeDiveActivityIDs`** scopes tagged-media to shared dives (not full owner logbook when cache hits). Test: **`diveBuddyDetailPresentation_mediaScopeDiveActivityIDs_usesSharedDivesNotFullOwnerLogbook`**.
- **Buddy detail content load** — init seeds **`OwnerDiveIndexSessionCache`** numbering + dive rows + map pins from pushed relationships; hero, pager, and mode toggle mount on frame one (**`showsDeferredBuddyChrome`** removed); only MapKit + SwiftData refresh defer until post-push (**`afterPushMapDeferral`**); marine catalog deferred to first **Tagged media** swipe; dive-index fetch + hero warm run in parallel after defer; video autoplay gated on stored preview / warm completion. Tests: **`diveBuddyDetailPresentation_numberedRows_seedFromOwnerIndexCache`**, **`diveBuddyDetailPresentation_initialMapPins_buildsFromSharedDives`**, **`pushedNavigationDeferralPresentation_afterPushMapDeferral_matchesAfterPushDelay`**.
- **Lazy trip rows** — **`fetchOwnerTrips`** runs when the user first opens **Trips together** (**`DiveBuddyDetailContentPager.onPageFirstMounted`**) instead of on every buddy open. Tests: **`ownerDiveIndexSessionCache_reusesPublishedOwnerIndex`**, **`diveBuddyDetailPresentation_ownerDiveIndex_buildsNumberingRowsFromActivities`**, **`pushedNavigationDeferralPresentation_afterPushDelay_matchesTripAutoLinkDeferral`**.
- **Explore → dive site detail performance** — drop owner-wide **`@Query`** dives + marine catalog on **`ExploreDiveSiteDetailView`**; init seeds **`ExploreDiveSiteDetailContentSnapshot`** from site relationships; **`ExploreDiveSiteDetailContentSnapshotBuilder`** site-scoped dive fetch after post-push defer; deferred MapKit (**`showsDeferredHeroMap`**) + marine catalog / species links on first **Marine life** / **Tagged media** pager visit; **`OwnerDiveIndexSessionCache`** also publishes from Explore scope-cache rebuild. Tests: **`exploreDiveSiteDetailContentSnapshotBuilder_fetchSiteDiveActivities_filtersOwnerSiteLinks`**, **`exploreDiveSiteDetailContentSnapshotBuilder_siteActivitiesFromRelationships_filtersOwner`**.
- **Buddy tagging draft-until-Done** — **`DiveActivityBuddiesEditSheet`** + **`DiveMediaBuddyTagPickerSheet`** keep selections in memory; **`DiveBuddyActivityTagDraftPresentation`** / **`DiveMediaBuddyTagDraftPresentation`** apply tag diffs + one **`save()`** on **Done** (no per-tap SwiftData writes or **`postMediaDidChange`**); **`DiveActivityAddBuddySheet`** supports **`deferActivityTagging`** + **`onBuddyCreated`** for roster-only add during draft flows; removing the last media tag for a buddy on a dive drops dive participation when they have no other media tags on that dive. Tests: **`diveBuddyActivityTagDraftPresentation_apply_writesOnlyOnDoneDiff`**, **`diveMediaBuddyTagDraftPresentation_apply_batchesMediaTagWrites`**.
- **Marine life tag sheet Fishial toolbar** — Fishial **sparkles** sits in the leading cluster beside **+** (not beside **Done**); pink→purple **`fishialIdentifyIconGradient`** marks the AI affordance. Test: **`diveMarineLifeTagSheetPresentation_fishialIdentifyIconGradient_usesPinkPurpleStops`**.

## 89 - Next batch **(pushed)**

**Summary:** Trip accent palette readability + trip detail date subtitle matches logbook rail color; Liquid Glass toolbar icons; subtler taller GoDive header scrim; Home top-five leaderboard tiles match logbook / Explore / species chrome.

- **Trip accent palette** — **`LogbookTripGroupAccentPalette`** swaps light cyan/sky/yellow/pastel greens for deeper teal, emerald, amber, indigo, etc. (readable in light mode). Test: **`logbookTripGroupAccentPalette_avoidsLightPastelHues`**.
- **Trip detail date accent** — **`TripDetailView`** date subtitle uses **`LogbookTripGroupAccentPresentation`** (same index as logbook trip rail; stable hash fallback when the trip is not grouped). Test: **`logbookTripGroupAccentPresentation_matchesLogbookRailIndexForTrip`**.
- **Liquid Glass toolbar icons** — **`AppToolbarIconButton`** (circular **`.glass`** icon chip); **Trip detail** share + **Profile** settings use the same chrome as Field Guide **+** / logbook airplane; Edit + share/settings grouped in **`GlassEffectContainer`**.
- **GoDive header scrim** — **`AppStatusBarEdgeScrim`** brand feather **40pt**; **`statusBarEdgeScrimGradient`** peaks at **60%** opacity (never fully opaque), mostly transparent through the band.
- **Home carousel dive chip** — site name + **#** use dark slate (**`backButtonForeground`** / **`secondaryText`**) in light mode on the Liquid Glass capsule (**`HomeMediaCarouselDiveLinkChromePresentation`**).
- **Home lifetime stat leaderboards** — **Top 5 dive sites** use **`ExploreDiveSiteRow`**; **Top 5 species** show catalog preview images when bundled/URL exists; **deepest** / **longest** use **`LogbookActivityRow`** tiles (no rank badges). Tests: **`homeLifetimeStatsLeaderboardPresentation_siteRowDisplayData_*`**, **`homeLifetimeStatsLeaderboardPresentation_speciesRowDisplayData_showsPreviewWhenImageExists`**.
- **Explore map top fade (light mode)** — **`ExploreMapTopChromeScrim`** + **`AppStatusBarEdgeScrim`** **`usesExploreMapChrome`** feather through **`mapChromeScrimBase`** (**`surfaceGradientBottom`** deep ocean); list mode keeps pale ocean scrim.
- **Explore search + site scope** — toggling **My Sites** / **All Sites** during search keeps query + keyboard open and refreshes results; scope toggle sits in **`safeAreaInset`** above the keyboard (**`ExploreSiteScopeKeyboardChrome`**); map suggestions show up to **3** visible rows (panel height fits **1–2** results; scroll when more). Tests: **`exploreSiteScopeChromePresentation_showsBottomToggle`**, suggestion panel height by row count.

## 90 - User guide & GitHub Pages **(pushed)**

**Summary:** User-facing GitHub Pages guide (MkDocs Material) — overview, getting started, feature pages, import, settings, privacy; deploy workflow on push to `main`.

- **`docs/`** — MkDocs site: index, getting-started, home, logbook, dive-detail, field-guide, explore, trips-and-buddies, import, settings, privacy-and-data (plain-language rewrite from **`app_summary.md`**).
- **`mkdocs.yml`** — Material theme, nav, search.
- **`.github/workflows/deploy-docs.yml`** — `mkdocs gh-deploy` on `docs/**` / `mkdocs.yml` changes.
- **`README.md`** — repo pointer to published guide URL and local `mkdocs serve` instructions.
- **`.cursor/rules/github-pages-user-guide-sync.mdc`** — pre-push sync of **`docs/`** with user-facing functionality (not a changelog); wired into **`git-commit-push-summary-body.mdc`** workflow before Xcode preflight.

## 91 - GitHub Pages deploy Node 24 **(pushed)**

**Summary:** GitHub Pages deploy workflow — bump Actions to Node 24; mark §90 pushed.

- **`.github/workflows/deploy-docs.yml`** — `actions/checkout@v6`, `actions/setup-python@v6` (Node 24; clears runner deprecation warning).

## 92 - Next batch **(pushed)**

**Summary:** GitHub Pages deploy fix + dive overview panel trim + trip overlap validation + dive media empty hero prompt.

- **`.github/workflows/deploy-docs.yml`** — split **build** (`mkdocs build` + `upload-pages-artifact@v4`) and **deploy** (`deploy-pages@v4`, `github-pages` environment); drop `mkdocs gh-deploy` (pushed to ignored `gh-pages` branch).
- **`DiveActivityEditableCatalog`** — map tab drops **Dive** section (header + stats box only); tank tab drops **Profile samples (gas)** and **Record**. Test: **`diveActivityEditableCatalog_overviewPanelHidesDiveSummaryAndTankDiagnostics`**.
- **Map stats box edit** — **`ellipsis`** top-trailing on **`DiveActivityMapOverviewStatsBox`** (matches section header edit affordance) opens hidden **`mapDiveSummarySection`** edit sheet. Test: **`diveActivityEditableCatalog_mapStatsBoxEdit_resolvesHiddenDiveSection`**.
- **Home carousel trip chip** — linked dives show trip title beside **#** on the dive capsule in **`LogbookTripGroupAccentPalette`** color. Tests: **`homeMediaHighlightPresentation_buildCandidates_mapsLinkedTripTitleAndAccent`**, **`LogbookTripGroupAccentPresentation.accentColorIndexByTripID`**.
- **`docs/dive-detail.md`** — user guide aligned.
- **Trip overlap + exclusive dive membership** — **`DiveTripDateRange.rangesOverlap`**, **`DiveTripOverlapValidation`**, **`DiveTripFormValues.canSave(existingOwnerTrips:)`** blocks add/edit when calendar days overlap another owner trip; **`TripPlannerFormContent`** footer error; **`DiveTripActivityLinking.link`** unlinks other trips first; **`applyAutoLink`** skips dives already linked elsewhere. Tests: **`diveTripDateRange_detectsOverlappingInclusiveRanges`**, **`diveTripFormValues_rejectsOverlappingOwnerTrips`**, **`diveTripFormValues_allowsEditingTripWithoutSelfOverlap`**, **`diveTripActivityLinking_linkMovesDiveFromPreviousTrip`**, **`diveTripActivityLinking_autoLinkSkipsDivesLinkedToAnotherTrip`**.
- **`docs/trips-and-buddies.md`** — overlap rule + one trip per dive.
- **Dive media empty hero** — **`AnimatedMediaUploadEmptyPrompt`** split into **`MediaUploadEmptyGhostFramesAnimation`** (hero) + **`MediaUploadEmptyPromptTextBlock`** (sheet); ghost frames only in hero (**minimized** / **medium**); copy in sheet at **medium** / **large**; no hero animation at **large**. Tests: **`diveActivityMediaEmptyHeroPresentation_centersGhostFramesInVisibleHeroBand`**, **`diveActivityMediaEmptyHeroPresentation_hidesHeroAnimationAtLargeDetent`**, **`diveActivityMediaEmptyHeroPresentation_showsUploadTextInMediumAndLargeSheet`**, **`diveActivityMediaEmptyHeroPresentation_reusesHomeHighlightTitle`**.

## 93 - Next batch **(pushed)**

**Summary:** Snappy navigation rules + Home/trip/buddy perf pass (off-main aggregates, scoped queries, signposts).

- **`.cursor/rules/swiftui-snappy-navigation.mdc`** — global perf checklist (main-thread UI only, off-main aggregates, fingerprint skips, scoped **`@Query`**, debounced rebuilds, deferred maps); **`AppPerformanceSignpost`** reference.
- **Home foreground perf** — **`scenePhase == .active`** skips full **`HomeOverviewAggregate`** rebuild when carousel is already warm; **`HomeOverviewRebuildScheduler`** debounces query/notification-driven rebuilds (~80 ms). Tests: **`homeReturnNavigationPresentation_skipsForegroundRebuildWhenCarouselReady`**.
- **Home off-main aggregate** — **`HomeOverviewSnapshotSeeding`** + **`HomeOverviewAggregateComputer`**; **`HomeOverviewAggregateBuilder.buildAsync`** snapshots on main, computes in **`Task.detached`**, reattaches **`DiveMediaPhoto`** / sightings from owner **`DiveActivity`** relationships. Tests: **`homeOverviewAggregateComputer_aggregatesOwnerMediaAndSightings`**, **`homeOverviewAggregateComputer_ignoresSightingsOutsideOwnerDives`**.
- **Home scoped queries** — drop global **`@Query`** for all **`DiveMediaPhoto`** / **`SightingInstance`**; media + sightings derive from owner activities; carousel + leaderboard read cached aggregate fields.
- **Dive detail lazy catalog** — **`ViewSingleActivity`** loads **`MarineLife`** in **`.task`** when the Media tab or overview sheet needs tagged-species UI (not on first paint).
- **Trip / buddy push deferral** — **`TripDetailView`** yields before **`rebuildTripDetailContent`**; buddy/trip rebuilds wrapped in **`AppPerformanceSignpost`**. Test: **`appPerformanceSignpost_intervalNamesAreStable`**.
- **Home carousel trip subtitle** — linked trip title uses the same secondary foreground as **#** with a middle dot separator (**`#12 · Bonaire 2026`**). Test: **`homeMediaCarouselDiveLinkChrome_subtitle_joinsDiveNumberAndTripWithMiddleDot`**.
- **Launch speed** — **`AppModelContainer.beginLoadingProductionIfNeeded()`** starts SwiftData I/O in **`GoDiveMVPApp.init`**; **`AccountSession.restoreSession`** restores the local profile immediately and defers Sign in with Apple credential checks + ownership claims to **`AppLaunchSessionValidation`** (offline-first on network failure). **`GoogleMapsBootstrap`** no longer runs in **`didFinishLaunching`** (lazy configure on first **`GMSMapView`** / deferred warm-up). Tests: **`appLaunchSessionRestorePresentation_persistedProfileID_parsesStoredUUID`**, **`appLaunchSessionValidationPolicy_*`**.
- **GitHub Pages acknowledgments** — **`docs/acknowledgments.md`** credits Meshy AI (3D), _Caribbean Reef Life_, OpenDiveMap dive sites, Garmin FIT SDK, FishBase / SeaLifeBase / REEF / Wikimedia / snorkelstj catalog sources, MapKit / Google Maps, Fishial.AI, and UDDF; linked from **`index.md`**, **`field-guide.md`**, **`explore.md`**, **`privacy-and-data.md`**.

## 94 - Marine life catalog + 3D heroes **(pushed)**

**Summary:** Added **Caribbean reef squid** (*Sepioteuthis sepioidea*) to the bundled Field Guide catalog from _Caribbean Reef Life_ (p. 245).

- **`caribbean_reef_life_species_reference.csv`** — epub profile row (INVERTEBRATES / squids).
- **`marine_life_caribbean_staging.csv`** — staging row (`marine-life-caribbean-reef-squid`, SeaLifeBase spec 57414, Loliginidae, 0–20 m, 30 cm max from book).
- **`marine_life_sample.json`** — synced via **`sync_marine_life_staging_to_json.py`** (1305 species); **`feature_model`: `CaribbeanReefSquid`** for the squid row (restored **`FrenchAngelfish`** link on re-sync).
- **`Resources/MarineLife3D/CaribbeanReefSquid.usdz`** — Meshy AI export (crimson squid) for Field Guide 3D hero.
- **`sync_marine_life_staging_to_json.py`** — preserves JSON-only **`feature_model`** on catalog merge.
- **`GoDiveMVPTests`** — **`marineLifeCatalogSeeder_seedsCaribbeanReefSquid`**, **`fieldGuideMarineLifeHeroPresentation_caribbeanReefSquidUsesBundledModel`**.
- **Green sea turtle** + **spotted eagle ray** 3D heroes — **`GreenSeaTurtle.usdz`**, **`SpottedEagleRay.usdz`** (Meshy AI) under **`Resources/MarineLife3D/`**; **`feature_model`** on **`marine-life-green-sea-turtle`** and **`marine-life-whitespotted-eagle-ray`**; seeder + hero presentation tests.

## 95 - Page alignment (blue sheet shell) **(pushed)**

**Summary:** Unified blue sheet shell family — **`BlueSheetPageLayoutBuilder`** + **`BlueSheetPageProportions`** drive identical hero vs blue-sheet proportions for Home tab root and pushed detail pages.

- **`BlueSheetPageLayoutBuilder`** + **`BlueSheetPageProportions`** — single hero/sheet proportion math for tab root and pushed detail; re-exports **`HomeOverviewLayout`** tokens (`panelOverlap`, `heroHeightToWidthRatio`, `heroBottomExtension`, tab bar reserve).
- **`BlueSheetPageShell`** — shared **`GeometryReader`** + **`BlueSheetHeaderPageLayout`** wiring.
- **`BlueSheetDetailPage`** — canonical pushed detail shell with builder slots (`hero`, `heroOverlay`, `panelOverlay`, `pinnedContent`, `panelContent`, `topChrome`).
- **`BlueSheetTabRootPage`** — Home tab root shell; same proportions as detail via **`BlueSheetPageLayoutBuilder`**; **`topChrome`** slot for GoDive header + profile avatar.
- **`LogOverviewView`** — migrated dashboard path onto **`BlueSheetTabRootPage`** (carousel/placeholder hero + lifetime stats panel); empty state uses **`BlueSheetHomeTopChrome`**.
- **`FieldGuideBlueSheetPage`** — updated to **`BlueSheetHeaderPageLayoutBuilder.make(..., mode: .pushedDetail(...))`** (no hand-rolled hero height).
- **`BlueSheetPagePresentation`** — **`tabRoot`** (Home) vs **`pushedDetail`**; config factories **`tabRoot(...)`** / **`pushedDetail(...)`**.
- **`GoDiveMVP/cursor/blue_sheet_detail_customizations.md`** — per-page customization matrix + migration order.
- **`GoDiveMVPTests`** — config/presentation tests, **`blueSheetPageProportions_reexportHomeOverviewLayoutTokens`**, **`blueSheetPageLayoutBuilder_tabRootMatchesPushedHeroHeightWhenViewportAligned`**.
- **Pushed detail migration** — **`ExploreDiveSiteDetailView`**, **`ExploreReferenceSiteDetailView`**, **`FieldGuideMarineLifeDetailView`**, **`ViewDiveBuddyDetails`**, **`TripDetailView`** now use **`BlueSheetDetailPage`** (removed ~300 lines of duplicate shell math per page).
- **Removed `FieldGuideBlueSheetPage`** — retired in favor of **`BlueSheetDetailPage`**; kept **`FieldGuideBrowseSearchChrome`** for category browse lists.
- **Bug fix:** restored **`BlueSheetHeaderPageLayoutContext`** struct (accidentally dropped from **`BlueSheetHeaderPageLayoutContext.swift`** during shell refactor — blocked device build).
- **Unified architecture spec** — **`GoDiveMVP/cursor/blue_sheet_detail_customizations.md`** rewritten: layer model, locked chrome decisions (buddy-only avatar, species/reference edit disabled but scalable, no Trip Share in chrome, reference one-tab pager, detail vs home fade tokens), Phase 1–6 implementation checklist.
- **Phase 1 — top chrome contract** — renamed detail **`backChrome`** → **`topChrome`** on **`BlueSheetDetailPage`** / **`BlueSheetPageShell`** / **`BlueSheetHeaderPageLayout`**. Added **`BlueSheetTopChromePresentation`** (**`homeHeroFade`**, **`detailTopFade`**), **`BlueSheetHomeTopChrome`**, **`BlueSheetDetailTopChrome`**, **`BlueSheetDetailEditAction`**. Home + all pushed detail pages wired through helpers; Trip **Share** removed from pinned title (Edit moved to top chrome); species/reference **Edit** shown but disabled via **`isEditEnabled`**. Removed **`BlueSheetDetailPageBackChrome`**. Tests: **`blueSheetTopChromePresentation_homeHeroUsesLogbookScrimFeather`**, **`blueSheetTopChromePresentation_detailTopUsesListFeather`**.
- **Phase 2 — pinned summary** — **`BlueSheetPinnedSummary`** + **`BlueSheetPinnedSummaryPresentation`** (shared accent / title / subtitle format; optional **`topRow`** + **`leadingAccessory`**). Migrated buddy, trip, species, reference pinned blocks; **`ExploreDiveSiteDetailPinnedTitleView`** composes **`BlueSheetPinnedSummary`** for catalog sites. Trip pinned order: date accent → title. **`BlueSheetDetailPage`** applies shell horizontal inset to **`panelContent`**; removed per-page pager **`.padding(.horizontal)`** on species, dive site, reference. Tests: **`blueSheetPinnedSummaryPresentation_rowSpacingUsesTheme`**, **`blueSheetDetailPagePinnedSummaryPresentation_shellHorizontalPaddingMatchesPagerInset`**.
- **Phase 3 — hero band** — **`BlueSheetDetailHeroBandFill`** (fill without duplicate **`heroHeight`**), **`BlueSheetDetailHeroPlaceholder`** / **`BlueSheetDetailHeroLoadingBand`**, **`BlueSheetDetailHeroPresentation`**. **`FieldGuideSpeciesDetailHeroBand`** unifies tagged media / catalog / map strategies. Species + reference drop inner height frames; trip always **`showsHero: true`** (airplane placeholder when empty) via unified **`PushedDetailHeroHeaderView`** path. **`PushedDetailHeroHeaderView`** uses shared placeholder helpers. Tests: **`blueSheetDetailHeroPresentation_placeholderTokens`**, **`blueSheetDetailPageConfiguration_pushedDetailDefaultsToShowsHero`**.
- **Phase 4 — detail pager** — **`BlueSheetDetailPager`** + **`BlueSheetDetailPagerPageLayout`** / **`BlueSheetDetailPagerPresentation`** (shared **`TabView`** page chrome, lazy mount, static vs scroll insets). Buddy, trip, species, dive site content pagers wired through wrapper; **`ExploreReferenceSiteDetailContentPager`** one-tab **Details** pager replaces scroll-only body. Tests: **`blueSheetDetailPagerPresentation_tripScrollInsetExtraUsesThemeSpacing`**, **`exploreReferenceSiteDetailContentPagerPresentation_singleTab`**.
- **Phase 5 — Home alignment** — **`BlueSheetPageShellLayoutResolveModifier`** fires **`onLayoutResolved`** on every settled layout change (not only **`onAppear`**). **`HomeOverviewLayoutAnchor.publishHomeTabRootLayout`** centralizes Home anchor snapshots; duplicate publishes skipped. **`LogOverviewView`** republishes when hero/viewport/seam inputs change (leaderboard toggle, header clearance, frozen viewport). Tests: **`blueSheetPageLayoutBuilder_pushedHeroUsesPublishedHomeAnchor`**, **`homeOverviewLayoutAnchor_publishHomeTabRootLayout_copiesSettledLayout`**, **`homeOverviewLayoutAnchor_publish_skipsIdenticalSnapshot`**.
- **Home seam vs detail** — **`HomeTabRootLayoutPresentation`**: bottom-up hero height from detail **`screenBot`** reference (**`sheetSeamYFromScreenBottom`** + **`rootTabBarLayoutHeight`** tab-content adjustment); Home stack uses tab-content band only. Home hero seam math now uses **`AppScrollUnderHeaderListLayout.resolvedSafeAreaTop`** (TabView **`GeometryReader`** often reports **0** top inset) so hero height + anchor match detail. Tests: **`homeTabRootLayoutPresentation_zeroGeometrySafeTop_matchesDetailHeroHeight`**, **`homeTabRootLayoutPresentation_screenBotMatchesDetailReference`**, **`blueSheetPageLayoutBuilder_tabRootStackUsesTabContentBandOnly`**.
- **Home layout rebuild (detail-style)** — dropped bottom-up seam inversion; Home tab root now uses the same **`BlueSheetPageLayoutBuilder`** path as pushed detail on **virtual full-screen geometry** (tab content + **49pt** tab bar). **`BlueSheetTabRootPage`** mirrors detail shell structure (embedded top chrome, pushed layout floors) without **`AppHeaderlessPage`** — **`LogOverviewView`** page background applies to empty state only so a duplicate ocean gradient no longer bleeds above **`HomeLifetimeStatsPanel`**. Tests: **`homeTabRootLayoutPresentation_stackMatchesDetailFullScreenHeight`**, **`blueSheetPageLayoutBuilder_tabRootStackUsesDetailFullScreenFrame`**, **`homeTabRootLayoutPresentation_panelBottomInsetIncludesTabBar`**.
- **Home hero extension** — **`heroBottomExtension`** **162 → 202 pt** so featured media extends lower behind the stats sheet (restores pre-shrink overlap bleed; shared with pushed buddy/trip heroes via **`BlueSheetPageProportions`**).
- **Home carousel fill** — **`HomeMediaCarouselLayout.carouselContentHeight`** extends slide height by **`topSafeAreaInset`** when **`PushedHeroBand`** owns safe-area bleed (**`appliesTopSafeAreaBleed: false`**), eliminating the black gap above the stats panel without moving the sheet seam. Home carousel + empty placeholder wrapped in **`BlueSheetDetailHeroBandFill`**.
- **Home seam debug off** — **`HomeSheetContainerDebug.usesPinkBackground`** **`false`**; stats panel restored to standard blue sheet fill.
- **Home content inset tune** — dive link / carousel chrome **`slideChromeBottomInset`** lowered into the overlap band (**`panelOverlap - md`**); stats panel in-panel top padding **32 → 16 pt** and bottom content padding **8 → 24 pt** (UI-only — hero band + sheet seam unchanged).
- **Detail pager inset** — **`BlueSheetDetailPagePinnedSummaryPresentation.horizontalPadding`** **16 → 24 pt** (**`AppTheme.Spacing.lg`**, matches logbook / catalog lists); removed duplicate **`md`** horizontal padding from trip pager sections. **`HomeLifetimeStatsPanel.appliesHorizontalContentPadding`** is **tab-root only** so detail pages are not double-inset (**panel lg + shell lg**); **`BlueSheetDetailPage`** applies one **`lg`** inset on the pinned + pager **`VStack`**.
- **Layout reference doc** — **`GoDiveMVP/cursor/blue_sheet_home_vs_detail_layout.md`** (Home vs detail measurement tokens, seam vs content-only tweaks, replication guide).
- **Equipment detail migration** — **`ViewEquipmentDetails`** on **`BlueSheetDetailPage`**: **`EquipmentDetailHeroBand`** (photo / placeholder), **`BlueSheetPinnedSummary`**, **`EquipmentDetailContentPager`** (one-tab **Details**), **`BlueSheetDetailTopChrome`** + Edit sheet; removed legacy **`AppHeader`** / hand-rolled hero height / full-page scroll. **`EquipmentDetailMetadataView`** holds card sections; shell **`lg`** horizontal inset only. Removed unused **`EquipmentItemPresentation.detailHeroBaseHeight`**. Tests: **`equipmentDetailContentPagerPresentation_singleTab`**.

## 96 - Unified search v2 **(pushed)**

**Summary:** Single app-wide search via native **`Tab(role: .search)`** morph tab; removed inline search bars from Logbook, Field Guide, and Explore.

- **`GlobalSearchView`** + **`GlobalSearchPresentation`** — indexes dives, dive sites, marine life, buddies, trips, equipment, and certifications; sectioned results with navigation to existing detail flows.
- **`ContentView`** — **`Tab(value: .search, role: .search)`** only; **`.searchable`** moved to **`GlobalSearchView`**’s **`NavigationStack`** (iOS 26 morph requirement). Root stack must not use **`navigationInteractivePopGestureForHiddenNavBar()`** (breaks morph like UIKit introspection).
- **`GlobalSearchView`** — full-bleed layout without **`AppHeaderlessPage`**; lightweight idle shell opens instantly (**`isStackSearchPresented`** defaults **true**, SwiftData index + bubble motion deferred until after the tab morph); native **`Tab(role: .search)`** morph presents the field without programmatic focus; results back keeps tab-bar search active (no **`dismissSearch()`**). **`.searchable`** attaches only at stack root (**`path`** empty) so pushed detail pages match tab-stack safe area; **`dismissSearch()`** on result push clears navigation search chrome; query + scope tokens are preserved across detail push/pop so back from a result returns to the results list (not the idle category grid); popping back to results re-presents the tab-bar search field when query/tokens are still active; stack-level interactive pop only while pushed (not at root — morph).
- **`ProfileBubbleBackgroundLayer`** — shared **`WaterBubbleBackground`** + **`profileBubbleScrim`** stack extracted from **`ProfileView`**.
- Removed inline **`CatalogSearchField`** chrome from **Logbook**, **Field Guide** (hub + category/subcategory browse), and **Explore**; toolbar rows retain trip/add/map actions only.
- **`LogbookToolbarChrome`**, simplified **`ExploreTopChrome`** / **`FieldGuideTopChrome`** / **`FieldGuideBrowseToolbarChrome`**.
- **Search idle tiles** — centered **Search** title below the status bar; **2×4** flex grid filling the viewport down to the morphed tab search field; extra bottom spacing when the keyboard is open.
- **Search results** — compact minimalist rows (~**60%** prior height; **30** pt artwork) with a single full-width top hairline per row (content evenly padded between lines; system list separators hidden) on transparent **`List`** rows over **`screenBackgroundGradient`** (generic category browse keeps **`ProfileBubbleBackgroundLayer`**); section headers (**Buddies**, **Dives**, etc.) right-aligned, transparent, **title3-scale** labels with compact vertical padding; **`contentMargins(.top)`** on the sectioned list uses back-chrome height only (status-bar inset is not double-counted) so the first section starts higher while sticky pinning stays on the back row; **`LogbookTopChromeScrim`** stacks above scrolling rows (below back button) so the top fade persists while sticky section headers hand off; interactive slide-back uses twin-layer offsets (results panel + gradient slide trailing; generic bubble browse slides in from leading) so the blue background participates in the dismiss animation; interactive slide-back locks list scroll once the dismiss drag begins and blocks row taps until the panel settles; **`SecondaryDestinationBackButton`** + interactive leading-edge slide-back (spring animation) return to category tiles; multi-category hits ordered buddies → sites → tags → trips → marine life → gear → certs → dives.
- Tests: **`globalSearchPresentation_*`**, **`globalSearchPresentation_applyReturnToCategoryBrowse_clearsQueryAndTokens`**, **`globalSearchResultsDismissPresentation_*`**, **`globalSearchResultsChromePresentation_*`**, **`globalSearchResultsSectionHeaderPresentation_*`**, **`globalSearchPushedDestinationPresentation_*`**, **`globalSearchPresentation_contextTokenScopesBrowseResultsWithoutQuery`**, **`globalSearchPresentation_contextTokenAndQueryFilterWithinScope`**, **`globalSearchPresentation_resultSections_followDisplayPriorityOrder`**, **`globalSearchResultListRowLayout_usesFullWidthHairlineAndCompactArtwork`**, **`globalSearchPresentation_contextTokenTileLayout_matchesHomeStatsGridSpacing`**, updated **`logbookListSurfaceEquatableInputs_scrollNonceChangeIsNotEqual`**.
- **Search tab keyboard** — removed manual **`resignFirstResponder`** / **`.searchFocused`** / tab-launch dismiss retries; **`Tab(role: .search)`** + **`isPresented`** morph handles the search field natively (keyboard only when the user taps the field).
- **`docs/search.md`** — user guide for the unified Search tab; updated Logbook / Field Guide / Explore pages.

## 97 - Home stats layout, chrome polish, Explore scope **(pushed)**

**Summary:** Explore **My Sites / All Sites** scope toggle moved from above the tab bar into the top chrome row.

- **`ExploreTopChrome`** — **`ExploreSiteScopeToggle`** centered in the top chrome row (map/list **leading**, **+** **trailing**); removed trailing spacer gap after the slider.
- **`ExploreView`** — removed bottom **`safeAreaInset`** for scope chrome and the extra list bottom inset that reserved tab-bar space.
- **`docs/explore.md`** — scope toggle placement updated in the user guide.
- **`GlobalSearchSiteIndexSeeding`** — Search tab **Sites** index now matches **Explore → All Sites** (OpenDiveMap reference rows + SwiftData catalog, including logbook-only supplemental sites). Reference-only hits open **`ExploreReferenceSiteDetailView`**; catalog hits unchanged.
- Tests: **`globalSearchSiteIndexSeeding_indexesReferenceCatalogAndSupplementalSites`**; updated **`DiveSiteIndexEntry`** fixtures.
- **`activity_upload.swift`** — Add activity import cards: **Garmin** (`.fit`) + Garmin Connect copy; **MacDive / Universal** (`.uddf`) + bulk compatible-source copy.
- **`docs/import.md`**, **`docs/logbook.md`** — matching import option labels.
- **Logbook title chrome** — inline **Activity Log** row (fixed **44** pt side columns + flexible title); scroll-offset collapse; **`LogbookTopChromeScrim`** feather **128** pt.
- **Collapsible inline title chrome** — shared **`CollapsibleInlineTitleHeader`** + **`AppPage(collapsibleInlineTitleHeader:)`** on **Certifications**, **Equipment Locker**, **Dive Buddies**, **Trips**, **My tagged media**, and **Field Guide** hub (Logbook-style white **`.largeTitle`**, scroll collapse, extended scrim).
- **Header chrome icons** — **`AppTheme.Colors.headerChromeIconForeground`** (white) on Liquid Glass top-bar actions (**trip**, **+**, back, map/list, settings, search dismiss) via **`appHeaderChromeIconForeground()`**.
- **Home carousel overlay chips** — fish / buddy icon buttons use **56×56** pt tap targets (**`taggedOverlayIconTapDimension`**) while keeping the glass circle at slide chrome height.
- Tests: **`logbookChromePresentation_titleAndScrimHeight`**.
- **`docs/logbook.md`** — Activity Log collapsible header.
- **GoDive wordmark typography** — **`AppTheme.Typography.headerBrandTitle`** (**.largeTitle**) everywhere the brand title appears: **`AppHeader`** (no shrink), **`AppLaunchOverlay`**, **`LaunchScreen.storyboard`**, **`SeedingLaunchOverlay`**, **`SignInView`**; **`AppLaunchLayout`** title metrics derived from UIKit **`.largeTitle`** bold.
- Tests: updated **`appLaunchLayout_matchesStoryboardConstraints`** for large-title launch metrics.
- **Home fish overlay alignment** — marine-life overlay frame matches **`carouselContentHeight`** (same bounds as slide media inside **`PushedHeroBand`**); species pager vertically centered in the visible hero band (below header, above bottom slide chrome); scrim clipped to media frame.
- Tests: **`homeMediaCarouselPresentation_marineLifeCarouselOverlaySizing_isCompact`** — overlay height tracks carousel content height.
- **Home profile avatar** — **`BlueSheetTopChromePresentation.homeProfileAvatarDiameter`** (**48 × 1.2** pt); **`AppHeaderBrandRowMetrics`** keeps avatar vertically centered with **GoDive** **`.largeTitle`** wordmark.
- Tests: **`blueSheetTopChromePresentation_homeProfileAvatarDiameter_isTwentyPercentLarger`**, **`appHeaderBrandRowMetrics_wordmarkLineHeight_tracksLargeTitle`**.
- **Home lifetime stats panel** — smaller highlight tiles (**82** pt) and **Top buddies** tile (**120** pt, **44** pt avatars); more top/bottom panel inset (**24** / **20** pt); synced **`HomeLifetimeStatsTilesLayout`** height estimates.
- Tests: updated **`homeLifetimeStatsLayout_*`**, **`homeBuddyLeaderboardLayout_*`**, **`homeLifetimeStatsPanelLayout_*`**.
- **Blue sheet overlap (+10%)** — **`HomeOverviewLayout.blueSheetPanelScale`** (**1.10**) raises **`panelOverlap`** (**148 → 163** pt) and **`heroBottomExtension`** (**202 → 222** pt) on Home and all **`BlueSheetPageShell`** detail pages (trip, buddy, equipment, dive site, species).
- **Blue sheet overlap (+15% more)** — scale **×1.265** (**1.10 × 1.15**); **`panelOverlap`** **187** pt (visual overlap over hero).
- **Blue sheet height fix** — **`blueSheetPanelScale`** now scales **`minimumStatsBandHeight`** (reserved stats band in **`HomeOverviewLayout.metrics`**) so the sheet is actually taller on viewport-limited phones; scaling **`panelOverlap`** alone did not change band height when the hero was capped. Home + all **`BlueSheetPageShell`** detail pages.
- **Home tab-bar clearance (UIKit)** — measured **`UITabBar`** top drives **`panelBottomSafeAreaInset`**; tile stack centered vertically between sheet seam and tab-bar top (**`resolvedVerticalEdgeInsets`** splits slack evenly).
- **Home stats layout guides** — temporary debug bands (**`HomeSheetContainerDebug.showsLayoutGuides`**, now **`false`**) validated buddy-bottom ↔ tab-top alignment on device.
- **Home stats flexible fill** — fixed **16** pt tile gaps; **Top buddies** full-width below the 2×2 grid.
- Tests: **`homeLifetimeStatsTilesLayout_resolvedVerticalEdgeInsets_centersBetweenSeamAndTabTop`**, **`homeLifetimeStatsTilesLayout_resolvedVerticalEdgeInset_splitsSlackEvenly`**, **`homeLifetimeStatsTilesLayout_resolvedFlexibleSectionHeights_distributesExtraByBaselineWeights`**, **`rootTabBarLayoutMeasurement_estimatedClearanceAboveTabBar`**, **`homeTabRootLayoutPresentation_panelBottomInsetPrefersMeasuredTabBar`**.
- Tests: **`homeOverviewLayout_blueSheetPanelScale_increasesOverlapAndHeroBleed`**, updated **`blueSheetPageProportions_reexportHomeOverviewLayoutTokens`**.

- **Search site index parity** — **`docs/search.md`**, **`docs/explore.md`**, **`docs/getting-started.md`**.
- **Collapsible inline titles** — **`docs/field-guide.md`**, **`docs/trips-and-buddies.md`** (Trips, Buddies, Equipment, Certifications, Tagged media).
- **Home stats panel** — **`docs/home.md`** (Top buddies placement).

## 98 - Next batch **(pushed)**

**Summary:** Search results reveal instantly; slide animation only on dismiss back to category browse.

- **`GlobalSearchResultsDismissPresentation.initialResultsPanelDragOffsetOnReveal`** — forward reveal uses offset **0** (no trailing slide-in).
- **`GlobalSearchView.syncResultsPanelVisibility`** — removed spring animation when search activates; dismiss slide unchanged.
- **`docs/search.md`** — instant forward transition vs slide-back dismiss.
- Tests: **`globalSearchResultsDismissPresentation_revealUsesInstantOffsetNotSlideIn`**, **`globalSearchResultsDismissPresentation_blocksResultsRowSelectionWhilePanelIsOffset`**.
- **Search swipe-back row lock** — **`blocksResultsRowSelection`** disables result rows while dismiss drag is active or the panel offset is non-zero; drag lock held through cancel/commit settle.
- **Search result push keyboard** — **`dismissSearch()`** + **`SoftwareKeyboardDismissal`** run before **`path.append`** while stack **`.searchable`** is still attached (fixes keyboard staying up on result tap).
- **Home fish overlay layout** — single draggable **PANEL TOP** line (Y + Δ); page dots follow while guides are on; double-tap to reset.
- **Home fish overlay seam guide visibility** — draggable **PANEL TOP** line moved to **`heroOverlay`** (above blue stats panel); pink full-width line + **`HomeMarineLifeOverlayVisibleKey`**; **`BlueSheetHeaderPageLayout`** raises **`heroOverlay`** **`zIndex`**.
- **Home fish overlay seam settled** — production seam offset **Δ −25** baked into **`marineLifeCarouselOverlaySheetSeamYOffsetFromTemplate`** (page dots + species stack); layout guides off.
- **Home fish overlay page dots** — anchored above tuned sheet seam with **8 pt** clearance (**`marineLifeCarouselOverlayPageIndicatorTopInsetFromTop`**).
- **Home fish overlay layout guides (on)** — pink tuned **PANEL TOP** line in **`heroOverlay`**; cyan **DOTS** row draggable with Y + Δ; double-tap dots to reset.
- **Home fish overlay page dots offset** — production dots down **Δ +50** from seam-spaced default (**`marineLifeCarouselOverlayPageIndicatorTopOffsetFromSeamSpacing`**).
- **Home fish overlay chrome** — **×** vertically centered with Home **`AppHeader`** profile row (status bar + brand-row math); species name top-aligned with feature image top; page dots unchanged.
- **Home fish overlay close guide** — orange **CLOSE** line draggable with Y + Δ while layout guides are on; double-tap to reset; species image + name follow **×** top; label + line share the **×** row.
- **Home fish overlay close settled** — production **×** down **Δ +75** from header-aligned default (**`marineLifeCarouselOverlayCloseTopOffsetFromHeaderAlignment`**); species image + name follow; layout guides off.
- **Home fish overlay species layout** — feature image **50% wider** (**144–204 pt**, **48%** of preview width); common name **56 pt** below image top (**`marineLifeCarouselOverlaySpeciesNameTopOffsetFromFeatureImageTop`**).
- **Home fish overlay species copy** — italic **`aboutText`** (fallback **`distinctiveFeatures`**) under common name; line limit fills space above page dots; tap opens Field Guide overview.
- **Home fish overlay close alignment** — **×** leading edge matches feature image (**`marineLifeCarouselOverlaySpeciesContentLeadingInset`**).
- **Home fish overlay page dots** — nudged **15 pt** lower (**`marineLifeCarouselOverlayPageIndicatorTopOffsetFromSeamSpacing`** **50 → 65**).
- **Home fish overlay feature image** — column bottom lifted **24 pt** (**`marineLifeCarouselOverlayFeatureImageColumnBottomLift`**).
- **Home fish overlay debug cleanup** — removed layout-tuning guides (**PANEL TOP**, **DOTS**, **CLOSE**), drag overrides, and **`HomeMarineLifeOverlayVisibleKey`**.

## 99 - Next batch **(pushed)**

**Summary:** Marine life image review UI — Tinder-style one-at-a-time flow with accept vs edit.

- **`marine_life_image_review.html`** — card stack UI: one species, large 4:3 photo, **Accept** (green check) or **Edit** (paste URL → save + bundle). Swipe right/left; keyboard **A**/**→** and **E**/**←**. Default queue **Needs review**.
- **`serve_marine_life_image_review.py`** — **`POST /api/species/{uuid}/approve`** clears **`imageNeedsReview`** without changing the URL.
- **`marine_life_image_review_store.py`** — **`apply_species_image_approval`**.
- **`MARINE_LIFE_CARIBBEAN_WORKFLOW.md`** — updated review UI docs.
- Tests: **`test_apply_species_image_approval_clears_review_flag`**.

**Summary:** reefguide.org image fetch script for Caribbean staging (permission required before ship).

- **`reefguide_image_utils.py`** — parse reefguide scientific-name index + species galleries; resolve full JPEG URLs.
- **`fetch_marine_life_images_reefguide.py`** — stage URLs on **`marine_life_caribbean_staging.csv`** with **`imageNeedsReview=yes`**; optional **`--bundle`**.
- **`MARINE_LIFE_CARIBBEAN_WORKFLOW.md`** — reefguide fetch section + licensing note.
- Tests: **`test_reefguide_image_utils.py`**.

**Summary:** Fix reefguide bundle downloads — URLs were correct; Pillow arch + clearer errors.

- **`reefguide_image_utils.py`** — derive direct **`/pix/{file}.jpg`** URLs from gallery thumbs (cache v2); **`--only-reefguide`** refresh flag on fetch script.
- **`marine_life_bundle_image_utils.py`** — reefguide **Referer** header; stop aliasing **`UnidentifiedImageError`** to **`Exception`** (misleading “not an image file” when Pillow missing).
- Re-ran **`fetch_marine_life_images_reefguide.py --only-reefguide`** + **`download_marine_life_images.py`** for 496 reefguide rows.

**Summary:** WoRMS photogallery fetch for species still missing hero images.

- **`worms_image_utils.py`** — AphiaID lookup, taxon gallery parse, direct **`images.marinespecies.org`** JPEG URLs + license metadata.
- **`fetch_marine_life_images_worms.py`** — stage gaps on **`marine_life_caribbean_staging.csv`**; default includes NC gallery photos flagged for review; **`--shippable-only`** for CC0/CC BY only.
- **`MARINE_LIFE_CARIBBEAN_WORKFLOW.md`** — WoRMS fetch section.
- Tests: **`test_worms_image_utils.py`**.

**Summary:** Marine life header media fill — Home fish overlay + Field Guide species hero.

- **`FieldGuideMarineLifeCatalogImage`** — **`.detailHero`** fills **`BlueSheetDetailHeroBandFill`**; single-layer placeholder (no fish icon bleeding through letterbox); bundled JPEG load falls back to **`Data`** when **`UIImage(contentsOfFile:)`** fails.
- **`FieldGuideSpeciesDetailHeroBand`** / **`FieldGuideMarineLifeRealityHeroView`** — catalog + 3D heroes expand to the pushed hero band slot.
- **Home fish overlay** — feature column spans to hero band floor; **aspect-fill** in the tall narrow column (fit was a tiny bottom strip that looked like “no image”).
- Tests: **`fieldGuideMarineLifeImageLayout_detailHeroFillsHeroBandSlot`**, updated overlay column-height expectations.

**Summary:** Field Guide category + subcategory browse — collapsible inline titles.

- **`FieldGuideBrowseCollapsibleHeader`** + **`FieldGuideCatalogBrowseListPage`** — category/subcategory pages use **`CollapsibleInlineTitleHeader`** (back + **+**, scroll compaction, list scrim) like Logbook hub and Profile library lists.
- **`FieldGuideCategoryDetailCopy`** / **`FieldGuideSubcategoryDetailCopy`** — description/hint only; title moves to chrome.
- **`CollapsibleInlineTitleHeader`** — shared title shrink-to-fit (**`minimumTitleScaleFactor`**); Field Guide browse uses tighter **`browseTitleMinimumScaleFactor`** when back + **+** flank the title.
- **`FieldGuideNavigationPresentation`** — root tab bar stays visible on category + subcategory browse; still hides on species / dive / site detail pushes.
- **`FieldGuideMarineLifeCatalogImage`** — species detail **`.detailHero`** defaults to width-fit (**`.fit`**) on **`screenBackgroundGradient`** (no center crop); mosaic tiles still use **4:3** fill.
- **Species detail catalog photo** — bottom-aligned with **36 pt** underlap under the blue-sheet seam (**`catalogPhotoSeamUnderlap`**); 3D / tagged video / map heroes unchanged.
- Tests: **`logbookAndFieldGuideCollapsibleHeaderTitles`** browse title accessibility IDs; **`fieldGuideMarineLifeImageLayout_detailHeroFitsWidthWithoutCropping`**.

**Summary:** Home fish overlay — shorter feature image column.

- **`marineLifeCarouselOverlayFeatureImageColumnBottomLift`** **126 pt** — raises the feature image bottom edge only; close, text, and page dots unchanged.

**Summary:** Field Guide subcategory tiles — species photo thumbnails.

- **`FieldGuideCatalogIndex.representativeSpecies`** — picks the first alphabetical species in a subcategory (or whole category for **All species**) that has a bundled/remote photo.
- **`FieldGuideSubcategoryRowThumbnail`** — **44×44** catalog crop on subcategory list rows; taxonomy SF Symbol placeholder when no photo exists.
- Tests: **`fieldGuideCatalogIndex_representativeSpecies_*`**.

**Summary:** Field Guide hub category tiles — two-line subtitle block.

- **`FieldGuideHubTileLayout.subtitleTwoLineMinHeight`** — hub tile taglines use **`.lineLimit(2)`** in a fixed two-line **`.caption`** frame (blank second line when copy is short); **`tileHeight`** **96 pt** to fit the taller text stack.

**Summary:** Fishial video scrub — frame-accurate preview.

- **`FishialVideoScrubPlayerView`** — scrub preview uses **`AVAssetImageGenerator`** with zero seek tolerance (replaces keyframe-snapped **`AVPlayer`** seeks that jumped ~1 s); timestamp shows tenths (**`formattedScrubTimestamp`**).
- Tests: **`formattedScrubTimestamp`**, **`videoScrubPreviewMaxEdge`**.

**Summary:** Home fish overlay + species catalog hero — device-tuned layout settled.

- **Home fish overlay** — **`marineLifeCarouselOverlayFeatureImageColumnTopCrop`** **103**; **`marineLifeCarouselOverlayFeatureImageColumnVerticalOffset`** **−83**; **`marineLifeCarouselOverlaySpeciesNameTopOffsetFromFeatureImageTop`** **21** (was **56**).
- **Field Guide species catalog hero** — **`catalogPhotoVerticalOffset`** **−206**.
- **Layout debug removed** — deleted temporary drag handles, HUD, and debug types after baking device-tuned tokens.
- Tests updated for settled tokens + column layout helper.

## 100 - Home leaderboards, tag detail, and blue-sheet header spacing **(pushed)**

**Summary:** Home lifetime stat leaderboards — top-ten podium layout.

- **`HomeLifetimeStatsLeaderboardPresentation`** — limit **10** (was 5); **`podiumLimit`** **3**; page titles **Top 10 …**; **`divePodiumMetricLabel`** / **`divePodiumTitle`** for podium copy.
- **`HomeLifetimeStatsLeaderboardLayout`** — classic podium slot order (**2 · 1 · 3**), tiered pedestal heights, medal/trophy SF Symbols.
- **`HomeLifetimeStatsLeaderboardPodiumSection`** — top-three podium (trophy + medals, colored pedestals, category icons/thumbnails); ranks **4–10** as numbered list rows below.
- **`DiveActivityBuddiesOverviewSection`** — map-tab buddy avatars push **`ViewDiveBuddyDetails`** when the tag links a roster buddy (self row stays static); **`DiveActivityBuddiesOverviewPresentation.shouldOpenBuddyDetail`**. Test: **`diveActivityBuddiesOverviewPresentation_shouldOpenBuddyDetail`**.
- **`ActivityTagDetailView`** — blue-sheet tag detail (**`PushedDetailHeroHeaderView`** media/map toggle, **`ActivityTagDetailContentSnapshotBuilder`**, five-page pager: stats → activities → marine life → buddies → media — reuses trip sections); map-tab tag chips + Search tag results push here. **`DiveActivityTagsSectionView`** chips use **`NavigationLink`**. Tests: **`activityTagDetailContentPagerPresentation_pagesMatchTripStartedOrder`**, **`activityTagDetailPresentation_ordersTaggedDivesNewestFirst`**.
- **Search → Tags** — category browse and tag hits list **tag names** (with dive count subtitle), not individual dives; tap opens **`ActivityTagDetailView`** (removed **`GlobalSearchTaggedDivesView`** dive-only list). Test: **`globalSearchPresentation_tagsScopedBrowse_listsTagNamesNotDives`**.
- **`ActivityTagDetailView`** pinned header — one-line **`tag.fill` · name · dive count** (count trailing). Test: **`activityTagDetailPresentation_headerUsesTagIcon`**.
- **Blue-sheet pinned header spacing** — **`BlueSheetDetailPagePinnedSummaryPresentation`**: seam → pinned **md**, pinned rows **sm**, pinned → pager **md**; **`BlueSheetPinnedSummaryPresentation.rowSpacing`** aliases shell token; removed buddy **`extraBottomPadding`**. Tests: **`blueSheetDetailPagePinnedSummaryPresentation_usesThemeSpacing`**, **`blueSheetPinnedSummaryPresentation_rowSpacingUsesTheme`**.
- **`HomeLifetimeStatsLeaderboardView`** — splits podium vs list; **`HomeLifetimeStatsLeaderboardRankBadge`** on list rows; species list rows (**4–10**) stack common name (one line) + blue sighting count on the second line.
- **`HomeOverviewSections`** — stat tile accessibility hint **Opens top ten list**.
- Tests: **`homeLifetimeStatsLeaderboardPresentation_rankedDiveIDs_limitsToTenAndSorts`**, **`homeLifetimeStatsLeaderboardLayout_podiumSlots_ordersClassicPodium`**, **`homeLifetimeStatsLeaderboardLayout_pedestalHeights_stepDownFromFirst`**, **`homeLifetimeStatsLeaderboardPresentation_divePodiumMetricLabel_formatsDepthAndDuration`**; updated page-title test.
- **`docs/home.md`** — top-ten + podium copy.

## 101 - Next batch **(pushed)**

**Summary:** Logged-out onboarding — activity picker, personalized feature slides, sign-in celebration, new-account profile setup.

- **`LoggedOutOnboardingWelcomeView`** — welcome **GoDive** uses **`GoDiveBrandWordmarkText`** (same gradient as **`AppHeader`**); **Show me around** uses Liquid Glass (**`.glass`** capsule).
- **`LoggedOutOnboardingView`** — sign-up / **Get started** slide uses **`LoggedOutMarketingChrome`** bubbles only (removed opaque full-page surface overlay).
- **`UserOnboardingActivitySelection`** + **`UserProfile`** **`doesScubaDiving`** / **`doesFreeDiving`** / **`doesSnorkeling`** — pending UserDefaults → applied at sign-in via **`UserProfileStore.applyActivitySelection`**.
- **`AppLoggedOutOnboardingPresentation`** — logged-out users always see onboarding on app open (no persisted skip); UI tests still use **`SignInView`**.
- **`PostSignUpProfileSetupView`** — new-account wizard after Sign in with Apple: profile photo → DAN + certification (scuba/free diving only, skippable) → profile preview (photo, name, DAN, cert, interests) → **`SignInCelebrationView`** bubble burst → Home; permissions after celebration. Certification step **`Form`** fills the space between the step header and **Continue**.
- **`PostSignUpProfileSetupPresentation`** — step list + dive-only gating; preview step copy **Welcome** / **Let's Dive In**; UI tests skip the wizard.
- **`SignInCelebrationView`** — after profile setup: **GoDive** logo + **`GoDiveBrandWordmarkText`**, standard bubbles ramping **1× → 2×** rise speed over **2 s**, semi-random haptic burst while bubbles animate (**`SignInCelebrationPresentation`** haptic tokens; skipped under UI tests), then Home slides up from the bottom; new-account permissions deferred until after celebration.
- **`OnboardingLogEveryDiveDemoView`** — scripted logbook scroll → dive open → map / tank / media tab micro-demo on **Log every dive** slide (**`OnboardingLogEveryDiveDemoFixtures`**). Logbook + media thumbnails use bundled Field Guide species photos (French angelfish, stoplight parrotfish, green sea turtle) instead of fish SF Symbol placeholders.
- **`OnboardingExploreSitesDemoView`** — scripted Caribbean map zoom / pan → Blue Hole pin callout → site detail micro-demo on **Explore sites across the world** slide (**`OnboardingExploreSitesDemoFixtures`**, **`OnboardingExploreSitesMapRepresentable`**). Fixed invalid fixture UUIDs that crashed the Explore onboarding slide; onboarding map pins use standard red markers; no top map fade scrim in the phone frame.
- **`OnboardingShareWithFriendsDemoView`** — scripted **Belize 2026** trip detail pager (stats → sites → buddies) → **Share** → full-frame **`TripShareCardView`** preview on **Share experiences with your friends** slide (**`OnboardingShareWithFriendsDemoFixtures`**; bundled buddy avatars). Taller trip hero header (lower blue-sheet seam), larger buddy avatars, share card fills the phone frame.
- **`OnboardingMonitorEquipmentDemoView`** — scripted **Equipment Locker** list → **Garmin Mk3i** dive computer detail (bundled Garmin product photo hero) → scroll to recurring **Service** notes on **Monitor your equipment** slide (**`OnboardingMonitorEquipmentDemoFixtures`**).
- **`OnboardingMarineSpeciesDemoView`** — scripted **Field Guide** category hub → **Fishes** → **Angelfishes** → **French Angelfish** species detail on **Learn from thousands of marine species** slide (**`OnboardingMarineSpeciesDemoFixtures`**; bundled catalog photo).
- **`SignInWithAppleSection`** + **`LoggedOutMarketingChrome`** — shared sign-in + bubble chrome.
- Tests: **`appLoggedOutOnboardingPresentation_featurePages_filterByActivitySelection`**, **`userOnboardingActivitySelection_pendingRoundTrip`**, **`signInCelebrationPresentation_skipsUnderUITest`**, **`postSignUpProfileSetupPresentation_*`**, **`onboardingMonitorEquipmentDemoFixtures_supportMicroDemo`**, **`onboardingMarineSpeciesDemoFixtures_supportMicroDemo`**.
- **`docs/getting-started.md`** — full pre-sign-in flow + new-account profile setup.

**Summary:** Home empty logbook — same blue-sheet layout, blank stat tiles, animated logging prompt.

- **`LogOverviewView`** — always uses **`BlueSheetTabRootPage`** (removed separate empty-state placeholder); zero dives still show hero + stats panel. Empty hero uses the same header fade + seam math as the media carousel (**`HomeTabRootLayoutPresentation`** / **`HomeMediaCarouselHeaderGradient`**).
- **`HomeMediaCarouselEmptyPlaceholder`** — matches populated carousel shell (header gradient, slide height); soft gradient hero fill + ghost-frame animation; compact **Log Your First Dive** Liquid Glass capsule (text-width, white label, **44 pt** height) lifted closer to the animation (**`ctaBottomLift` 96**); dives-without-media headline is **Add Media to your Dives** (not tappable). Ghost frames sit under the header (**`contentDownshift` 48**).
- **`LogbookStoredEmptyState`** / **`LogYourFirstDiveGlassButtonLabel`** — same compact text-width Liquid Glass capsule as Home (**`logYourFirstDiveGlassButtonChrome`**), height **`AppTheme.Layout.glassChromeControlHeight`** (**44 pt**) to match toolbar / search glass controls.
- **`ExploreSiteScopePresentation.defaultScope`** — empty logbook defaults Explore to **All Sites**; any logged activities default to **My Sites** (**`ExploreView`** applies on first appear and when activity presence changes).
- **`FieldGuideCategoryAccent`** — hub tile palette (taxonomy order): Yellow, Red, Purple, Light Green, Orange, Cyan, Deep Pink.
- **`HomeLifetimeStatsPresentation.highlightStatTileDescriptors`** — always four tiles (**Deepest**, **Longest**, **Top site**, **Top species**) with **—** placeholders when empty.
- **`HomeLifetimeStatsTilesLayout`** — slightly larger highlight tiles (**90** pt) and grid gaps (**20** pt); empty and populated tiles share one fixed height (footnote row always reserved).
- **`HomeBuddyLeaderboardPresentation.shouldShow`** — always **true** so empty Home keeps the **Top buddies** band; empty tile shows three placeholder slots.
- Tests: **`homeLifetimeStatsPresentation_highlightStatTileDescriptors_alwaysReturnsFourTiles`**, updated carousel empty copy test.
- **`docs/home.md`** — empty logbook layout copy.

**Summary:** Light-mode top chrome — dark blue page titles and toolbar icons (profile avatar ring hue).

- **`AppTheme.Colors`** — **`pageTitleForeground`**, **`headerChromeIconForeground`**, and **`backButtonForeground`** use **`accentDeep`** light stop (profile avatar ring) in light mode; dark mode unchanged (light text / white icons).
- **`AppHeader`**, **`CollapsibleInlineTitleHeader`**, global search idle header, **`AppEditToolbarButton`** — adopt shared chrome title / icon tokens.

**Summary:** Onboarding feature slides — two-line titles, lower copy and continue chrome.

- **`LoggedOutOnboardingFeatureSlidePresentation`** — **`titleLineLimit` 2**, slightly shorter micro-demo height, copy + bottom padding tokens.
- **`LoggedOutOnboardingFeatureSlideView`** — flexible spacer pins title/body lower; title wraps to two lines.
- **`LoggedOutOnboardingView`** — page indicator + **Continue** / **Get started** pin near the physical bottom (**`ignoresSafeArea(edges: .bottom)`** + **`bottomChromeBottomPadding` 14**); feature-slide **Continue** is plain secondary text (not a filled button); last-slide **Get started** pulses **twice** (scale + opacity), then settles to static accent text (respects Reduce Motion).

**Summary:** Home media carousel — light haptic on dive title tap.

- **`HomeMediaCarouselDiveLinkButton`** — light impact haptic when the dive title capsule is tapped (opens dive); skipped under UI tests via **`HomeMediaCarouselDiveLinkChromePresentation.shouldPlayOpenDiveHaptic`**. Uses **`.sensoryFeedback`** after starting navigation so an unprepared UIKit generator does not stall the dive push.
- Test: **`homeMediaCarouselDiveLinkChrome_openDiveHaptic_skipsUnderUITest`**.
- **`docs/home.md`** — dive link capsule haptic note.

**Summary:** Empty Home buddy band — pushed seam defaults match reserved **Top buddies** height.

- **`HomeOverviewPushedLayoutPresentation.pushedPageSeamInputs`** — when Home anchor is unset, uses **`HomeTabRootLayoutPresentation.defaultLifetimeGridSeamInputs`** (buddy band on) instead of the old 2×2-only band.
- Tests updated for always-on buddy band + layout-anchor reset isolation; header chrome color compare uses resolved **`UIColor`**.

## 102 - Next batch **(pushed)**

**Summary:** Post-sign-up import offer slide before bubble celebration.

- **`PostSignUpImportOfferView`** — after profile setup (scuba / free dive new accounts): MacDive / UDDF bulk import pitch, **Import dives** + **Skip for now**; bubble celebration → Home, or Logbook → UDDF import options when import is chosen.
- **`AccountSession`** — `showsPostSignUpImportOffer`, logbook / UDDF handoff flags consumed by **`ContentView`** + **`LogbookView`** + **`ActivityUploadView`**.
- Tests: **`postSignUpImportOfferPresentation_*`**, **`accountSession_completePostSignUpImportOffer_isNoOpWhenNotShowingOffer`**.
- **`docs/getting-started.md`** — step 5 in new-account flow.

**Summary:** Onboarding **Log every dive** — Red lionfish on Photos tab panel.

- **`OnboardingLogEveryDiveDemoView`** — **Photos** tab overview panel shows **Marine life** tag + **Red lionfish** / *Pterois volitans* + ID copy (replaces **1 video**).
- **`OnboardingLogEveryDiveDemoFixtures`** — tagged species constants; bundled **`marine-life-red-lionfish`** in demo photo list.

**Summary:** Onboarding **Log every dive** — bundled dive video on Photos tab.

- **`onboarding-log-every-dive-demo.mov`** in **`Resources/`**; **`OnboardingBundledLoopingVideoView`** plays it full-bleed (muted loop) on the **Photos** tab micro-demo.
- Replaces the three-photo pager on that tab.

**Summary:** Onboarding **Log every dive** micro-demo — satellite map on dive map tab.

- **`OnboardingLogEveryDiveMapRepresentable`** — read-only **MKImagery** map + red marker at Blue Hole (Belize), matching dive detail map chrome.
- **`OnboardingLogEveryDiveDemoFixtures`** — `diveCoordinate` + `mapRegion`.
- Test: map region centers on fixture coordinate.

**Summary:** File import — survive backgrounding and avoid partial saves.

- **`DiveFileImportRuntimeProtection`** — disables SwiftData autosave for the import pass, rolls back pending rows on interruption, and requests a UIKit background task so bulk imports can finish site / buddy work before save.
- **`UddfDiveFileImport`** / **`FitDiveFileImport`** — atomic persist (site matching + buddy contact linking before **`save()`**); cancellation returns **`DiveFileImportInterruption`** message instead of silent partial state.
- **`ActivityUploadView`** — no longer cancels import or hides the overlay on **`onDisappear`**; back navigation disabled while the scrim is up; interrupted imports show the failure dialog.
- Tests: **`diveFileImportInterruption_*`**, **`diveFileImportAutosaveScope_restoresPriorAutosaveFlag`**.
- **`docs/import.md`** — keep app open tip + troubleshooting row.

**Summary:** Profile — confirm before sign out.

- **`ProfileView`** — **Sign out** presents an **Are you sure?** alert (**Cancel** / destructive **Sign out**) before clearing the session.

**Summary:** Post-sign-up import — MacDive guide before celebration; skip exits to bubbles.

- **`PostSignUpOnboardingImportView`** — after **Import dives** on the offer slide: MacDive UDDF guide (no back; **Skip for now** top-right → celebration); file picker + bulk import on last step.
- **`MacDiveUddfImportGuideView`** — optional onboarding chrome (`showsBackButton`, skip trailing action).
- **`AccountSession`** — **`showsPostSignUpOnboardingImport`**; removed Logbook handoff flags after import offer.
- Shared **`DiveImportOverlayState`** + **`DiveImportProgressOverlayView`** for import scrim.
- Tests + **`docs/getting-started.md`**.

**Summary:** Post-sign-up — Contacts & Photos page before import offer.

- **`PostSignUpPermissionsView`** — after profile setup, explains Contacts + Photos; **Continue** runs **`AppOnboardingPermissions`** then advances to import offer or celebration.
- **`AccountSession`** — **`showsPostSignUpPermissions`**; profile setup no longer defers permission prompts until after celebration.
- Tests: **`postSignUpPermissionsPresentation_*`**, **`accountSession_completePostSignUpPermissions_isNoOpWhenNotShowingPermissions`**.
- **`docs/getting-started.md`** — new step 5 in new-account flow.

**Summary:** Profile — omit certification subtitle when none on file.

- **`CertificationPresentation`** — no **GoDive User** fallback; **`profileFeaturedCertification`** / **`profileCertificationSubtitle`** return **`nil`** without a certification-type card.
- **`ProfileView`** + **`PostSignUpProfileSetupView`** preview — hide certification line under the name when absent.
- Tests + **`docs/getting-started.md`**, **`docs/trips-and-buddies.md`**.

**Summary:** Post-sign-up profile setup — welcome copy + skip on all building steps.

- **`PostSignUpProfileSetupPresentation`** — profile photo title **Welcome,** *display name*; subtitle **Add a profile photo**; **Skip for now** on photo, DAN, and certification steps.
- **`docs/getting-started.md`** — updated step 1 copy.

**Summary:** Onboarding **Share experiences** — beach hero on trip / buddies micro-demo.

- **`onboarding-share-trip-hero-beach.jpg`** (Unsplash) in **`Resources/OnboardingPhotos/`**; **`OnboardingShareWithFriendsDemoView`** **`tripHero`** shows full-bleed beach + palm trees instead of the blue gradient placeholder.
- **`OnboardingShareWithFriendsDemoFixtures`** — **`tripHeroPhotoResourceName`**, **`tripHeroImage`**.
- Test: bundled trip hero photo resolves in **`onboardingShareWithFriendsDemoFixtures_supportMicroDemo`**.
- **`docs/acknowledgments.md`** — Unsplash credit for onboarding trip hero.
- **`ProfilePresentation`** — shared confirmation title, message, and button titles.
- Test: **`profilePresentation_signOutConfirmation_copyIsNonEmpty`**.
- **`docs/settings.md`**, **`docs/getting-started.md`** — confirmation note.

**Summary:** Onboarding **Share experiences** — trip micro-demo layout fits phone frame with beach hero.

- **`OnboardingShareWithFriendsDemoFixtures`** — shorter **`heroHeight`** (300), layout-aware **`panelOverlap`** (32), **`pagerContentHeight`**, slightly smaller buddy avatars.
- **`OnboardingShareWithFriendsDemoView`** — negative **`VStack`** overlap (replaces visual-only offset), page-dot clearance, tighter panel bottom padding.
- Test: **`onboardingShareWithFriendsDemoFixtures_supportMicroDemo`** asserts pager band fits the 2×2 stats grid.

**Summary:** Onboarding **Share experiences** — trip title + date range no longer clip in micro-demo.

- **`OnboardingShareWithFriendsDemoFixtures`** — **`pinnedSummaryMinHeight`** (84); panel chrome math uses seam padding.
- **`OnboardingShareWithFriendsDemoView`** — trip-detail subtitle accent + **title2** title; intrinsic height instead of fixed 68pt clip; **`AppTheme.Spacing.md`** top seam padding.

**Summary:** Onboarding MacDive import guide — **Skip** button label.

- **`PostSignUpOnboardingImportPresentation`** — top-right skip title **Skip** (was **Skip for now**).
- **`docs/getting-started.md`** — step 6 MacDive guide copy.

**Summary:** Post-sign-up profile setup — **Continue** only after step input.

- **`PostSignUpProfileSetupPresentation.showsContinueButton`** — photo after crop, DAN after text, cert after required fields; preview always shows CTA.
- **`PostSignUpProfileSetupView`** — hides **Continue** until the step is complete; **Skip for now** unchanged.
- Tests: **`postSignUpProfileSetupPresentation_showsContinueButton_onlyAfterStepInput`**; **`docs/getting-started.md`**.

**Summary:** Post-sign-up profile setup — back chevron on later steps.

- **`PostSignUpProfileSetupView`** — upper-left **chevron.left** returns to the previous builder step (hidden on profile photo).
- **`PostSignUpProfileSetupPresentation.showsBackButton`** + accessibility id **`PostSignUpProfileSetup.Back`**.

**Summary:** Onboarding import — **Import dives** opens UDDF options first.

- **`PostSignUpOnboardingImportView`** — **`DiveFileImportOptionsView`** root (choose file + MacDive card); pushes MacDive guide; no back; **Skip** top-right on both screens.
- **`DiveFileImportOptionsView`** — optional **`showsBackButton`**, onboarding skip chrome, glass **Choose UDDF file** when requested.
- Tests + **`docs/getting-started.md`**.

**Summary:** Onboarding primary CTAs — Liquid Glass **`.glass`** capsule buttons.

- **`AppButtonChrome.appOnboardingPrimaryGlassButtonStyle()`** — shared full-width glass CTA (welcome **Continue**, profile setup, permissions, import offer, MacDive guide import).
- Replaces **`.borderedProminent`** on post-sign-up **Continue** / **Import dives**; **`LoggedOutOnboardingWelcomeView`** uses the shared helper.

**Summary:** Onboarding **Share experiences** — trip micro-demo rebuilt for phone frame.

- **`OnboardingShareWithFriendsDemoLayout`** — explicit hero / blue-sheet / pager geometry budget for **393×852** logical frame.
- **`OnboardingShareWithFriendsDemoView`** — compact stats/sites/buddies; fixed-height pager; pre-rendered share-card PNG **`scaledToFit`** full preview.
- **`OnboardingShareWithFriendsDemoFixtures.renderShareCardPreviewImage()`**; tests updated.

## 103 - Performance, onboarding, PADI OCR, and certification polish **(pushed)**

**Summary:** Fix launch/onboarding freeze — defer Google Maps warm-up and heavy demo work off the first frame.

- **`GoogleMapsWarmup`** — non-blocking async warm-up with **`Task.yield()`** between SDK init and hidden **`GMSMapView`** layout.
- **`ProductionAppRoot`** — Google Maps warm-up only when **`AccountSession.showsMainAppShell`**; re-triggers after post-sign-up gates complete.
- **`LoggedOutOnboardingFeatureSlideView`** — mount micro-demos only after the slide becomes active (avoids TabView preloading maps/video/render work).
- **`OnboardingShareWithFriendsDemoView`** — defer share-card **`ImageRenderer`** until the slide is active (yield before render).
- Tests: **`accountSessionMainShellPresentation_requiresSignedInPastPostSignUpGates`**.

**Summary:** Silence SwiftUI “modifying state during view update” warnings.

- **`BlueSheetPageShell`** — defer **`onLayoutResolved`** to the next run loop.
- **`BlueSheetTabRootPage`** — defer **`frozenRootViewportHeight`** binding writes.
- **`LoggedOutOnboardingFeatureSlideView`** — defer demo mount + entrance animation when a slide becomes active.
- Onboarding micro-demos — move **`resetDemoState()`** inside the demo **`Task`** (not synchronous in **`onChange`**).
- **`HomeMediaCarouselTaggedBuddyScrollRow`** — defer buddy viewport frame latch.

**Summary:** Opaque **`ImageRenderer`** snapshots — no **AlphaLast** PNG warnings.

- **`AppSwiftUIImageRenderer`** — **`isOpaque`** rendering + flatten before **`pngData()`**.
- **`OnboardingShareWithFriendsDemoFixtures`**, **`TripShareCardPresentation`**, **`DiveMediaPreviewPersistence`** updated.
- Test: **`appSwiftUIImageRenderer_opaqueUIImage_omitsAlphaChannel`**.

**Summary:** `@MainActor` usage rule + off-main marine-life catalog loads.

- **`.cursor/rules/swift-mainactor-usage.mdc`** — when to use / avoid `@MainActor` (UI vs heavy work), patterns, test notes; complements **`swiftui-snappy-navigation.mdc`**.
- **`MarineLifeCatalogLoader`** — fetch + sort catalog on a background **`ModelContext`**, re-bind on the UI context.
- **`ViewSingleActivity`** — marine-life + dive-site catalog loads use the loader (Media tab / overview sheet no longer block on full-table main-actor fetch).
- **`ViewDiveBuddyDetails`** — tagged-media page loads marine-life catalog asynchronously.
- **`DiveActivityMapCoordinateResolution`** — dive-site catalog fetch off main actor.
- Test: **`marineLifeCatalogLoader_loadsSortedCatalogOffMainActor`**.

**Summary:** MainActor audit — snapshot enrichment, profile queries, buddy index, linked dive cover.

- Snapshot **`enrichMarineLife`** builders (**trip**, **activity tag**, **explore site**) take preloaded catalog; callers use **`MarineLifeCatalogLoader`** (no main-actor full-table fetch).
- **`ExploreDiveSiteDetailView`** — marine-life enrichment deferred to async when marine-life / tagged-media pager mounts.
- **`DiveBuddyDetailPresentation.fetchOwnerDiveIndex(container:)`** — owner dive index off main; **`ViewDiveBuddyDetails`** uses it.
- **`LinkedMediaFullscreenLinkedDiveCover`** — dive lookup in **`.task`**, not computed property on every body pass.
- **`ProfileView`** / **`ProfileTaggedMediaView`** — owner-scoped **`@Query`** predicates (no store-wide fetch + filter on Profile).
- Tests: **`diveBuddyDetailPresentation_fetchOwnerDiveIndexOffMainActor`**.

**Summary:** MainActor audit — medium-priority screens (tag sheets through explore site fetch).

- **Marine-life tag sheets** — **`DiveMarineLifeMediaTagsSheet`**, **`DiveMarineLifeTagPickerSheet`**, **`DiveMediaFishialIdentifySheet`**: removed full-table **`@Query`**; lazy **`MarineLifeCatalogLoader`** in **`.task`**.
- **`DiveSiteCatalogLoader`** — off-main dive-site catalog fetch + re-bind (Field Guide + species detail map pins).
- **Field Guide tab** — owner-scoped dive **`@Query`**; marine-life + dive-site catalogs load asynchronously; **`ContentView`** passes **`ownerProfileID`**.
- **Explore tab** — owner-scoped dives **`@Query`**; marine-life + dive-site catalogs lazy-loaded in **`.task`** (no full-table catalog **`@Query`** on first frame).
- **`FieldGuideMarineLifeDetailView`** — scoped **`MarineLifeUserRecord`** query; dive sites via loader.
- **Buddy detail trips pager** — **`fetchOwnerTripsAsync`** when trips tab mounts (not sync in rebuild).
- **Explore dive site detail** — site-scoped dive fetch off main (**`fetchSiteDiveActivitiesAsync`**).
- Tests: **`diveSiteCatalogLoader_loadsSortedCatalogOffMainActor`**.

**Summary:** MainActor audit — lower-priority screens (Home catalogs, Global Search, sheets, scoped buddy queries).

- **Home (`LogOverviewView`)** — full-table marine-life / dive-site **`@Query`** replaced with lazy catalog loaders; home aggregate rebuild uses preloaded catalogs.
- **Global Search** — index + destination screens: owner-scoped dive **`@Query`**; marine-life + dive-site catalogs lazy-loaded; search index build runs off main via **`Task.detached`**.
- **Logbook** — dive-site catalog lazy-loaded for catalog site navigation (no full-table **`@Query`** on tab open).
- **Manual dive entry** / **trip planned sites** — dive-site picker catalogs load in **`.task`**.
- **Explore** — dive-site catalog lazy-loaded alongside marine-life (scope cache rebuilds when catalogs arrive).
- **Buddy / trip sheets** — **`DiveActivityBuddiesEditSheet`**, **`DiveMediaBuddyTagPickerSheet`**, **`TripPlannedBuddyPickerSheet`**, **`DiveBuddiesListView`**, **`TripAddSheetView`**, **`PostSignUpProfileSetupView`**: owner-scoped **`@Query`** predicates (no fetch-all + filter).

**Summary:** Onboarding welcome CTA — **Get Started**.

- **`AppLoggedOutOnboardingPresentation.welcomeContinueTitle`** — **Get Started** (was **Show me around**).
- **`docs/getting-started.md`** — welcome step copy.

**Summary:** Onboarding last feature slide — **Sign Up**; hide redundant **Skip**.

- **`AppLoggedOutOnboardingPresentation.signUpButtonTitle`** — last-slide bottom CTA **Sign Up** (was **Get started**); **`showsSkipButton`** hides **Skip** on that slide.
- Tests: **`loggedOutOnboardingPresentation_*`** skip visibility expectations.
- **`docs/getting-started.md`** — feature-slide copy.

**Summary:** Post-sign-up profile photo — auto-advance after crop.

- **`ProfileAvatarEditor`** — optional **`onPhotoSaved`** after successful crop save.
- **`PostSignUpProfileSetupView`** — advances to the next step on photo save (no **Continue** on photo step); **Skip for now** unchanged.
- Tests: **`postSignUpProfileSetupPresentation_showsContinueButton_onlyAfterStepInput`**.
- **`docs/getting-started.md`** — profile photo step copy.

**Summary:** Profile photo crop sheet — standard blue background.

- **`ProfilePhotoCropSheet`** — full-sheet **`screenBackgroundGradient`** (crop canvas + nav bar via hidden toolbar background + **`presentationBackground`**); replaces black crop backdrop.

**Summary:** PADI eCard OCR — digital front layout + cert name.

- **`PADICertificationCardParser`** — eCard path: **CERTIFICATION**, **CERT. DATE** / **PADI NO.** (combined or split); full-month dates (`12-August-2024`); alphanumeric PADI numbers (`24080D5449`); ignores diver name, **BIRTHDATE**, **edit photo**.
- **`PADICertificationCardParseResult`** — **`certName`**; **`applyPADIParseResult`** fills empty certification name.
- **`CertificationFormContent`** — OCR on **Front** or **Back** photo pick.
- Tests: **`padiCertificationCardParser_parsesECardFrontLines`**, **`certificationFormValues_applyPADIParseResult_setsCertNameWhenEmpty`**.
- **`docs/trips-and-buddies.md`** — eCard / front-photo auto-fill note.

**Summary:** Certification OCR — fix cert name not applying from front scan.

- **`CertificationFormContent`** — independent front/back scan tasks (adding back no longer cancels front apply).
- **`PADICertificationCardParser`** — physical front detected from cert title alone; prefers longest title match (**Advanced Open Water Diver** over **Open Water Diver**); merges multi-line OCR before single lines.
- **`applyPADIParseResult`** — only auto-fills agency when detected on card; DEBUG log when a field is skipped because it already has text.
- Tests: **`padiCertificationCardParser_parsesAdvancedOpenWaterFrontLines`**, **`padiCertificationCardParser_parsesAdvancedOpenWaterSplitFrontLines`**.

**Summary:** Certification OCR debug logging + front-card fixes.

- **`CertificationCardOCRDebug`** — DEBUG console category **`CertOCR`**: logs pixel size, orientation, each OCR line, and parse result (filter device log while scanning).
- **`CertificationCardTextRecognition`** — passes photo label to logs; applies UIImage orientation to Vision; renamed entry point **`parsePADICard`**.
- **`PADICertificationCardParser`** — physical front merges split title lines (**Open Water** + **Diver**); **`agencyDetectedFromCard`** so agency-only reads still apply.
- Tests: **`padiCertificationCardParser_parsesPhysicalFrontCardSplitOCRLines`**.

**Summary:** PADI OCR — blacklist card footer boilerplate for dive shop.

- **`PADICertificationCardParser`** — ignore ISO/PADI footer prose (**This diver…**, **qualification meets…**, etc.); prefer all-caps shop labels (**HOMESTEAD CRATER**) over person-name heuristics.
- Tests: **`padiCertificationCardParser_ignoresCardFooterBoilerplateForDiveShop`**.


- **`Certification`** / **`CertificationFormValues`** — new **`diveShopNumber`** (shop identification number); dive shop name stored separately.
- **`PADICertificationCardParser`** — shop number no longer appended to instructor or dive shop; title-case parsed person/organization names; strip trailing shop digits from merged OCR lines; physical front handles **PADI®** and Vision layout (**Open Water Diver** / **PADI**).
- **`CertificationFormContent`** / **`ViewCertificationDetails`** — shop ID field + detail row.
- Tests: updated parser/form expectations + **`padiCertificationCardParser_parsesPhysicalFrontCardVisionOCRLines`**, **`padiCertificationCardParser_stripsShopNumberFromMergedInstructorLine`**.


- **`PADICertificationCardParser`** — back-card detection runs before eCard; eCard requires label lines (not footer **certification** prose); normalize Cyrillic OCR homoglyphs in dates (**А**pr → **Apr**).
- Tests: **`padiCertificationCardParser_parsesPhysicalBackCardVisionOCRLines`**.

**Summary:** PADI physical front card — agency + certification name OCR.

- **`PADICertificationCardParser`** — physical front path: recognizes agency (**PADI**, etc.) and titles (**Open Water Diver**, **Rescue Diver**, …); ignores diver name and taglines; back-card detection no longer triggers on **PADI** alone.
- Tests: **`padiCertificationCardParser_parsesPhysicalFrontCardLines`**.
- **`docs/trips-and-buddies.md`** — front-photo agency/title auto-fill note.

**Summary:** Certification form — tap card thumbnail to preview fullscreen.

- **`CertificationFormContent`** — uploaded front/back thumbnail opens fullscreen preview; **Change photo** still opens PhotosPicker.

- **`PADICertificationCardParser`** — back-card **Diver No.** / **Instr. No.** accept alphanumeric values (`21040R0406`, `OWSI-396419`); ignores diver name + **BirthDate**; pairs shop number with next line (`19956` + **HOMESTEAD CRATER**).
- Tests: **`padiCertificationCardParser_parsesPhysicalBackCardAlphanumericLines`**.

**Summary:** Adaptive GoDive pin logo — light/dark appearances.

- **`GoDiveLogoPin`** asset — **GoDiveLogoPin-Light** (navy pin) for light mode, **GoDiveLogoPin-Dark** (light blue pin) for dark mode; launch screen + share card pick up catalog appearances automatically.
- **`GoDiveLogoPinPresentation`** — shared **`Image`** accessor / asset name.
- Tests: **`goDiveLogoPin_assetResolvesDistinctImagesForLightAndDark`** (includes alpha-channel check).

**Summary:** GoDive pin logos — restore transparent backgrounds.

- Source art was JPEG (no alpha); converted PNGs were opaque RGB with baked-in black. Re-keyed black to transparency → **RGBA** assets.
- Test: alpha-channel expectation in **`goDiveLogoPin_assetResolvesDistinctImagesForLightAndDark`**.

**Summary:** GoDive pin logos — Desktop source art (RGBA).

- **`GoDiveLogoPin-Light.png`** / **`GoDiveLogoPin-Dark.png`** replaced from Desktop **`pin LIGHT.png`** / **`pin DARK.png`** (native transparency, no black keying).

**Summary:** Logged-out onboarding — page dots pin to screen bottom.

- **`LoggedOutOnboardingView`** — bottom chrome order swapped: **Continue** / **Sign in with Apple** above, page indicator at the physical bottom.

**Summary:** Certification onboarding — keyboard row X + Continue.

- **`PostSignUpProfileSetupView`** — certification keyboard accessory: **X** left, **Continue** right (when form is valid); bottom **Skip** / **Continue** hidden while keyboard is open.
- **`PostSignUpProfileSetupPresentation`** — **`showsSkipInBottomChrome`**, **`showsContinueInBottomChrome`**, **`showsContinueInCertificationKeyboardToolbar`**.
- Tests: **`postSignUpProfileSetupPresentation_certificationKeyboardChrome_hidesBottomSkipAndContinue`**.

- **`PostSignUpProfileSetupDanDraft`** — local DAN buffer; only **`showsContinue`** publishes to the wizard (not every keystroke).
- **`PostSignUpProfileSetupDanInsuranceStep`** — isolated **`TextField`** with **`.textContentType(.none)`**; bubbles paused on DAN/cert steps via **`LoggedOutMarketingChrome`**.
- Console note: **`[MC] Reading from public effective user settings`** is harmless iOS noise on text-field focus, not an app fault.
- Tests: **`postSignUpProfileSetupDanDraft_updatesContinueVisibilityOnlyOnBoundary`**, updated **`showsContinueButton`** expectations.

- **`SignInCelebrationTransitionDiagnostics`** — Xcode console lines prefixed **`[SignInCelebration]`** (+ elapsed ms) and Instruments signposts for import handoff, celebration first frame, shell prewarm, Home rebuild.
- **`PostSignUpOnboardingImportView`** — defers **`onComplete`** after alert dismiss / import finish; flags **`followsBulkImport`** for bulk UDDF summary path.
- **`CelebrationShellPrewarmPresentation`** — shell prewarm waits **1.5 s** after bulk import (was **120 ms** for all paths).
- **`LogOverviewView`** — starts initial **`HomeOverviewAggregate`** rebuild while the celebration underlay is hidden (not at handoff); incidental query-driven rebuilds wait until the first build is scheduled.
- **`HomeRootAppearPresentation`** / **`HomeOverviewRebuildPresentation`** — testable prewarm rebuild policy.
- **`GoogleMapsWarmup`** — **`includeHiddenMapView: false`** before shell prewarm so Explore’s map is the only **`GMSMapView`** (avoids **`CCTClearcutUploader`** duplicate warning).
- **`AppSessionRootView`** — SDK-only Google Maps configure when celebration starts.
- Tests: **`homeRootAppearPresentation_startsInitialRebuildDuringCelebrationPrewarm`**, **`homeOverviewRebuildPresentation_skipsIncidentalRebuildUntilInitialBuildDuringPrewarm`**.

**Summary:** Profile setup + celebration handoff — snappier step transitions and less bubble freeze.

- **`PostSignUpProfileSetupView`** — opacity-only step crossfade; DAN on flat layout (no **`ScrollView`**); bubbles keep animating through DAN handoff; bubble pause deferred ~180 ms after entering certification so the crossfade stays fluid; certification keyboard **Continue** uses white label text.
- **`ProfileAvatarEditor`** — defers wizard advance until crop sheet dismisses (~320 ms).
- **`SignInCelebrationView`** — fades logo/wordmark before **`completeSignInCelebration`**; **`AccountSession`** + **`AppSessionRootView`** reveal Home without animating **`ContentView`** opacity in the same transaction as overlay removal.
- **`PostSignUpProfileSetupPresentation`** — **`shouldPauseBubbleAnimation`**, **`usesFlatStepLayout`**, **`stepTransitionDuration`**.
- Tests: bubble pause + flat layout expectations; **`handoffFadeOutDuration`**.

**Summary:** Logged-out onboarding — Sign in with Apple on last feature slide; Skip → dedicated sign-in.

- **`LoggedOutOnboardingView`** — last feature slide bottom chrome is **`SignInWithAppleSection`** (no slide-up sign-up page); **Skip** / welcome **Already have an account?** → **`SignInView`**.
- **`AppLoggedOutOnboardingPresentation`** — **`showsContinueButton`** / **`showsSignInWithAppleOnLastFeatureSlide`** replace last-slide **Sign Up** CTA helpers.
- Tests + **`docs/getting-started.md`**.

**Summary:** Post-sign-up certification step — expanded form + keyboard dismiss.

- **`PostSignUpProfileSetupView`** — certification step hides the **Snap your card…** subtitle (animated) once the user adds photos, types, or focuses a field; title compacts and the **`Form`** gains vertical space.
- Keyboard accessory shows **×** to dismiss (no QuickType bar); tapping a field reopens the keyboard.
- **`CertificationFormContent`** — optional **`@FocusState`** wiring + autocorrection disabled for onboarding text fields.
- **`PostSignUpProfileSetupPresentation`** — **`certificationStepHasStartedEntry`** / **`certificationStepUsesExpandedLayout`**.
- Test: **`postSignUpProfileSetupPresentation_certificationExpandedLayout_afterEntryOrFocus`**.

**Summary:** PADI front-card OCR — apply agency when cert title is recognized.

- **`PADICertificationCardParser`** — physical front infers **PADI** when a certification title is parsed without a separate agency line; back/eCard paths finalize agency when any field is extracted.
- **`CertificationFormValues.applyPADIParseResult`** — fills **Agency** whenever the parse produced any field (not only when OCR read a **PADI** token).
- Tests: **`padiCertificationCardParser_infersPADIAgencyWhenFrontTitleWithoutAgencyLine`**, **`certificationFormValues_applyPADIParseResult_setsAgencyWhenCertNameParsedWithoutAgencyFlag`**.

**Summary:** Certification form — fix **Change photo** picker.

- **`CertificationCardPhotoPicker`** — dedicated subview observes `@Binding` selection reliably, clears selection after load, and expands the tap target so repeat picks fire **`onChange`**.

**Summary:** PADI cert date OCR — local wall-clock day (no UTC off-by-one).

- **`PADICertificationCardParser.parseCertDate`** — builds date-only values in the device calendar so **`DatePicker`** shows the printed day (e.g. **02-Dec-2021** stays Dec 2 in Mountain Time).
- Test: **`padiCertificationCardParser_parseCertDate_inlineUsesLocalWallClockDay`**.

**Summary:** Certification OCR re-apply — update fields when re-scan differs.

- **`CertificationFormValues.applyPADIParseResult`** — changing front/back card photos re-applies OCR: updates a field when the new parse has a different non-empty value; leaves it alone when the parse is missing that field or matches what is already filled.
- Tests: **`certificationFormValues_applyPADIParseResult_updatesFieldsWhenParsedValueDiffers`**, **`_leavesFieldUnchangedWhenParsedValueMatches`**, **`_leavesFieldUnchangedWhenParsedValueMissing`**.

**Summary:** Certification card photo preview — stable first open.

- **`certificationCardPhotoPreviewCover`** — fullscreen preview state lives on the sheet / onboarding root (not inside the **`Form`**), with deferred presentation so OCR + picker transitions do not dismiss the cover on first tap.

**Summary:** Post-sign-up profile photo → DAN step snappier.

- **`ProfilePhotoCropSheet`** — circular JPEG render runs off the main actor before save.
- **`ProfileAvatarEditor`** — dismisses crop sheet first, advances onboarding on the next frame, then persists **`profilePhoto`** asynchronously.
- **`PostSignUpProfileSetupView`** — certification **`@Query`** scoped to preview step only; faster step transition animation.

**Summary:** Home **Log Your First Dive** opens dive import.

- **`EnvironmentValues.openDiveImport`** — switches to Logbook tab and pushes **`ActivityUploadView`** (**`LogbookRoute.addActivity`**) instead of only opening the Logbook list.
- **`ContentView`** — **`pendingLogbookRoute`** binding; **`LogbookView`** consumes pending route on appear.
- **`HomeOverviewSections`** — empty-state CTA uses **`openDiveImport`**.
- Test: **`logbookPendingRouteNavigation_addActivityReplacesStack`**.

## 104 - Profile cert number layout **(pushed)**

**Summary:** Profile — hide featured certification number so top chrome aligns with other pages.

- **`ProfileView`** — featured certification shows cert name only (no cert number under the title); frees vertical space under the top **Edit** / **Settings** row.

## 105 - Next batch **(pushed)**

**Summary:** Search — **Media** tile opens cross-log photo/video grid with filterable search.

- **`GlobalSearchPresentation.ContextToken.media`** — ninth search category tile (**photo.on.rectangle.angled**); tap pushes **`GlobalSearchMediaBrowseView`** (not scoped text search).
- **`GlobalSearchMediaBrowseView`** — full-screen 3-column grid of all owner dive media; filters via tab-bar **`.searchable`** (**`buddy:`**, **`tag:`**, **`trip:`**, **`species:`** prefixes + suggestion chips above the grid).
- **`GlobalSearchMediaBrowsePresentation`** / **`GlobalSearchMediaIndexSnapshotBuilder`** — sendable index + off-main filter rebuild.
- **`Destination.mediaBrowse`** — search stack push target; grid uses **`LinkedMediaGridSection`** + **`LinkedMediaFullscreenView`** (**View on dive**).
- Tests: context token count/row layout, media filter prefixes, index ordering.
- **`docs/search.md`** — Media tile + browse filters.
- Search tile accents — **Certifications** cyan (**`sea_turtles`**); **Media** lavender (**`global_search_media`**).
- **Media browse** — inline search bar removed; tab-bar **`.searchable`** stays visible on the grid page.
- **Media browse loading** — atomic **`DisplayCache`** (index + filter off-main); spinner until first paint; no brief “no results” flash; stale grid kept during query debounce.
- **Media browse title** — dynamic **`X videos, X photos`** header from filtered results (updates as search narrows).
- **Media browse tab bar fix** — **`GlobalSearchPushedDestinationPresentation.hidesBottomTabBar(for:)`** keeps the bottom tab bar (home navigation) and its morphed **`.searchable`** field visible on **Media** browse; other pushed search details still hide it. Test: **`globalSearchPushedDestinationPresentation_keepsBottomTabBarOnlyForMediaBrowse`**.
- **Media browse header/layout** — dynamic count title now uses a smaller centered font (**`.title3`** via new **`AppPage`** / **`CollapsibleInlineTitleHeader`** **`collapsibleInlineTitleFont`** param); grid scroll surface (**`GlobalSearchMediaBrowseScrollLayer`**) reads the shared **`scrollContentUnderHeader`** insets so it starts below the header at the same height as search-result lists on other pages (space between title and grid) and collapses the title on scroll.
- **Media browse search state fix** — opening **Media** no longer sets an active **`.media`** context token or force-presents the tab search. Fixes the phantom empty "media" results page (double search state) seen on back, and lets the user tap the magnifying glass to type filter terms. Popping out of Media browse resets cleanly to the category tiles (**`isMediaBrowsePresented`** + **`finishReturnToGenericSearchPageFromMediaBrowse`**); removed the dead **`.media`**-token auto-push.
- **Media now behaves like every other search tile (redesign)** — tapping **Media** no longer pushes a separate page (where the tab-bar magnifying glass could not be opened). It now sets the **`.media`** scope token in the search field and renders the media grid in the **results panel** at the search root, so the search field stays fully usable — the user types additional terms (site free text, **`buddy:`**, **`tag:`**, **`trip:`**, **`species:`**) to filter the grid, and **Back** / swipe returns to the category tiles. **View on dive** pushes the dive detail and the media grid is restored on back (shared results-session preservation).
  - New **`GlobalSearchMediaResultsView`** (results-panel body: shared **`GlobalSearchResultsTopChrome`** back row + scrim + off-main **`DisplayCache`** grid + centered **`X videos, X photos`** count title).
  - **`GlobalSearchPresentation.isMediaScope(_:)`** gates the panel (media grid vs. text-search list); **`GlobalSearchView.searchResultsPanel`** branches on it.
  - Removed **`Destination.mediaBrowse`**, the pushed **`GlobalSearchMediaBrowseView`**, **`ContextToken.opensMediaBrowseOnSelect`**, and the media special-cases in **`GlobalSearchPushedDestinationPresentation`** (**`isMediaBrowseDestination`**, **`hidesBottomTabBar(for:)`**, media clauses in **`attachesStackSearch`** / **`shouldDismissSearchBeforePathAppend`**) plus **`isMediaBrowsePresented`** / **`finishReturnToGenericSearchPageFromMediaBrowse`**.
  - Tests: **`globalSearchPresentation_isMediaScopeOnlyForLoneMediaToken`**, updated **`attachesStackSearchOnlyAtRoot`** / **`dismissesSearchBeforePathAppend`**; removed obsolete media-push tests.

**Summary:** Search enhancements — full result counts, reliable results scrolling, restored idle search bar, and Media filtering consistent with other categories.

- **Bug fix — typed queries no longer truncate at 12 per section:** **`GlobalSearchPresentation.maxHitsPerSection`** raised from **12 → 500** and applied to both scoped browse and typed multi-category searches (removed the separate **`maxScopedBrowseHits`**). Searching a buddy name (or any text) now returns **all** matching dives/rows in each section, not just the first 12. Test: **`globalSearchPresentation_typedQueryReturnsAllMatchesNotCappedAtTwelve`**.
- **Bug fix — results list scroll freeze:** the leading-edge interactive dismiss gesture used to claim any drag starting near the screen's left edge (including vertical scrolls), which set **`isDragActive`** and locked the list scroll. New **`GlobalSearchResultsDismissPresentation.shouldEngageDismissDrag(startLocationX:translation:)`** only engages the slide-back for a clearly horizontal, rightward swipe from the leading edge; vertical scrolls pass through to the list. Test: **`globalSearchResultsDismissPresentation_engagesOnlyForHorizontalEdgeSwipe`**.
- **Bug fix — idle search bar not restored on return:** sliding back from the results panel to the category tiles now calls **`restoreIdleStackSearchPresentation`** (**`GlobalSearchView`**) — dismisses the keyboard and re-presents the morphed tab-bar search field so it matches the state when the Search tab is first opened (field visible, not focused).
- **Media search now consistent with other categories:** **Media** filtering dropped the **`buddy:`** / **`tag:`** / **`trip:`** / **`species:`** prefix syntax and the suggestion chips (**`GlobalSearchMediaSpeciesSuggestionsView`**, tag/buddy/trip/species suggestion rows). Typing now free-text matches media across its site name, tagged buddies, activity tags, trip title, and tagged species (**`GlobalSearchMediaBrowsePresentation.matchesFreeText`**). Simplified **`ResolvedFilter`** to a single **`query`**; removed **`FilterPrefix`**, the confirmed-* filter fields, the suggestion builders, **`GlobalSearchMediaSpeciesSearchSuggestion`**, and the Media-specific search prompt (Media now uses the standard **`Search GoDive`** prompt). Test: **`globalSearchMediaBrowsePresentation_freeTextFiltersAcrossAllMediaFields`** (replaces the prefix-based filter test).

**Summary:** Search results — top alignment matches other result pages (title/label on the back-button row, content below the back arrow).

- **Media results top alignment:** the **`X videos, X photos`** count title moved out of the scroll body and onto the back-button row — **`GlobalSearchResultsTopChrome`** gained an optional **`trailingTitle`** (rendered above the scrim, matching the section-header type; centered in the space between the back button and the trailing screen-edge buffer via a fill frame). The media grid now starts right below the back-arrow row (same top inset as scoped result lists) instead of below a separate centered title. Removed the now-unused **`countTitleView`**.
- **General (sectioned) free-search top alignment:** first section label now sits **even with** the back button. **`ResultsSectionHeaderPresentation.scrollContentTopMargin()`** no longer offsets by the full chrome height; it centers the pinned section header on the back-button row (derived from **`appHeaderTopPadding`** + **`glassChromeControlHeight`** vs. header padding/font). Updated call site in **`sectionedResultsList`**. Test updated: **`globalSearchResultsSectionHeaderPresentation_reservesBackButtonAndScrollMargin`** (asserts the centered **12 pt** margin).

**Summary:** Media now appears in general (unscoped) search results — a **Media** section, second after **Buddies**.

- **Media in general results:** typing a free-text query (no category scope) now also matches media by site name, tagged buddies, activity tags, trip title, and tagged species, and surfaces them as a **Media** section positioned **second, right after Buddies**. **`SectionKind.resultSectionDisplayOrder`** gained **`.media`** at index 1; **`search()`** still emits no media **`Hit`**s (media returns **`[]`**), so the results view injects the section from a matching-media snapshot. Test: **`globalSearchPresentation_mediaSection_rendersSecondAfterBuddies`**.
- **`GlobalSearchSearchIndexLayer`** — added **`buddyMediaTags`** / **`sightings`** **`@Query`**s and reuses **`GlobalSearchMediaIndexSnapshotBuilder`** + **`GlobalSearchMediaBrowsePresentation`** to build/filter a media **`DisplayCache`** off-main (index rebuild keyed on data fingerprint; **80 ms** debounced query re-filter). Media work is **gated to the general context only** (skipped while a single-category scope is active) so scoped searches stay light. Empty-state now yields to media matches (`displayedResults.isEmpty && !showsMediaSection`).
- **`GlobalSearchResultsMediaGrid`** — media section row (**`sectionedResultsList`** iterates **`resultSectionDisplayOrder`** and injects it after buddies): a **3-wide** thumbnail grid capped at **two rows** (6 items) when collapsed, with an **Expand** / **Collapse** chevron that reveals the rest **in place** (grid grows down like the Media tile grid — no horizontal scroll). Tapping a thumbnail opens the shared **`LinkedMediaFullscreenView`** (**View on dive** pushes the dive). Collapsed layout keeps the section compact so it doesn't bury the sections below it. Collapse/expand math lives in **`GlobalSearchMediaBrowsePresentation.ResultsSectionGrid`** (**`columnCount`**, **`collapsedRowLimit`**, **`visibleCount`**, **`showsExpandControl`**, **`hiddenCount`**). Test: **`globalSearchMediaResultsGrid_collapsesToTwoRowsUntilExpanded`**.

**Summary:** Search category tiles now play a light haptic on tap.

- **Category tile haptic:** tapping a Search category tile (**`GlobalSearchContextTokensView.tokenButton`**) fires **`.sensoryFeedback(.impact(weight: .light))`** via a **`categorySelectHapticTick`** bump — same pattern as the Home media-carousel dive link (navigation runs first, then the tick bumps so the haptic doesn't stall the push).

**Summary:** Bug fix — back-swipe from the Media scope page no longer accidentally opens a media item.

- **Media grid tap freeze during back-swipe:** the dedicated **Media** scope page's grid (**`LinkedMediaGridSection`** via **`GlobalSearchMediaResultsView`**) now honors the same interactive-dismiss freeze as the text result rows and the general-results media grid. Threaded a new **`isSelectionBlocked`** flag (defaulted **`false`** so other **`LinkedMediaGridSection`** callers are unchanged) computed from **`GlobalSearchResultsDismissPresentation.blocksResultsRowSelection`**; the thumbnail button now guards its action and is **`.disabled`** while blocked. Previously only **`.allowsHitTesting`** on the parent gated taps, which does not cancel a touch that began before the horizontal swipe was recognized — so a swipe-back could still fire the in-flight tap and open a photo/video. (Decision logic already covered by **`globalSearchResultsDismissPresentation_blocksResultsRowSelectionWhilePanelIsOffset`**; the new code threads that tested flag into the shared grid's button guard.)

**Summary:** Dives search now matches more fields — site country/region, dive month + year, tagged marine life, linked trip name, and notes.

- **Expanded dive search index:** each dive's search haystack (was: site name, dive **#**, activity tags, buddy names) now also folds in the linked site's **country** (canonical name + aliases via **`DiveSiteCountryPresentation.searchTerms`**) and **region**, the dive's **month spelled out + 4-digit year** (so `march` or `2026` match), **tagged marine-life common names**, **linked trip name(s)**, and the dive **notes** text. Built in **`GlobalSearchCatalogSeeding.catalog`** via labeled **`SearchField`**s (**`diveMatchFields`**, main-actor capture; species resolved via linked row or denormalized **`marineLifeUUID`** against the loaded catalog, trips via relationship or denormalized **`tripID`**); the haystack is derived from those field values (single source of truth) plus the row title/site.
- New **`GlobalSearchDiveIndexing`** — pure/nonisolated date helpers: **`monthSymbols(locale:)`** (built once per catalog rebuild), **`monthName(for:calendar:monthSymbols:)`**, **`yearString(for:calendar:)`**, and **`dateSearchTokens(...)`**. Matching stays case-insensitive substring and runs off-main.
- **Notes performance:** indexing notes is cheap — one extra string appended to the per-dive haystack, matched via **`contains`** off the main actor. Note: the catalog fingerprint is count-based, so editing an existing dive's text (notes, etc.) re-indexes on the next Search-tab open, not instantly (pre-existing behavior for all fields).
- Tests: **`globalSearchDiveIndexing_dateSearchTokens_yieldsMonthNameAndYear`**.

**Summary:** Search results explain *why* they matched — italic "Label: text" reason lines under each hit (with windowed notes snippets).

- **Match-reason lines:** when a typed query matches a result, an italic line (or up to 3) shows under the row in the form **`Field: matched text`** (e.g. `Dive year: 2026`, `Buddy: Mike`, `Notes: … swam with dolphins for a …`). Matches already visible in the row title (e.g. the dive's site name) produce no line, so only the non-obvious reasons are surfaced.
- **`GlobalSearchPresentation.MatchReason`** (label + text) is carried on **`Hit.matchReasons`**; **`SearchField`** (label, match `value`, optional canonical `display`, `isSnippet`) describes each labeled, searchable value on an index entry. Populated for **dives** today (buddy, marine life, tag, trip, country, region, dive month/year, notes, dive number); the row plumbing is wired for every category so other categories can opt in later.
- **`GlobalSearchMatchReasoning.reasons(query:fields:maxReasons:wordsAround:)`** — scans fields in priority order, dedupes, caps at 3; alias-matched fields (e.g. country `MX`) surface the canonical display name. **`GlobalSearchMatchSnippet.snippet(from:query:wordsAround:)`** — windows long text (notes) to a few whole words on each side with leading/trailing ellipses, preserving original casing.
- **`GlobalSearchResultListRow`** gained a **`matchReasons`** parameter rendering **`GlobalSearchResultMatchReasonLines`** (caption2, italic, semibold label); **`GlobalSearchDiveResultListRow`** + every **`GlobalSearchScopedResultLabel`** branch pass **`hit.matchReasons`** through.
- Tests: **`globalSearchMatchReasoning_reasons_labelMatchedFieldsWithDisplayText`**, **`globalSearchMatchReasoning_reasons_capsAndOrdersByFieldOrder`**, **`globalSearchMatchSnippet_windowsNotesAroundMatch`**.

**Summary:** Bug fix — Fishial AI video still picker now previews frames live as the user scrubs the timeline (previously the preview only refreshed after the finger lifted).

- **Live scrub preview:** **`FishialVideoScrubPlayerView`** no longer cancels the prior Swift task on every slider tick. Cancelling a `Task` does not stop the underlying `AVAssetImageGenerator` decode, so the old **`latestGenerationID`** guard dropped every intermediate frame and only showed the final one after the drag ended — the preview appeared frozen while scrubbing. It now coalesces requests via **`FishialVideoScrubFrameRequestCoalescer`** (**`FishialVideoScrubPresentation.swift`**): one decode runs at a time, each completed frame is shown, and the newest fraction requested meanwhile runs next, so the preview chases the slider live.
- **Faster preview decodes:** **`DiveMediaFishialFrameExport.makeScrubPreviewImageGenerator`** dropped zero tolerance for the same **±0.05 s** tolerance the exported still already uses — exact decodes were slow enough to limit live refreshes, and the modest tolerance keeps the preview representative of the frame that is ultimately exported.
- Tests: **`fishialVideoScrubFrameRequestCoalescer_runsFirstRequestImmediately`**, **`_clampsRequestedFraction`**, **`_queuesLatestWhileGenerating`**, **`_resetClearsPendingWork`**.

**Summary:** Field Guide — marine life category tiles now breathe like the Logbook dive tiles (more space from text to tile edges, matching species pill insets).

- **Category tile spacing:** **`FieldGuideHubTileLayout.tileHeight`** raised **96 → 108** so each category tile's title + two-line subtitle + species pill keep the same **8 pt** breathing room the dive activity tile gets from its intrinsic height — the old fixed height squeezed the content against the tile edges.
- **Species pill insets:** the white **`X species`** / **Explore** capsule on **`FieldGuideCategoryHubTile`** now uses named **`speciesBadgeHorizontalPadding`** (**10**) / **`speciesBadgeVerticalPadding`** (**4**) tokens matching the dive tile's compact **`ActivityTagOvalChipLabel`** oval (was horizontal **8**).
- Tests: **`fieldGuideHubTileLayout_matchesLogbookActivityRowSpacing`** (updated to **108** + content-fit assertion) and new **`fieldGuideHubTileLayout_speciesBadgeMatchesCompactActivityOvalInsets`**.

**Summary:** Search — every scoped category now shows a count header on the back-button row (e.g. "12 Buddies", "8 Dives") that fades out as the results scroll; the Media count header now follows the same fade-on-scroll pattern.

- **Per-category count header:** tapping a Search category tile now renders a bold count title (e.g. **12 Buddies**, **1 Dive**, **9 Species**, **4 Gear items**) centered on the **`GlobalSearchResultsTopChrome`** back-button row — the same slot the Media grid already used for **`X videos, X photos`**. Computed in **`GlobalSearchSearchIndexLayer.scopedCountTitle`** (only for the flat single-category list; the multi-category sectioned list keeps its per-section headers) from the displayed hit count via new **`GlobalSearchPresentation.ContextToken.scopedResultsCountTitle(_:)`** (singular/plural nouns per category — Buddy/Buddies, Dive/Dives, Site/Sites, Species, Tag/Tags, Gear item/Gear items, Trip/Trips, Certification/Certifications).
- **Fade on scroll:** the back-row count title now fades to hidden as the user scrolls down (fully visible at rest, gone after **44 pt**) via new **`GlobalSearchPresentation.ResultsCountTitlePresentation.titleOpacity(scrollOffset:)`** + a **`trailingTitleOpacity`** parameter on **`GlobalSearchResultsTopChrome`**. Scroll position is read with **`.onScrollGeometryChange`** on both the scoped **`List`** (**`global_search_view.swift`**) and the Media **`ScrollView`** (**`GlobalSearchMediaResultsView`**), so **Media now animates away the same way** instead of staying static. Category switches reset the offset so a new category opens with its header visible.
- Tests: **`globalSearchContextToken_scopedResultsCountTitle_usesSingularAndPluralNouns`**, **`globalSearchResultsCountTitlePresentation_fadesTitleAsListScrollsDown`**.

**Summary:** Bug fix — Field Guide marine life category tile descriptions now wrap onto the reserved second line instead of truncating on one line.

- **Category tile subtitle wrap:** the subtitle **`Text`** on **`FieldGuideCategoryHubTile`** only had its **height** constrained (the reserved two-line **`subtitleTwoLineMinHeight`** block), so the text sized to its full single-line width and truncated instead of wrapping. Added **`maxWidth: .infinity`** to the subtitle frame so the text is given the tile's text-column width and wraps into the two-line block (e.g. "Anemones, worms, mollusks, crustaceans, and more"). Cosmetic layout fix (no logic change).

**Summary:** Search performance — results load snappier (cache the search index, stop rebuilding it on every keystroke; reuse the media snapshot).

- **Bug fix — search index rebuilt on every keystroke:** **`GlobalSearchSearchIndexLayer.scheduleSearchRefresh`** used to call **`GlobalSearchCatalogSeeding.catalog(...)`** on the **main actor** for every query change, rebuilding the entire index — all dives (now heavier: country/region, month/year, tagged species, trip name, notes) **plus the full OpenDiveMap reference site index** — even though the catalog is query-independent. This was the main source of the "laggy to load results" typing lag. Now the **`Sendable`** catalog is built once and cached in **`cachedCatalog`** keyed by **`cachedCatalogFingerprint`** (**`ensureBuiltCatalog()`**); keystrokes reuse it and only re-run the already-off-main **`search()`**. The catalog is also **pre-warmed** after data loads (**`warmSearchCatalogIfNeeded()`**, deferred a frame via **`Task.yield()`** so it doesn't block tab entry) so the first search / scoped browse is instant too.
- **Media scope snappier:** the general-results media snapshot (**`GlobalSearchMediaIndexSnapshotBuilder.captureInput`**, a main-actor capture) is no longer discarded when the query is cleared or a category token toggles. A new **`mediaSnapshotToken`** (data fingerprint) lets **`scheduleMediaIndexRebuild`** / **`scheduleMediaFilterRebuild`** **reuse** the cached snapshot across those transitions and only re-capture when the underlying media data actually changes — so re-entering a general search just re-filters off-main instead of re-capturing on the main actor. Display stays gated by **`showsMediaSection`**, so keeping the snapshot has no visual effect when no query is active.
- **No behavior change:** search results, ordering, match reasons, and the media grid are unchanged — only the work scheduling is optimized (cache + reuse). Existing search/catalog tests continue to cover correctness; no new assertions since the observable output is identical.

**Summary:** Search performance — tapping a category tile now returns results without the noticeable delay (warm the index before the tap, and drop the debounce on discrete taps).

- **Bug fix — first category tile tap paid the full index build on the main actor:** the catalog warm (**`warmSearchCatalogIfNeeded`**) lived inside **`GlobalSearchSearchIndexLayer`**, which only mounts when the results panel appears — i.e. on the first tap — so warming never ran beforehand and the first scoped browse built the entire index (every dive + the full OpenDiveMap reference site index, thousands of rows) on the main actor while the panel was already sliding in. The built catalog is now cached in a shared **`GlobalSearchCatalogStore`** (via **`GlobalSearchCatalogWarming.ensureCatalog`**, keyed by the data **`fingerprint`**), and a hidden warmer instance of the layer (**`rendersResultsBody: false`**, mounted by **`GlobalSearchView.catalogWarmerLayer`** after the tab morph) builds it during idle time. The first tile tap then reuses the warm cache instead of building on the tap. The warmer unmounts while the (non-media) results layer is active — that visible instance owns the cache then — and resumes when the panel is dismissed or media-scoped.
- **Bug fix — 80 ms keystroke debounce applied to discrete taps:** **`scheduleSearchRefresh`** gained an **`immediate`** flag; category tile taps / scope changes and the scoped-browse **`onAppear`** now run **immediately** (no debounce), while typed queries keep the **80 ms** keystroke debounce. Removes an extra ~80 ms of latency from every tile tap.
- **No results/ordering change:** the shared store produces the exact same catalog as before (the fingerprint + build logic moved into **`GlobalSearchCatalogWarming`**, reused by both the results layer and the warmer). Tests: **`globalSearchCatalogWarming_fingerprintReflectsOwnerAndCounts`**, **`globalSearchCatalogWarming_ensureCatalogCachesByFingerprint`**.

**Summary:** Search performance — fix laggy results scrolling (stop re-resolving every row's display data on the main actor each frame).

- **Bug fix — search result rows recomputed their display data on every scroll frame:** each **`GlobalSearchScopedResultLabel`** resolved its row content inside SwiftUI `body` — linear `first(where:)` scans over all dives/sites/species/buddies/trips/equipment/certs, a **`DiveLogbookDisplay.rowData`** numbering pass per dive, and worst of all a **`DiveSiteReferenceCatalog.bundledReference().first(where:)`** scan over the **thousands-row** OpenDiveMap reference catalog **per reference-site row**. Because the row views were handed large, non-`Equatable` **`@Model`** arrays, SwiftUI re-ran all of that for every visible row whenever the list re-evaluated (including every scroll-offset tick from the count-title fade) — the cause of the frame drops.
- **Fix — precomputed, `Equatable` row content built once per results change:** new **`GlobalSearchResultRowContent`** (value type) + **`GlobalSearchResultRowContentBuilder`** (main actor, one pass: O(1) dictionary lookups for every category, dive numbering computed once across the owner's dives). The layer caches it (**`scopedRowContents`** / **`rowContentByID`**, rebuilt on **`displayedResults`** / unit-system change) and rows now render from it via the new lightweight **`GlobalSearchResultRowView`** (replaces the per-row-resolving **`GlobalSearchScopedResultLabel`**). Scrolling now only diffs cheap `Equatable` values, so SwiftUI skips re-rendering unchanged rows.
- **Fix — O(1) reference-site lookup:** **`DiveSiteReferenceCatalog.bundledReferenceByID()`** builds and caches a `[String: DiveSiteReferenceSnapshot]` map once, replacing the per-row full-catalog scan.
- **Enabler:** **`GlobalSearchPresentation.Section`** / **`Results`** are now **`Equatable`** so **`onChange(of: displayedResults)`** can drive the one-shot rebuild.
- Tests: **`diveSiteReferenceCatalog_bundledReferenceByID_keysMatchBundledReference`**, **`globalSearchResultRowContentBuilder_tagHitUsesHitFieldsAndTagArtwork`**, **`globalSearchResultRowContentBuilder_missingModelFallsBackToHitFields`**.

## 106 - Next batch **(pushed)**

**Summary:** Marine life — CRL EPUB image extraction pipeline + sync 452 new bundled hero photos into the app catalog (local dev).

- **New pipeline:** **`caribbean_reef_life_image_utils.py`** + **`extract_marine_life_images_from_crl.py`** index ~2,195 photos in the Caribbean Reef Life 4 EPUB (`OEBPS/image/`), match staging rows by scientific name (preferred) then common name, center-crop to 960×720, and write **`Resources/MarineLifePhotos/{uuid}.jpg`**. Rows tagged **`imageSource=caribbean-reef-life`**, **`imageNeedsReview=yes`**, **`imageLicense="© Mickey Charteris — permission required"`** (hold for review — same posture as reefguide; local dev sync only for now).
- **Coverage:** filename matching filled **452** of **803** image-less staging rows (invertebrates **189**, fishes **157**, plants **76**, corals **18**, sponges **12**). Remaining gaps use descriptive book filenames — still fillable via Commons/WoRMS.
- **Config:** **`caribbean_reef_life_config.json`** `default_epub_path` → `Desktop/dive example data/Caribbean Reef Life 4.epub`.
- **Synced to app:** **`sync_marine_life_staging_to_json.py --all`** — **1,407** species in **`marine_life_sample.json`**; **1,059** with **`feature_image_resource`** (452 new CRL bundles).
- **Docs:** **`MARINE_LIFE_CARIBBEAN_WORKFLOW.md`** — new CRL EPUB image section.
- Tests: **`test_caribbean_reef_life_image_utils.py`** (7 tests — filename parsing, scientific/common precedence, provenance marker).

**Summary:** Bug fix — Field Guide marine life category tile descriptions now actually wrap to two lines instead of showing one line + ellipsis.

- **Category tile subtitle wrap (real fix):** the earlier `maxWidth: .infinity` change wasn't enough — the subtitle **`Text`** on **`FieldGuideCategoryHubTile`** still truncated to one line because the frame's fixed **`maxHeight`** (exactly two line-heights) clipped the second line, so the text engine fell back to a single line + ellipsis. Added **`.fixedSize(horizontal: false, vertical: true)`** so the text takes the vertical space it needs to wrap up to its two-line limit, and dropped the hard **`maxHeight`** cap (kept **`minHeight: subtitleTwoLineMinHeight`** to reserve the block). Cosmetic view-layer fix — no logic change (the `subtitleTwoLineMinHeight` token is unchanged).

**Summary:** Marine life — removed 89 catalog entries whose common name was identical to the scientific name (no distinct common name).

- **Deleted 89 rows** from **`marine_life_caribbean_staging.csv`** where `commonName == scientificName` (sponges **33**, corals **21**, invertebrates **16**, fishes **11**, plants **8**), cleaned up their **28** orphaned bundled photos in **`Resources/MarineLifePhotos/`** and matching **`marine_life_bundle_photos_manifest.json`** entries.
- **Resynced:** **`sync_marine_life_staging_to_json.py --all`** — catalog now **1,318** species (was 1,407); **`MarineLifeCatalogSeeder`** removes the dropped uuids from the app on next launch.

**Summary:** Tests — fix Swift 6 main-actor `Equatable` warnings in search presentation types.

- **`GlobalSearchPresentation.MatchReason`** and **`GlobalSearchMediaBrowsePresentation.MediaKindCounts`** — explicit **`nonisolated`** `==` (and `hash` for **`MatchReason`**) so **`#expect`** in unit tests no longer triggers main-actor-isolated synthesized **`Equatable`** warnings.

## 107 - Next batch **(pushed)**

**Summary:** Home Top 10 pages (deepest / longest / sites / species) now use the same collapsible inline title as Dive Buddies and Certifications — title aligned with the back button, shrinks on scroll.

- **`HomeLifetimeStatsLeaderboardView`:** enabled **`collapsibleInlineTitleHeader: true`** on **`AppPage`** and dropped stacked **`AppHeaderStackedTitleChrome`** (title-below-back) placement — all four kinds share this one view, so deepest, longest, sites, and species get the Logbook-style chrome together.
- Presentation flag **`HomeLifetimeStatsLeaderboardPresentation.usesCollapsibleInlineTitleHeader`**; tests cover all four **`pageTitle`** strings + the chrome flag.
- **Titles:** **My Deepest Dives**, **My Longest Dives**, **My Top Sites**, **My Top Marine Life**.

**Summary:** Home featured media — faster carousel load (stop full-quality video upgrade, restore tiered photo warm, parallelize preview JPEGs, stabilize load keys).

- **Bug fix — Home videos silently requested full-quality streams:** **`DiveActivityVideoPlayerView`** treated **`.homeCarousel`** as **`allowsBackgroundUpgrade: true`**, so after the preview stream was ready it immediately requested PhotoKit **`.highQualityFormat`** — a large iCloud download that contended with image warm. Home now never schedules a full-quality upgrade (**`DiveMediaProgressivePresentation.allowsFullQualityUpgrade`** is false for **`.homeCarousel`**); carousel playback stays on the lighter **`.automatic`** / preview stream.
- **Bug fix — tiered bootstrap was dead:** **`warmBootstrapTier`** warmed all three slides at **`.full`** despite **`bootstrapQuality(forCarouselIndex:)`** (slide **0** full, slides **1…n** preview). Wired the presentation policy back into warm so off-screen slides stay at preview quality.
- **Preview JPEG capture no longer blocks warm:** **`scheduleCarouselWarmupIfNeeded`** runs **`ensureStoredPreviews`** in parallel with **`warmHighlights`** via a MainActor **`TaskGroup`** (existing **`previewJPEGData`** is already seeded first). **`ensureStoredPreviews`** itself captures missing JPEGs via a parallel **`TaskGroup`** instead of serial awaits.
- **Stabilize progressive image loads:** **`HomeMediaCarouselPresentation.stableImageLoadWidth`** buckets container width to **8 pt** for **`loadTaskID`** and hero cache edges so ±1 pt geometry jitter does not cancel/restart PhotoKit requests.
- Tests: **`allowsFullQualityUpgrade`** for Home vs full quality; **`stableImageLoadWidth`** bucketing.

**Summary:** Home / dive media progressive ladder restored — still preview → low-res → high-res with live upgrade (fix stuck soft previews + video timeouts).

- **Bug fix — soft JPEGs masked sharper frames:** display used **`sessionCachedImage ?? loadedImage`**, and session cache stored 256px **`previewJPEGData`** under the **480** edge — so once a soft preview existed, progressive hero/final frames never showed. **`preferredStillImage`** now prefers the progressive / loaded frame; **`bestCachedImage`** returns the **largest** cached frame for an asset (not a fixed 780/480 lookup that miss-matched bucketed edges).
- **Bug fix — videos never left preview tier:** the prior pass blocked full upgrade for **`.homeCarousel`**, which also broke the dive Media tab (same quality). Restored the ladder: poster → **`.homeCarousel`** / preview stream → **`.fullQuality`** while playing (and Home may background-upgrade session-pinned carousel clips via **`allowsBackgroundFullVideoUpgrade`**). Playback swaps streams in place.
- **Home warm:** all **3** carousel stills warm at hero **`.full`** again and stay session-pinned; videos warm at preview first, then upgrade. Preview JPEG fill still runs in parallel with warm (does not block it).
- Tests: preferred still priority; Home allows full upgrade + background upgrade; Media uses playback-gated upgrade only.

**Summary:** Media ladder contention fix — stop racing full-quality video against preview; prefer sharpest still by pixel area.

- **Bug fix — videos starved / timed out:** full-quality upgrades started as soon as preview *resolved* (and Home used background upgrade), flooding PhotoKit while the preview stream still needed iCloud. Full upgrade now waits until preview is **display-ready**, then delays **~400 ms**, and **never** background-upgrades. Home warm runs heroes + preview videos first; missing JPEG capture runs after warm (not in parallel with it).
- **Bug fix — soft previews stuck:** **`preferredStillImage(UIImage…)`** now picks the **largest pixel area** among progressive / session / stored candidates so a 256px JPEG cannot mask a warmed hero. Home video slides request **poster-sized** stills only (not full hero edges) so image loads do not compete with **`requestAVAsset`**. Home warm order: photo heroes → video posters → preview AVAssets → missing JPEG fill.
- Tests: **`shouldScheduleFullVideoUpgrade`** requires display-ready; background full upgrade stays off; UIImage preferred still by area; **`bootstrapStillQuality`** video → preview.

**Summary:** Soft JPEG false cache hits — soft **256 px** was keyed as edge **480**, so warm/load skipped PhotoKit forever.

- **Bug fix — stuck on low-res previews:** **`DiveMediaPreviewStorage.seedSessionCacheIfNeeded`** now stores soft JPEGs under **`storedPreviewSessionEdge` (256)**, not **`previewImageEdge` (480)**. Session cache lookups reject frames whose pixel size does not satisfy the requested edge (**`sessionCachedImageSatisfiesRequestedEdge`**), so legacy soft-under-480 entries no longer short-circuit progressive / hero loads. Preview warm no longer early-returns on “has stored JPEG alone.”
- Tests: soft JPEG does not satisfy preview edge; session cache rejects soft frames under the **480** key.

**Summary:** Home video never reaches previewReady — duplicate `requestAVAsset` races + still PhotoKit competing.

- **Bug fix — video stuck after `video resolve began`:** Home slide warm, player resolve, poster fetch, and still upgrade all hit PhotoKit at once; one call timed out with **`nil`** even when another already had the **`AVAsset`**. **`loadVideoAsset`** now **coalesces inflight** requests per identifier+quality, rechecks session cache after timeout, and late PhotoKit successes still seed the session cache. Soft posters skip extra still PhotoKit loads while the video resolves; player skips poster PhotoKit when an initial soft frame already exists.
- Warm logs now include **`loaded=`** so Console can distinguish fail vs success (`cacheHit=false` alone was ambiguous).
- Tests: preferred asset after raced request; skip still load while video resolves.

**Summary:** Home video `→ failed` / `loaded=false` — switch playback to PhotoKit **`requestPlayerItem`** (stream) instead of **`requestAVAsset`** (full download).

- **Bug fix — carousel video PhotoKit nil / timeout:** Apple recommends **`requestPlayerItem`** for playback; **`requestAVAsset`** waits on a full iCloud download and was failing under the timeout while the soft poster stayed up. **`.homeCarousel`** now loads via **`requestPlayerItem`** (asset cached from the player item); **`.fullQuality`** keeps **`requestAVAsset`** for Fishial/export. Timeouts are quality-specific (**30 s** preview / **45 s** full). Failed requests log **`video asset request failed`** with timedOut / net / iCloud / error detail.
- Tests: **`usesPlayerItemRequest`**, failure detail formatting, quality timeouts.

**Summary:** All carousel videos `timedOut net=1 30.1s` together — parallel PhotoKit video requests starved each other.

- **Bug fix — serial PhotoKit video lane:** at most one library video request at a time (**`DiveMediaVideoPhotoKitGate`**); Home warm loads videos **serially** (priority / first slide first); inactive slides no longer call **`ensureCarouselVideoReady`**. Soft timeout **30 s** only when no iCloud progress; hard cap **90 s** while progress advances.
- Tests: active-only ensure; priority warm order; soft/hard timeout policy.

**Summary:** Home videos hung ~30 s because we blocked on **`playerItem.asset`** inside PhotoKit’s callback (full iCloud download) then re-wrapped that asset into a new **`AVPlayerItem`**.

- **Bug fix — use streaming player items as-is:** Home / overview **`playerItem`** returns PhotoKit’s **`requestPlayerItem`** result directly and never reads **`.asset`** in that callback. **`DiveActivityFillVideoPlayerUIView`** plays that item without **`AVPlayerItem(asset:)`**. Carousel warm uses one streaming snapshot for the visible clip (no **`requestAVAsset`** warm). Success logs **`video asset request ready … Xs`**. Soft timeout back to **15 s**.
- Tests: **`shouldExtractAssetInPlayerItemCallback`** is false; soft timeout **15 s**.

**Summary:** First Home video played; slides **2–3** never prepared — warm stopped after the first clip and only the active slide called ensure.

- **Bug fix — remaining carousel videos stay soft / unloaded:** warm streams **all** carousel videos serially (priority first). Active **and adjacent** slides set **`shouldPrepareVideo`** so neighbors prefetch a streaming player item before swipe.
- Tests: adjacent ensure + adjacent logical indices wrap.

**Summary:** Home featured videos — simple PhotoKit streaming preload for all **3** carousel clips.

- **Home video path simplified:** **`HomeCarouselVideoSessionCache`** preloads up to **3** library videos in **parallel** via **`requestPlayerItem`** only (muted **`AVPlayer`**, no app-local file, never reads **`.asset`** in the PhotoKit callback). Home slides play through **`HomeCarouselMutedVideoPlayer`** instead of the progressive dive Media player. Still images / other screens still load on demand.
- Tests: **`HomeCarouselVideoPresentation`** preload filters.

**Summary:** Root-cause fix from device logs — `.automatic` video delivery forced full iCloud downloads (every `requestPlayerItem` timed out with zero callbacks), and opportunistic still loads hung forever discarding local thumbnails. Plus: featured media now starts loading during the launch screen.

- **Evidence (Dre's Phone, fresh launch):** both carousel videos failed **`timedOut net=1 20.3s`** with no PhotoKit callback at all; the slide-0 **photo** hero also never delivered a final frame (no `load ended` for 2.5 min). Library has ~20k photos / ~3.8k videos in iCloud (optimized storage → originals remote).
- **Bug fix — video delivery tier:** **`.homeCarousel`** now requests **`.mediumQualityFormat`** (streamable medium rendition) instead of **`.automatic`**, which resolved to the full-quality original on optimized-storage libraries — a download far larger than the timeout window. Applies to Home carousel and dive-overview preview playback (**`DiveMediaVideoRequestQuality.photoKitDeliveryMode`**).
- **Bug fix — stills hung forever on stalled iCloud finals:** **`DiveMediaReferenceLoader`** opportunistic requests now keep the **degraded local thumbnail** and, after **`DiveMediaStillLoad.requestTimeoutSeconds`** (20 s) without a final frame, resolve with it instead of hanging the caller (warm tasks, hero loads, launch overlay). Degraded fallbacks are **displayed but never cached** (**`shouldCacheFetchedImage`**), so future loads still upgrade. Progressive loads get the same timeout resume; late finals still flow to the UI and caches.
- **Home video diagnostics:** the simple path now sets a **`progressHandler`** (logs `video load progress … %`) and uses the shared progress-aware timeout (soft 20 s only with **no** iCloud progress, hard 90 s) instead of a flat cutoff; still-timeout fallbacks log `still request timed out … degradedFallback=`.
- **Feature — preload during launch screen:** **`HomeCarouselLaunchPreload`** persists today's 3 carousel picks (owner + daily seed + Photos pointers/kinds). On next launch, as soon as the app shell shows, it preloads all 3 posters and muted video streams — before the Home aggregate rebuild (~3.5 s) even finishes. No-ops when the owner or day changed.
- **Bug fix — carousel picks reshuffled every launch:** **`HomeMediaHighlightPresentation.dailySeed`** used Swift's **`Hasher`**, which is randomly seeded **per process** — so "daily" picks actually changed on every cold launch (confirmed on device: different assets each run), defeating both the daily-pick UX and the launch preload. Replaced with a deterministic **FNV-1a** hash over owner UUID + year + day-of-year.
- Tests: still-load cache/fallback policy; launch-preload owner+seed matching and pointer/kind entry building; `.homeCarousel` delivery mode is `.mediumQualityFormat`.

**Summary:** Home carousel slide **0** starved by neighbor video prepares + parallel PhotoKit.

- **Bug fix — first featured item often failed while slides 2–3 worked:** video prepare for the active slide was gated on **`isPlaybackAllowed`** (carousel `onAppear` + scene active). Before that, only **neighbors** of index **0** (slides **1** and **n−1**) called **`shouldPrepareVideo`**, so they claimed PhotoKit first and slide **0** timed out or stayed on the soft poster. Prepare now keys off the selected logical index (playback itself still waits for visibility).
- **Bug fix — parallel Home video `requestPlayerItem`:** **`HomeCarouselVideoSessionCache.preload`** is serial again (caller order / priority first) and each request goes through **`DiveMediaVideoPhotoKitGate`**. Launch poster preload loads slide **0** before the rest; warm stills warm media row **0** first.
- **Bug fix — soft-skip stuck after failed video:** if prepare finishes without a player, the slide forces a still upgrade instead of leaving the **256 px** JPEG forever.
- Tests: **`shouldPrepareCarouselVideo`** includes active index **0**; soft-skip requires prepare in-flight/ready.

**Summary:** Muted in-app video must not stop Music / other phone playback.

- **Bug fix — Home carousel video interrupted other audio:** **`HomeCarouselMutedVideoPlayer`** never called **`DiveMutedVideoAudioSession`** (dive overview / onboarding already did). **`AVPlayer`** then activated the default **`.playback`** session and paused Music. Home now sets **`.ambient` + `.mixWithOthers`** before every **`play()`** (and when building carousel players). Dive / onboarding play paths re-assert the same. Session config is re-applied on each activate (no one-shot) so a later default session steal cannot stick.
- Tests: ambient + mixWithOthers policy unchanged.

**Summary:** Fix Home slide **0** stuck / silent + reshuffle featured media on every cold launch.

- **Bug fix — looping pager silenced slide 0:** with 3 picks the TabView mounts a duplicate of slide **0** as the last page; both pages shared the same logical index and both set **`isVideoPlaybackActive`**, so two **`AVPlayerLayer`**s fought one shared muted player (and **`detach()`** paused it). Playback now requires the **selected pager index**. **`detach()`** no longer pauses the shared player.
- **Bug fix — all 3 videos prepared at once:** prepare is now **active + forward neighbor** only (not wrap-previous), so slide **0** is not starved by slides **1** and **2** on first paint.
- **Bug fix — one-shot soft timeout left slide 0 on a poster:** **`ensurePlayer`** retries up to **3** times; late PhotoKit items after soft timeout are still cached; the slide polls briefly for a late player before falling back to still upgrade.
- **Behavior — new featured picks each launch:** carousel shuffle uses **`carouselShuffleSeed`** (daily FNV salt ⊕ per-process nonce). Cross-launch UserDefaults preload is disabled so yesterday’s picks cannot pin PhotoKit to the wrong assets.
- Tests: pager playback gating; prepare excludes wrap-previous; launch preload always off; shuffle seed salts daily seed.

**Summary:** First Home carousel video stayed frozen until swipe-away / swipe-back.

- **Bug fix — `play()` before AVPlayerItem ready:** muted Home player called **`play()`** immediately (and raced with **`seek`**). Item often still **`.unknown`**, so rate stayed **0** until a remount on swipe. Now observes **`.status == .readyToPlay`** (with **`.initial`**), seeks then plays from the seek completion, and remounts when the selected page becomes active if a cached player already exists.

**Summary:** Home featured videos loop while visible.

- **Bug fix — muted carousel clips played once then froze:** looping was gated to fish/buddy overlay hold only; normal play called **`onSlideFinished`** and often left the item on its last frame. Videos now **always loop** while the pager page is active; multi-slide carousels still auto-advance after one playthrough (asset duration, or photo dwell fallback).
- Tests: **`shouldLoopCarouselVideo`**, **`videoAutoAdvanceSeconds`**.

**Summary:** Hold-to-pause for videos in Search media grid fullscreen (and other linked-media galleries).

- **Bug fix — hold-to-pause never fired in media search fullscreen:** **`LinkedMediaFullscreenView`** mounts **`DiveActivityMediaItemView`** with **`allowsHitTesting(false)`** so browse/dismiss drags win — which also blocked the item’s long-press. Hold-to-pause now lives on the gallery’s interactive surface and is passed down as **`isPausedByUserHoldFromParent`** (clears on swipe / media change / marine-life overlay). Same path as trip / buddy / dive-site tagged media grids.
- Tests: parent owns hold when media hit-testing is disabled.

**Summary:** Media grid fish + buddy corner icons (Search / trip / site galleries).

- **UX — media grid tag badges (tagged-only):** preview tiles show accent **buddy** (**bottom-leading**) and **fish** (**bottom-trailing**) only when that media has buddy / marine-life tags (no empty white icons). Shared **`linkedMediaGridTagBadges`**; Search → Media + general search media strip included. Buddy detail media grid now receives sightings so fish badges appear when species are tagged too.
- Tests: **`showsTagIcon`**.

**Summary:** Fullscreen media fish button → dive-style tagged species sheet overlay (not full-bleed card).

- **`LinkedMediaFullscreenView`** (Search media, trip / site / buddy galleries): tapping the marine-life fish when the item has tags presents **`LinkedMediaTaggedMarineLifeSheet`** (medium/large detents + **`appSheetPresentationChrome`**) with the same species selector + overview as dive Media **large** detent; video pauses while the sheet is up.
- Removed the inline **`TripDetailMediaMarineLifeOverlay`** path from this fullscreen chrome.
- Presentation gate **`LinkedMediaFullscreenPresentation.shouldPresentTaggedMarineLifeSheet`**; test for button+tags requirement.

**Summary:** Search → Media grid groups thumbnails under month/year section dividers (same header style as multi-category search).

- **`GlobalSearchMediaResultsView`:** month sections newest-first (**March 2026**), using shared **`GlobalSearchResultsSectionHeader`**; one cross-month fullscreen pager.
- **`GlobalSearchMediaBrowsePresentation.monthSections`** / **`MonthSection`**; **`MediaEntry.diveStartTime`** + **`sectionDate`** (`capturedAt` ?? dive start).
- Tests: **`globalSearchMediaBrowsePresentation_monthSections_groupsNewestMonthFirstUsingCaptureOrDiveDate`**.

**Summary:** Media preview tiles — buddy badge lower-left, fish lower-right; icons only when tagged.

- **`LinkedMediaGridSection`** / Search media grids: accent **person.2** bottom-leading and **fish** bottom-trailing, only when that media has buddy / species tags. Shared **`linkedMediaGridTagBadges`**.
- Buddy tagged-media grid now gets sightings so fish badges can appear; untagged tiles stay clean (no white placeholders).
- Tests: **`showsTagIcon`**.

**Summary:** Fullscreen media playback always shows fish + buddy so tags can be added.

- **`TripDetailMediaGalleryOverlayControls`:** buddy lower-left + fish lower-right always (accent when tagged, white when not). Tap opens **`DiveMediaBuddyTagsSheet`** / **`DiveMarineLifeMediaTagsSheet`**. Preview tiles stay tagged-only.
- **`LinkedMediaFullscreenPresentation.shouldPresentMediaTagSheet`**; tests for gate + active state.

**Summary:** Search → Media grid scroll performance — lazy sections, no scroll-driven rebuilds, soft JPEG thumbnails.

- **`LazyVStack`** for month sections (was eager **`VStack`** inside **`ScrollView`**, which mounted every cell).
- Grid body is **`Equatable`** so count-title fade (**`scrollOffset`**) does not rebuild thumbnails every frame.
- Precomputed **`marineLifeTaggedMediaIDs`** / **`buddyTaggedMediaIDs`** on **`DisplayCache`**; grid uses stored-preview-only thumbnails (no PhotoKit while scrolling); square cells use **`Color.clear.aspectRatio(1)`** + overlay fill (no per-cell **`GeometryReader`**).

**Summary:** Restore square linked-media grid cells after scroll perf pass.

- **Bug fix — portrait/landscape tiles in the 3-column grid:** cells drove layout from the image’s natural aspect instead of a square clip. Restored **`aspectRatio(1)`** square shells with **`scaledToFill`** thumbnails; kept stored-preview + lazy sections.
- **`LinkedMediaGridPresentation.cellAspectRatio`**; test asserts square cells.

**Summary:** Search → Media month headers pin at the top like multi-category search.

- **`GlobalSearchMediaResultsView`:** month/year titles use a plain **`List`** with **`Section`** headers + the same **`scrollContentTopMargin`** as sectioned search results so they stick under the back row while scrolling.
- Grid thumbs stay **`Equatable`**; **`pinsMonthSectionHeaders`** flag + test.

**Summary:** Slightly sharper linked-media grid thumbnails.

- Raised grid PhotoKit edge (**`gridThumbnailPointSize` 128 → 180**, **`photoKitRequestEdge` 360**) so 3-column tiles can clear soft **256 px** JPEGs.
- Search → Media paints stored soft first, then upgrades via PhotoKit (no longer stored-preview-only). Soft JPEG size on disk stays **256**.
- Tests: grid point / PhotoKit edge metrics.

**Summary:** Fullscreen media fish → transparent tagged-species details sheet (dive Media large detent).

- **`LinkedMediaFullscreenView`:** fish with tags opens **`LinkedMediaTaggedMarineLifeSheet`** (**medium** / **large** + **`appSheetPresentationChrome`**) — species chips + overview over the media; fish without tags still opens **`DiveMarineLifeMediaTagsSheet`** to add tags. Buddy control unchanged.
- Restored **`shouldPresentTaggedMarineLifeSheet`**; tests cover the gate.

**Summary:** Fullscreen media buddy → transparent tagged-buddies sheet (avatar + name).

- **`LinkedMediaTaggedBuddiesSheet`:** same medium/large frosted chrome as the species sheet; 3-column grid of profile photo + display name.
- Fish / buddy with tags → details sheets; without tags → tagging sheets. **`shouldPresentTaggedBuddiesSheet`** + tests.

**Summary:** Tagged species / buddy overview sheets get upper-right **+** to add more tags.

- **`LinkedMediaTaggedMarineLifeSheet`** / **`LinkedMediaTaggedBuddiesSheet`:** Liquid Glass trailing **plus** opens the existing marine-life / buddy tagging sheets; lists refresh on dismiss.
- **`LinkedMediaTaggedOverviewSheetPresentation.showsAddTagsControl`** gated on media + dive.

**Summary:** Dive Media **large** detent also shows trailing **+** to tag marine life.

- **`DiveActivityPhotosPanelContent`:** upper-right Liquid Glass **plus** at **large** (same control as fullscreen species overview) opens the marine-life tag sheet; untagged prompt points at **+**.
- **`showsLargeDetentAddMarineLifeControl`**; tests updated for chrome/prompt.

**Summary:** Dive Media **medium** fish expands the sheet to **large** (instead of opening tagging).

- Sheet chrome **fish** prefers **`onExpandMarineLifeDetail`** → **large** detent; tagging stays on **large** **+** (and the medium untagged prompt).
- **`opensMarineLifeDetailOnSheetFishTap`**; test covers medium-only gate.

**Summary:** Dive Media **large** fish/buddy toggle (map/media chrome) switches tagged overviews.

- Upper-leading **`DiveActivityMediaLargeDetentModeToggle`** (**fish** / **person.2**) matches pushed hero map/media chrome; trailing **+** opens marine-life or buddy tagging based on mode.
- Buddy mode shows avatar + name grid (or untagged prompt); fish mode keeps species detail.
- Tests for mode icons, buddy **+** gate, chrome height.

**Summary:** Dive Media **medium** buddy icon opens **large** with the buddy toggle selected.

- Medium sheet chrome **buddy** sets **`largeDetentMode = .buddies`** then expands (mirrors fish → marine life); tagging stays on **large** **+**.
- **`opensBuddyOverviewOnSheetBuddyTap`**; test covers medium-only gate.

**Summary:** Search media grid fish/buddy badges open the dive Media **large** overview sheet.

- Shared **`DiveActivityMediaLargeDetentOverviewSheet`** (**large** + frosted chrome) — same fish/buddy toggle and **+** as dive Media.
- Search → Media (and typed-search Media section): fish badge → fullscreen + marine-life overview; buddy badge → fullscreen + buddies overview. Fullscreen chrome fish/buddy use the same sheet.
- **`LinkedMediaGridPresentation.tagOverviewMode`**; dive panel large body reuses **`DiveActivityMediaLargeDetentOverviewContent`**.

**Summary:** Fullscreen media **View** opens the dive on **map**; top chrome vertically aligned.

- **`LinkedMediaFullscreenLinkedDiveCover`** presents **`ViewSingleActivity`** without media focus (default **map** tab), not **Media**.
- Shared **`topChromeControlHeight` (48)** — **X**, **View**, and **#/#** share one vertical center.
- Docs **`search.md`**; test for control height.

**Summary:** Fullscreen media **X** matches app toolbar / back button size.

- Close uses **`appToolbarIconButtonLabel()`** + **`appStandaloneIconButtonStyle()`** (same **44** glass chrome as back / other **×**).
- **`topChromeControlHeight`** is **44** (same as glass chrome / back buttons); stored as a literal for **`nonisolated`** access.

**Summary:** Search → Media month headers clear the videos/photos count title.

- Media browse top margin uses **`scrollContentTopMarginBelowChrome(chromeHeight:)`** (same clearance as scoped results under the floating chrome), not the multi-category **12 pt** pin-on-back-row margin — so **March 2026** no longer clips into **X videos, X photos**.
- Test covers below-chrome vs on-back-row margins.

**Summary:** Fullscreen fish/buddy overview stays frosted over playing media (dive Media **large**).

- Overview sheet uses **`embeddedOverviewTranslucentOpacity`** (**0.62**) instead of denser default sheet chrome.
- Video keeps playing under the overview; only nested tagging sheets pause (**`shouldPauseVideoForPresentedTagChrome`**).
- Test covers pause gate + translucency token.

**Summary:** Media grid fish/buddy corners always accent blue + count capsules (Home style).

- Corner icons always show (not tagged-only); **`showsTagCountBadge`** when count **> 1** (same as Home carousel).
- Search Media / results grids pass tag counts from **`DisplayCache`**.
- Tests updated for always-on icons + count badge gate.

**Summary:** Fullscreen media top chrome — centered **#/#**, white **View**.

- Position chip is horizontally centered in the top row (**`ZStack`**), independent of **View** placement.
- **View** chip label uses white (not accent).

**Summary:** Dive **Tank** / **Media** medium sheets keep the map identity header.

- Shared **`DiveActivityMapOverviewHeader`** (dive **#**, site, place, date/time) on **Tank** medium+large and **Media** medium (above species chips / empty prompt).
- **`showsDiveIdentityHeaderInSheet`**; docs + test.

**Summary:** Large Media marine-life hero — no letterbox bars, top fade like Home.

- Media-sheet catalog photos no longer draw the blue/gradient letterbox fill; image is centered with **`.fit`**.
- Top fade to transparency reuses Home fish-overlay opaque stop; placeholder dropsthe filled rectangle.
- Test ties fade stop to Home carousel token.

**Summary:** Media grid badges tagged-only; fullscreen fish/buddy always on with count badges.

- Search / linked media **grid** previews show accent fish / buddy only when that item has tags; multi-tag count capsules stay **> 1**.
- Fullscreen playback keeps fish / buddy **always** accent; notification-style badge shows tag count when **≥ 1**.
- Tests: **`showsTagIcon`**, fullscreen **`showsTagCountBadge`**.

**Summary:** Fullscreen fish/buddy overview uses dive Media translucent panel (not opaque sheet).

- Tag overview is an **in-hierarchy** frosted panel (**`diveActivityMediaLargeDetentOverviewEmbeddedChrome`**) matching dive Media **`usesTranslucentChrome`**, so playing media shows through.
- System **`.sheet`** over fullscreen was compositing opaque; cleared-background sheet helper remains as a fallback.
- Panel height matches dive **large** detent; tap above / grabber dismisses. Test covers panel height helper.

**Summary:** Fish/buddy tag count badges are circular (Home shared chip).

- Shared **`MediaTagCountBadge`** — fixed equal **18×18** frame + **`Circle`** fill (no stretched capsule).
- Home carousel, fullscreen playback, and media grid all use it.

**Summary:** Fullscreen playback chrome uses Liquid Glass.

- **X** stays **`.glass`** circular toolbar; **View** + **#/#** use capsule **`appLiquidGlassSearchFieldChrome`**; **buddy** / **fish** (and star) use **`appLiquidGlassCircleChrome`** like Home.
- Overlay rows wrapped in **`GlassEffectContainer`**. Dropped hand-rolled black/material icon fills.

**Summary:** Fullscreen chrome — Home dive chip lower-left; merged buddy/fish glass group.

- Replaced **View** with shared **`MediaDiveLinkChromeButton`** (book, site, **#** · trip) opening the dive.
- Buddy + fish sit lower-right in one Liquid Glass union ([toolbars](https://developer.apple.com/design/Human-Interface-Guidelines/toolbars)); accent when tagged, white when not (no count badges).
- **#/#** stays top-centered; Home carousel reuses the same dive chip.

**Summary:** Fullscreen **#/#** moves upper-left beside **X**, matching glass control height.

- Position chip shares the leading top row with **X** (**`topChromeControlHeight`** / **44**).
- Removed centered top placement from the bottom overlay controls.

**Summary:** Large marine-life overview — Fishial sparkles leading **+** in one glass group.

- On fish mode, pink→purple **sparkles** leads **+** in a shared Liquid Glass union (**`DiveActivityMediaLargeDetentMarineLifeTrailingActions`**); opens Identify fish when configured.
- Same chrome on dive Media **large** and fullscreen overview sheet; buddy mode keeps **+** alone.

**Summary:** Playback **#/#** plain text upper-right; dual icons use one capsule.

- Position label is unstyled white text (no glass chip), trailing in the top row.
- Buddy/fish and Fishial/**+** use **`AppLiquidGlassIconPair`** — one capsule border wrapping both glyphs.

**Summary:** Fullscreen frosted tag overview — centered fish/buddy toggle, grabber swipe-down dismiss.

- **`DiveActivityMediaLargeDetentOverviewContent`:** fish/buddy toggle is horizontally centered.
- Grabber drag follows the finger and dismisses past **`tagOverviewGrabberDismissThreshold`** (**`shouldDismissTagOverview`**); tap above the panel also closes.
- Test: **`linkedMediaFullscreenPresentation_shouldDismissTagOverview_usesGrabberThreshold`**.

**Summary:** Fullscreen fish/buddy capsule matches dive chip height.

- **`AppLiquidGlassIconPair.mediaTagControls`** uses **`HomeMediaCarouselPresentation.slideChromeControlHeight`** (same as **`MediaDiveLinkChromeButton`**).

**Summary:** Tag-overview grabber tracks the finger live; sheet dismiss **X** removed.

- Grabber drag shrinks panel height with animations off (same pattern as dive overview grabber); no tap-vs-drag delay on the grabber.
- Close via swipe-down or tap above the panel; leading overview **X** removed so the toggle stays centered alone.

**Summary:** Fullscreen video — center play/pause; tap media to hide/show chrome.

- Liquid Glass **play** / **pause** (**`LinkedMediaFullscreenCenterPlaybackControl`**) centered on videos; hold-to-pause still works.
- Tap empty media toggles top, bottom, and center controls (**`showsPlaybackChrome`**); control taps do not toggle.
- Tests: **`linkedMediaFullscreenPresentation_playbackChrome_*`**.

**Summary:** Restore top chrome corners; remove fullscreen hold-to-pause.

- **X** / **#/#** again fill the height of a bottom-aligned **`ZStack`** so they stay upper-left / upper-right.
- Fullscreen hold-to-pause gesture removed so a tap on the video toggles chrome + center pause without delay; pause is center-button only.

**Summary:** Overlay **+** opens tag pickers; remove redundant tagged-list sheets.

- Large-detent / fullscreen overview **+** presents **`DiveMarineLifeTagPickerSheet`** / **`DiveMediaBuddyTagPickerSheet`** (same for dive Media medium tag actions).
- Removed **`DiveMarineLifeMediaTagsSheet`**, **`DiveMediaBuddyTagsSheet`**, and **`LinkedMediaTaggedMarineLifeSheet`** / **`LinkedMediaTaggedBuddiesSheet`** (overview content already lives on the frosted panel).

**Summary:** Overlay **+** icons are white (not accent blue).

- Standalone **+** and Fishial pair trailing **+** use white glyphs on the frosted overview chrome.

**Summary:** Overlay dismiss **X** upper-left; tag sheets use white circular glass icons.

- Fullscreen tag overview leading **X** closes the panel (playback **X** hides while the overlay is up).
- **Tag marine life** / **Tag buddy** sheets: leading white circular **X** (saves/dismisses); buddy **+** is the same white circular glass control.

**Summary:** Hide dive chip + fish/buddy chrome while tag overview is open.

- **`TripDetailMediaGalleryOverlayControls`** are removed from the hierarchy when **`showsTagOverviewSheet`** is true.

**Summary:** Overlay buddy avatar → buddy page; marine life **Learn More** → Field Guide.

- Tapping a buddy profile photo opens **`ViewDiveBuddyDetails`**.
- **Learn More** under tagged species opens **`FieldGuideMarineLifeDetailView`**.

**Summary:** Search → Media grid scroll lag — stop per-frame list invalidation and main-thread JPEG re-decodes.

- **Bug fix — count-title fade invalidated the list every scroll frame:** **`onScrollGeometryChange`** now transforms to the **derived title opacity** (not the raw offset), so the `@State` update / body re-evaluation only fires inside the 44 pt fade band instead of on every frame of a long scroll.
- **Bug fix — stored previews re-decoded per body evaluation:** **`DiveMediaPreviewStorage.storedPreviewImage`** caches decoded **256 px** JPEGs in an **`NSCache`** keyed by media ID (`previewJPEGData` is write-once), so grid cell bodies and `seedSessionCacheIfNeeded` stop constructing a fresh `UIImage` from data on the main actor each pass.
- **Bug fix — month-grid `Equatable` touched SwiftData per compare:** **`GlobalSearchMediaBrowseMonthGrid`** compares the display cache's precomputed **`mediaIDs`** instead of `mediaItems.map(\.id)` (model getter per item per invalidation).
- **Removed page-open hitch:** dropped bulk **`seedSessionCache(for:)`** over the whole filtered result set in `applyResolvedMedia` — the session cache holds only `carouselLimit` (3) entries, so decoding every stored JPEG just to evict them was wasted main-thread work; visible cells still seed themselves on appear.
- Test: **`diveMediaPreviewStorage_storedPreviewImage_reusesDecodedInstance`** (cached decode returns the same instance; missing data stays `nil`).

**Summary:** Search tab open lag — keep the warm-index work out of the tab-morph animation frames.

- **Bug fix — hidden search warmer mounted mid-morph:** **`scheduleDeferredSearchIndexMount`** deferred by a single `Task.yield()`, so one runloop tick after the Search tab appeared the warmer layer mounted **eight SwiftData `@Query` fetches** (including unscoped all-sightings / all-buddy-media-tags), bound the full species (~1.3k) + dive-site catalogs on the main actor, and built the entire search index (every dive + **3,123** OpenDiveMap reference sites) — all inside the opening animation. Mount now waits **`searchIndexWarmMountDelayNanoseconds`** (**450 ms**) so the morph finishes first; active search, tile taps, and pushed details still mount immediately (**`mountSearchIndexImmediatelyIfNeeded`**).
- **Off-main reference decode:** **`warmSearchCatalogIfNeeded`** pre-decodes the **~877 KB** reference JSON via `Task.detached` before the main-actor index build, which then reads the warm cache. **`DiveSiteReferenceCatalog`** caches are now **`NSLock`**-guarded so the background decode and main-thread readers stay consistent.
- Tests: **`diveSiteReferenceCatalog_concurrentAccessReturnsConsistentRows`**, **`globalSearchTabLaunch_warmIndexMountWaitsOutTabMorphButUserActionsMountImmediately`**.

**Summary:** Media tile open lag — hidden warmer now prebuilds the Search → Media grid cache so the tap paints from it.

- **Bug fix — Media grid rebuilt its whole index on the tile tap:** opening **Search → Media** ran **`GlobalSearchMediaIndexSnapshotBuilder.captureInput`** on the main actor (walking every dive, media photo relationship, buddy tag, and sighting) during the results-panel slide-in — then ran it a **second** time when the view's own species-catalog load finished and flipped the refresh token. New shared **`GlobalSearchMediaSnapshotStore`**: the hidden search warmer prebuilds the full display cache (snapshot + unfiltered month sections) during idle time, and **`GlobalSearchMediaResultsView`** paints from it on open (**`applyPrewarmedSnapshotIfCurrent`**) instead of re-capturing.
- **Double rebuild eliminated:** **`canReusePrewarmedSnapshot`** accepts a core-token match (all data counts except species) while the browse's species catalog is still loading — the warmer built the snapshot with species names included — and the later species-load re-fire lands on the exact-match no-op branch. A stale store falls back to the full rebuild, which then refreshes the store for the next open.
- **Warmer keeps the cache fresh:** the hidden layer's `mediaIndexRefreshToken` task now warms the store on data changes (**`warmMediaSnapshotIfNeeded`**, token-guarded); a typed query on open re-filters the prewarmed snapshot off-main instead of re-capturing.
- Tests: **`globalSearchMediaBrowse_coreDataTokenStripsSpeciesComponent`**, **`globalSearchMediaBrowse_prewarmedSnapshotReuseRules`**, **`globalSearchMediaSnapshotStore_holdsPrewarmedCacheForBrowseOpen`**.

**Summary:** Fullscreen tag overview — no **X**; close with grabber or tap above.

- Removed the leading dismiss **X** from the fish/buddy frosted overlay (`DiveActivityMediaLargeDetentOverviewContent` / `DiveActivityMediaLargeDetentOverviewSheet`). Close the overlay with the grabber (swipe down) or tap above the panel.
- Playback **X** stays for leaving fullscreen back to the media grid (still hidden while the overlay is open so it isn’t confused with overlay dismiss).

## 108 - Next batch **(pushed)**

**Summary:** Fix empty search results after popping back from a result detail; morphed field re-presents with keyboard hidden.

- **Bug:** returning from a pushed result showed empty text sections (dives, sites, species, …) while the Media section still loaded. Two causes: the hidden catalog warmer's `onDisappear` cancelled the **shared** `searchTask` binding right as the remounted results layer scheduled its refresh (media rebuilds on per-instance tasks, so it survived); and the transient `dismissSearch()` query clear on push wiped `displayedResults`.
- **`GlobalSearchIndexLayerPresentation`** (new) — `cancelsSharedSearchTaskOnDisappear` (only the visible results layer cancels the shared task) + `shouldClearResultsForInactiveSearch` (keep results while a detail push preserves the session). `GlobalSearchSearchIndexLayer` gains `preservesDetailPushResultsSession`.
- **Pop restore** — `restoreStackSearchPresentationIfNeeded` now resigns the keyboard after the morphed field presents (`stackSearchRestoreKeyboardDismissDelayNanoseconds`), so the field is open over the restored results but unfocused; preserved session retires after a completed restore.
- Tests: `globalSearchIndexLayer_onlyVisibleResultsLayerCancelsSharedSearchTaskOnDisappear`, `globalSearchIndexLayer_keepsDisplayedResultsWhileDetailPushPreservesSession`, `globalSearchPresentation_stackSearchRestoreDismissesKeyboardAfterPresentation`.
- **Follow-up (still reproduced on device):** three more holes closed. (1) **Row caches on remount** — `scopedRowContents` / `rowContentByID` are per-instance `@State` rebuilt only via `onChange(of: displayedResults)`, which skips equal values; after pop the refreshed results equal the preserved ones, so rows never rebuilt and every text hit rendered empty (`if let content = rowContentByID[hit.id]` failed) while Media rendered from its own cache. Rows now rebuild in `onAppear` (preserved results paint instantly) and after a refresh returning an unchanged value. (2) **Panel hidden by query blips** — `keepsResultsPanelThroughInactiveSearch` keeps `isResultsPanelVisible` through transient `.searchable` dismiss/reattach query clears while the session is preserved. (3) **Bar present swallowed mid-transition** — the morphed field now presents after `stackSearchRestoreAfterPopDelayNanoseconds` (550 ms, past the nav pop + returning tab bar), with bindings re-applied first in case reattach stomped them. Tests: `globalSearchPresentation_stackSearchRestorePresentsAfterPopTransitionSettles`, `globalSearchPushedDestinationPresentation_keepsResultsPanelThroughPreservedSessionBlips`.

**Summary:** Certification card hero — full-bleed width like media headers; seam alignment unchanged.

- Card photos size **width-first** (`maxWidth` + `fixedSize`) with **0** horizontal inset so width matches media/map heroes; bottom still sits on **`panelOverlap`** seam.

**Summary:** Certification card hero — bottom-align photos to the visible blue-sheet seam.

- Card images sit on the **rounded panel top** via **`cardPhotoSeamBottomInset`** (= **`HomeOverviewLayout.panelOverlap`**), not under the sheet or centered high in the full hero band.
- Presentation token + unit test.

**Summary:** Field Guide glow — plate under model + upward particle spray; **3D** heroes **~40%** smaller.

- Glow disc **Y** sits **below** the model’s lowest point (clearance subtracted, not into the mesh).
- Particles emit on world **+Y** with a hemispheric **`spreadingAngle`** so sparkles shoot outward above the plate; thin cylinder emitter under the mesh.
- Scene order: glow/particles added before the USDZ; **`fitExtent`** **0.2304** (**0.384 × 0.6**).
- Tests updated for fit extent, disc placement, and emission direction.

**Summary:** Migrate certification detail onto the blue sheet template (front/back hero, two-page pager, dives-since-attained).

- **`ViewCertificationDetails`** — **`BlueSheetDetailPage`** + **`BlueSheetDetailTopChrome`** (Edit); ocean-gradient hero letterboxes card photos so unmatched aspect ratios don’t leave empty bars; front/back glass toggle only when **both** photos exist; type badge pinned **above** the certification name.
- **Pager** — **Details** (agency, number, date attained, dives logged on/after the attained day) → **Instructor & shop** (instructor, instructor #, dive shop, shop ID).
- **`CertificationPresentation.divesLoggedSinceAttainedCount`** / label helpers; hero/pager presentation types + unit tests.

**Summary:** Tank depth profile chart — labeled time/depth axes + scrub callout fields.

- **`DiveDepthProfileOverlayChart`** draws an **L**-shaped **x** (dive time, minutes) / **y** (depth, ft or m from **Settings**) axis with tick labels; plot insets leave room for chrome.
- Scrub callout now includes **Time** and **Depth** (pressure line unchanged when PSI samples exist).
- **`DiveDepthProfileChartAxisPresentation`** — nice ticks + label helpers; layout inset update; unit tests for formatting, ticks, and plot insets.

**Summary:** Four new Field Guide **3D** heroes (Meshy USDZ).

- Bundled **`Resources/MarineLife3D/`**: **`GreatBarracuda.usdz`**, **`SergeantMajor.usdz`**, **`RockBeauty.usdz`**, **`RedLionfish.usdz`**.
- **`marine_life_sample.json`** **`feature_model`** on **`marine-life-great-barracuda`**, **`marine-life-sergeant-major`**, **`marine-life-rock-beauty`**, **`marine-life-red-lionfish`** (existing installs pick up on catalog reseed).
- Seeder + hero presentation unit tests for each species.

**Summary:** Add missing **Caribbean reef shark** to Field Guide catalog.

- Confirmed in **Caribbean Reef Life 4** EPUB (ID plate): **`Carcharhinus perezii`**, to **3 m**; dorsal behind pectorals, dusky paired-fin tips, white abdomen.
- Seeded **`marine-life-caribbean-reef-shark`** in **`marine_life_sample.json`** + staging / CRL species reference; uses already-bundled photo (**CC0** Openverse); seeder test.

**Summary:** Field Guide **3D** heroes — **20%** smaller + accent glow disc.

- Default **`fitExtent`** **0.384** (**0.48 × 0.8**) for all bundled species configs.
- RealityKit soft **light-blue** (**accent**) grounded glow under each model — three additive **`UnlitMaterial`** discs (static while the model spins).
- Tests: fit extent + glow placement/tint helpers.

**Summary:** Field Guide glow — breathe animation + soft accent particles.

- Disc plate **pulses** (horizontal scale + slight vertical bob) each frame via **`SceneEvents.Update`**.
- RealityKit **`ParticleEmitterComponent.Presets.magic`** tuned to brand blue/cyan sparkles rising from the plate.
- Glow presentation helpers + unit tests for pulse / emitter footprint.

**Summary:** Certifications list tile — three text rows.

- Row layout: thumbnail + **name + type badge**, then **agency · #number**, then **date attained**.
- **`CertificationPresentation`** formats cert numbers with a leading **`#`**; list / subtitle helpers + unit tests.

**Summary:** Landscape tank depth chart — tighter side inset; hide **0 min** axis label.

- Landscape minimized chart horizontal inset **12 → 28** pt each side.
- Time axis omits the **0 min** tick label (end/mid labels unchanged).

**Summary:** Landscape depth chart — more side inset; time labels at mid + end only.

- Landscape horizontal inset **28 → 48** pt (clears Dynamic Island / edge chrome).
- Time axis shows only **halfway** and **end** of the visible window (no start / **0 min**).

**Summary:** Field Guide **3D** heroes — slightly larger models, lower glow plate, cool backdrop.

- Default **`fitExtent`** **0.22** (down from **0.28**); glow **`verticalClearance`** **0.018 → 0.18** so the disc + particles sit much lower under the mesh.
- Cool teal atmospheric wash: simple gradient backplate (no bloom discs) behind the model.
- Glow disc + particles are **siblings** of the spinning model anchor, centered on the yaw axis (**x/z = 0**) so they do not orbit with the mesh.
- Unit tests for fit, clearance, and spin-axis glow placement.

**Summary:** Field Guide **3D** hero scale from typical species size (non-linear).

- **`FieldGuideMarineLifeHeroFitExtentPresentation`** maps catalog min/max size (meters → ft) to **`fitExtent`**: steep mid-band (**0.5–6 ft**), compressed under **0.5 ft** and over **6 ft**; missing size → default plate.
- Field Guide detail, hero toggle preview, and dive media species hero pass **`minSizeMeters` / `maxSizeMeters`** into scene config.
- Unit tests cover average/max pick, mid-band slope emphasis, and barracuda vs sergeant major plating.

**Summary:** Marketing site dependency — Wix Premium + **godiveios.com**.

- Documented **Wix Premium** (GoDive / GoDive iOS project) and domain **godiveios.com** in **`app_summary.md`** External dependencies and **`docs/acknowledgments.md`**.
- Connected **godiveios.com** to the Wix site via pointing (GoDaddy DNS); landing-page ops notes in **`cursor/wix_landing_page.md`**.

**Summary:** Media **Tag marine life** sheet — trailing **Done** confirms tags.

- Trailing **Done** commits staged species tags and dismisses; leading **×** cancels without applying pending tags.
- Presentation helpers + unit test for Done/cancel identifiers.
- Leading **×** uses a plain toolbar button (no nested overlay glass) so Liquid Glass nav chrome is not double-outlined; white **×** icon.
- Trailing **Done** uses **`.glassProminent`** (matches **Tag buddy**).
- **Tag marine life** / **Tag buddy** use **`diveMediaTagPickerSheetPresentation`**: **large** only, visible grabber, interactive swipe-down dismiss (discards draft like **×**); no **medium** detent.

**Summary:** Media tab carousel — trailing **+** at medium; featured star on previews.

- Medium detent moves upload **+** to the carousel trailing edge (matches minimized).
- Featured star lives on carousel thumbnails: selected → always show (accent if featured, white if not; tap toggles); featured unselected → smaller accent star; non-featured unselected → no star.
- Presentation helpers + unit test for star visibility / scale; user guide + **`app_summary`** updated.

**Summary:** Media **medium** — fish/buddy trailing dive number; header matches Map/Tank.

- Fish / buddy move to the trailing side of the shared dive identity header (top-aligned with dive **#**); no reserved top chrome band so number / title / place / date match **Map** / **Tank** height.
- Empty-media hero: Liquid Glass **Upload Media** CTA above the sheet at **minimized** / **medium**.
- Tests + user guide / **`app_summary`** updated.

**Summary:** Media large overview — pin fish/buddy toggle + **+**; content scrolls under with fade.

- Fish/buddy mode toggle and trailing **+** / Fishial stay pinned; species detail and buddy grid scroll underneath.
- Soft top fade under the pinned chrome (no hard clip); outer Media panel scroll disabled so the inner host gets a bounded height.
- Unit tests for pinned chrome fade height and Media outer-scroll always-off; user guide / **`app_summary`** refreshed.

**Summary:** **Tag buddy** sheet toolbar — **×** left; **+** then **Done** on the right.

- Leading **×** discards draft tags; trailing **+** (add roster buddy) and **Done** (save) are separate toolbar buttons.
- Plain nav toolbar controls (no nested overlay glass); presentation identifier helpers + unit test.
- **+** / **Done** use separate Liquid Glass borders (**`ToolbarSpacer`**); **Done** uses **`.glassProminent`**.
- Sheet title **Tag buddy** centered via principal toolbar item (asymmetric trailing chrome no longer shifts it).
- Presentation switched from shared tags **medium/large** helper to media tag picker **large**-only dismissible chrome.

**Summary:** Lightweight crash analytics — MetricKit + abnormal-exit heuristic stored in SwiftData, opt-in CloudKit upload to the developer, viewable in **Settings → Crash Reports**.

- **`CrashReportRecord`** (`@Model`, in **`AppSwiftDataSchema`**) — kind, reason, versions, diagnostic details, **`sharedToCloudAt`**; **`CrashReport`** Sendable snapshot; **`CrashReportStore`** (per-call background **`ModelContext`**) with newest-first load, prune to **20**, pending-share fetch, mark-shared.
- **`CrashDiagnosticsCollector`** — **MetricKit** subscriber converts delivered **`MXCrashDiagnostic`**s (signal, exception, call-stack JSON) into stored reports (arrive on the launch after a crash; not while the debugger is attached).
- **`CrashSessionMarker`** heuristic — `UserDefaults` lifecycle marker; a launch that finds the previous session still **foreground** records an **Abnormal exit** report (catches watchdog kills / crashes MetricKit misses).
- **`CrashReportCloudUploader`** — uploads pending reports to the **CloudKit public database** (**`iCloud.PrimoSoftware.GoDiveMVP`**, record type **`CrashReport`**; oversized details ship as **`CKAsset`**); idempotent by report UUID; skips silently when offline / no iCloud account (retries next launch). Entitlements gain iCloud **CloudKit** + container id.
- **Settings → Share crash reports** toggle (**`goDiveShareCrashReports`**, default **off** — sharing is opt-in); enabling uploads the stored backlog immediately; new captures upload automatically while on.
- **`CrashReportingService.startAtLaunch(container:)`** wired in **`ProductionAppRoot.task`**; scene-phase changes keep the marker in sync. No third-party SDK.
- **Settings → Crash Reports** (`SettingsNavigationLinkRow`) — list with kind + date + reason + **Sent / Not sent to developer** status, detail page with monospaced diagnostic body, **Share** export (single or all) and confirmed **Clear All**.
- Tests: SwiftData store round-trip / prune / pending-share / mark-shared / delete-all, abnormal-exit decision, CloudKit record field mapping + details-asset threshold, share-toggle default off, reason-line + export formatting, kind + status labels. User guide **`docs/settings.md`** + **`docs/privacy-and-data.md`** + **`app_summary`** updated.

**Summary:** Enrich crash / abnormal-exit reports with a persistent UI breadcrumb trail (tab, dive overview, sheets, memory).

- **`CrashBreadcrumbTrail`** — ring of last **20** events in **`UserDefaults`** (survives the dying process); last UI context (root tab, screen, dive id/#, overview tab/detent, open sheet); process snapshot (uptime, memory footprint, machine id).
- Launch **freezes** the dying session's trail into a previous-session export, then starts a fresh trail — attached to **Abnormal exit** and **MetricKit** report bodies.
- Wired from root tab changes, dive overview appear/tab/detent, media tag/Fishial sheets, Settings / Crash Reports screens.
- Tests for ring prune, freeze/previous-session export, formatter, label helpers; user guide note on breadcrumbs.

**Summary:** Richer abnormal-exit breadcrumbs — media selection context + actions; keep session marker fresh while navigating.

- **`CrashBreadcrumbTrail.Context`** adds **mediaCount**, selected/featured media IDs, media kind, panel on/off, orientation, **lastAction**; dive overview lines encode the same.
- **`noteAction`** for carousel select, featured star, upload, open tag/Fishial.
- **`CrashSessionMarker.refreshDetailsPreservingState`** on every breadcrumb so the dying session’s marker is no longer stuck on launch-time **home**.
- Abnormal-exit reports prefer the frozen trail (plus a thin lifecycle preface) to avoid the duplicated stale+fresh blocks.
- Thermal state in process snapshot; unit tests for dive-overview encoding + lifecycle preface.

**Summary:** Fix Media-tab crash when rapidly selecting library videos in the carousel.

- Breadcrumb report: dive **#144** Media medium, **15** videos, last action **`carouselSelect`** after flipping between clips in ~1s.
- **Cause:** pager pages deferred-invalidated shared video session cache on **`onDisappear`**, racing remount of the same clip; neighbors also kept mounting **`AVPlayer`**s.
- **Fix:** mount overview **`DiveActivityVideoPlayerView`** only while that page is the active selection (poster otherwise); stop deferred invalidate on player disappear (snapshot only); invalidate dive video caches when leaving **`ViewSingleActivity`**.
- Test: **`mountsVideoPlayerForActivePlayback`**.

**Summary:** Harden Media video carousel crash under sustained rapid tapping.

- Follow-up crash still only **`carouselSelect`** between library videos (took longer — prior fix helped).
- **300 ms settle delay** before mounting an **`AVPlayer`** on dive overview pages (poster while flipping).
- Dive overview players **`reusesSessionPlayerAcrossRemounts: false`** — full **`stop()`** on dismantle, no SwiftUI snapshot/player cache reuse across remounts; release any cached owner of an **`AVPlayerItem`** before wrapping a new player.
- Tests for settle-mount policy.

**Summary:** CloudKit entitlement no longer breaks in-memory SwiftData tests / previews.

- With iCloud **CloudKit** entitlements for crash-report upload, ad-hoc **`ModelConfiguration`**s that omitted **`cloudKitDatabase: .none`** were treated as CloudKit-mirrored and failed load (missing inverses / non-optional attributes).
- All test + preview ad-hoc configs now pass **`.none`** (production **`AppSwiftDataSchema.makeContainer`** already did).
- Field Guide size→**fitExtent** small-band weight lowered so mid-band (**0.5–6 ft**) slope stays steeper than compressed tiny sizes; cert / Rock Beauty seeder expectations aligned with current `#` formatting and catalog casing.

## 109 - Next batch **(pushed)**

**Summary:** Three new Field Guide **3D** heroes (Meshy USDZ) sized from catalog length.

- Bundled **`Resources/MarineLife3D/`**: **`CaribbeanReefShark.usdz`**, **`Tarpon.usdz`**, **`StoplightParrotfish.usdz`**.
- **`marine_life_sample.json`** **`feature_model`** on **`marine-life-caribbean-reef-shark`**, **`marine-life-tarpon`**, **`marine-life-stoplight-parrotfish`**; tarpon gains **`max_size` 2.5 m** (and depth / family) so hero **`fitExtent`** uses the mid→large size curve (shark **3.0 m**, parrot **0.64 m** already present).
- Seeder + relative **fitExtent** unit tests; acknowledgments / **`app_summary`** lists updated.

**Summary:** Dive Media tagged-species panel defaults to the catalog photo, not 3D.

- **`mediaOverlayHeroKind`** prefers bundled/remote photo; 3D only when no catalog image (Field Guide detail toggle unchanged).
- **`DiveActivityMediaTaggedSpeciesDetailContent`** uses that helper; unit test.

**Summary:** Field Guide **3D** heroes — drop teal backplate / wash.

- Removed SwiftUI gradient wash and RealityKit scene plate behind USDZ models (glow disc + particles under the mesh stay).
- Heroes render in a non-AR **`ARView`** with a **clear** environment so the page / blue sheet shows through (virtual **`RealityView`** canvas was opaque).
- **`FieldGuideMarineLifeHeroBackdropPresentation`** deleted; backdrop unit test removed.

**Summary:** Field Guide **3D** heroes — lower glow + subtle vertical bob.

- Glow plate **`verticalClearance`** **0.18 → 0.54** (~**3×** lower under the mesh).
- Species model now floats up/down (**`FieldGuideMarineLifeHeroModelMotionPresentation`**) while spinning; unit test for sine bob.

**Summary:** Field Guide **3D** hero motion polish — bigger bob, glow above seam, longer sparkles.

- Model bob amplitude **0.014 → 0.042**; glow clearance **0.54 → 0.36** (lifted above the sheet seam).
- Particles: longer life (**2.1 → 3.4 s**), higher speed / variation, wider emitter footprint so sparkles travel farther before fading.

## 110 - Next batch **(pushed)**

**Summary:** Tank tab hero — shift PSI / cylinder / depth chart lower.

- Portrait tank hero content moves down **`heroContentDownwardOffset` (40 pt)** — minimized PSI + small cylinder, medium animated tank, and minimized depth profile (landscape full-bleed chart unchanged).
- Unit tests for padding, medium center Y, and chart Y bias.

**Summary:** Dive overview sheets — raise identity header at minimized detent.

- **`minimizedPanelContentTopPadding` (10 pt)** vs **24 pt** on medium/large so dive **#** / site / place / date sit higher and are less likely to clip under the low sheet band (map / tank / media share the token).
- Unit test covers height-fraction-aware top padding.

**Summary:** Dive overview grabber-to-content spacing unified at **10 pt**.

- One **`panelContentTopPadding`** for **minimized** (map) and **medium** (all tabs) — same gap under the grabber; no detent-specific inset.
- Intentionally tighter than generic **`AppTheme.Sheet.contentTopSpacing`** (24) so identity lines clear the low sheet band.

**Summary:** Map-tab notes now edit in a blue detent-styled sheet.

- Tapping the **Notes** card on the map overview panel opens a dedicated **`DiveActivityNotesEditSheet`** instead of the generic frosted section form.
- The notes editor uses **`AppOverviewSheetPanelBackground`** via **`appOverviewPanelSheetPresentationChrome()`** so its sheet background matches the embedded overview detent styling.
- The notes section header ellipsis routes to the same dedicated notes editor for a consistent map-tab notes flow.
- Notes text sits directly on the blue sheet under **Edit Notes** (no inset card / container).
- **Cancel** (leading) discards draft edits; **Done** saves. Grabber hidden and interactive dismiss disabled — sheet closes only via Cancel / Done.

**Summary:** Buddy tag sheets match the blue notes-sheet chrome.

- **`DiveActivityBuddiesEditSheet`** (map) and **`DiveMediaBuddyTagPickerSheet`** (media): opaque blue panel, no grabber / swipe dismiss.
- Toolbar: **Cancel** leading; trailing white **+** and prominent **Done** (draft commits only on Done).
- Shared presentation helper: **`diveActivityOverviewPanelModalSheetPresentation()`**.

**Summary:** Map Tags sheet matches the blue modal chrome.

- **`DiveActivityTagsEditSheet`** now uses the same opaque blue panel, hidden grabber, disabled swipe-dismiss, leading **Cancel**, trailing white **+**, and prominent **Done**.
- Tag row taps update a draft; **Cancel** discards dive tag changes and **Done** applies/removes tags, matching the buddy picker flow.

**Summary:** Dive Conditions edit sheet matches the blue modal chrome.

- Map-tab **Dive Conditions** (**`DiveActivitySectionEditSheet`** for `diveConditions`) uses the blue panel, hidden grabber, no swipe-dismiss, leading **Cancel** (discards), and prominent **Done** (saves). No **+** button.
- Other section edit sheets (tank gas / consumption / weights / operator / source, map dive summary) keep the standard frosted **Done**-only chrome.

**Summary:** Dive tag ovals allow up to **25** characters.

- Replaced the cramped **88 pt** adaptive grid with content-sized wrapping chips (**`ActivityTagChipWrappingLayout`**).
- **`ActivityTagPresentation.chipDisplayTitle`** caps visible oval text at **25** characters with **…**; full names stay in accessibility labels.
- Unit test covers truncation.

**Summary:** Blue edit sheets open at dive **large** detent with no layered fills.

- Notes / Buddies / Tags / Dive Conditions / media Tag buddy use **`diveActivityOverviewPanelModalSheetPresentation()`** at the system **`.large`** detent only — fully covers the ~85% overview panel beneath; no grabber / swipe-dismiss.
- Removed duplicate content **`AppOverviewSheetPanelBackground`** and Form/List row fills so only the presentation blue panel shows; nav bar background hidden over the panel.
- Sheet toolbars match Tag marine life: leave nav-bar background visible so system Liquid Glass wraps controls; white **Cancel** / **+** (**`AppGlassToolbarCancelButton`** / **`AppSheetToolbarPlusButton`** — no nested **`.glass`**); **Done** **`.glassProminent`** tinted with **`AppTheme.Colors.accent`** (blue) per [HIG Liquid Glass color](https://developer.apple.com/design/human-interface-guidelines/color#Liquid-Glass-color).
- Blue overview-panel edit sheets hide the nav-bar title (toolbar-only chrome).
- **New trip** (**`TripAddSheetView`**) uses the same blue **`.large`** modal chrome: no grabber / title, Liquid Glass **Cancel** + prominent **Done** (**`diveActivityOverviewPanelModalSheetPresentation`**).
- **Edit trip** (**`TripEditSheetView`**) matches that chrome (**`tripPlannerAddSheetPresentation`** → overview modal): no grabber / title, Liquid Glass **Cancel** + prominent **Done** (saves), cleared Form rows, **Delete trip** section retained.
- **New species** (**`FieldGuideMarineLifeAddSheet`**) uses the same blue **`.large`** modal chrome: no grabber / title, cleared Form row fills, Liquid Glass **Cancel** + prominent **Done** (**`fieldGuideMarineLifeAddSheetPresentation`** → **`diveActivityOverviewPanelModalSheetPresentation`**).
- **New dive site** (**`DiveSiteAddSheet`** / **`ExploreCatalogDiveSiteAddSheet`**) uses the same blue **`.large`** modal chrome via **`diveSiteAddSheetPresentation`**.
- **Edit dive site** — catalog detail **Edit** opens **`DiveSiteEditSheet`** (same blue Cancel / Done chrome) only for **user-defined / local** catalog sites (**`DiveSiteCatalogMatcher.isUserEditableCatalogSite`** — no **`opendivemap:`** tag). OpenDiveMap-linked catalog rows and reference-only sites hide **Edit**. Saves name, place, water type, entry, environment, max depth, and coordinates via **`DiveActivitySiteAssociation.applyCatalogSiteEdits`** (not dive count / media).
- **Edit marine life** — Field Guide species detail **Edit** appears only for **user-created** species (**`user-marine-life-`** uuid / **`isUserEditable`**). Bundled catalog species hide **Edit**. Opens **`FieldGuideMarineLifeEditSheet`** (same blue Cancel / Done chrome) via **`FieldGuideMarineLifeAddPresentation.applyEdits`**.
- **Trip planned sites picker** — **`TripPlannedSitePickerSheet`** uses the same blue **`.large`** Cancel / Done chrome; **Cancel** discards draft selection, **Done** commits planned sites.
- **Trip planned buddies picker** — **`TripPlannedBuddyPickerSheet`** uses the same blue **`.large`** Cancel / **+** / Done chrome as dive buddies; taps update a draft (**`DiveTripPlannedBuddyDraftPresentation`**); **Cancel** discards, **Done** applies links + save; **+** opens roster-only **New buddy** and selects them in the draft.
- **Planned trip hero** — not-yet-started trips with selected planned sites that have map pins default the header to the **map** (**`TripDetailPresentation.prefersMapHero`**).
- Map stats **Dive** summary editor (start time, dive number, etc.) uses the same blue Cancel / Done modal as Dive Conditions (**`usesOverviewPanelModalEditor`**).
- Tank tab **Gas & cylinder**, **Weights**, **Operator**, and **Add equipment** use the same blue large-detent Cancel / Done chrome.
- **New certification** (**`CertificationAddSheetView`**) uses the same blue **`.large`** modal chrome: no grabber / title, cleared Form rows, Liquid Glass **Cancel** + prominent **Done**.
- **Edit profile** (**`ProfileEditSheet`**) uses the same blue **`.large`** Cancel / **Done** chrome (display name + DAN; **Save** renamed to **Done**).
- **New equipment** (**`EquipmentAddSheetView`**) uses the same blue **`.large`** Cancel / **Done** chrome (cleared Form rows; no grabber / title).
- **New buddy** (**`DiveActivityAddBuddySheet`**) uses the same blue **`.large`** Cancel / **Done** chrome (name + Connect to Contact; **Add** renamed to **Done**).
- **Manual entry new dive** (**`ManualDiveEntrySheet`**) uses the same blue **`.large`** Cancel / **Done** chrome (date + optional site; **Create** renamed to **Done**); choose-site picker matches.
- **Home Top 10 page titles** — **Deepest Dives**, **Longest Activities**, **Top Sites**, **Top Species** (dropped **My** / **Marine Life** wording).
- **Fishial Identify fish** (**`DiveMediaFishialIdentifySheet`**) uses the same blue **`.large`** Cancel / glass prominent trailing chrome (**Continue** / **Identify** / **Done**; multi-select save uses **Done**).
- **Tag marine life** (**`DiveMarineLifeTagPickerSheet`**) uses the same blue **`.large`** Cancel / **+** / Done chrome; **+** opens **New species** (**`FieldGuideMarineLifeAddSheet`**) and stages the new catalog row for tagging on Done.
- **Media medium detent** — **Buddies** section (avatar chips) under marine-life ovals; carousel bottom-pinned near the sheet edge for the extra content.
- **Media carousel thumbnails** — base size **43.2 pt** (~60% of prior **72 pt**); spacing scaled to **6 pt**.

**Summary:** Nine new Field Guide **3D** heroes (Meshy USDZ).

- Bundled **`Resources/MarineLife3D/`**: **`BarredHamlet`**, **`BlackHamlet`**, **`ButterHamlet`**, **`GrayAngelfish`**, **`IndigoHamlet`**, **`LongspineSquirrelfish`**, **`PorcupineFish`**, **`QueenAngelfish`**, **`ShyHamlet`**.
- **`marine_life_sample.json`** **`feature_model`** on matching catalog UUIDs (gray angelfish → juvenile row; porcupine fish → **Porcupinefish**).
- Seeder test **`marineLifeCatalogSeeder_seedsNineAdditionalFeatureModels`**.

## 111 - Next batch **(pushed)**

**Summary:** Empty Media hero — pin **Upload Media** CTA below the animation.

- Ghost frames no longer expand under a centered full-height stack (which buried the button under the overview sheet).
- **`DiveActivityMediaEmptyHeroPresentation`** reserves CTA height in the visible hero band and places **Upload Media** near the sheet seam under the animation (**minimized** / **medium**).
- Unit test **`diveActivityMediaEmptyHeroPresentation_pinsUploadCTABelowAnimationInHeroBand`**.
- Marked CTA layout constants **`nonisolated`** to clear Swift 6 main-actor warnings from layout helpers.
- Ghost frames shifted down **`ghostFramesDownshift` (40 pt)** toward the CTA; **Upload Media** button Y unchanged.
- **Upload Media** CTA is text-width compact Liquid Glass (same chrome as **Log Your First Dive**), not full-bleed.
- **Upload Media** label uses **`AppTheme.Colors.secondaryText`** (dark gray in light mode; light slate in dark).
- **Media frosted overlays** (dive **Media** translucent panel + media-grid playback tag overview) always use dark-mode **`.thinMaterial`** / content tokens via **`DiveActivityMediaFrostedOverlayPresentation.forcesDarkAppearance`**, so light mode matches the same gray frost as dark mode.
- **Empty Media sheet matches populated layout** — removed the dedicated empty-panel branch (identity row + upload copy); with no media the sheet shows the same identity header, fish / buddy chrome, marine-life + buddies sections (untagged prompts), and carousel row with **+**. Upload copy lives only in the hero; fish/buddy sheet chrome no longer hidden by the has-media gate (tag actions still require a media target). Test updated: **`diveActivityMediaEmptyHeroPresentation_emptySheetReusesPopulatedLayout`**.

**Summary:** Map-tab **Marine Life** section under Buddies.

- New **`marineLife`** editable section on dive **Map** (large) between **Buddies** and **Notes**.
- Lists unique species from all dive sightings (media tags + dive-level tags); **+** opens **`DiveActivityMarineLifeTagPickerSheet`** to add dive-level tags without media.
- **`MarineLifeSightingRecorder.tagSpeciesOnDive`** / **`tagPendingSpeciesOnDive`** — no-op when the species is already sighted on the dive.
- Buddy-style chips: 3D RealityKit avatar when **`featureModelResourceName`** is set, else catalog photo, else fish icon + common name; tap opens Field Guide.
- Tests: unique-chip dedupe, avatar kind priority, dive-level tag dedupe with media, catalog section order / header action.

**Summary:** Marine Life avatar 3D — fill the circle, drop the glow.

- **`FieldGuideMarineLifeHeroSceneConfiguration.showsGlow`** gates the accent glow plate / sparkles; species detail heroes keep it, compact avatar chips opt out.
- **`compactModelSceneConfiguration`** uses a fixed **`avatarModelFitExtent` (0.42)** so every species fills the circle at max size (not the species-size hero fit), centers the model vertically (no hero downshift), and disables the glow.
- Tests: **`diveActivityMarineLifeOverviewPresentation_compactAvatarConfigMaximizesModelAndDropsGlow`**, **`fieldGuideMarineLifeHero_speciesConfigKeepsGlow`**.

**Summary:** Map Buddies / Marine Life chip rows — soft trailing fade.

- Horizontal chip `ScrollView`s use **`horizontalChipRowTrailingScrollFade()`** so overflow softens on the right instead of a hard clip; fade ramps down as the user scrolls to the end.
- **`DiveActivityHorizontalChipRowScrollFadePresentation`** owns fade width + opacity math; Reduce Transparency skips the mask.
- Tests: **`diveActivityHorizontalChipRowScrollFade_*`**.

**Summary:** Bug fix — Home carousel swipe unresponsive on the first item after a loop wrap.

- The looping pager snapped the duplicate-first page back to index **0** synchronously inside **`onChange`**, racing the still-running **0.35 s** wrap animation. A non-animated jump mid-transition desyncs the paged **`TabView`** (it keeps showing the duplicate last page — which has no next page — while the binding says **0**), so forward swipes on slide **0** bounced until the next **10 s** auto-advance resynced it.
- Reset now defers **`loopingPagerResetDelaySeconds` (0.6 s)** after landing on the duplicate, re-verifies the pager is still there, then snaps without animation; cancelled if the user swipes away first or the carousel disappears. Advance animation length moved to **`slideAdvanceAnimationSeconds`**.
- Test: delay outlasts the wrap animation (in **`homeMediaCarouselPresentation_nextIndex_wrapsAndRequiresMultipleSlides`**).
- **`AvatarKind`** — explicit **`nonisolated`** **`Equatable`** for Swift Testing **`#expect`** (clears Swift 6 main-actor warnings).

## 112 - Next batch **(pushed)**

**Summary:** Hybrid cloud sync Phase 0 — data ownership boundaries.

- **`cursor/hybrid_cloud_sync_boundaries.md`** — Option A boundary doc for the feature branch: user-generated structured data → future CloudKit private user store; media bytes stay in Photos / iCloud Photos with synced pointers; app-provided catalogs → local cache + future developer CDN.
- Phase 0 decisions: full **`DiveProfilePoint`** rows sync by default (volume-gated later if needed); user-created **`MarineLife`** / **`DiveSite`** rows are user data, not app catalog rows; crash reports remain local + opt-in public CloudKit upload outside private sync.
- **`app_summary.md`** records the boundary while noting runtime sync remains off until Phase 1 schema split / migration is ready.

**Summary:** Hybrid cloud sync Phase 1 kickoff — schema readiness (sync still off).

- **`AppSwiftDataStorePartition`** — target user / catalog / diagnostics model lists; Firebase catalog CDN vendor lock; synced vs local-only preference keys.
- CloudKit-shape prep in the unified store: removed `@Attribute(.unique)` on **`MarineLife.uuid`** / **`SightingInstance.sightingUUID`**; property defaults; inverse gaps filled; **`AppSwiftDataLogicalUniqueness`** + sighting insert dedupe.
- Hybrid ownership: **`MarineLifeOwnership`** / **`DiveSiteOwnership`** + **`ownershipRaw`** with launch **`AppSwiftDataOwnershipBackfill`**.
- **`DiveMediaPhoto.photosCloudIdentifier`** for Phase 3; empty until resolve.
- Migration plan: **`cursor/hybrid_cloud_sync_phase1_migration.md`** (production stays single store until cross-store relationships become UUID-only).
- Tests: partition coverage, CloudKit-off schema, ownership inference, cloud identifier persistence, logical uniqueness, ownership backfill, sighting UUID dedupe.
- Simulator preflight fix: SwiftData `@Model` defaults must be fully qualified (`Date()`, `DiveSource.manual`); CloudKit policy helper avoids non-`Equatable` switch.

**Summary:** Hybrid cloud sync Phase 1b — user species/sites in the user store + UUID-only refs.

- **`UserMarineLife`** / **`UserDiveSite`** models in the user partition; Field Guide add + Explore add create these rows (not catalog **`MarineLife`** / **`DiveSite`**).
- Dropped live catalog relationships: sightings/overlays/dives/trips use **`marineLifeUUID`** / **`diveSiteID`** / **`plannedSiteIDs`**; resolve via **`MarineLifeSpeciesResolver`** / **`DiveLinkedSiteResolver`**.
- Launch **`AppSwiftDataHybridRowMigration`** moves legacy user-owned catalog rows into the new models; **`AppSwiftDataDualStoreFactory`** opens split in-memory stores for tests (production still unified, CloudKit still **`.none`**).
- UI: **`ExploreDiveSiteDetailHost`**, Field Guide / Explore / trip planned sites resolve catalog + user rows; map pin lookup prefers linked site id in provided catalogs.
- Tests: hybrid migration, dual-store open, species/site resolvers, user species create path; updated site-link / map / seeder expectations.
- Docs: **`hybrid_cloud_sync_phase1_migration.md`**, **`app_summary.md`**.

**Summary:** Hybrid cloud sync Phase 1c — production dual-store flip (CloudKit still off).

- **`AppSwiftDataDualStoreFactory`** — on-disk **`GoDiveUser` / `GoDiveCatalog` / `GoDiveDiagnostics`** store URLs under Application Support / GoDiveMVP.
- **`AppSwiftDataDualStoreBootstrap`** — production open path; one-shot migrate from legacy unified store; marker key **`godive.dualStoreMigration.v1.completed`**.
- **`AppSwiftDataDualStoreMigrator`** — copies catalog / diagnostics / user graph (IDs preserved, relationships rewired); legacy store renamed **`*.migrated-bak`**.
- **`AppSwiftDataSchema.makeContainer`** — in-memory stays unified (tests); on-disk uses dual bootstrap.
- Tests: in-memory unified→dual copy; fresh dual open in temp directory.
- Docs: migration plan + **`app_summary`** / boundaries updated for Phase 1c.

**Summary:** Hybrid cloud sync Phase 2 — private CloudKit on the user store only.

- **`AppSwiftDataDualStoreFactory`** — production on-disk **user** configuration uses **`.private("iCloud.PrimoSoftware.GoDiveMVP")`**; catalog + diagnostics stay **`.none`**. In-memory / custom-root test opens keep CloudKit off; legacy→dual migrator copies with sync off, then production reopen enables user mirroring.
- **`AppSwiftDataCloudKitCompatibility`** — Phase 2 policy helpers (`privateUserCloudKitDatabase`, `usesPhase2DualStoreCloudKitPolicy`); shared container id with crash public uploader.
- Background **`remote-notification`** Info.plist key for CloudKit wakeups.
- Tests: Phase 2 policy + local-only dual open; temp-root bootstrap asserts user CloudKit off.
- Docs: migration plan, boundaries, **`app_summary`**, privacy guide.
- Device build warning fixes: **`nonisolated`** on dual-store bootstrap / migrator / catalog resolvers / logical uniqueness (Swift 6 default MainActor).
- **Launch crash fix:** opening existing dual user store with private CloudKit was failing → `fatalError` in **`AppModelContainer`**. **`makeOnDiskSplitContainer`** now falls back to local-only user store on CloudKit open failure so the app can launch; logs the error.
- **Empty dual remigration:** empty dual stores could skip copying from legacy **`default.store`**. Bootstrap now remigrates when legacy still exists and dual dive count is 0 (wipes empty dual first). Legacy URL is explicit Application Support / **`default.store`** (not bare **`ModelConfiguration().url`**); refuse to park legacy if 0 dives were copied from a large store.
- **Migration performance:** copy **`DiveProfilePoint`** per dive with intermediate saves (full-table fetch of 100k+ rows was hanging launch). Remigrate when dual dive count is below legacy count (interrupted copy).
- **Data recovery:** object-by-object dual remigration was crashing on device. While legacy **`default.store`** still has dives and dual is empty/incomplete, production opens the **unified legacy store** so the log is usable; dual copy deferred.
- **Phase 2 strategy (dev):** legacy unified → dual **migration out of scope**. Production bootstrap opens dual + user CloudKit only (no remigration / no legacy open). Clean install (delete app) for Phase 2 device smoke.
- **Local-only fallback root cause:** device diagnostics showed `accountStatus=available` but `SwiftDataError` **`loadIssueModelContainer`** even after wipe+retry — not an iCloud sign-in problem. CloudKit rejects Codable transformable attributes (`NSCodableAttributeType`). **`DiveActivity.entryCoordinate: DiveCoordinate?`** was the blocker; replaced with **`entryLatitude` / `entryLongitude`** Doubles + `@Transient` **`entryCoordinate`** wrapper. Diagnostics now map SwiftDataError cases, append A/B/C open probes (user-only CloudKit vs dual vs local), and record the fix in **`removedCodableAttributeKeys`**.
- Tests: entry coordinate primitive persistence; CloudKit probe diagnostics file; schema documents removed Codable key.
- **Data-loss fix:** CloudKit open failure no longer **wipes** dual store files (that deleted **`UserProfile`** + dives and forced a new Sign in with Apple after force-quit). Fallback opens **local-only on existing files**; sticky local-only skips CloudKit on later launches; policy version **2** clears sticky once after this fix so CloudKit can be retried safely.
- Tests: sticky / policy-bump helpers; CloudKit failure preserves existing store files + marker (no `removeDualStoreFiles`).
- **CloudKit array flatten (policy v3):** stored `[UUID]` / `[String]` on **`MarineLifeUserRecord`**, **`DiveTrip`**, **`UserDiveSite`**, **`DiveSite`** → JSON **`Data?`** + `@Transient` accessors (`AppSwiftDataCloudKitArrayStorage`). Fixes in-place append/remove call sites. Sticky local cleared once via open-policy **3**; when leaving sticky local, dual files are **renamed aside** so a fresh CloudKit-backed store can be created (local-only files cannot enable CloudKit in place — expect one re-sign-in for Phase 2 smoke).
- Tests: array storage codecs + model Data persistence.
- **Device retest:** after v3, fresh CloudKit create still failed (`probeA`/`probeB` `loadIssueModelContainer`). **Policy v4–v5:** flatten enums to raw strings; Core Data probe **D** revealed the real blocker: **CloudKit requires all relationships optional**, including to-many arrays (`UserProfile.diveActivities`, `DiveActivity.buddies`, …).
- **Policy v6:** optional to-many `*Storage` relationships + `@Transient` non-optional accessors; inverses retargeted to storage properties.
- **Device:** Dre’s Phone open diagnostics **`result=success`** with **`enableUserCloudKitSync=true`**, **`accountStatus=available`** (policy v6). Fresh dual user store created after rename-aside; next smoke = Sign in → add a dive → confirm private DB records in CloudKit Console (**Development** / container **`iCloud.PrimoSoftware.GoDiveMVP`**).
- **OpenDiveMap My Sites after CloudKit restore:** linking an OpenDiveMap / catalog **`DiveSite`** now upserts a synced **`UserDiveSite`** snapshot (same id + **`openDiveMapReferenceID`**). Launch hydrate recreates missing snapshots for orphaned **`diveSiteID`**s (rematch from name/GPS when the local catalog row is gone). Explore My Sites dedupes catalog+user pins; refreshes user sites on appear.
- **CloudKit reinstall empty logbook:** Sign in with Apple was minting a new **`UserProfile` UUID** before CloudKit imported the existing account (same **`appleUserIdentifier`**). UI filters by **`ownerProfileID`**, so synced dives looked missing. **`UserProfileCloudKitIdentityMerge`** collapses duplicates, reassigns owned rows, updates the session; runs on sign-in, launch, session validation, and CloudKit import events.
- **Synced user settings:** **`UserPreferences`** in the CloudKit user store mirrors units / tank / renumber / auto-upload / diver weights / bulk UDDF create-sites; **`UserDefaults`** stays a cache for `@AppStorage`. **Share crash reports** remains local-only. Sync on sign-in, launch, Settings edits, and CloudKit import.

## 113 - Phase 3 Photos cloud identifiers **(pushed)**

**Summary:** Phase 3 — resolve Photos **`PHCloudIdentifier`** across devices so dive media pointers survive CloudKit restore.

- **`DiveMediaCloudIdentifierPolicy`** / **`DiveMediaCloudIdentifierResolver`** / **`DiveMediaCloudIdentifierCodec`** — capture local→cloud at attach; resolve cloud→local on Device B; prune only after **`notFound`** (never while resolve is pending/unavailable).
- **`DiveActivityMediaStorage.addLibraryReference`** stores **`photosCloudIdentifier`** when PhotoKit can map it.
- **`DiveMediaLibraryIdentifierRepair`** + launch **`DiveMediaCloudIdentifierBackfill`** fill missing cloud IDs and rewrite stale local IDs.
- Thumbnails / full media loaders resolve-before-load; **`DiveMediaReferencePruning`** resolve-before-prune.
- Tests: cloud-identifier policy gates + **`libraryCloudIdentifier`** trim helper.
- Docs: hybrid boundaries / migration checklist, **`app_summary`**, privacy + getting-started.

## 114 - Next batch **(pushed)**

**Summary:** Harden dive media ID map against duplicate-key traps; clarify abnormal-exit breadcrumbs after install kills.

- **`Dictionary(godiveUniquingKeysWithValues:)`** — last-wins map builder; dive overview **`mediaPhotosByID`** uses it instead of **`uniqueKeysWithValues`** (duplicate CloudKit / relationship IDs no longer **`EXC_BREAKPOINT`**).
- **`CrashBreadcrumbTrail.freezePreviousSessionAndBeginNew`** clears live UI context after snapshotting so the next launch trail is not paired with a stale dive Media / star action.
- Silent Photos cloud→local ID repair no longer posts **`.diveActivityMediaDidChange`** (avoids cascading derived-data rebuilds while the gallery loads).
- Tests: uniquing helper keeps last on duplicate keys; freeze clears context.
- **Explore tab crash:** map pin sync used **`Dictionary(uniqueKeysWithValues:)`** on plottable sites — duplicate site IDs (catalog + user snapshot / remigration) crashed on tab open. MapKit + Google map coordinators now use **`godiveUniquingKeysWithValues`**; **`ExploreCatalogMapPresentation.deduplicatingPlottableSites`** + scope cache / all-sites merge dedupe first.
- **Stale media after CloudKit restore:** batch **`DiveMediaReferencePruning.pruneMissingLibraryAssets`** runs after successful CloudKit **import** events and on launch (full Photos access only). Pointers whose Photos originals were deleted (e.g. delete app → delete photo → reinstall) are removed; cloud resolve that still cannot find an asset also prunes.

## 115 - Phase 4 Catalog CDN



