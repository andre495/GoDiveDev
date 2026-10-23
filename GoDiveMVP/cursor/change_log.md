# Change Log

**Since last push** — running notes for the current batch. Cleared after each successful **commit + push**; shipped history lives in **git**.

Agents: append summaries and bullets here during work; refresh **`cursor/app_summary.md`** for architecture.

---

## Exclude mock sample JSON from Release; add `-GoDiveMockSeed` flag

### Summary

Mock data seeding is now gated by the **`-GoDiveMockSeed`** Debug launch flag. Sample JSON files are excluded from Release builds entirely.

### Changes

- **`MockDataSeeding.isLaunchSeedingEnabled`** is now a computed property in Debug (checks for `-GoDiveMockSeed` launch argument) and compile-time `false` in Release.
- **`MockDataSeeder`** code is wrapped in `#if DEBUG` — no seeding logic in Release binary.
- Added `EXCLUDED_SOURCE_FILE_NAMES = "MockData/*_sample.json"` to Release build settings — sample files don't ship.
- Seeding is idempotent: runs once per install (UserDefaults marker).
- Added unit tests for flag gating and idempotency marker.
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

