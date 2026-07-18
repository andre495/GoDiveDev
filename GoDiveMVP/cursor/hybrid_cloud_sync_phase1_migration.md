# Hybrid Cloud Sync — Store Plan (Phase 1–2)

Source of truth companion to `hybrid_cloud_sync_boundaries.md` and `AppSwiftDataStorePartition`.

## Current state (Phase 2 — migration out of scope)

- **Production** opens dual on-disk stores via **`AppSwiftDataDualStoreBootstrap`** (`GoDiveUser` / `GoDiveCatalog` / `GoDiveDiagnostics`).
- **User store:** prefers `cloudKitDatabase: .private("iCloud.PrimoSoftware.GoDiveMVP")`; falls back to **`.none`** if CloudKit open fails.
- **Catalog + diagnostics:** stay `cloudKitDatabase: .none`.
- **Legacy unified `default.store` migration is out of scope** for this development build (no real-user fleet). Delete the app / clear container data for a clean dual + CloudKit install. An in-memory / test migrator may remain in-tree but is **not** on the production launch path.
- **In-memory tests** use a unified container (`AppSwiftDataSchema.makeUnifiedContainer`) with CloudKit **off**. Custom-root dual opens keep user CloudKit **off** unless explicitly enabled.
- **UUID-only catalog refs:** sightings, overlays, dives, and trips resolve via UUID/ID helpers.
- **User store models:** `UserMarineLife` and `UserDiveSite`.
- Background mode **remote-notification** is set for CloudKit wakeups.

## Target stores

| Store | CloudKit | Contents |
|-------|----------|----------|
| User | `.private` (Phase 2) | `AppSwiftDataStorePartition.userModelTypes` including **`UserMarineLife`** / **`UserDiveSite`** |
| Catalog | `.none` | Catalog-owned `MarineLife` + OpenDiveMap / CDN `DiveSite` rows |
| Diagnostics | `.none` | `CrashReportRecord` |

## Resolution

| Link | Mechanism |
|------|-----------|
| Sighting → species | `marineLifeUUID` → `MarineLifeSpeciesResolver` |
| Overlay → species | `marineLifeUUID` |
| Dive → site | `diveSiteID` → `DiveLinkedSiteResolver` |
| Trip planned sites | `plannedSiteIDs: [UUID]` |
| Sighting → site | `diveSiteID` |

## Preferences

- Synced later (still UserDefaults for now; keys in `AppSwiftDataStorePartition.syncedPreferenceKeys`).
- Local only: `shareCrashReports` (`localOnlyPreferenceKeys`).

## Catalog CDN

- Vendor: **Firebase Storage + Hosting** (versioned manifests, content-addressed assets).
- Bundled seed remains offline fallback.
- **Phase 4 (Marine Life):** HTTPS Hosting manifest + full `marine_life.json` upsert via **`CatalogCDNRefresh`** (optional **`CatalogCDNSecrets.plist`**). See **`catalog_cdn_publish.md`**.
- **Phase 4b:** OpenDiveMap `dive_sites.json` → on-disk reference cache; photos/USDZ on Firebase Storage with on-demand disk cache (bundled offline-first).

## Gate checklist

- [x] Partition lists defined
- [x] Ownership fields + inference
- [x] Unique attributes removed; logical uniqueness helpers
- [x] `photosCloudIdentifier` on `DiveMediaPhoto`
- [x] UUID-only species/site refs; `UserMarineLife` / `UserDiveSite`
- [x] Dual-store factory + production dual open
- [x] Phase 2: private CloudKit on the **user** store (with local fallback)
- [x] Legacy unified → dual **migration out of scope** (dev-only; delete app for clean Phase 2)
- [x] Dual-store / multi-device smoke on a real iPhone (signed into iCloud) — device smoke after clean install / profile-merge fix
- [x] Synced **`UserPreferences`** for Settings keys (crash sharing local-only)
- [x] Phase 3: Photos `PHCloudIdentifier` resolve across devices
- [x] Phase 4: Firebase catalog CDN (Marine Life JSON refresh; sites / assets = Phase 4b)
- [x] Phase 4b: OpenDiveMap sites CDN (reference cache) + Storage photos/USDZ
