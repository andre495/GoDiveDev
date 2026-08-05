# Catalog authoring

Working files for building bundled catalogs. **Not** shipped in the app bundle (excluded via Xcode membership exceptions).

## Marine life

| File | Role |
|------|------|
| `marine_life_caribbean_staging.csv` | Authoring sheet (facts + prose + image fields) |
| `marine_life_source.csv` | Legacy angelfish scratch pad |
| `marine_life_bundle_photos_manifest.json` | SHA / URL manifest for bundled JPEGs |
| `*_cache.json` / `*_reference.csv` / `*_report.json` | Pipeline caches and validation outputs |
| `MARINE_LIFE_CARIBBEAN_WORKFLOW.md` | Full Caribbean import / image / sync workflow |

**Shipped seed:** sync staging into **`Resources/Catalog/marine_life.json`** with:

```bash
GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/sync_marine_life_staging_to_json.py --all
```

Half-filled rows → original diver-facing copy per **`.cursor/rules/marine-life-catalog-authoring.mdc`**.

## Dive sites (OpenDiveMap)

| File | Role |
|------|------|
| `opendivemap_dive_sites_staging.csv` | Optional staging export (see **`Scripts/opendivemap_config.json`**) |

**Shipped seed:** fetch / refresh **`Resources/Catalog/dive_sites.json`** with:

```bash
python3 GoDiveMVP/Scripts/fetch_opendivemap_sites.py
```

Loaded at runtime by **`DiveSiteReferenceCatalog`** (resource name **`dive_sites`**); CDN publish reads the same file.
