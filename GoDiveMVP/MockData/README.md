# Mock Data

Opt-in Debug fixtures for empty-store testing (not production catalog assets).

Expected fixtures:

- `dives_sample.json`
- `divesites_sample.json`

Expected JSON shape for dive fixtures:

- Root is an array of activity objects.
- Each activity includes `profilePoints` as an array.
- Dates must use ISO-8601 format.

## Enabling Mock Seeding

Launch seeding is **off** by default. To enable in **Debug**:

1. Add **`-GoDiveMockSeed`** to scheme arguments (**Product → Scheme → Edit Scheme → Run → Arguments**)
2. Or via CLI: `xcrun simctl launch booted PrimoSoftware.GoDiveMVP -GoDiveMockSeed`

Seeding runs once per app install (idempotency marker in UserDefaults). Use **Logbook → Add activity** for real `.fit` / `.uddf` imports.

## Release Builds

In Release, these sample files are **excluded** from the bundle via `EXCLUDED_SOURCE_FILE_NAMES`. The seeder code is wrapped in `#if DEBUG` and does not compile into Release.

See **`dev-docs/mock-data-seeding.md`** for verification steps.

## Production catalog assets (not mock data)

| Asset | Location |
|-------|----------|
| Field Guide seed | **`Resources/Catalog/marine_life.json`** (`MarineLifeCatalogSeeder`) |
| OpenDiveMap dive-site reference | **`Resources/Catalog/dive_sites.json`** (`DiveSiteReferenceCatalog`) |
| Authoring CSV / caches / workflow | **`CatalogAuthoring/`** |
| Marine life photos / USDZ | **`Resources/MarineLifePhotos/`**, **`Resources/MarineLife3D/`** |
