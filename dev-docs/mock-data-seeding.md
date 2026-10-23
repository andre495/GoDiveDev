# Mock Data Seeding

Debug-only launch flag for loading sample dive fixtures into a fresh SwiftData store.

## Usage

### Xcode Scheme Arguments

1. Edit your scheme (**Product → Scheme → Edit Scheme** or **⌘<**)
2. Select **Run** → **Arguments**
3. Add `-GoDiveMockSeed` to **Arguments Passed On Launch**

### Simulator via CLI

```bash
xcrun simctl launch booted PrimoSoftware.GoDiveMVP -GoDiveMockSeed
```

## Behavior

When the flag is present in a **Debug** build:

- `MockDataSeeder` loads `dives_sample.json` and `divesites_sample.json` into SwiftData.
- Seeding runs once per app install (idempotency marker stored in UserDefaults).
- After seeding, ownership is claimed for the signed-in profile.

Without the flag (or in **Release**):

- `MockDataSeeding.isLaunchSeedingEnabled` returns `false`.
- No seeding code path runs.

## Release Configuration

In Release builds:

- `isLaunchSeedingEnabled` is a compile-time constant `false` (no runtime check).
- The sample JSON files (`*_sample.json`) are excluded from the bundle via `EXCLUDED_SOURCE_FILE_NAMES` in the Release build settings.
- The seeder code is wrapped in `#if DEBUG` and does not exist in the Release binary.

## Verifying Release Excludes Sample Files

Build for Release and inspect the app bundle:

```bash
# Build Release for simulator
xcodebuild -project GoDiveMVP.xcodeproj -scheme GoDiveMVP \
  -configuration Release -sdk iphonesimulator \
  -derivedDataPath /tmp/GoDiveReleaseBuild \
  build

# Find the app bundle
APP_PATH=$(find /tmp/GoDiveReleaseBuild -name "GoDiveMVP.app" -type d | head -1)

# Verify no sample JSON files exist
find "$APP_PATH" -name "*_sample.json"
# Should return nothing
```

Expected result: no output (the sample files are excluded).

## Files

| File | Purpose |
|------|---------|
| `GoDiveMVP/MockData/dives_sample.json` | Sample dive activities |
| `GoDiveMVP/MockData/divesites_sample.json` | Sample dive sites |
| `GoDiveMVP/Data/Seed/MockDataSeeding.swift` | Flag definition |
| `GoDiveMVP/Data/Seed/MockDataSeeder.swift` | Seeding logic (Debug-only) |

## Notes

- The catalog files (`marine_life.json`, `dive_sites.json` in `Resources/Catalog/`) are **not** affected by this exclusion and ship in all builds.
- Use the real **Logbook → Add activity** flow for `.fit` / `.uddf` imports in production testing.
