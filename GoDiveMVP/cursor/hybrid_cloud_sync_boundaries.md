# Hybrid Cloud Sync Boundaries

Source of truth for the hybrid architecture on `feature/icloud-hybrid-sync` (Phases **1–4b** + **friends-ready v1** are **implemented**).

**Goal:** Apple-native hybrid strategy. User-generated rows sync through the user’s **iCloud private CloudKit** database; app-provided catalog content stays developer-owned and refreshes from a **Firebase** CDN; media bytes stay in the user’s Photos / iCloud Photos library by default; a **Firebase Auth + Firestore** social directory is friends-ready (no dive data in Firebase).

## Current Decision

| Layer | Local store | Cloud owner | Status |
|-------|-------------|-------------|--------|
| User-generated dive log data | SwiftData user store | User iCloud private database (**CloudKit**) | **Phase 2 — live** |
| Media bytes | Photos library | User iCloud Photos | **Phase 3 — live** (bytes never in CloudKit) |
| Media pointers / previews | SwiftData user store | User iCloud private database (**CloudKit**) | **Phase 3 — live** |
| App catalogs | Local catalog cache | GoDive CDN (**Firebase Hosting / Storage**) | **Phase 4 / 4b — live** (optional secrets) |
| Social directory (friends-ready) | Firestore `users/{uid}` | **Firebase Auth + Firestore** | **Friends-ready v1 — live** |
| Crash reports | Local diagnostics rows | GoDive CloudKit **public** database (opt-in) | Existing |

### Highlighted dependencies

| Stack | Role |
|-------|------|
| **Apple CloudKit** | Dive-log sync (private) + opt-in crash upload (public). Entitlement container **`iCloud.PrimoSoftware.GoDiveMVP`**. |
| **Firebase** (SPM: **Core**, **Auth**, **Firestore**, **Storage**; Hosting/Storage for CDN) | Social directory (display name, interests, avatar) + developer catalog CDN. **Never** stores the dive log. |

Option A is the chosen approach:

- Use **SwiftData + CloudKit private** for user-owned structured data (dive log).
- Use **PhotoKit / iCloud Photos** for media storage; sync identifiers and small previews, not full media copies.
- Use **CDN manifests** for app-owned catalogs and heavy reference assets (**Firebase Storage + Hosting**).
- Use **Firebase Auth + Firestore** only as a **social directory** (display name + stable Firebase UID for future friends) — **not** as dive-log sync. Dive data stays on CloudKit / SwiftData.

## Store Split

Phase 1 should split today's single `ModelContainer` into at least two configurations before enabling CloudKit:

| Store | CloudKit | Models / data | Notes |
|-------|----------|---------------|-------|
| User store | `.private("iCloud.PrimoSoftware.GoDiveMVP")` or explicit equivalent | `UserProfile`, dives, buddies, media pointers, sightings, equipment, certifications, trips, user tags/settings overlays | Must become CloudKit-compatible before sync turns on. **Does not** include depth-profile samples. |
| User-local store | `.none` | `DiveProfilePoint` | On-device chart rows; UUID-linked to dives. Full track also synced as **`DiveActivity.profileTrackData`** on the user store. |
| Catalog store | `.none` | Bundled / remote `MarineLife`, reference `DiveSite` cache, app-provided catalog metadata | Developer-owned; refreshed by seeder / CDN. Never uploads to a user's private DB. |
| Diagnostics | `.none` locally, manual CloudKit upload | `CrashReportRecord` | Existing opt-in uploader can keep using CloudKit public records outside SwiftData mirroring. |

CloudKit shape requirements for the user store (addressed for Phase 2 open):

- All relationships **optional** (including to-many) — stored as `*Storage: [T]?` with `@Transient` non-optional accessors.
- No **Codable / transformable** attributes (`NSCodableAttributeType`) — GPS as Doubles; list fields as JSON **`Data`** + `@Transient`.
- Enums as raw **`String`** storage where needed; no `@Attribute(.unique)` on synced models (app-level uniqueness instead).

