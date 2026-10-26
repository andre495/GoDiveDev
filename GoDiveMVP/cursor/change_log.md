# Change Log

**Since last push** — running notes for the current batch. Cleared after each successful **commit + push**; shipped history lives in **git**.

Agents: append summaries and bullets here during work; refresh **`cursor/app_summary.md`** for architecture.

---

## Fix emulator-session isolation (Issue #68)

Prevent emulator-origin sessions from being restored on non-emulator Debug launches.

### Bug

When a user signed in via the emulator test sign-in (`-GoDiveUseFirebaseEmulator` + `-GoDiveEmulatorTestSignIn`), then relaunched without the emulator flag, the session was restored and the app ran against production Firebase with an emulator-origin identity.

### Fix

On any DEBUG launch without the emulator flag, if the persisted session came from the emulator (via the `GoDiveEmulatorSessionActive` marker), the guard now:

1. Signs out of Firebase Auth locally
2. Clears persisted session state from Keychain (`currentProfileID`)
3. Clears returning account hints (`lastAppleUserIdentifier`, `lastProfileID`, `lastDisplayName`)
4. Clears cached Firebase UID
5. Clears the emulator session marker
6. Logs one `.info` line (subsystem `GoDive`)

The user lands on Welcome after session restore with no production Firestore/Storage calls made.

### Changes

- Added `clearPersistedEmulatorSession()` to `GoDiveEmulatorSessionGuard` — clears all Keychain-persisted session state
- Updated `clearEmulatorSessionIfNeededOnMain` to call `clearPersistedEmulatorSession()` before clearing the marker
- Changed log subsystem from `PrimoSoftware.GoDiveMVP` to `GoDive` and log level from `.warning` to `.info`
- Added unit tests for session isolation: emulator-marked session on non-emulator launch is cleared, emulator-marked session on emulator launch is kept, no marker means unchanged, complete session clear removes all persisted state

### Manual verification

1. Launch with `-GoDiveUseFirebaseEmulator -GoDiveEmulatorTestSignIn qa@example.com`
2. Sign in completes (emulator)
3. Relaunch WITHOUT the emulator flag
4. App lands on Welcome — no production calls made

Fixes #68.

---

## Add loading screen for returning account sync

When a user signs back in to an existing account (Sign in with Apple), a loading screen now appears while their data syncs, instead of showing an empty Home screen.

### Changes

- Added **`AccountSyncState`** observable class with gate-based sync tracking:
  - Gates: **firebaseAuth**, **firestoreProfile**, **cloudKitImport**, **socialFirstSnapshot**
  - States: **idle**, **syncing**, **ready**, **failed**, **timedOut**
- Added **`AccountSyncLoadingOverlay`**: full-screen loading view matching launch screen style with progress messages ("Restoring your dives…", "Loading account…", "Loading friends…")
- Added **`AccountSyncBanner`**: non-blocking banner shown after 20s timeout ("Still syncing…" → "Sync complete")
- Modified **`AccountSession`** to track and coordinate sync state for returning accounts
- Modified **`AccountRemoteDataPopulation`** to release gates as steps complete and run Firebase/CloudKit in parallel
- Moved photo upload/restore, roster linking, and push token upload out of critical path (deferred to background)
- Updated **`AppSessionBootstrapPresentation`** with sync overlay/banner helpers
- Updated **`app_session_root.swift`** to show sync overlay during sync and banner after timeout
- Added timeline log events for sync gates (sync.begin, sync.gate_released, sync.ready, sync.timeout, sync.failed)
- Added comprehensive unit tests in **`AccountSyncStateTests`**

### Behavior

- **Returning accounts** (via ReturningAccountHints): Show sync loading screen until all gates release
- **New accounts**: Skip sync screen, go directly to onboarding
- **Timeout** (20s): Show Home with "Still syncing" banner that auto-dismisses when data lands
- **Offline/iCloud unavailable**: Show failure screen with Retry and Continue buttons
- **Accessibility**: VoiceOver labels on all interactive elements, Dynamic Type support

Fixes #54.

---

## Exclude mock sample JSON from Release; add `-GoDiveMockSeed` flag

### Summary

Mock data seeding is now gated by the **`-GoDiveMockSeed`** Debug launch flag. Sample JSON files are excluded from Release builds entirely.

### Changes

- **`MockDataSeeding.isLaunchSeedingEnabled`** is now a computed property in Debug (checks for `-GoDiveMockSeed` launch argument) and compile-time `false` in Release.
- **`MockDataSeeder`** code is wrapped in `#if DEBUG` — no seeding logic in Release binary.
- Added `EXCLUDED_SOURCE_FILE_NAMES = "MockData/*_sample.json"` to Release build settings — sample files don't ship.
- Seeding is idempotent: skips if sample dive UUID exists in SwiftData (not UserDefaults — survives store erasure).
- Added unit tests for flag gating and store-based idempotency.
- Added `dev-docs/mock-data-seeding.md` with usage instructions and Release verification steps.

### Files

- `GoDiveMVP/Data/Seed/MockDataSeeding.swift` — flag definition
- `GoDiveMVP/Data/Seed/MockDataSeeder.swift` — Debug-only seeding logic + idempotency
- `GoDiveMVP/Data/GoDiveReleaseConfigurationGates.swift` — testable helper
- `GoDiveMVP.xcodeproj/project.pbxproj` — Release exclusion
- `GoDiveMVPTests/SwiftDataInfrastructureTests.swift` — unit tests

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

