# Import dives

GoDive imports dive logs from industry-standard files. Original files are **not** stored after import — only the parsed dive data lands in your logbook.

## Supported formats

| Format | Extension | Typical source | Dives per file |
|--------|-----------|----------------|----------------|
| **Garmin** | `.fit` | Garmin Connect App / dive computers (e.g. MK series) | One |
| **MacDive / Universal** | `.uddf` | MacDive, Subsurface, other UDDF 3.2 exporters | One or many |

## How to import

1. Open **Logbook**.  
2. Tap **+** → **Add activity**.  
3. Choose **Garmin** or **MacDive / Universal**.  
4. Review **import options** (see below).  
5. Pick the file in the system file picker.  
6. Wait for the progress overlay to finish.

After a **single-dive** import, GoDive usually navigates to the new dive. **Multi-dive UDDF** files show a summary alert (dives imported, duplicates skipped, sites created) — open individual dives from Logbook.

## Import options

Before the file picker, you can set:

### Create dive sites from import

When **on** (default for bulk UDDF):

- New site names from the file become **Explore** catalog entries if no match exists.  
- GPS may link to an existing nearby site when names align.

When **off**, dives still import but unmatched sites may stay as text on the dive only.

### Attach photos from library

When **on**, GoDive scans your Photos library for images and videos whose **capture time** falls within each dive window (with a small padding) and attaches them as references — no duplicate copy of the file inside GoDive.

This respects **Settings → Auto-upload media to activities** as the default; you can override per import.

Turn **off** for a fast import without PhotoKit access.

## Garmin FIT

- One diving session per file.  
- Imports depth profile, temperatures, tank pressure when present, gas mix, GPS entry point, and summary stats.  
- Buddy names from the file join your buddy roster when possible.

## UDDF (including MacDive)

- MacDive exports often contain many dives in one `.uddf` file.  
- Tap **MacDive Import** on the options screen for a **step-by-step guide** inside the app, then **Import MacDive Data** on the last step.  
- Imports profile samples, tank data, buddies, and site names per UDDF mapping.

!!! note "MacDive scope"
    Bulk UDDF import brings in **dives and related dive fields** only. MacDive photos, equipment locker, and certifications in the export file are **not** imported in the current MVP.

## Duplicate detection

GoDive blocks importing the same dive twice when:

- The same **source dive ID** appears again, or  
- Time, depth, and duration closely match an existing dive (including across FIT vs UDDF).

Skipped duplicates appear in the bulk import summary. Logbook may label suspicious pairs **Possible duplicate** — there is no merge tool yet.

## Dive numbers after import

New dives receive the next dive number in sequence. If **Automatically renumber dives** is on, the full logbook renumbers chronologically after import.

## What gets imported

Typical fields include:

- Start time and timezone hints  
- Max / average depth, duration, bottom time  
- Water temperature  
- Ascent rate and NDL samples on the profile chart  
- Tank pressure series and gas mix  
- SAC / RMV when calculable  
- Site name, GPS, buddies  

Fields missing from your file simply stay empty in GoDive.

## Troubleshooting

| Issue | Things to try |
|-------|----------------|
| File grayed out in picker | Ensure extension is `.fit` or `.uddf` |
| Import fails immediately | File may be corrupt or not a dive FIT session |
| No photos attached | Enable attach option; grant Photos access; check capture times overlap the dive window |
| Wrong local time on UDDF | GoDive applies watch-specific rules for Garmin vs Suunto-style timestamps |
| Site not on map | Link or add a site from dive detail; confirm import included coordinates |

## Manual entry

Choose **Manual entry** on Add activity to create a dive without a file. You can fill location, conditions, tank info, and buddies yourself; profile chart appears when you add samples or dive without import constraints.