## User-Synced Models

These rows represent user-created or user-owned data and should sync across the same user's Apple devices once CloudKit shape issues are fixed.

| Model | Sync policy | Notes / required Phase 1 work |
|-------|-------------|-------------------------------|
| `UserProfile` | Sync | Stable Apple user ID already exists (`appleUserIdentifier`). Avoid depending on local UUID as cross-device identity. |
| `DiveActivity` | Sync | Core log entry. Needs defaults/optionals and inverse audit. Keep canonical units. |
| `DiveProfilePoint` | **Local-only** (`GoDiveUserLocal`) + synced via dive blob | Row samples stay local for charts. Full track syncs as compressed **`DiveActivity.profileTrackData`** (`DiveProfileTrackCodec`) — one CloudKit field update per dive, not per sample. |
| `DiveBuddy` | Sync | Contact links are device-local-ish; sync roster name/photo, resolve Contacts opportunistically per device. |
| `DiveBuddyTag` | Sync | Join row. Use stable denormalized IDs plus relationships. |
| `DiveMediaPhoto` | Sync pointer row | Sync `PHCloudIdentifier` + local identifier + preview JPEG. Full asset bytes stay in Photos. |
| `DiveMediaBuddyTag` | Sync | Join row between media / buddy / dive. Needs inverse audit. |
| `ActivityTag` | Sync | User-created reusable tags and dive links. |
| `SightingInstance` | Sync | Replace CloudKit-incompatible unique enforcement with app-level uniqueness by `sightingUUID`. |
| `MarineLifeUserRecord` | Sync | User overlay for catalog species; references catalog UUIDs, not private copies of catalog records. |
| `EquipmentItem` | Sync | Gear photos can sync as blobs if small; consider later asset treatment if photos grow. |
| `DiveActivityEquipmentList` | Sync | Dive-owned equipment grouping. |
| `DiveEquipmentEntry` | Sync | Join row. Preserve denormalized IDs for conflict recovery. |
| `Certification` | Sync | Card images may be larger; keep in Phase 1 but monitor CloudKit payload size / asset requirements. |
| `DiveTrip` | Sync | Trip plans and completed trip records. Catalog planned sites should reference stable site IDs. |
| `DiveTripActivityLink` | Sync | Join row. |
| `DiveTripBuddyLink` | Sync | Join row. |

## Local-Only / Developer-Owned Models

| Model / data | Policy | Reason |
|--------------|--------|--------|
| `DiveProfilePoint` | Local user-local store (+ blob on dive) | Per-sample CloudKit rows blocked export; charts use local rows; sync uses compressed **`profileTrackData`** on **`DiveActivity`**. |
| `MarineLife` bundled catalog rows | Local catalog cache | App-provided source of truth belongs to GoDive CDN / bundled seed, not each user. |
| User-created `MarineLife` (`user-marine-life-*`) | **`UserMarineLife`** in user store | Synced user data; catalog store keeps bundled / CDN `MarineLife` only. |
| `DiveSite` reference catalog / OpenDiveMap rows | Local catalog cache | App/reference source comes from GoDive CDN / OpenDiveMap seed. |
| User-created / edited `DiveSite` rows | **`UserDiveSite`** in user store | Synced user data; OpenDiveMap / CDN reference rows stay on catalog `DiveSite`. |
| OpenDiveMap sites linked from a dive | **`UserDiveSite` snapshot** (same UUID) + local catalog cache | Catalog `DiveSite` alone does not sync — snapshot carries My Sites / resolve across reinstall. |
| `CrashReportRecord` | Local diagnostics; manual opt-in public upload | Not part of private user sync. |
| `SecurityEventRecord` | User store (private CloudKit) + opt-in public upload | Journal mirrors across the user’s devices; developer share is scrubbed public CloudKit (no `ownerProfileID`). |
| Raw FIT / UDDF files | Never sync by default | GoDive does not retain source file bytes today; keep that behavior. |
| Generated preview / session caches | Never sync, except `previewJPEGData` on media rows | Rebuildable or device-specific. |
| App settings in `UserDefaults` | Synced via **`UserPreferences`** (except crash / diagnostic sharing) | Units / tank / renumber / auto-upload / weights / bulk UDDF create-sites mirror through CloudKit; **`shareCrashReports`** and **`shareSecurityEvents`** stay local. |

