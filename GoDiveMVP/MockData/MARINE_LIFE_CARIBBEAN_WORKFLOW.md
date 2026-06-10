# Caribbean marine life catalog — FishBase workflow

Facts-only import from [FishBase](https://www.fishbase.se) (CC BY-NC). **You** write diver-facing descriptions in the staging spreadsheet; the app bundle only grows when you choose to sync.

## Files

| File | Role |
|------|------|
| `marine_life_caribbean_staging.csv` | **Authoring sheet** — diver-visible Caribbean saltwater fish (FishBase v24.07; ~600 species after reef/depth filter) |
| `marine_life_sample.json` | **App seed** — curated species shipped in the bundle |
| `marine_life_source.csv` | Legacy scratch pad (angelfish batch); optional |
| `Scripts/extract_fishbase_caribbean.py` | Rebuild staging CSV from FishBase |
| `Scripts/sync_marine_life_staging_to_json.py` | Merge staging → JSON |
| `Scripts/fetch_marine_life_images.py` | CC0 / CC BY hero images → staging CSV |
| `Scripts/fishbase_caribbean_config.json` | Parquet URL, family → subcategory map |
| `marine_life_image_cache.json` | API result cache (re-runs skip network when cached) |

## One-time setup

```bash
cd /path/to/GoDiveMVP
python3 -m venv GoDiveMVP/Scripts/.venv
GoDiveMVP/Scripts/.venv/bin/pip install -r GoDiveMVP/Scripts/requirements-fishbase.txt
```

## Refresh facts from FishBase

```bash
GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/extract_fishbase_caribbean.py
```

**Scope:** `Region = Caribbean` in FishBase + saltwater presence (`country.Saltwater = 1`, `species.Saltwater = 1`, not freshwater-primary).

**Diver visibility filter** (default on in `fishbase_caribbean_config.json`):

| Signal | FishBase field | Notes |
|--------|----------------|-------|
| Reef-associated | `species.DemersPelag = reef-associated` | Same label FishBase uses for “Reef-associated” search |
| Sand / grass / slope | `demersal`, `pelagic-neritic`, `benthopelagic` | Common on Caribbean dives outside pure reef |
| Ecology reef flag | `ecology.CoralReefs = -1` | FishBase stores habitat flags as **-1** (not 1) |
| Depth cap | `DepthRangeDeep <= 130` m | Drops bathypelagic / abyssal species divers never see |

Set `"diver_visibility_filter": { "enabled": false }` to restore the full ~1,677-species Caribbean marine list. Tighten `max_depth_meters` (e.g. `100`) for recreational-only scope.

## Hero images (CC0 / CC BY)

```bash
# Preview first 20 matches:
GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/fetch_marine_life_images.py --dry-run --limit 20

# Fill staging CSV (skips rows that already have images in CSV or bundled JSON):
GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/fetch_marine_life_images.py

# CC0 / public domain only:
GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/fetch_marine_life_images.py --cc0-only
```

**Sources:** Wikimedia Commons (primary), Openverse (fallback). Search queries append **`underwater`**, **`diver`**, and **`scuba`** to the scientific name; scoring boosts in-situ reef photos and penalizes maps, sketches, fishing shots, and diagrams. Use **`--refetch-gaps`** to retry misses and `imageNeedsReview=yes` rows. Writes `featureImageURL` plus workflow columns `imageLicense`, `imageAttribution`, `imageSource`, `imageNeedsReview`. Re-run **`sync_marine_life_staging_to_json.py --all`** to push images into the app bundle.

## Offline bundled photos (Field Guide)

After URLs are approved in staging, materialize JPEGs for offline use:

```bash
GoDiveMVP/Scripts/.venv/bin/pip install Pillow
GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/download_marine_life_images.py --dry-run --limit 5
GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/download_marine_life_images.py
GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/sync_marine_life_staging_to_json.py --all
```

Writes **`Resources/MarineLifePhotos/{uuid}.jpg`** (960×720, center-cropped 4:3 — same aspect as the mosaic UI). Sets **`featureImageResourceName`** on the staging CSV and ships **`feature_image_resource`** in JSON. The app loads bundled photos first; remote **`feature_image`** URLs remain as fallback/provenance only.

To replace one image manually: paste a new URL in **`featureImageURL`**, re-run **`download_marine_life_images.py --overwrite --limit 1`** (or edit the CSV row uuid only and download), then sync JSON.

Manifest: **`MockData/marine_life_bundle_photos_manifest.json`** (source URL + SHA256 per bundled file).

## Manual image review (local HTML UI)

```bash
GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/serve_marine_life_image_review.py
open http://127.0.0.1:8765
```

- Browse all species in a **4:3 mosaic grid** (bundled JPEG when present, otherwise remote URL).
- Filter by **needs review**, **no image**, or **missing bundle**.
- Click a card → paste a new **CC0 / CC BY** URL, edit license/attribution, then:
  - **Save URL only** → updates **`marine_life_caribbean_staging.csv`**
  - **Save + download bundle** → also re-crops and writes **`Resources/MarineLifePhotos/{uuid}.jpg`**
- **Mark for removal** → sets **`markForDeletion=yes`** on the staging row (red **Remove** badge). Apply deletions with **`apply_marine_life_staging_deletions.py --sync-json --all`** to remove rows from CSV, bundled photos, manifest, and **`marine_life_sample.json`**.
- After batch edits, run **`sync_marine_life_staging_to_json.py --all`** before rebuilding the app.

## Your authoring loop

1. Open **`marine_life_caribbean_staging.csv`** (Numbers, Excel, or Cursor).
2. For each species you want in the app, fill **your** prose columns:
   - `aboutText` (required before sync — gates shipping)
   - `distinctiveFeatures`, `Abundance`, `habitatBehavior`, `diverReaction` (optional but recommended)
3. Optionally set `subCategory` when `needs_subcategory = yes` (deep-water / unmapped families).
4. Sync to JSON:

```bash
GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/sync_marine_life_staging_to_json.py
```

Default: rows with **non-empty `aboutText`** merge into `marine_life_sample.json`. With FishBase descriptions enabled (~569/601 filled), that ships nearly the full staging set. Use `--all` to include the few facts-only rows still missing text. Output is **staging-only** (legacy JSON uuids not in the CSV are dropped). Use `--dry-run` to preview counts.

5. Run the app — `MarineLifeCatalogSeeder` upserts by `uuid` and **removes** catalog rows no longer in bundled JSON.

## What FishBase fills (staging)

| Column | Source |
|--------|--------|
| `uuid` | Generated `marine-life-{slug}` (stable; deduped with spec code) |
| `fishbase_spec_code` | FishBase `SpecCode` |
| `commonName` | `FBname` or best English vernacular |
| `scientificName` | Genus + species |
| `category` | `fish` |
| `subCategory` | Family map in config (~53% mapped; rest flagged `needs_subcategory`) |
| `familyName` | FishBase family |
| `maxSizeMeters` | `Length` (cm → m) |
| `minDepthMeters` / `maxDepthMeters` | `DepthRangeShallow` / `DepthRangeDeep` |
| `aboutText` | `species.Comments` (ecology `AddRems` fallback) when `include_fishbase_descriptions` is **true** |
| `distinctiveFeatures` | `species.BodyShapeI` (prefixed “Body shape: …”) when descriptions enabled |

## Left empty on purpose

| Column | Why |
|--------|-----|
| `Abundance`, `habitatBehavior`, `diverReaction` | **You** write original GoDive copy (or backfill later) |
| `aboutText`, `distinctiveFeatures` | Empty when `include_fishbase_descriptions` is **false** — replace FishBase placeholders with your prose before shipping final copy |
| `featureImageURL` | Not from FishBase (backfill later) |
| `minSizeMeters` | FishBase max length only; no reliable min size (backfill later) |

JSON-only fields (`feature_model`) are not in CSV — add in JSON when needed.

## Backfill later (not in this pass)

- Minimum size / juvenile size
- Hero images (`feature_image`) and bundled USDZ (`feature_model`)
- Remaining `subCategory` for ~786 deep-pelagic / unmapped families
- Distribution prose in `Abundance` (FishBase has country lists; we did not auto-stub)

## Attribution

Ship FishBase attribution in app About before publishing a large import. Config reminder: `Scripts/fishbase_caribbean_config.json`.
