# Friend-Shared Activity Media — High-Quality Design

**Status:** Approved for implementation (design locked).  
**Related:** `hybrid_cloud_sync_boundaries.md`, `owasp_access_control_policy.md`, `GoDiveSharedMediaStorage.swift`, `GoDiveProfileHeroMediaExport.swift`.

## Goal

Upgrade buddy activity sharing from **256 px preview thumbnails only** to a **two-tier** model:

| Tier | Purpose | Format |
|------|---------|--------|
| **Thumbnail** | Buddy feed, grids, placeholders — fast first paint | 256 px JPEG (~50–500 KB) |
| **Content** | Detail view, pinch-zoom, video playback | Full-quality JPEG or 1080p MP4 |

**Dive and snorkel activities use the same quality tier and pipeline** (parity).

**“Full res”** means the owner’s photo exported at share quality (compressed JPEG from PhotoKit), not the original RAW/HEIC master. Friends decode and display at the exported resolution.

---

## Locked product decisions

| Decision | Value |
|----------|--------|
| Photos per activity | **20 max** — if more, take **first 20 by capture timestamp** (oldest first, same sort as gallery) |
| Videos per activity | **10 max** — if more, take **first 10 by capture timestamp** |
| Shared video duration | **30 seconds max** — longer clips export **first 30 s only** |
| Photo content export | Longest edge up to **4096 px**, JPEG, ≤ **6 MB** |
| Video content export | **1080p** H.264 MP4 (`AVAssetExportPreset1920x1080`), ≤ **50 MB** |
| Network default | **Cellular OK** for upload and download |
| WiFi-only option | **Settings toggle** (off by default) — when on, restrict content-tier upload/download to Wi‑Fi; thumbnails may still load on cellular |
| Storage URL access | **Public Firebase download tokens** (current model); friend-only signed URLs **deferred** |
| Snorkel parity | **Same** schema, caps, export, upload, and friend UI as dives |
| Settings opt-in | Existing master **Share dives with friends** + **Share media with friends** gates all uploads |

---

## Current state (v1 — live)

- Firestore `sharedDives` **schema v2**: `mediaPreviews[]` → `{ photoId, previewURL }`
- Storage: `users/{uid}/sharedMedia/{diveId}/{photoId}.jpg` — **5 MB**, **image only**
- Upload reuses local **256 px** `previewJPEGData` (`DiveMediaPreviewPersistence`)
- **No video MP4** — videos get poster JPEG only; no `mediaKind` in schema
- Snorkel projections upload **structured fields + swim track** but **`mediaPreviews: []`**
- Friend UI: `AsyncImage(previewURL)` — no disk cache, no progressive load
- Reference export pattern: `GoDiveProfileHeroMediaExport` (1920 px JPEG, 720p / 45 s video — profile hero only)

---

## Architecture: two-tier media

```
Owner device (SwiftData + Photos)
  → Settings opt-in gates
  → GoDiveSharedMediaExport (thumb + content bytes)
  → GoDiveSharedMediaUploadQueue (background, deduped)
  → Firebase Storage (per-item folder)
  → Firestore sharedDives (metadata + URLs)

Friend device
  → fetchFriendSharedDives
  → thumb first (feed / grid)
  → content on demand (detail / zoom / AVPlayer)
  → GoDiveSharedMediaCache (disk LRU)
```

### Two-phase publish (speed)

Do **not** block Firestore upsert on content-tier upload.

1. Upload **thumbnails** → write Firestore `mediaItems` with `contentURL` omitted or null.
2. Background queue uploads **content** tier.
3. Patch Firestore `contentURL` when each object completes.
4. Friends see activity + thumbs immediately; full media appears when patches land.

---

## Firestore: `sharedDives` schema v3

Bump `schemaVersion` to **3**. Replace `mediaPreviews` with **`mediaItems`** (keep v2 read compat: map `previewURL` → `thumbnailURL`).

```json
{
  "schemaVersion": 3,
  "mediaItems": [
    {
      "mediaId": "uuid",
      "kind": "photo",
      "thumbnailURL": "https://…",
      "contentURL": "https://…",
      "width": 4032,
      "height": 3024,
      "durationSeconds": null,
      "contentBytes": 1843200
    },
    {
      "mediaId": "uuid",
      "kind": "video",
      "thumbnailURL": "https://…",
      "contentURL": "https://…",
      "width": 1920,
      "height": 1080,
      "durationSeconds": 30,
      "contentBytes": 12582912
    }
  ],
  "featuredMediaId": "uuid"
}
```

**Field notes**

