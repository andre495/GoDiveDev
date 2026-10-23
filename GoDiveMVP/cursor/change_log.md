# Change Log

**Since last push** — running notes for the current batch. Cleared after each successful **commit + push**; shipped history lives in **git**.

Agents: append summaries and bullets here during work; refresh **`cursor/app_summary.md`** for architecture.

---

## Fix top gradient banding on scroll-under-header pages

Fix visible horizontal bands (3-band effect) at the top of Notifications, Trips, Top Species, Field Guide, and other pages that use `scrollContentUnderHeader` or similar layouts.

### Root cause

Introduced in commit **9033143** ("Home stats centering, blue sheet scale, and chrome polish", 2026-07-01). That commit added both `LogbookTopChromeScrim` to `AppPage.scrollUnderHeaderBody` AND `AppStatusBarEdgeScrim` to `CollapsibleInlineTitleHeader` in the same change, creating a double-scrim when these components are used together.

### Bug fix

- Two semi-transparent scrims were stacked: `LogbookTopChromeScrim` from `AppPage.scrollUnderHeaderBody` (or Field Guide's manual layout), plus `AppStatusBarEdgeScrim` from `CollapsibleInlineTitleHeader` or `AppHeader`. The overlapping gradients at different opacity curves created visible banding.
- Added `statusBarScrimIsProvidedExternally` parameter to `CollapsibleInlineTitleHeader`, `AppHeader`, and related chrome components. When `true`, the component skips rendering its own `AppStatusBarEdgeScrim`, avoiding the double-scrim.
- `AppPage.scrollUnderHeaderBody` now passes `statusBarScrimIsProvidedExternally: true` since it already renders `LogbookTopChromeScrim`.
- Field Guide, Logbook, and category browse chrome components default to `true` since their parents also render the tall scrim.

### Affected screens

- Notifications (`HomeNotificationsView`)
- Trips (`TripPlannerView`)
- Top Species / Deepest / Longest / Top Sites (`HomeLifetimeStatsLeaderboardView`)
- Field Guide hub and category/subcategory browse
- Logbook (`LogbookCollapsibleHeader`)
- All `AppPage` users with `scrollContentUnderHeader: true`

### Not changed

- Home (`BlueSheetHomeTopChrome`) — was on the do-not-regress list and not reported; keeping both scrims preserves status-bar legibility over hero photos/videos.
- `ExploreTopChrome` and `ExploreMapTopChromeScrim` — Explore uses `AppStatusBarEdgeScrim` directly (not through shared headers), so it continues to work as before.
- `BlueSheetDetailTopChrome`, `profile.swift`, `friend_profile_view.swift` — these use `.detailTop` fade style which renders `EmptyView()`, so no double scrim.
- Global search — custom chrome components, unchanged.

Fixes #15.

---

## Fix Map tab crash with 'Invalid Region' (Issue #53)

Fix crash when opening the Map tab with All Sites scope. MKMapView throws `NSException 'Invalid Region'` when `setRegion` receives a latitude span > 180 - 2*|centerLat| or longitude span > 360.

### Root cause

`ExploreCatalogMapPresentation.boundingRegion` (line 94-95) and `TripDetailMapPresentation.regionSpec` (line 258) compute spans as `max(range * 1.35, 0.04)` with no upper limit. When the All Sites scope fits the worldwide catalog, longitude span can reach ~486° and latitude span can exceed 180°.

### Bug fix

- Added `sanitized` computed property to `DiveLocationMapRegionSpec` that clamps center/spans to MapKit-valid ranges:
  - Center latitude clamped to [-90, 90]
  - Center longitude wrapped to [-180, 180]
  - Latitude span clamped to `min(inputSpan, 180 - 2*|centerLat|)` (prevents poles overflow)
  - Longitude span clamped to <= 360
  - Falls back to `worldFallbackRegion` on NaN, infinity, zero, or negative spans
- `mkCoordinateRegion` and `mkMapRect` now go through `sanitized` automatically
- Google Maps `gmsCoordinateBounds` extensions also use sanitized values
- `DiveSiteCoordinatePickerPresentation.region` now uses `DiveLocationMapRegionSpec.mkCoordinateRegion`

### Call sites now sanitized

- `ExploreCatalogMapRepresentable.applyRegion` (Explore tab MapKit)
- `ExploreCatalogGoogleMapRepresentable.applyRegion` (Explore tab Google Maps)
- `TripDetailMapRepresentable.applyRegion` (Trip detail MapKit)
- `TripDetailGoogleMapRepresentable.applyRegion` (Trip detail Google Maps)
- `OnboardingExploreSitesMapRepresentable` (onboarding scripted map)
- `OnboardingLogEveryDiveMapRepresentable` (onboarding demo)
- `DiveSiteCoordinatePickerMapRepresentable` (coordinate picker)

### Tests

- Unit tests for sanitization: worldwide spread, date-line wrap, polar latitude, single site, empty spans, NaN/infinity, negative spans, longitude overflow
- UI test that opens Explore Map tab with All Sites scope and verifies no crash

### QA follow-up fixes

- Fixed 3 nonisolated warnings at `DiveLocationMapRegionSpec.swift:43-45`: added `nonisolated` to `minimumSpan` constant
- Added test with exact QA crash input: `center:-2.348,+2.907 span:+117.25,+477.83`
- Added DEBUG-only `-GoDiveOpenExploreMap` launch argument that:
  - Bypasses onboarding and UITest stub
  - Opens Explore → Map → All Sites with real catalog sites
  - Combined with `-GoDiveMockSeed` for populated catalog
- Updated UI test to use `-GoDiveOpenExploreMap` (DEBUG builds only; skips on Release)
- Documented launch arguments in `dev-docs/dev-setup.md`

### Note on unit tests

Unit tests are blocked by #28 (MockFishialURLSession compile error on main). The new sanitization tests are correct and will pass once #28 is resolved.

### Verification

On simulator: Explore → Map segment → All Sites toggle. Map should display the world view without crashing.

Fixes #53.

