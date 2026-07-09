# Dive detail

Open any dive from Logbook, Home, Explore, a buddy page, or a trip to see **dive detail**. The screen is built around three tabs and a draggable bottom sheet.

## Three tabs

| Tab | Icon | Purpose |
|-----|------|---------|
| **Map** | Map pin | Location, stats, conditions, buddies, notes, tags |
| **Tank** | Cylinder | Gas mix, cylinder, consumption, equipment, depth profile |
| **Media** | Camera | Photos and videos from your library |

Use the **back chevron** (top leading) or swipe from the left screen edge to return to the previous screen.

## Bottom sheet detents

The overview panel slides up from the bottom in three sizes:

1. **Minimized** (~20% of screen) — compact summary; map still visible behind  
2. **Medium** (~50%) — headers, key stats, and primary sections  
3. **Large** (~85%) — full scrollable detail including notes, tags, and edit affordances  

Drag the grabber or sheet edge to change size. Switching tabs resets the sheet to **medium**.

## Map tab

- Shows a map pin at the dive location when coordinates exist.
- If the dive is linked to a catalog **dive site**, the site name appears under the dive number; tap it to open that site in Explore.
- **Medium** and **large** detents show the stats box (max depth, average depth, surface interval, dive time), **Dive Conditions**, buddies, notes, and **Tags**. Tap **⋯** (top trailing on the stats box) to change dive metrics when editable.
- If the dive has a location hint but no linked site, GoDive may prompt you to add or match a dive site.

## Tank tab

- **Gas**, **cylinder**, and **consumption** fields when import or manual entry provided them.
- **Equipment** row opens a sheet to link gear from your **Equipment locker**.
- A **depth profile chart** appears in the hero area (portrait) or full width (landscape).
- **SAC** and **RMV** are calculated from tank pressure and depth when data allows — read-only.
- Some fields from file import (duration, max depth, bottom time, surface interval, average ascent rate) are **read-only** on imported dives; manual dives can edit more fields.

Tap a section **⋯** menu to edit all fields in that section in one sheet.

## Media tab

- Full-bleed **hero pager** swipes between photos and videos.
- When a dive has **no media yet**, the hero shows bouncing photo/video frames at **minimized** and **medium** (hidden at **large**). The **Your highlight reel lives here** copy sits in the overview sheet at **medium** and **large**; **+** adds library items.
- **Carousel** at minimized and medium detents jumps between items; oldest capture time on the left.
- **+** opens the photo picker to attach library items (up to 20 per add).
- **Star** marks the featured item used as the Logbook row thumbnail.
- **Fish** opens marine life tagging for the current item.
- Videos play **muted** and **loop** on the visible page; hold briefly to pause.

### Marine life on media

Tag catalog species on a photo or video frame. At **large** detent, tagged species appear as chips with Field Guide links and natural-history copy.

If **Fishial** is configured in the app build, a **sparkles** control can suggest species from a cropped still (network required).

## Tags (map tab)

**Tags** are free-form labels on a dive (separate from marine life species tags). Tap a tag chip to open its detail page — a blue sheet with the same five pages as an active trip (**Overall stats**, **Dive activities**, **Marine life**, **Buddies**, **Media**) and a media/map toggle in the hero when tagged dives have site coordinates. Use **+** on the Tags section or the overview sheet to add, pick, or remove tags.

## Buddies

On the map overview, **Buddies** lists people tagged on this dive. Tap an avatar to open that buddy’s detail page. **+** opens the buddy picker from your roster or lets you create a new buddy.

## Landscape

Rotate your phone sideways on dive detail:

- **Map** fills the screen interactively; the sheet hides.
- **Tank** shows a wide depth chart with media markers on the profile.
- **Media** uses a full-bleed pager.

Portrait returns the sheet layout.

## Deep links

- From Logbook, tapping the **row thumbnail** opens this dive on **Media** at that item.
- From Home carousel, tapping the hero opens the same focused media view.

## Editing and source info

- **Manual dives** — most summary fields editable via section edit sheets.
- **Imported dives** — source, import format, and source dive ID are read-only; many metrics from the file stay read-only.
- **Operator** and **source & import** details appear at **large** detent on the tank tab.
