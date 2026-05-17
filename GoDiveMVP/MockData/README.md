# Mock Data

Place local fixture files in this folder for app testing.

Minimum setup expects:

- `dives_sample.json`

Expected JSON shape:

- Root is an array of activity objects.
- Each activity includes `profilePoints` as an array.
- Dates must use ISO-8601 format.

This file is loaded at app launch by `MockDataSeeder` only when the database has no existing `DiveActivity` records.