## Media Boundary

Default behavior:

- Store a local PhotoKit identifier for the current device.
- Add a synced `PHCloudIdentifier` for cross-device lookup.
- Keep `previewJPEGData` synced for fast UI and fallback when the full asset is unavailable.
- Do not upload full photos/videos to GoDive servers or CloudKit assets by default.
- Surface a clear state when a synced media row cannot resolve on the current device (iCloud Photos off, asset deleted, permission missing).

Opt-in future behavior:

- Add explicit export / backup copies only as a user-controlled feature.
- If full media backup is added, use user-owned storage first (iCloud private assets or Files / iCloud Drive), with clear quota messaging.

## Catalog Boundary

Phase 4 app-owned catalog refresh uses a **Firebase Hosting** CDN (HTTPS manifests + JSON; Storage for heavy assets later):

- Bundled seed remains the offline fallback.
- Manifest includes version, minimum app version, checksums (`catalog/v1/manifest.json`).
- **v1 Marine Life:** full JSON upsert via **`CatalogCDNRefresh`** / **`MarineLifeCatalogUpsert`** (optional **`CatalogCDNSecrets.plist`**).
- Assets may use content-addressed immutable URLs later (Phase 4b); manifests use short cache TTL.
- Local cache upserts by stable catalog IDs and prunes removed reference rows while preserving user-created rows and user overlays.
- Android can reuse this catalog API unchanged later.
- Do **not** put user dive data or media bytes in Firebase Hosting/Storage — those stay CDN-only for catalogs.
- Dive site / OpenDiveMap CDN and photo/USDZ CDN are **Phase 4b** (implemented: ODM reference cache + Storage asset URLs; bundled assets remain offline-first).

## Social directory (Firebase Auth + Firestore)

Friends-ready v1 — setup notes in **`cursor/firebase_user_profiles.md`**.

| Doc | Path | Access |
|-----|------|--------|
| Public profile | `users/{firebaseUid}` | Signed-in read; owner write |
| Private Apple link | `users/{firebaseUid}/private/account` | Owner read/write only |

Public fields: `displayName`, `handle` (reserved, empty), `photoURL` (Storage download URL after signup photo), `interests` (`Scuba Diving` / `Free Diving` / `Snorkeling`), `discoverable` (default `true`), `createdAt` / `updatedAt`, `schemaVersion` (= 2).  
Private fields: `appleUserIdentifier` (links to CloudKit `UserProfile`; never on public reads).

- Sign in with Apple still drives **`AccountSession`** / CloudKit `UserProfile`.
- Same Apple credential also signs into **Firebase Auth** (`identityToken` + nonce); soft-fail if Firebase is unavailable.
- **New accounts:** Auth immediately; **defer** Firestore until post-sign-up **photo** step (upload avatar to Storage when present, then upsert with `photoURL` + `interests`). Returning accounts upsert on sign-in / launch.
- **Delete account** (Settings): revoke Apple token via Firebase, delete Storage avatar + Firestore docs + Auth user, wipe local SwiftData user store (CloudKit mirrors deletes), clear returning-account hints, sign out (`GoDiveAccountDeletion`).
- `ownerProfileID` for dive rows remains the CloudKit / SwiftData UUID — not the Firebase UID.
- Deferred: friend requests / friendships collections, handle uniqueness UI.

## Conflict and Identity Rules

