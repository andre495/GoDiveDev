# GoDive MVP App Summary

High-level architecture **map** — keep sections short; detail lives in **`cursor/change_log.md`** (unpushed batch), **`docs/`**, and topic docs (**`hybrid_cloud_sync_boundaries.md`**, **`firebase_user_profiles.md`**, **`rules.md`**).

---

## Stack and entry

- **SwiftUI** + **SwiftData** (multiple on-disk stores). **Deployment target: iOS 26**.
- **Hybrid cloud:** **CloudKit** private DB = owner dive log (source of truth). **Firebase** (Auth, Firestore, Storage) = social directory, friends, friend-visible activity projections, catalog CDN, anonymized community sightings (Settings opt-out). See **`cursor/hybrid_cloud_sync_boundaries.md`**.
- **Maps:** **MapKit** by default; **Google Maps SDK** when **`Config/GoogleMapsSecrets.plist`** has a valid key.
- **Entry:** **`GoDiveMVPApp`** → Sign in with Apple → **`ContentView`**. Launch overlay until Home chrome is ready; deferred maintenance (catalog CDN, PhotoKit backfill, CloudKit kick) after first paint.
- **Crash reporting:** MetricKit + local **`CrashReportRecord`** rows; opt-in upload to CloudKit public DB (**Settings → Share crash reports**).
- **UI tests:** **`-GoDiveUITest`** → **`GoDiveUITestRootView`** only (no SwiftData / maps).
- **Release:** **`MockDataSeeding.isLaunchSeedingEnabled`** stays **`false`**.

---

## External dependencies

SPM pins: **`Package.resolved`** (often gitignored).

| Dependency | Role | Secrets |
|------------|------|---------|
| **Apple CloudKit** | Private dive-log sync; public DB for opt-in crash reports | iCloud capability |
| **Firebase** (Core, Auth, Firestore, Storage) | Social profile, friends, shared projections, optional catalog CDN | **`GoogleService-Info.plist`** (gitignored) |
| **FITSwiftSDK** | **`.fit`** dive + snorkel import | — |
| **Google Maps SDK** | Explore / activity maps when keyed | **`GoogleMapsSecrets.plist`** |
| **Fishial.AI REST** | Optional manual fish ID on dive media | **`FishialSecrets.plist`** |
| **PhotoKit, Contacts, MapKit, Sign in with Apple** | Media, buddy linking, geocode, account | System permissions |

**Google Maps:** API-key tiles only today — no user Google OAuth. Revisit consent/privacy before Places, Routes, or Google Sign-In.

**Fishial:** Off unless configured. User crops one JPEG per identify; results fuzzy-matched to Field Guide catalog. See **`cursor/owasp_secrets_handling.md`**.

---

## App shell and navigation

- **Account:** **`SignInView`** while logged out. New users: welcome interests → profile setup → permissions → optional import → celebration → Home. Returning users reuse local **`UserProfile`**.
- **Root tabs** (all mounted — iOS 26 `TabView` lazy placeholders freeze): **Home**, **Logbook**, **Field Guide**, **Explore**, **Search** (native search role). Tab selection synced from UIKit **`didSelect`** when SwiftUI binding stalls.
- **Navigation:** **`NavigationStack`** pushes; **`hidesBottomTabBarWhenPushed()`** on deep flows. **`NavigationStackPushCoalescing`** prevents double-push.
- **Deep links:** Buddy-tag, like, comment, mention, gear, trip, friend-invite, and push notifications drain pending stores on shell appear / Home chrome ready.
- **Orientation:** Portrait by default; dive/snorkel detail unlocks landscape for map / tank / media.

---

## Headers and page wrappers

- **`AppHeader`:** Home / **`AppPage`** roots — brand wordmark, status-bar scrim, measured clearance spacer (never outer top padding on lists).
- **`AppHeaderlessPage`:** Full-bleed pushed flows (logbook, dive detail, Field Guide, trips) — custom top chrome, scroll-under lists.
- **Blue sheet layout:** Home + pushed detail share hero band + overlapping stats panel (**`BlueSheetTabRootPage`** / **`BlueSheetDetailPage`**). Layout reference: **`cursor/blue_sheet_home_vs_detail_layout.md`**.
- **Sheets:** Modal **`.sheet`** uses **`appSheetPresentationChrome()`**; dive overview uses opaque blue embedded panel (**`DiveActivityOverviewEmbeddedPanel`**, minimized + large detents).

