# Change Log

Keep ongoing work under **one numbered section** until that batch is **`(pushed)`** to git. After a successful **commit + push** you requested, the agent marks the latest open section **`(pushed)`** (see **`.cursor/rules/changelog-mark-pushed-on-git-push.mdc`**). Start the **next number** only when you ask for a new section.

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

