# Settings

Open **Profile → menu (☰) → Settings**.

The **Settings** title uses the same collapsible large-title header as Certifications and Friends — it compacts when you scroll and expands when you return to the top.

Settings are grouped into **Preferences**, **Activity Sharing**, **Notifications**, and **Advanced**, with compact rows and an **info** (ⓘ) button on some items for longer explanations. The bottom of the screen shows **GoDive v0.MVP** and **Primo Software LLC**.

When you’re signed into **iCloud**, most Preferences and notification choices (units, default tank, renumber, auto-upload media, default weights, bulk UDDF “create dive sites”, and the all-notifications / gear / trip toggles) sync across **your** Apple devices with your dive log. **Share crash reports**, **Share diagnostic events**, and friend-share toggles stay on this device only.

## Preferences

### Units

When **on** (default for new installs):

- Depths in **feet**  
- Temperatures in **Fahrenheit**  
- Other measurements follow imperial conventions in the UI  

When **off**, GoDive shows **metric** (meters, Celsius).

!!! note
    Stored dive data stays in canonical metric units internally. Toggling units only changes **display** — nothing is converted in your saved log.

### Default Tank Type

Choose the cylinder GoDive assumes for **gas calculations** when an import doesn’t specify size:

| Option | Typical use |
|--------|-------------|
| **AL80** | Standard aluminum 80 cu ft |
| **AL63** | Smaller aluminum |
| **ST100** | Steel 100 cu ft |
| **ST120** | Large steel |

Affects **SAC**, **RMV**, and tank summaries on new imports and manual dives without their own volume data.

### Default Weights

Optional defaults for **fresh water** and **salt water** that pre-fill the Weights section on newly imported dives. Clear a field to stop auto-filling that water type. You can still change weight on each dive.

### Automatically Renumber Dives

When **on** (default):

- Dive numbers stay **1, 2, 3…** in chronological order by start time.  
- Runs after import, seeding (debug), and delete.  
- Dives you marked **hide number in logbook** show **-** and are skipped in the sequence.

When **off**, existing numbers are kept except new imports still chain from the highest number.

Turning this **on** once renumbers the entire logbook immediately.

### Auto-upload media to activities

When **on** (default):

- After each **import**, GoDive scans your Photos library for items captured **during the dive window** and attaches them.  
- Turning the toggle **on** later can **backfill** existing dives (progress overlay).  

Requires **Photos** permission. GoDive stores **references** to library assets (identifiers), not full copies of your files.

When **off**, imports skip library scan unless you enable attach on the import options screen for that one import.

## Activity Sharing

Buddy options apply when you use **Profile → Buddies** (QR / invite link). Community contribution is separate and optional.

### Share activities with buddies

When **on** (default): buddies can see your dive and snorkel details (site, depth or distance, duration, conditions, and more). GoDive keeps a buddy-visible copy in Firebase for them to read. Your private log on device / iCloud stays the source of truth.