- Treat Sign in with Apple `appleUserIdentifier` as the stable account key for GoDive profile lookup (CloudKit dive log).
- Treat Firebase Auth UID as the stable key for the **social directory** only (`users/{uid}`).

- After CloudKit import, **`UserProfileCloudKitIdentityMerge`** collapses duplicate profiles that share the same Apple ID and reassigns `ownerProfileID` rows to one canonical profile (avoids empty logbook after reinstall).
- Treat CloudKit private database ownership as the sync boundary: one user's private data, across that user's Apple devices.
- Do not support buddy-to-buddy shared editing in Phase 0-2. That requires a separate CloudKit Sharing / shared-database design.
- Prefer app-level logical uniqueness and tombstones over CloudKit-unsupported uniqueness constraints.
- Preserve denormalized stable UUID/string IDs on join rows so relationships can be repaired after sync conflicts.

## Phase 1 Readiness Checklist

- [x] Define separate user and catalog schemas/configurations (`AppSwiftDataStorePartition`).
- [x] Decide how to split hybrid models (`MarineLife` / `DiveSite` ownership flags + migration note that dual-store needs a type split or user-owned synced model because SwiftData allows each type in only one configuration).
- [x] Add a structural test for CloudKit-compatible user models (defaults/optionals, no unique attributes, explicit inverses).
- [x] Add migration plan from today's single local store to split stores (`hybrid_cloud_sync_phase1_migration.md`).
- [x] Add `PHCloudIdentifier` field design for `DiveMediaPhoto` (`photosCloudIdentifier`).
- [x] Decide whether user preferences move from `UserDefaults` into a synced model (Phase 2: **`UserPreferences`** + `syncedPreferenceKeys`; crash sharing stays local).
- [x] Keep `cloudKitDatabase: .none` until the structural test and migration are green.
- [x] Dual-store migration runner + cross-store relationship removal (Phase 1b/1c).
- [x] Phase 2: enable private CloudKit on the user store only.
- [x] Legacy unified → dual migration **out of scope** for development (clean install / delete app).

## Phase 1 Progress (schema readiness kickoff)

Shipped on `feature/icloud-hybrid-sync`:

- Partition lists + Firebase CDN vendor lock.
- Removed `@Attribute(.unique)` from `MarineLife.uuid` and `SightingInstance.sightingUUID`; app-level uniqueness helpers.
- CloudKit-oriented property defaults on user/catalog models; inverse relationship gaps filled (`DiveMediaPhoto` buddy tags / sightings, `DiveSite` sightings, `UserProfile.marineLifeUserRecords`).
- `ownershipRaw` on `MarineLife` and `DiveSite` with launch backfill.
- `DiveMediaPhoto.photosCloudIdentifier` — captured at attach + launch backfill; resolved to device-local IDs on load/prune (Phase 3).
- Production container opens **dual on-disk stores**; Phase 2 enables **private CloudKit on the user store** (`iCloud.PrimoSoftware.GoDiveMVP`); catalog + diagnostics stay local-only. Legacy unified store migrates once.

## Phase 3 Media Resolve

- Capture **`PHCloudIdentifier.stringValue`** into **`photosCloudIdentifier`** when attaching library media (and backfill legacy rows).
- On other devices / after reinstall: map cloud → **`photosLocalIdentifier`** before PhotoKit load or prune.
- Full media bytes remain in **iCloud Photos**; CloudKit syncs only the pointer row + preview JPEG.

## Phase 4 / 4b Catalog CDN

- Optional **`CatalogCDNSecrets.plist`** → **`ManifestBaseURL`** (Firebase Hosting).
- Launch: bundled seed, then **`CatalogCDNRefresh.refreshIfNeeded`** (Marine Life upsert + OpenDiveMap reference disk cache; version gate + SHA-256).
- Photos/USDZ: Firebase Storage URLs + on-demand disk cache; bundled offline-first.
- Publish notes: **`cursor/catalog_cdn_publish.md`**. User sites stay CloudKit **`UserDiveSite`**.