---

## Theme and chrome

- **`AppTheme`:** semantic colors, spacing, typography — prefer over ad-hoc RGB.
- **Backgrounds:** **`screenBackgroundGradient`** on most roots; **`WaterBubbleBackground`** on Logbook, Field Guide, Profile, Explore list (not Home or Search results).
- **Chrome:** Liquid Glass toolbar buttons, segmented controls, catalog search fields, list scrims.
- **Launch:** **`LaunchScreen.storyboard`** + **`AppLaunchOverlay`** (dark ocean palette until main shell).

---

## SwiftData models

Canonical fields stored in **metric** (m, °C, psi where applicable); UI formats via **`DiveQuantityFormatting`** + Settings units.

| Model | Role |
|--------|------|
| **`UserProfile`** | Apple ID account; owns dives, snorkels, trips, gear, certs |
| **`DiveActivity`** | Dive summary + relationships (buddies, media, site, equipment, sightings) |
| **`DiveProfilePoint`** | Per-sample depth/time series — **local store only**; full track also in compressed **`profileTrackData`** for sync |
| **`SnorkelActivity`** | Snorkel summary; swim track compressed in **`swimTrackData`**; profile points local |
| **`SnorkelProfilePoint`** | Snorkel GPS/HR samples — local store |
| **`DiveBuddy`** / **`DiveBuddyTag`** | Roster + per-dive tags; friends link via **`linkedFirebaseUID`** |
| **`DiveMediaPhoto`** | PhotoKit pointer + optional preview JPEG + cloud identifier — not full bytes |
| **`DiveSite`** | Catalog / user site; linked from dives on import |
| **`UserDiveSite`** | Synced snapshot for Explore My Sites |
| **`DiveTrip`** / **`DiveTripActivityLink`** / **`DiveTripBuddyLink`** | Trips, linked activities, planned buddies |
| **`MarineLife`** | Field Guide catalog (~1.3k species from bundled JSON) |
| **`SightingInstance`** | Species sighting on a dive (optional media link) |
| **`MarineLifeUserRecord`** | Per-user species overlay (sighted, tagged media) |
| **`ActivityTag`** | Reusable dive/snorkel tags |
| **`EquipmentItem`** / **`Certification`** | Locker gear + training cards |
| **`UserPreferences`** | Synced settings (CloudKit + UserDefaults cache) |

---

## Data storage strategy

- **Four SwiftData configurations:** **user** (private CloudKit), **user-local** (profile points only, no CloudKit), **catalog** (marine life + dive sites, local), **diagnostics** (crash reports, local).
- **No retained import file bytes** after **`.fit`** / **`.uddf`** import.
- **Media bytes** stay in Photos / iCloud Photos; CloudKit syncs pointers + small preview JPEGs.
- **Firebase** holds social data and friend-visible **projections** — not a second dive account. Two-phase buddy media publish (thumbs first, full content background). See **`cursor/firebase_user_profiles.md`**, **`cursor/buddy_activity_push_notifications.md`**.
- **Community sightings:** anonymized SiteReports / sightings when enabled (default on).
- **Catalog CDN:** optional Firebase Hosting/Storage refresh after bundled seed (**`CatalogCDNRefresh`**).
- **Delete account:** revokes Apple via Firebase, wipes Firestore social data, clears local user store.

---

## Data pipeline

- **`MockData/`** — opt-in Debug fixtures only.
- **`Resources/Catalog/`** — **`marine_life.json`**, **`dive_sites.json`** (OpenDiveMap reference).
- **`CatalogAuthoring/`** — offline authoring workflow (not in app target).
- Seeders: **`MarineLifeCatalogSeeder`**, **`DiveSiteReferenceCatalog`**, **`MockDataSeeder`**.

---

## Dive file import

- **Logbook → +** hub: **FIT dive**, **FIT snorkel** (Garmin swim/snorkel), **UDDF** (MacDive etc.), **manual dive**, **Connect device** (placeholder).
- **FIT:** **`FitDiveFileDecoder`** → **`DiveActivity`** or **`SnorkelActivity`**; scuba validates single-gas diving sessions.
- **UDDF:** **`UddfDiveFileDecoder`**; may import multiple dives per file; MacDive import guide for bulk.
- **Options per import:** create dive sites, attach library media, duplicate detection (**`DiveActivityDuplicateMatcher`**).
- **Post-import:** chained dive numbers, auto-link equipment with **`autoAdd`**, optional auto-renumber, site association, buddy consolidation.
- **Gaps:** no merge-duplicate UX beyond import block; bulk UDDF does not import MacDive media/locker/certs yet. See **`cursor/todo.md`**.

