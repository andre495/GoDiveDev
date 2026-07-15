# Settings

Open **Profile → Settings** (gear icon).

Settings use compact rows with an **info** (ⓘ) button on some items for longer explanations in a popup.

## Display units

### Imperial units

When **on** (default for new installs):

- Depths in **feet**  
- Temperatures in **Fahrenheit**  
- Other measurements follow imperial conventions in the UI  

When **off**, GoDive shows **metric** (meters, Celsius).

!!! note
    Stored dive data stays in canonical metric units internally. Toggling units only changes **display** — nothing is converted in your saved log.

## Default tank

Choose the cylinder GoDive assumes for **gas calculations** when an import doesn’t specify size:

| Option | Typical use |
|--------|-------------|
| **AL80** | Standard aluminum 80 cu ft |
| **AL63** | Smaller aluminum |
| **ST100** | Steel 100 cu ft |
| **ST120** | Large steel |

Affects **SAC**, **RMV**, and tank summaries on new imports and manual dives without their own volume data.

## Automatically renumber dives

When **on** (default):

- Dive numbers stay **1, 2, 3…** in chronological order by start time.  
- Runs after import, seeding (debug), and delete.  
- Dives you marked **hide number in logbook** show **-** and are skipped in the sequence.

When **off**, existing numbers are kept except new imports still chain from the highest number.

Turning this **on** once renumbers the entire logbook immediately.

## Auto-upload media to activities

When **on** (default):

- After each **import**, GoDive scans your Photos library for items captured **during the dive window** and attaches them.  
- Turning the toggle **on** later can **backfill** existing dives (progress overlay).  

Requires **Photos** permission. GoDive stores **references** to library assets (identifiers), not full copies of your files.

### How matching works

- Uses the photo or video **creation date** from Photos.  
- Applies dive timezone from site, GPS, or import metadata.  
- Includes a few minutes padding before and after the logged dive.  
- Action-camera videos with odd timezone metadata get extra tolerance.

When **off**, imports skip library scan unless you enable attach on the import options screen for that one import.

## Crash reporting

If GoDive crashes or quits unexpectedly, a report is saved in the app's on-device database.

### Share crash reports

When **on**, saved reports upload automatically to the GoDive developer so problems can be diagnosed and fixed. Reports contain **technical diagnostics only** (crash type, call stack, app and iOS version) — never your dive log, photos, or personal data.

- Requires an iCloud account signed in on the device.
- Turning the toggle on also sends any reports saved while it was off.
- When **off** (the default), reports stay on your device.

### Crash Reports page

Open **Settings → Crash Reports** to review what was captured:

- Reports list newest first, each showing whether it was **sent to the developer**.
- Tap a report for full detail, or use **Share** to send it manually (works regardless of the toggle).
- **Clear All** deletes every stored report (asks to confirm).

Reports include technical diagnostics plus a short **breadcrumb trail** of recent UI context (which tab you were on, dive overview tab/detent, media counts and selection, open sheets, and recent actions like starring or uploading) so crashes and unexpected quits are easier to place. Trails use screen names and dive/media IDs only — not your log text or photos.

!!! note
    System crash diagnostics (full call stacks) can take until the **next app launch** to appear. An **Abnormal exit** entry may show first with breadcrumbs; a fuller **Crash** entry can follow later.

## Related settings elsewhere

These aren’t on the Settings page but interact with it:

| Control | Location | Behavior |
|---------|----------|----------|
| **Featured media** | Dive detail → Media → star | Logbook thumbnail |
| **Hide dive number** | Dive detail edit | Shows **-** in Logbook |
| **Auto-add equipment** | Equipment locker item | Links gear on import |
| **Create dive sites** | Import options sheet | Per-import site creation |

## Sign out

**Sign out** lives on **Profile**, not Settings. Tapping it asks **Are you sure?** before clearing the session. Your dives for that Apple ID remain on the device until you delete the app or its data.
