# Mock Data

Place local fixture files in this folder for app testing.

Minimum setup expects:

- `dives_sample.json`
- `marine_life_sample.json` (field-guide catalog; seeded on launch when missing)
- `marine_life_source.csv` (legacy angelfish authoring scratch pad)
- `marine_life_caribbean_staging.csv` (FishBase + SeaLifeBase Caribbean facts — see workflow below)

**Marine life content:** Half-filled CSV/JSON → agent completes original diver-facing copy per **`.cursor/rules/marine-life-catalog-authoring.mdc`** (stable `marine-life-*` UUIDs, taxonomy slugs, meters).

**Caribbean marine life import:** See **`MARINE_LIFE_CARIBBEAN_WORKFLOW.md`** — extract fish with **`Scripts/extract_fishbase_caribbean.py`**, append invertebrates with **`Scripts/extract_sealifebase_caribbean.py`**, write descriptions in **`marine_life_caribbean_staging.csv`**, sync with **`Scripts/sync_marine_life_staging_to_json.py`**.

Expected JSON shape:

- Root is an array of activity objects.
- Each activity includes `profilePoints` as an array.
- Dates must use ISO-8601 format.

Launch seeding is **off** by default (`MockDataSeeding.isLaunchSeedingEnabled` in `Data/Seed/MockDataSeeding.swift`). Set it to `true` in Debug to load fixtures when the store is empty. Use **Logbook → Add activity** for real `.fit` / `.uddf` imports.
