# Logbook

The **Logbook** tab is your master list of dives, sorted **newest first**.

The top bar shows **Activity Log** in large white type centered on the same row as **Trips** and **+**. Scroll down and the title compacts; scroll back up and it expands again. A soft fade extends below the header as rows scroll underneath.

## Dive rows

Each row shows:

- **Dive number** (or **-** if you hid the number for that dive)
- **Site name** (or location label)
- **Date, max depth, and duration**
- A **thumbnail** when the dive has media — tap the thumbnail to open the dive directly on the **Media** tab at that photo

Rows grouped under the same **trip** show a colored trip header with title, dive count, and date range. Tap the trip title to open trip detail.

An **upcoming trip** banner may appear at the top when you have a planned trip whose start date is still in the future.

## Search and filters

Use the **Search** tab to find dives, buddies, sites, tags, and more across the app. Tap **Dives** on the category grid (or type in the search field) to filter your logbook.

From **Logbook**, the list itself is not filtered inline — open **Search** to look up dives by site, trip, buddy, or tag. See [Search](search.md).

## Add a dive

Tap **+** (or the empty-state **Log Your First Dive** button) to open **Add activity**:

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

With no dives, Logbook prompts you to add your first activity via the same **+** flow.
