# Change Log

**Since last push** — running notes for the current batch. Cleared after each successful **commit + push**; shipped history lives in **git**.

Agents: append summaries and bullets here during work; refresh **`cursor/app_summary.md`** for architecture.

---

## Fix top gradient banding on scroll-under-header pages

Fix visible horizontal bands (3-band effect) at the top of Notifications, Trips, Top Species, Field Guide, and other pages that use `scrollContentUnderHeader` or similar layouts.

### Bug fix

- Two semi-transparent scrims were stacked: `LogbookTopChromeScrim` from `AppPage.scrollUnderHeaderBody` (or Field Guide's manual layout), plus `AppStatusBarEdgeScrim` from `CollapsibleInlineTitleHeader` or `AppHeader`. The overlapping gradients at different opacity curves created visible banding.
- Added `statusBarScrimIsProvidedExternally` parameter to `CollapsibleInlineTitleHeader`, `AppHeader`, and related chrome components. When `true`, the component skips rendering its own `AppStatusBarEdgeScrim`, avoiding the double-scrim.
- `AppPage.scrollUnderHeaderBody` now passes `statusBarScrimIsProvidedExternally: true` since it already renders `LogbookTopChromeScrim`.
- Field Guide, Logbook, and category browse chrome components default to `true` since their parents also render the tall scrim.
- `BlueSheetHomeTopChrome` (Home) also updated for consistency.

### Affected screens

- Notifications (`HomeNotificationsView`)
- Trips (`TripPlannerView`)
- Top Species / Deepest / Longest / Top Sites (`HomeLifetimeStatsLeaderboardView`)
- Field Guide hub and category/subcategory browse
- Logbook (`LogbookCollapsibleHeader`)
- Home (`BlueSheetHomeTopChrome`)
- All `AppPage` users with `scrollContentUnderHeader: true`

### Not changed

- `ExploreTopChrome` and `ExploreMapTopChromeScrim` — Explore uses `AppStatusBarEdgeScrim` directly (not through shared headers), so it continues to work as before.
- `BlueSheetDetailTopChrome`, `profile.swift`, `friend_profile_view.swift` — these use `.detailTop` fade style which renders `EmptyView()`, so no double scrim.
- Global search — custom chrome components, unchanged.

Fixes #15.

