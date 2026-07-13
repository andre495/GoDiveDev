# Caribbean marine life catalog — FishBase + SeaLifeBase workflow

Facts-only import from [FishBase](https://www.fishbase.se) (fish) and [SeaLifeBase](https://www.sealifebase.se) (invertebrates and other non-fish marine life), both CC BY-NC. **You** write diver-facing descriptions in the staging spreadsheet; the app bundle only grows when you choose to sync.

> **Note:** [ReefBase.org](https://reefbase.org) is a coral-reef *systems* database (locations, threats, resources), not a species catalog. Non-fish marine animals come from **SeaLifeBase**, the FishBase sister project with the same parquet layout.

## Files

| File | Role |
|------|------|
| `marine_life_caribbean_staging.csv` | **Authoring sheet** — diver-visible Caribbean saltwater species (fish + invertebrates) |
| `marine_life_sample.json` | **App seed** — curated species shipped in the bundle |
| `marine_life_source.csv` | Legacy scratch pad (angelfish batch); optional |
| `Scripts/extract_fishbase_caribbean.py` | Rebuild **fish** rows in staging CSV from FishBase |
| `Scripts/extract_sealifebase_caribbean.py` | **Append** non-fish rows from SeaLifeBase (keeps existing fish) |
| `Scripts/sync_marine_life_staging_to_json.py` | Merge staging → JSON |
| `Scripts/fetch_marine_life_images.py` | CC0 / CC BY hero images → staging CSV |
| `Scripts/fishbase_caribbean_config.json` | FishBase parquet URL, family → subcategory map |
| `Scripts/filter_marine_life_by_reef.py` | Keep staging rows that match REEF.org scientific names |
| `Scripts/fetch_snorkelstj_species_reference.py` | Crawl snorkelstj.com species pages → common names |
| `Scripts/validate_marine_life_by_snorkelstj.py` | Fuzzy-match staging common names against snorkelstj.com |
| `Scripts/snorkelstj_caribbean_config.json` | Crawl seeds, fuzzy threshold, cache path |
| `MockData/snorkelstj_species_reference.csv` | Cached snorkelstj.com species names |
| `Scripts/reef_caribbean_config.json` | REEF regions (TWA + SAS) and cache path |
| `MockData/reef_species_reference.csv` | Cached REEF species reference export |
| `marine_life_image_cache.json` | API result cache (re-runs skip network when cached) |

## One-time setup

```bash
cd /path/to/GoDiveMVP
python3 -m venv GoDiveMVP/Scripts/.venv
GoDiveMVP/Scripts/.venv/bin/pip install -r GoDiveMVP/Scripts/requirements-fishbase.txt
```

## Refresh facts from FishBase (fish)

```bash
GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/extract_fishbase_caribbean.py
```

**Scope:** `Region = Caribbean` in FishBase + saltwater presence (`country.Saltwater = 1`, `species.Saltwater = 1`, not freshwater-primary).

**Diver visibility filter** (default on in `fishbase_caribbean_config.json`):

| Signal | FishBase field | Notes |
|--------|----------------|-------|
| Reef-associated | `species.DemersPelag = reef-associated` | Same label FishBase uses for “Reef-associated” search |
| Sand / grass / slope | `demersal`, `pelagic-neritic`, `benthopelagic` | Common on Caribbean dives outside pure reef |
| Ecology reef flag | `ecology.CoralReefs = -1` | FishBase stores habitat flags as **-1** (aggregated to 1 in extract SQL) |
| Depth cap | `DepthRangeDeep <= 130` m | Drops bathypelagic / abyssal species divers never see |

Set `"diver_visibility_filter": { "enabled": false }` to restore the full ~1,677-species Caribbean marine fish list. Tighten `max_depth_meters` (e.g. `100`) for recreational-only scope.

## Refresh facts from SeaLifeBase (invertebrates + marine mammals)

```bash
python3 GoDiveMVP/Scripts/extract_sealifebase_caribbean.py
```

**Appends** non-fish rows to the existing staging CSV — your fish rows (images, prose, review flags) are untouched. Re-run safely; species already present (matching `fishbase_spec_code`) are skipped.

Use `--replace-inverts` to drop all existing non-fish rows and rebuild from SeaLifeBase while keeping fish rows.

**Scope:** Caribbean saltwater species from SeaLifeBase v24.07, excluding fish classes (`Actinopterygii`, `Chondrichthyes`, `Sarcopterygii`) and limiting to diver-relevant phyla (sponges, cnidarians, mollusks, crustaceans, echinoderms, worms, bryozoans, tunicates, marine mammals).

**Diver visibility filter** (default on in `sealifebase_caribbean_config.json`):

| Signal | SeaLifeBase field | Notes |
|--------|-------------------|-------|
| Depth cap | `DepthRangeDeep <= 130` m | Same recreational cap as fish |
| Pelagic exclusion | `DemersPelag` not in `pelagic-oceanic`, `bathypelagic`, … | Drops open-ocean pelagics |
| Taxonomy | `class_to_taxonomy` + `gastropod_order_to_subcategory` in config | Maps to Field Guide categories (corals, sponges, mollusks, …) |

SeaLifeBase `ecology.CoralReefs` uses **1** (not FishBase’s **-1**). The invert extract leaves the ecology reef filter off by default because many benthic inverts lack ecology rows.

## Cross-reference with REEF.org (optional quality filter)

REEF’s [Species Reference List](https://www.reef.org/db/reports/species?region_code=TWA) is the standard diver survey checklist for Caribbean fish (**Tropical Western Atlantic**). By default the filter applies to **fish only** — invertebrates and other categories are kept.

```bash
# Preview fish-only intersection counts:
python3 GoDiveMVP/Scripts/filter_marine_life_by_reef.py --dry-run

# Drop fish not on REEF TWA; keep all non-fish; sync JSON:
python3 GoDiveMVP/Scripts/filter_marine_life_by_reef.py --apply --sync-json --all

# Filter every category against REEF (not recommended for inverts — TWA is fish-only):
python3 GoDiveMVP/Scripts/filter_marine_life_by_reef.py --apply --all-species --sync-json --all
```

Matching is on normalized **genus + species** for fish rows. REEF exports are cached in **`MockData/reef_species_reference.csv`**; use **`--refresh-reef`** to re-download.

## Cross-reference with Caribbean Reef Life (Mickey Charteris)

The book’s **Scientific Name Index** (pages 450–463 in the 4th edition) is the authoritative glossary. It is **not** published as a downloadable list on [caribbeanreeflife.com](https://www.caribbeanreeflife.com) — only sample pages are online — so extract names from your purchased **interactive PDF** or **ePub export**.

```bash
# 1. Place your ebook PDF at MockData/CaribbeanReefLife.pdf (gitignored) or pass --pdf
python3 GoDiveMVP/Scripts/extract_caribbean_reef_life_reference.py --pdf ~/Downloads/CaribbeanReefLife.pdf

# 2. Validation report (fish-only by default; inverts unchanged)
python3 GoDiveMVP/Scripts/validate_marine_life_by_crl.py

# 3. Optional: drop fish not listed in the book, then sync JSON
python3 GoDiveMVP/Scripts/validate_marine_life_by_crl.py --apply --sync-json --all
```

Outputs **`MockData/caribbean_reef_life_species_reference.csv`** (~1,800 names from a full PDF) and **`MockData/caribbean_reef_life_validation_report.json`** (matched / not-in-book counts plus samples). Use **`--all-species`** to validate invertebrates too once the full index is extracted.

## Cross-reference with snorkelstj.com (fuzzy common names)

[snorkelstj.com](https://www.snorkelstj.com/coral_gallery.html) hosts a Caribbean ID gallery for St. John / USVI, including [corals](https://www.snorkelstj.com/coral_gallery.html), fish, creatures, and an [All Species List](https://www.snorkelstj.com/list-species.html). We crawl species profile pages and fuzzy-match **common names** (scientific names used as an exact tie-breaker when present).

```bash
# Cache ~470 snorkelstj species names (one-time / refresh):
python3 GoDiveMVP/Scripts/fetch_snorkelstj_species_reference.py

# Validation report (default threshold 0.88):
python3 GoDiveMVP/Scripts/validate_marine_life_by_snorkelstj.py

# Optional: keep matched rows only, then sync JSON:
python3 GoDiveMVP/Scripts/validate_marine_life_by_snorkelstj.py --apply --sync-json --all
```

Report: **`MockData/snorkelstj_validation_report.json`**. Tune fuzziness with **`--threshold 0.92`** (stricter) or **`--threshold 0.85`** (looser).

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

- **Tinder-style review** — one species at a time with large 4:3 photo, **Accept** (green check clears `imageNeedsReview`) or **Edit** (paste a new URL → **Save + download bundle**). Swipe right to accept, left to edit. Keyboard: **A** / **→** accept, **E** / **←** edit. Default queue: **Needs review**.
- Filter queue by **needs review**, **no image**, or **missing bundle**.
- Edit sheet → paste a new **CC0 / CC BY** URL, edit license/attribution, then **Save + download bundle** (updates staging CSV and **`Resources/MarineLifePhotos/{uuid}.jpg`**).
- **Mark for removal** → sets **`markForDeletion=yes`** on the staging row (red **Remove** badge). Apply deletions with **`apply_marine_life_staging_deletions.py --sync-json --all`** to remove rows from CSV, bundled photos, manifest, and **`marine_life_sample.json`**.
- After batch edits, run **`sync_marine_life_staging_to_json.py --all`** before rebuilding the app.

## reefguide.org image fetch (optional)

[Florent's Guide to the Tropical Reefs](https://reefguide.org/about.html) has excellent in-situ Caribbean photos, but they are **© Florent Charpin — redistribution requires express written permission** (email **www@reefguide.org**). Use this only when you intend to request permission and manually review every match.

```bash
GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/fetch_marine_life_images_reefguide.py --dry-run --limit 10
GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/fetch_marine_life_images_reefguide.py
GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/fetch_marine_life_images_reefguide.py --bundle
```

- Matches staging **`scientificName`** against reefguide.org **Caribbean** + **Florida Keys** scientific-name indexes (`carib/cat_sci.html`, `keys/cat_sci.html`).
- Picks the best adult gallery photo, resolves the full-size JPEG under **`reefguide.org/pix/`**, writes **`featureImageURL`** + attribution with **`imageSource=reefguide`** and **`imageNeedsReview=yes`**.
- **`--bundle`** runs **`download_marine_life_images.py --overwrite`** after staging (960×720 crop into **`Resources/MarineLifePhotos/`**).
- Prefer **`fetch_marine_life_images.py`** (Wikimedia/Openverse, CC0/CC BY) for images you can ship without a separate license deal.

## WoRMS image fetch (optional)

[WoRMS](https://www.marinespecies.org/) hosts a large [photogallery](https://www.marinespecies.org/photogallery.php) linked to Aphia taxon pages. Useful for species still missing hero images after reefguide / Commons passes.

```bash
GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/fetch_marine_life_images_worms.py --dry-run --limit 20
GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/fetch_marine_life_images_worms.py
GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/fetch_marine_life_images_worms.py --shippable-only
GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/fetch_marine_life_images_worms.py --bundle
```

- Resolves **`scientificName`** → AphiaID via **`/rest/AphiaRecordsByNames`**, parses the taxon **Images** gallery, resolves direct JPEGs on **`images.marinespecies.org`**, writes staging metadata with **`imageSource=worms`**.
- **Default:** stages gallery matches including **CC BY-NC-SA** with **`imageNeedsReview=yes`**. Use **`--shippable-only`** to keep only **CC0 / CC BY** WoRMS photos.
- **`--bundle`** runs **`download_marine_life_images.py`** after staging.

## Caribbean Reef Life EPUB image extraction (optional)

The CRL 4th-edition EPUB (`caribbean_reef_life_config.json` → `default_epub_path`) stores ~2,195 species photos in `OEBPS/image/`, named by species (`Agelas_spectrum_cmyk.jpg`, `African_pompano_cmyk.jpg`). These photos are **© Mickey Charteris — get written permission before shipping**, the same hold-for-review posture as reefguide.

```bash
# Preview coverage (default is a dry run — writes nothing):
GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/extract_marine_life_images_from_crl.py
# Crop + bundle the matched JPEGs and stage metadata:
GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/extract_marine_life_images_from_crl.py --bundle
```

- Indexes EPUB image filenames (works on an unpacked `.epub` directory or a zipped `.epub`), matching staging rows by **`scientificName`** (preferred) then **`commonName`**.
- **`--bundle`** center-crops each match to 960×720 and writes **`Resources/MarineLifePhotos/{uuid}.jpg`**, sets **`featureImageResourceName`**, and tags the row **`imageSource=caribbean-reef-life`**, **`imageLicense="© Mickey Charteris — permission required"`**, **`imageNeedsReview=yes`**. Provenance is recorded in the bundle manifest.
- **Never syncs `marine_life_sample.json`** — review in the HTML UI and run **`sync_marine_life_staging_to_json.py --all`** yourself only once you have permission.
- Filename matching (v1) covers ~452 of the ~803 image-less rows; the rest use descriptive book filenames and can still be filled from Commons / WoRMS.

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

## What FishBase / SeaLifeBase fill (staging)

| Column | Source |
|--------|--------|
| `uuid` | Generated `marine-life-{slug}` (stable; deduped with spec code) |
| `fishbase_spec_code` | FishBase or SeaLifeBase `SpecCode` |
| `commonName` | `FBname` or best English vernacular |
| `scientificName` | Genus + species |
| `category` / `subCategory` | Fish: family map. Inverts: class/order map in `sealifebase_caribbean_config.json` |
| `familyName` | FishBase / SeaLifeBase family |
| `maxSizeMeters` | `Length` (cm → m) |
| `minDepthMeters` / `maxDepthMeters` | `DepthRangeShallow` / `DepthRangeDeep` |
| `aboutText` | `species.Comments` (ecology `AddRems` fallback) when descriptions enabled in config |
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

Ship FishBase and SeaLifeBase attribution in app About before publishing a large import. Config reminders: `Scripts/fishbase_caribbean_config.json`, `Scripts/sealifebase_caribbean_config.json`.