New activities always start **local only** — when you have buddies, a **Share with Buddies?** banner on the activity map prompts you to publish (or open ⋯ → **Activity Settings**). See [Friends](friends.md#publishing-a-new-activity).

### Share Private notes with buddies

When **on**, activity notes are included for buddies. **Off** by default.

### Share Media with buddies

When **on**, buddies see thumbnails right away and full-quality photos (up to 20 per activity) and 1080p video clips (up to 10, 30 seconds each) when they open an activity. Full originals stay in your Photos library. **Off** by default.

Buddy media **downloads** always use Wi‑Fi or cellular (there is no download Wi‑Fi-only setting).

### Upload media on wifi only

When **on**, full-quality shared photos and videos **upload** only on Wi‑Fi. Thumbnails may still upload on cellular so buddies see activity media quickly.

### Contribute sightings to community

When **on**, GoDive may share **anonymized** marine-life sightings and per-activity site reports (species, dive-site id, depth, time of day, date, and conditions — **not** your name, photos, notes, or exact GPS) so the community similarity graph can improve Field Guide **Similar species**. **Off** by default. Requires a GoDive social sign-in. Turning it **on** can backfill your existing activities; turning it **off** removes your contributions from the community mirror.

## Notifications

### All notifications

Master switch for buddy activity pushes, gear servicing defaults, and trip reminders. When **off**, those alerts stop; individual toggles keep their settings and apply again when this is turned back on.

### Buddy activity

When **on** (default), you get a push notification when someone in your friend network shares new activities — one notification per batch when several are shared together. Tap it to open the activity in **Buddy Feed**. Requires iOS notification permission; see [Friends](friends.md#when-a-buddy-shares-new-activities) for details. This choice follows your account, so it applies on all your devices.

### Gear Servicing

When **on** (default), new gear with recurring service starts with a **1 week prior** reminder. When **off**, new gear defaults to **no reminders**. You can still change reminders on each gear item in the add/edit sheet — those per-item choices override this default.

### Trip Reminders

When **on** (default), GoDive reminds you about upcoming trips **1 month** before, **1 week** before, and the **day before**. Turn **off** to stop all trip reminders. This is the only trip notification control (there are no per-trip settings).

## Advanced

### Share crash reports

When **on**, saved reports upload automatically to the GoDive developer so problems can be diagnosed and fixed. Reports contain **technical diagnostics only** (crash type, call stack, app and iOS version) — never your dive log, photos, or personal data.

- Requires an iCloud account signed in on the device.
- Turning the toggle on also sends any reports saved while it was off.
- When **off** (the default), reports stay on your device.

### View crash reports

Open **Settings → Advanced → View crash reports** to review what was captured:

- Reports list newest first, each showing whether it was **sent to the developer**.
- Tap a report for full detail, or use **Share** to send it manually (works regardless of the toggle).
- **Clear All** deletes every stored report (asks to confirm).

Reports include technical diagnostics plus a short **breadcrumb trail** of recent UI context (which tab you were on, dive overview tab/detent, media counts and selection, open sheets, and recent actions like starring or uploading) so crashes and unexpected quits are easier to place. Trails use screen names and dive/media IDs only — not your log text or photos.

!!! note
    System crash diagnostics (full call stacks) can take until the **next app launch** to appear. An **Abnormal exit** entry may show first with breadcrumbs; a fuller **Crash** entry can follow later.

### Share diagnostic events

When **on**, scrubbed events upload automatically to the GoDive developer. Events contain **short technical tokens only** — never your dive log, photos, or personal data.

- Requires an iCloud account signed in on the device.
- Turning the toggle on also sends any events saved while it was off.
- When **off** (the default), the journal stays on your devices.

### View diagnostic events

Open **Settings → Advanced → View diagnostic events** to review what was recorded:

- Events list newest first, each showing whether it was **sent to the developer**.
- Tap an event for full detail, or use **Share** to send it manually (works regardless of the toggle).
- **Clear All** deletes every stored event for your account on this device (asks to confirm).

### Sign Out

**Sign Out** is under **Settings → Advanced** (red). Tapping it asks **Are you sure?** before clearing the session. Your dives for that Apple ID remain on the device until you delete the app or its data.

### Delete Account

**Delete Account** is under **Settings → Advanced** (red). It stays grayed out when the device is offline — deletion needs a network connection for Apple and account cleanup.

Flow when online:

1. **Are you sure?** confirmation.  
2. **Sign in with Apple** once more to authorize permanent deletion.  
3. GoDive removes your **social profile** (Firebase), **revokes** Sign in with Apple for this app, **deletes** your on-device dive log and related data (and syncs those deletes to your private iCloud dive store when CloudKit is enabled), then **signs you out**.

This cannot be undone. Catalog species/sites that come with the app are not removed.

## Related settings elsewhere

These aren’t on the Settings page but interact with it:

| Control | Location | Behavior |
|---------|----------|----------|
| **Featured media** | Dive detail → Media → star | Logbook thumbnail |
| **Hide dive number** | Dive detail edit | Shows **-** in Logbook |
| **Auto-add equipment** | Equipment locker item | Links gear on import |
| **Create dive sites** | Import options sheet | Per-import site creation |