- `kind`: `"photo"` | `"video"`
- `contentURL`: optional until background upload completes
- `durationSeconds`: video only (max 30)
- `contentBytes`: optional hint for prefetch / progress UI
- Deprecate `mediaPreviews` / `featuredMediaPhotoId` in new writes; readers accept both during migration

---

## Firebase Storage layout

```
users/{ownerUID}/sharedMedia/{activityID}/{mediaID}/
  ├── thumb.jpg      # 256 px JPEG, ≤ 1 MB
  ├── photo.jpg      # full share JPEG (photos only), ≤ 8 MB rule
  └── video.mp4      # 1080p MP4 (videos only), ≤ 50 MB rule
```

`activityID` = dive or snorkel activity UUID (same `sharedDives` doc id as today).

### Storage rules (`catalog-cdn/storage.rules`)

Replace flat `{photoId}.jpg` match with nested folder rule:

```javascript
match /users/{userId}/sharedMedia/{activityId}/{mediaId}/{fileName} {
  allow read: if true;
  allow write: if request.auth != null && request.auth.uid == userId
    && (
      (fileName == 'thumb.jpg'
        && request.resource.size < 1 * 1024 * 1024
        && request.resource.contentType.matches('image/.*'))
      ||
      (fileName == 'photo.jpg'
        && request.resource.size < 8 * 1024 * 1024
        && request.resource.contentType == 'image/jpeg')
      ||
      (fileName == 'video.mp4'
        && request.resource.size < 50 * 1024 * 1024
        && request.resource.contentType == 'video/mp4')
    );
  allow delete: if request.auth != null && request.auth.uid == userId;
}
```

Deploy per `firebase-rules-deploy.mdc` when changed.

**Security (v1):** Public token URLs — same as avatars / profile hero. Obscurity via UUID paths. Signed URLs via Callable Cloud Function **deferred**.

---

## Media selection (per activity)

Use the same sort as in-app galleries:

- **Dives:** `DiveActivityMediaPresentation.sortedPhotos(on:)` — `capturedAt` ascending, else `sortOrder`
- **Snorkels:** `SnorkelActivityMediaPresentation.sortedPhotos(_:)` — same rules

Then:

```text
photos  = sorted.filter(kind == .image).prefix(20)
videos  = sorted.filter(kind == .video).prefix(10)
shared  = merge preserving gallery order (photos + videos interleaved as sorted)
```

Featured media: prefer owner’s featured id when it is within the capped set; else first item in `shared`.

**Owner messaging (optional v1):** Settings or one-time notice when caps trim items — not required for first ship.

---

## Client export: `GoDiveSharedMediaExport`

New module (mirror `GoDiveProfileHeroMediaExport`).

### Photos

| Output | Settings |
|--------|----------|
| `thumb.jpg` | Reuse `previewJPEGData` / `DiveMediaPreviewPersistence` (256 px, q=0.72, ≤512 KB) |
| `photo.jpg` | PhotoKit `highQualityFormat`, longest edge **min(source, 4096)**, JPEG q=0.85 → 0.75 fallback, ≤ **6 MB** |

### Videos

| Output | Settings |
|--------|----------|
| `thumb.jpg` | Poster frame at 256 px (from first frame or existing preview) |
| `video.mp4` | `AVAssetExportPreset1920x1080`, `shouldOptimizeForNetworkUse = true`, trim **first 30.0 s**, include audio when present |

### Export hygiene

- Strip **GPS EXIF** from shared JPEGs
- Transcode on **`Task.detached`** (off main actor)
- Soft-fail per item — omit failed items from Firestore; do not fail entire activity publish

---

## Upload: `GoDiveSharedMediaStorage` + queue

Refactor `GoDiveSharedMediaStorage`:

| Method | Role |
|--------|------|
| `objectPath(ownerUID:activityID:mediaID:file:)` | `thumb.jpg` / `photo.jpg` / `video.mp4` |
| `uploadTier(...)` | `putDataAsync` / resumable `putFile` for video |
| `deleteActivityMedia(ownerUID:activityID:)` | Wipe activity folder |
| `deleteAllForOwner(ownerUID:)` | Account delete (existing) |

**`GoDiveSharedMediaUploadQueue`**

- Content fingerprint (SHA-256 of export bytes or `photosLocalIdentifier` + mod date) — skip unchanged re-uploads
- Concurrency: **2** parallel uploads
- Resumable upload for `video.mp4`
- WiFi gate: when **Share media on Wi‑Fi only** is on, queue content tiers until Wi‑Fi (recommend queue all pending bytes for simplicity)

**Call sites**

- `GoDiveSharedDiveProjectionSync.upsertDive` — replace `uploadMediaPreviewsIfNeeded`
- `GoDiveSharedDiveProjectionSync.upsertSnorkel` — wire same helper (today `mediaPreviews: []`)

