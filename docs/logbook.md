# Logbook

The **Logbook** tab is your master activity list — **dives and snorkel sessions**, sorted **newest first**.

The top bar shows **Activity Log** in large white type centered on the same row as **Trips** and **+**. Directly under the title, a compact glass control switches **My Activities** (your log) and **Buddy Feed** (friends’ shared dives, when they’ve enabled sharing) — the same style as **Explore → My Sites / All Sites**. When **My Activities** is selected, a **filter** button sits beside that control: choose **All activities**, **Dives**, or **Snorkels** to narrow the list (Buddy Feed is unchanged). Scroll down and that control fades away; scroll back to the top (or tap the **Logbook** tab again) and it returns. The **Activity Log** title still compacts when you scroll.

## My Activities vs Buddy Feed

| Segment | What you see |
|--------|----------------|
| **My Activities** | Your dives and snorkel sessions — everything below in this page applies to this view |

Use the **filter** next to the segment control to show **all** activities, **dives only**, or **snorkels only**. The dive count and bottom-time summary under the toggle reflects the same filter (dives and bottom time still count scuba dives only).

Under **My Activities**, a centered line under the scope toggle shows your **numbered** dive count and combined bottom time (for example **12 Dives | 4 hr Bottom Time**). While the list is still loading, a spinner appears there instead of **0 Dives | 0 Bottom Time**. Dives you hid from numbering in the logbook (**-**) still appear in the list but are not counted here. It hides when you scroll down, together with the expanded **Activity Log** title and **My Activities | Buddy Feed** toggle. It sits below an upcoming-trip banner in the list when one is shown.

| **Buddy Feed** | A merged list of dives your friends share with you (newest first) |

Buddy Feed loads when you select it. Each row shows the dive title, your friend’s name, and a short summary (dive number, date, depth, duration). Tap a row for read-only detail. Notes and photos appear only if your friend opted in under Settings.

Pull down on Buddy Feed to refresh. The feed also refreshes when you switch to **Buddy Feed**, open the **Logbook** tab while that segment is selected, return from a shared dive detail, tap the **Logbook** tab again while already on it, or bring the app back to the foreground while you’re on Buddy Feed in Logbook.

If you have no friends yet, Buddy Feed explains that and offers **Add friends** to open the Friends list (invite via QR or link). If friends have not shared dives yet, you’ll see **No buddy activities yet** with **View friends**.

## Activity rows

Each row shows a type chip, site or session title, stats, and an optional thumbnail.

### Scuba dives

- **Dive number** (or **-** if you hid the number for that dive), with a small **downward waves** icon before the number
- **Site name** (or location label)
- **Date, max depth, and duration**
- A **thumbnail** when the dive has media — tap the thumbnail to open the dive directly on the **Media** tab at that photo

### Snorkel sessions

- **Snorkel** sessions show a **swimmer** icon only (no oval chip); scuba dives show the **downward waves** icon beside an oval **#** (symbol not inside the oval).
- **Site name** (or **New Snorkel** when no site is set)
- **Date**, optional **swim distance** (meters or yards per Settings) and shallow **depth**, and **duration**
- Tap the row to open **snorkel detail** — same three-tab overview as a dive (**Map**, **Heart rate**, **Media**). On **Map**, expand the sheet to **large** for a **Weather** section (Apple Weather at entry time) when GPS or a linked site provides coordinates; imported snorkels keep a stored snapshot from import. The **Heart rate** tab shows your GPS swim track on the map and heart-rate stats/chart in the panel (instead of tank and gas). **Media** works like dive photos: add from your library, tag **marine life** and **buddies**, use **Fishial** identify when configured, and pick a **featured** thumbnail for the logbook row. Tap a thumbnail to open **Media** on that photo.

Rows grouped under the same **trip** show a colored trip header with title, dive count, and date range. Tap the trip title to open trip detail.

An **upcoming trip** banner may appear at the top when you have a planned trip whose start date is still in the future.

## Search and filters

Use the **Search** tab to find dives, buddies, sites, tags, and more across the app. Tap **Dives** on the category grid (or type in the search field) to filter your logbook.

From **Logbook**, the list itself is not filtered inline — open **Search** to look up dives by site, trip, buddy, or tag. See [Search](search.md).

## Add a dive

Tap **+** (or the empty-state **Log Your First Dive** button) to open **Add activity** — three full-height choices:

- **New Dive Activity** — import a scuba dive (FIT / UDDF) or add one manually (same flow as before).
- **New Snorkel Activity** — import a snorkel or open-water swim FIT file (Garmin **Snorkeling** or **Open Water** swim). When import finishes, GoDive shows **Import complete** or **Import failed** with how many activities were imported, then opens that activity’s detail (for bulk dive imports, the **newest** dive).
- **Connect Device** — pair a dive computer or wearable (coming soon).

### New dive activity

=== "Import from a file"

    - **Garmin** (`.fit`) — import a single dive from your Garmin Connect App
    - **MacDive / Universal** (`.uddf`) — import one or many dives from MacDive or another compatible source

    See [Import dives](import.md) for step-by-step options.

=== "Add it yourself"

    **Manual entry** — create a dive without a file (blue sheet: date, optional site, **Cancel** / **Done**).

Before import, you can choose whether to **create dive sites** from import data and whether to **attach photos** from your library for that session.

## Delete a dive

Swipe a row left and tap **Delete**. Confirm in the dialog.

- Deletion removes the dive, its profile samples, buddy tags on that dive, media links, and related data.
- If **Automatically renumber dives** is on in Settings, remaining dive numbers update after delete.
- A short progress overlay may appear while cleanup finishes.

## Duplicate dives

If two dives look like the same import (same file ID or very similar time, depth, and duration), Logbook marks them **Possible duplicate**. GoDive blocks re-importing an exact duplicate; there is no merge tool in the MVP yet.

## Dive numbers

- Imported dives usually receive the next number in sequence.
- **Settings → Automatically renumber dives** keeps numbers in chronological order (1, 2, 3…) across the logbook.
- On an individual dive you can hide its number in the logbook (shows **-**); hidden numbers don’t take a slot when auto-renumber runs.

## Trips in Logbook

Dives linked to a trip appear under that trip’s header with a distinct accent color. Linking happens from **Trips** (planned or active) or automatically when a dive’s date falls inside an active trip window.

## Empty logbook

With no dives or snorkel sessions, Logbook prompts you to add your first activity via the same **+** flow.