---

## Friends and sharing

- **Invites:** QR / **`links.godiveios.com/invite/{token}`**; 24h **`friendInvites`**; mutual **`friendships`**.
- **Buddy feed:** Firestore **`sharedDives`** projections; Me \| Buddies pager on Logbook; likes, comments, @mentions.
- **Friend profile:** shared stats, activities, media — read-only; distinct from local **`ViewDiveBuddyDetails`**.
- **Owner sharing:** Settings master toggle + per-activity **Activity Settings** (activity / media / private notes). New activities default sharing off with optional publish checkpoint banner.
- **Push:** FCM for invite accepted and buddy activity shared (batched, deduped server-side).

---

## Notable screens

| Screen | Summary |
|--------|---------|
| **Home** | Featured media carousel (3 daily picks), lifetime stats tiles, top buddies/species leaderboards, notifications bell |
| **Logbook** | Me: merged dives + snorkels, filters, trip grouping, swipe delete. Buddies: friend feed with social actions |
| **Dive detail** | Map-first; icon tabs map / tank / media; embedded blue overview sheet; landscape on phone sideways |
| **Snorkel detail** | Same shell; map / heart-rate / media; map tagging parity (buddies, marine life, tags) |
| **Field Guide** | Category hub → subcategory → species detail (about, range, similar, tagged dives/media) |
| **Explore** | Map or list; My Sites vs All Sites; catalog + user sites; add/edit site sheets with searchable country picker + world-scale map pin start |
| **Search** | Unified index: dives, snorkels, buddies, sites, species, trips, gear, certs, media grid |
| **Profile** | Blue-sheet hero, stats + tagged photos pager, side menu (trips, certs, locker, buddies, settings) |
| **Settings** | Units, tank default, renumber, auto-upload, sharing, notifications, crash reports, sign out / delete |
| **Trips** | Planner list (upcoming / active / past); detail with map hero, stats, activities, buddies, media, share card |
| **Equipment / Certs** | Locker + service reminders; cert OCR from card photos |

---

## User preferences (high level)

- **`AppUserSettings`:** imperial units, auto-renumber dives, default tank, auto-upload media to dives, buddy-share toggles, community sightings, notification prefs.
- Stored values canonical; display layer converts. **`UserPreferences`** syncs most settings via CloudKit.

---

## Not yet built / deferred

- Storing original FIT/UDDF attachments; export; merge/delete-duplicate beyond import guard.
- Full MacDive export parity (media, locker, certs from UDDF bulk).
- Garmin Connect auto-import; CloudKit Sharing (co-edit).
- **`cursor/todo.md`** and **`cursor/rules.md`** for larger deferrals.

---

## Mock data and testing

- **Policy:** Non-trivial code changes need tests (**`GoDiveMVPTests`** unit, **`GoDiveMVPUITests`** UI). See **`.cursor/rules/code-changes-require-tests.mdc`**.
- **Test layout:** Themed suites under **`GoDiveMVPTests/`** (e.g. `DiveActivityMediaTests`, `BuddyFeedTests`) + **`GoDiveMVPTestSupport.swift`** — no single monolithic test file.
- **Debug:** mock JSON seeding available but **off** at launch.
- **Unit tests:** import decoders, duplicate matcher, formatting, deletion, navigation helpers, presentation logic.
- **UI tests:** minimal launch shell test; scheme runs serially (not parallel across sims).
- **Agent builds:** only when user asks or before commit/push (**`.cursor/rules/xcode-workflow.mdc`** via **`workflow-triggers.mdc`**).
- **TestFlight:** **`cursor/testflight_setup.md`**.

---

## Documentation maintenance

When **`GoDiveMVP/`** behavior changes: append **`cursor/change_log.md`** (cleared after push). Touch **`cursor/app_summary.md`** only for architecture / user-visible shifts — **≤2 short sentences** per batch (**`.cursor/rules/ship-workflow.mdc`**).