**Opt-out / cleanup fixes**

- When media sharing off: `FieldValue.delete()` for `mediaItems` (fix merge-stale-fields)
- Delete Storage objects for removed media and when toggles turn off

---

## Client retrieval: speed + quality

### Progressive loading

| Surface | Load |
|---------|------|
| Buddy feed tile | `thumbnailURL` only |
| Detail hero pager | Thumb → crossfade to `contentURL` when available |
| Pinch-to-zoom | `contentURL` |
| Video | Poster thumb + `AVPlayer` streaming `contentURL` |

### `GoDiveSharedMediaCache`

- Disk LRU under `Caches/GoDiveSharedMedia/` — separate `thumbs/` and `content/` namespaces
- Suggested caps: thumbs ~50 MB, content ~500 MB (tunable)
- All URLs through **`GoDiveRemoteURLPolicy.sanitizedFirebaseStorageURL`**

### Prefetch

| Trigger | Action |
|---------|--------|
| Buddy feed scroll | Prefetch next **3** thumbnails |
| Open friend detail | Prefetch featured **content** + adjacent thumbs |
| Media pager swipe | Prefetch next **content** in background |
| Low Data Mode | Thumbnails only unless user overrides |

### Network settings

| Setting | Default | Behavior |
|---------|---------|----------|
| Share media on Wi‑Fi only | Off | Queue uploads until Wi‑Fi when on |
| Download friend media on Wi‑Fi only | Off | Skip `contentURL` fetch on cellular when on |

Respect system **Low Data Mode** via `URLSessionConfiguration`.

### Decode

- JPEG decode off main actor; single `@MainActor` image apply
- Video: stream via `AVPlayer` — do not load full MP4 into memory

---

## Friend UI changes

| Area | Change |
|------|--------|
| `LogbookBuddyFeedTileView` | Thumb-only heroes; video badge on thumb |
| `FriendSharedActivityDetailPanels` | Progressive thumb → content; `AVPlayer` for video |
| `FriendSharedDiveDetailView` | Same for dive + snorkel |
| Schema mapping | `GoDiveSharedDiveProjectionMapping` v3 types |
| Presentation | `FriendSharedActivityDetailPresentation`, `LogbookBuddyFeedPresentation` |

---

## Settings copy (draft)

- **Share media with friends** (existing): Includes thumbnails and full-quality photos (up to 20) and videos (up to 10, 30 seconds each).
- **Share media on Wi‑Fi only**: Upload shared photos and videos only on Wi‑Fi.
- **Download friend media on Wi‑Fi only**: Download full-quality friend photos and videos only on Wi‑Fi. Thumbnails may still appear on cellular.

---

## Implementation phases

| Phase | Work |
|-------|------|
| **1** | Schema v3 mapping + Storage path helpers + rules deploy |
| **2** | `GoDiveSharedMediaExport` (photo + video caps) |
| **3** | Upload queue + two-phase Firestore publish + dedup/cleanup |
| **4** | `GoDiveSharedMediaCache` + progressive friend UI + URL policy |
| **5** | Snorkel parity in `upsertSnorkel` + shared selection helper |
| **6** | WiFi-only settings + `AppUserSettings` keys |
| **7** | Tests + `docs/friends.md` / `privacy-and-data.md` |

**Estimated effort:** ~1.5–2 weeks focused.

---

## Tests (required)

| Case | Expect |
|------|--------|
| 25 photos on activity | Only **20** earliest exported |
| 12 videos on activity | Only **10** earliest exported |
| 60 s video | Export length ≤ **30 s** |
| Photo export | ≤ 4096 px edge, ≤ 6 MB |
| Schema v2 read | `previewURL` maps to thumb |
| Schema v3 write | `mediaItems` with kinds |
| WiFi gate | Content upload skipped on cellular when setting on |
| Snorkel upsert | Same `mediaItems` as dive |
| Selection order | Matches `sortedPhotos` gallery order |
| URL policy | Rejects non-Firebase hosts on friend media |

---

## Deferred

- Friend-only signed URLs (Cloud Function + friendship verify)
- HLS / adaptive streaming
- Per-owner Storage egress alerts (console ops only for now)
- Owner UI surfacing when caps trim media

---

## Cost & ops notes

- Hash dedup limits re-upload on dive edits
- Per-activity caps bound worst-case Storage (20 × ~6 MB photos + 10 × ~50 MB videos theoretical max per activity)
- Firebase CDN caches token URLs at edge — disk cache on friend device reduces repeat egress
- Monitor Storage prefix growth: `users/*/sharedMedia/`
