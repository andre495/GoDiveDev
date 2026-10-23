# Mock Data

Opt-in Debug fixtures for empty-store testing (not production catalog assets).

Expected fixtures:

- `dives_sample.json`
- `divesites_sample.json` (tiny catalog sample loaded only when **`MockDataSeeding.isLaunchSeedingEnabled`**)

Expected JSON shape for dive fixtures:

- Root is an array of activity objects.
- Each activity includes `profilePoints` as an array.
- Dates must use ISO-8601 format.

Launch seeding is **off** by default (`MockDataSeeding.isLaunchSeedingEnabled` in `Data/Seed/MockDataSeeding.swift`). Set it to `true` in Debug to load dive/site fixtures when the store is empty. Use **Logbook → Add activity** for real `.fit` / `.uddf` imports.

## Production catalog assets (not mock data)

| Asset | Location |
|-------|----------|
| Field Guide seed | **`Resources/Catalog/marine_life.json`** (`MarineLifeCatalogSeeder`) |
| OpenDiveMap dive-site reference | **`Resources/Catalog/dive_sites.json`** (`DiveSiteReferenceCatalog`) |
| Authoring CSV / caches / workflow | **`CatalogAuthoring/`** |
| Marine life photos / USDZ | **`Resources/MarineLifePhotos/`**, **`Resources/MarineLife3D/`** |
