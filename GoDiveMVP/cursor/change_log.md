# Change Log

**Since last push** — running notes for the current batch. Cleared after each successful **commit + push**; shipped history lives in **git**.

Agents: append summaries and bullets here during work; refresh **`cursor/app_summary.md`** for architecture.

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

