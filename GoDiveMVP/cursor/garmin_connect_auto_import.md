# Garmin Connect auto-import — research summary

**Status:** Deferred / not started  
**Last updated:** 2026-07-07  
**Goal:** Automatically import new dive activities into GoDive when they appear in a linked user’s Garmin Connect account (after watch sync).

---

## Executive summary

The **Garmin FIT SDK does not connect to Garmin Connect**. GoDive already uses **[FITSwiftSDK](https://github.com/garmin/fit-swift-sdk)** correctly — to **decode `.fit` files** after manual file pick. Automatic import requires Garmin’s **Connect Developer Program → Activity API**, plus a **small backend** for OAuth and webhooks. The FIT SDK stays the parser; new work is account linking, fetching files, and delivery to the app.

---

## What GoDive has today

| Piece | Status | Location |
|-------|--------|----------|
| FITSwiftSDK (v21.x+) | ✅ Integrated (SPM) | `GoDiveMVP` target |
| `.fit` decode | ✅ Single `Sport.diving` session per file | `Data/Import/FitDiveFileDecoder.swift` |
| Import + persist | ✅ Duplicate check, sites, buddies, photos | `Data/Import/FitDiveFileImport.swift` |
| Manual UI | ✅ Logbook → **+** → **Garmin** → file picker | `Views/Pages/activity_upload.swift` |
| Garmin Connect sync | ❌ Not built | Deferred in `cursor/rules.md` |

**Manual flow today:** Export a `.fit` from Garmin Connect → pick it in GoDive. The decode/persist pipeline is reusable for auto-sync by feeding it `Data` from the API instead of the file picker (`FitDiveFileImport.importFitData(_:)`).

---

## FIT SDK vs Garmin Connect API

| | **FIT SDK** | **Garmin Connect Activity API** |
|---|-------------|----------------------------------|
| **Purpose** | Parse/create `.fit` binary files | Access user’s Garmin Connect data after consent |
| **Auth** | None | OAuth 2.0 + PKCE (partner program) |
| **Trigger** | App already has the file | User syncs watch → data in Connect → API notifies partner |
| **Dive detail** | Full profile, tank, NDL, etc. | Summary JSON + downloadable **`.fit`** for full detail |
| **iOS-only?** | ✅ Yes | ❌ Needs server for tokens + callbacks |

**References**

- [FIT SDK (Swift)](https://github.com/garmin/fit-swift-sdk) — already in repo  
- [Garmin Connect Developer Program](https://developerportal.garmin.com/developer-programs/connect-developer-api)  
- [Activity API overview](https://developer.garmin.com/gc-developer-program/activity-api/)

---

## How automatic import would work

```
User finishes dive on watch
    → syncs to Garmin Connect (phone / USB)
    → Garmin POSTs activity webhook to GoDive backend
    → backend downloads .fit (OAuth, within ~24h window)
    → filter: diving activities only
    → queue FIT for user / notify app (APNs or poll on foreground)
    → app: FitDiveFileDecoder + persistImportedActivity (existing path)
```

### 1. Garmin Connect Developer Program

Apply for **Activity API** with **`ACTIVITY_EXPORT`** permission. Partner-gated — not self-serve API keys. Provides consumer key/secret, UAT environment, webhook tooling, and backfill for testing.

### 2. Link user account (OAuth 2.0 PKCE)

- Settings → **Connect Garmin** in app  
- `ASWebAuthenticationSession` → Garmin consent screen  
- Backend exchanges auth code for access + refresh tokens; map tokens to GoDive profile  
- Garmin rotates refresh tokens on every refresh — server must persist updates  
- On disconnect: call Garmin `DELETE user/registration` per their terms  

### 3. Receive new activities (Push or Ping/Pull)

| Mode | Behavior |
|------|----------|
| **Push** | Garmin POSTs activity summaries to registered HTTPS webhook shortly after user sync |
| **Ping/Pull** | Garmin pings; partner pulls from API (good for backfill) |

**FIT files:** Raw `.fit` delivery is typically **ping/pull** — webhook includes a **`callbackURL`** to fetch the file. Download within **~24 hours**, **once** (duplicate fetches may return HTTP 410). Backend needs a FIT downloader, not JSON-only handling.

### 4. Filter and dedupe

- Accept only **diving** activities (Descent / MK dives)  
- Reuse **`DiveActivityDuplicateMatcher`** and FIT `sourceDiveId` to skip re-imports  

### 5. Import on device

**Recommended:** Backend downloads `.fit` → app imports bytes via existing `FitDiveFileImport.importFitData(_:)` (same options: create sites, attach photos).

**Alternative:** Backend parses FIT and syncs JSON — duplicates mapping logic; avoid unless needed.

GoDive is **on-device SwiftData** with no cloud logbook today. Auto-import still needs minimal transport: pending-import queue + optional APNs wake.

---

## Why a backend is required

GoDive cannot be iOS-only for this feature:

1. **OAuth** — client secret and long-lived refresh tokens belong on a server for reliable background sync.  
2. **Webhooks** — Garmin must POST to a public HTTPS URL; the phone cannot receive these reliably while backgrounded.  
3. **FIT URLs expire** — something always-on should fetch within the 24h window and queue for the device.

**Minimal backend scope (v1):**

- OAuth connect / disconnect  
- Webhook receiver (activities + activity files)  
- Per-user token store  
- Queue of pending `.fit` blobs  
- Optional APNs: “new dive ready”  

Full cloud logbook sync is **not** required for v1.

---

## Phased plan

### Phase 0 — No Garmin approval

- Keep manual `.fit` export path documented (`docs/import.md`).  
- Ensure `importFitData` remains the single entry point for FIT bytes (already mostly true).

### Phase 1 — Partner setup

- Apply for Activity API; build UAT OAuth + one webhook.  
- End-to-end test: connect → sync Descent dive → download FIT → `FitDiveFileDecoder`.

### Phase 2 — Auto-import MVP

- **Settings → Connect Garmin**  
- Backend queues diving FITs; app pulls on launch / foreground (+ optional background fetch).  
- Same import options as manual flow; source remains `DiveSource.garminMK3`.

### Phase 3 — Polish

- Historical backfill on first connect  
- Disconnect / token revocation UX  
- Errors: expired token, non-diving activity, edge cases  

---

## What not to do

- **Replace FITSwiftSDK** — Activity API delivers the same `.fit` format.  
- **Unofficial Connect scrapers** — community login SDKs violate ToS and break with MFA.  
- **Direct USB/BLE to watch** — separate problem; not exposed for third-party dive apps like this path.

---

## Risks and constraints

| Risk | Notes |
|------|-------|
| Partner approval | Timeline and use-case review; pitch “dive log import for divers”. |
| 24h FIT window | Backend must download promptly; don’t rely on phone polling days later. |
| One dive per FIT | Decoder already enforces; multi-dive days may arrive as separate activities. |
| No server today | Main new infrastructure, not FIT parsing. |

---

## Code touchpoints (when implementing)

| Area | Files |
|------|-------|
| FIT decode | `Data/Import/FitDiveFileDecoder.swift` |
| FIT persist | `Data/Import/FitDiveFileImport.swift` |
| Duplicates | `DiveActivityDuplicateMatcher` |
| Manual import UI | `Views/Pages/activity_upload.swift` |
| User guide | `docs/import.md` |
| Deferral note | `cursor/rules.md` |

**New work (future):** Settings connect flow, backend service, webhook handlers, pending-import sync layer in app.

---

## Open questions (for later)

- Host backend where? (Existing infra vs new small service)  
- Notify app via APNs only, or also poll on schedule?  
- Per-import options defaults for auto-sync (create sites / attach photos)?  
- Multi-profile / family Garmin accounts?  
- Backfill depth on first connect (all history vs last N dives)?  

---

## Related docs

- `cursor/backlog.md` — backlog entry  
- `cursor/rules.md` — “no full Garmin device sync beyond `.fit` file MVP”  
- `cursor/app_summary.md` — current FIT import architecture  
- `docs/import.md` — user-facing manual import guide  
