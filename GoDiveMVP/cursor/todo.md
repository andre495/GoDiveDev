# GoDive MVP — Development TODO

This file tracks outstanding work, known gaps, and planned follow-ups across the project.
Update this file whenever a model, view, or feature is added or changed.

---

## Models

### DiveActivity (`Models/DiveActivity.swift`)

**Status:** Initial model created. Not yet connected to UI or persistence layer.

**What was built:**
- `DiveSource` enum (`garminMK3`, **`macDive`**, `manual`) — `String`, `Codable`, `CaseIterable`
- `DiveCoordinate` struct — `Codable`, stores `latitude` / `longitude`
- `DiveActivity` SwiftData `@Model` with all canonical fields defined in rules.md

**Pending:**
- [ ] Wire `DiveActivity` into SwiftData `ModelContainer` in `GoDiveMVPApp.swift`
- [ ] Connect to a list view so stored dives are displayed (see Views section below)
- [x] Add a `@Relationship` to `DiveProfilePoint` (`profilePoints` on `DiveActivity`, inverse on `DiveProfilePoint.dive`)
- [ ] Confirm SwiftData correctly encodes/decodes `DiveCoordinate` (test with mock data)
- [x] Add `DiveSource.macDive` for **UDDF** / **MacDive** logbook import
- [ ] Add further `DiveSource` cases as additional import origins become supported

---

## UDDF (MacDive export) — present in XML, **not** mapped to `DiveActivity` / `DiveProfilePoint` yet

These paths (or concepts) appear in **UDDF 3.2** exports such as **`MacDiveExport.uddf`** but are **intentionally ignored** for now. When extending the model, start here.

| UDDF area | Examples / notes |
|-----------|------------------|
| **`generator`** | Exporter name/version (only folded into **`rawImportVersion`** string). |
| **`diver/owner`** | Owner identity — not linked as a **`DiveBuddyTag`**. |
| **`diver/…/equipment/**`** | Full equipment catalog: **`tank`**, **`regulator`**, **`fins`**, **`mask`**, **`camera`**, **`variouspieces`**, **`purchase`**, **`shop`**, **`price`**, **`serialnumber`**, equipment **`notes`**. |
| **`informationbeforedive/divenumber`**, **`divenumberofday`** | Exporter’s log **#** — **GoDive** uses chained **`diveNumber`** from **`DiveActivityDiveNumbering`**, not UDDF’s number. |
| **`surfaceintervalbeforedive`** beyond **`passedtime`** | Other SI sub-elements if present. |
| **`gasdefinitions/mix`** | **`o2`**, **`n2`**, **`he`**, mix **`name`** — no **`DiveActivity`** gas / mix field. |
| **`tankdata`** | **`tankvolume`**, **`tankpressurebegin`**, **`tankpressureend`**, **`link`** to mix — no tank model. |
| **`samples/waypoint/tankpressure`**, **`switchmix`** | Per-sample tank / gas switch — not on **`DiveProfilePoint`**. |
| **`informationafterdive/equipmentused`** | **`link`** refs into equipment catalog — not stored. |
| **`divesite/site/geography/address`** | Beyond **`country`** + **`location`** (e.g. street) — not mapped. |
| **`profiledata/repetitiongroup`** | Group **`id`** / repetition semantics — dives flattened. |
| **NDL, deco, ceiling, alarm, heartbeat, samples other than `waypoint`** | Not in the sample; add rows here when seen in the wild. |
| **Timezone on `datetime`** | **Partial:** naive **`datetime`** + site **`geography/timezone`** → dive-local wall → UTC instant; naive without site → UTC wall fallback; **`Z`/`±HH:MM`** on **`datetime`** when present; else **`DiveGeographicTimeZoneLookup`** (coords + **`startTime`**, DST). Requires network for **`MKReverseGeocodingRequest`**; no offline tz DB yet. |

**Implemented mapping (high level):** **`informationbeforedive/datetime`** → **`startTime`**; **`informationafterdive/greatestdepth`** + profile max → **`maxDepthMeters`**; **`diveduration`** → **`durationMinutes`** and **`bottomTimeSeconds`**; **`surfaceintervalbeforedive/passedtime`** → **`surfaceIntervalSeconds`**; **`informationafterdive/lowesttemperature`** (K→°C) with waypoint min → **`waterTempMinCelsius`**; site **`link`** → **`siteName`**, **`locationName`**, **`coordinate`**; buddy **`link`**s → **`DiveBuddyTag`**; **`notes/para`** (CDATA) → **`notes`**; **`samples/waypoint`** → **`DiveProfilePoint`** (depth, time, K→°C temp, segment **`ascentRateMetersPerSecond`**); mean depth / mean ascent from samples; **`dive/@id`** → **`sourceDiveId`**.

**UDDF — parsed XML today but not represented as distinct `DiveActivity` / `DiveProfilePoint` fields (beyond the table above):** structured **`generator`** name/version (only folded into **`rawImportVersion`**); separate **`site`** **`country`** vs **`location`** lines (only a combined **`locationName`**); per-**`waypoint`** children other than **`depth`**, **`divetime`**, **`temperature`** (e.g. **`tankpressure`**, **`switchmix`**) — not read by the parser yet, hence no model slot.

---

## FIT (Garmin `.fit`, **FITSwiftSDK** profile **21.202.0**) — present in SDK / typical dive files, **not** read by `FitDiveFileDecoder` and/or **not** mapped to `DiveActivity` / `DiveProfilePoint`

**Decoder today:** first **`SessionMesg`** with **`sport == .diving`** → **`startTime`**, **`totalElapsedTime`** / **`totalTimerTime`** → **`durationMinutes`**, **`maxDepth`**, **`avgDepth`** (or mean of record depths); **`DiveSummaryMesg`** (session-linked when present) → **`bottomTimeSeconds`**, **`surfaceIntervalSeconds`**; **`FileIdMesg`** → **`sourceDiveId`**; session + record temps via **`DiveImportWaterTemperatureSummary`** → **`waterTempAvgCelsius`** / **`waterTempMaxCelsius`** / **`waterTempMinCelsius`**; **`RecordMesg`** → **`DiveProfilePoint`** (**`timestamp`**, **`depth`**, **`temperature`**, **`ascentRate`**, **`ndl_time`**, **`time_to_surface`**, **`heartRate`**, **`po2`**, **`n2Load`**, **`cnsLoad`**, **`tankPressurePSI`** when **`TankUpdate`** stream exists); first record **position** → **`coordinate`**. Still not from FIT: **`siteName`**, **`locationName`**, **`notes`**, **`buddies`**, **`avgAscentRateMetersPerSecond`** (watch vs waypoint-derived conflict — UDDF only for now).

| FIT area | Examples / notes (no matching persisted field, or not read) |
|----------|----------------------------------------------------------------|
| **`SessionMesg`** (beyond fields used for **`DiveActivity`** today) | **`subSport`**, session **`timestamp`**, **`startPositionLat`/`Long`**, **`endPositionLat`/`Long`**, **`necLat`/`Long`**, **`swcLat`/`Long`**; Garmin **`diveNumber`**; **`startCns`/`endCns`**, **`startN2`/`endN2`**, **`o2Toxicity`**; **`avg`/`max`/`min` `RespirationRate`** (and enhanced variants); **`avgSpo2`**, **`avgStress`**, HR **`avg`/`max`/`min`**, calories / training effect / TSS / zones / sport profile metadata; dozens of non-diving-specific session aggregates. **`surfaceInterval`** on session is only a fallback if **`DiveSummaryMesg`** has none. |
| **`DiveSummaryMesg`** (remaining fields) | SAC/RMV, descent/ascent times, avg/max ascent & descent rates, **`hangTime`**, **`o2Toxicity`**, CNS/N₂ bookends, **`diveNumber`**, etc. — **`bottom_time`** + **`surface_interval`** consumed when linked to session. |
| **`DiveGasMesg`** (whole message) | **`heliumContent`**, **`oxygenContent`**, **`status`**, **`mode`** — no gas / mix model on **`DiveActivity`**. |
| **`RecordMesg`** (per-sample, SDK exposes but import still ignores) | **`absolutePressure`**; RMV / SAC **`rmv`**, **`pressureSac`**, **`volumeSac`**; **`respirationRate`** / **`enhancedRespirationRate`**; **`coreTemperature`**; **`airTimeRemaining`**; **`nextStopDepth`**, **`nextStopTime`**; other record channels (speed, distance, altitude, power, etc.). **Also on `DiveProfilePoint` (FIT):** **`heartRate`**, **`po2`**, **`n2Load`**, **`cnsLoad`**. |
| **`FileIdMesg`** | **`type`**, **`manufacturer`**, **`product`** / **`garminProduct`**, **`productName`** — not stored (only folded into synthetic **`sourceDiveId`** with serial/number/time). |
| **Other mesg types** | **`LapMesg`**, **`EventMesg`**, **`DeviceInfoMesg`**, **`DeveloperData`** fields, etc. — not read; add rows when a fixture needs them. |

**Note:** Logbook **`diveNumber`** for Garmin imports is assigned by app logic (**`DiveActivityDiveNumbering`**), not from **`SessionMesg.getDiveNumber()`** / **`DiveSummaryMesg`**.

### UDDF ↔ FIT — same-dive parity (MacDive export vs Garmin **`.fit`**)

Cross-checked on a **single-gas** dive pair (**`MacDiveExport.uddf`** vs **`176 Single-Gas Dive.fit`**): **start time**, **max depth**, **bottom / in-water duration** (**`diveduration`** vs **`DiveSummaryMesg.bottom_time`**), **surface interval** (±1 s), **water temperature** after **K→°C** vs **°C** records, **EAN33 / 33% O₂**, **device serial**, and **FIT session start GPS** vs coordinates in UDDF **notes** all align. **Deferred (conflicting or divergent semantics):** Mac vs Garmin **dive #**; **average depth** (different definitions); **session total elapsed** vs **bottom time** for **`durationMinutes`** (FIT keeps **`durationMinutes`** from session clock; **bottom** lives on **`bottomTimeSeconds`**); **catalog site GPS** vs **water-entry** coordinate; **UDDF tank pressure** vs **FIT ambient pressure** — see backlog tables below.

### Import gap backlog — **dive** vs **profile point** (time series)

Use this when extending **`DiveActivity`** vs **`DiveProfilePoint`**. **Dive** = one value (or small fixed set like gas rows) for the whole dive. **Profile** = varies with each sample timestamp along the profile.

#### Dive-level data to add (`DiveActivity`, dive-owned child rows, or import metadata — not per-sample)

| Concept | Suggested type | Source |
|---------|----------------|--------|
| Exporter **`generator`** name / version (structured, not only in **`rawImportVersion`**) | `String` | UDDF |
| **`diver` / `owner`** identity | `String` (or future `Person` ref) | UDDF |
| **`equipment`** catalog (tank, regulator, fins, mask, camera, pieces, purchase, shop, price, serial, notes) | `struct` / future **`Equipment`** rows | UDDF |
| **`informationbeforedive`** exporter **`divenumber`**, **`divenumberofday`** | `Int?` | UDDF |
| **`surfaceintervalbeforedive`** beyond **`passedtime`** | `String` / `Duration` / structured | UDDF |
| **`gasdefinitions` / `mix`** (**`o2`**, **`n2`**, **`he`**, **`name`**) | `[DiveGasMix]` or similar | UDDF |
| **`tankdata`** (**`tankvolume`**, **`tankpressurebegin`**, **`tankpressureend`**, mix **`link`**) | `struct` / tank row | UDDF |
| **`informationafterdive` / `lowesttemperature`** (summary min water temp) | `Double?` | UDDF — **`waterTempMinCelsius`** (with waypoint min). |
| **`informationafterdive` / `equipmentused`** **`link`** refs | `[String]` | UDDF |
| **`divesite` / `site` / `geography` / `address`** beyond country+location line | `String` / structured address | UDDF |
| **`profiledata` / `repetitiongroup`** semantics | `String?` / `UUID?` | UDDF |
| **`bottomTimeSeconds`** (reliable **`diveduration`** / FIT **`bottom_time`**) | `Int?` | UDDF / FIT — **implemented** |
| Dive **`datetime`** timezone / offset (vs **`TimeZone.current`** assumption) | `TimeZone` / `String` | UDDF |
| **`FileIdMesg`**: **`type`**, **`manufacturer`**, **`product`**, **`productName`** | `enum` + `String` | FIT |
| **`SessionMesg`**: **`subSport`**, session **`timestamp`**, **`sportProfileName`**, **`sportIndex`** | `enum` / `Date?` / `String?` | FIT |
| **`SessionMesg`**: **`surfaceInterval`**, Garmin **`diveNumber`** | `UInt32?` / `UInt32?` | FIT |
| **`SessionMesg`**: **`startCns`**, **`endCns`**, **`startN2`**, **`endN2`**, **`o2Toxicity`** | `UInt8?` / `UInt16?` | FIT |
| **`SessionMesg`**: session water **`avg`/`max`/`min` `Temperature`** | `Int8?` each | FIT — **implemented** via **`DiveImportWaterTemperatureSummary`** onto **`waterTemp*Celsius`**. |
| **`SessionMesg`**: respiration **`avg`/`max`/`min`** (and enhanced variants), **`avgSpo2`**, **`avgStress`**, HR **`avg`/`max`/`min`**, calories / training effect / TSS / zones | `UInt8`/`Float64` / `UInt16` as appropriate | FIT |
| **`SessionMesg`**: **`startPositionLat`/`Long`**, **`endPositionLat`/`Long`**, bounds **`nec`/`swc` Lat/Long`** (dive-level site / track box) | `DiveCoordinate?` / `struct` | FIT |
| **`DiveSummaryMesg`** (fields beyond **`bottom_time`**, **`surface_interval`**, **`reference*`** used for **`DiveActivity`**) | SAC/RMV, descent/ascent times, avg/max ascent & descent rates, **`hangTime`**, **`o2Toxicity`**, CNS/N₂, **`diveNumber`**, etc. | FIT |
| **`DiveGasMesg`** rows (**`heliumContent`**, **`oxygenContent`**, **`status`**, **`mode`**, **`messageIndex`**) | `[DiveGas]` child rows (not per GPS sample) | FIT |

#### Profile-point time series to add (`DiveProfilePoint` — aligned with **`timestamp`**)

| Concept | Suggested type | Source |
|---------|----------------|--------|
| **`samples` / `waypoint` / `tankpressure`** | `Double?` | UDDF |
| **`samples` / `waypoint` / `switchmix`** (active mix at sample) | `String?` or `Int?` (ref) | UDDF |
| Per-sample **NDL**, **deco ceiling**, **alarms**, **heartbeat** (when present under **`samples`**, not dive summary) | `Int?` / `Double?` / `Int?` | UDDF |
| **`RecordMesg` / `ndlTime`** | `UInt32?` → maps to existing **`ndlSeconds`** | FIT — **implemented** |
| **`RecordMesg` / `timeToSurface`** | `UInt32?` → **`timeToSurfaceSeconds`** | FIT — **implemented** |
| **`RecordMesg` / `nextStopDepth`**, **`nextStopTime`** | `Float64?`, `UInt32?` | FIT |
| **`RecordMesg` / `ascentRate`** | `Float64?` → **`ascentRateMetersPerSecond`** | FIT — **implemented** |
| **`RecordMesg` / `heartRate`** | `UInt8?` → **`heartRateBPM`** | FIT — **implemented** |
| **`RecordMesg` / `absolutePressure`** | `UInt32?` | FIT |
| **`RecordMesg` / `cnsLoad`**, **`n2Load`** | `UInt8?`, `UInt16?` → **`cnsLoad`**, **`n2Load`** | FIT — **implemented** |
| **`RecordMesg` / `po2`** | `Float64?` → **`po2Bars`** | FIT — **implemented** |
| **`RecordMesg` / `pressureSac`**, **`volumeSac`**, **`rmv`** | `Float64?` each | FIT |
| **`RecordMesg` / `respirationRate`**, **`enhancedRespirationRate`** | `UInt8?`, `Float64?` | FIT |
| **`RecordMesg` / `coreTemperature`** | `Float64?` | FIT |
| **`RecordMesg` / `airTimeRemaining`** | `UInt32?` | FIT |
| Other **`RecordMesg`** channels (**`speed`**, **`distance`**, **`altitude`**, **`enhancedAltitude`**, **`verticalSpeed`**, etc.) if needed for charts | `Float64?` / `UInt32?` | FIT |

**Ambiguous (usually dive-level summary; use profile only if exporter emits per-sample rows):** **`SessionMesg`** / **`DiveSummary`** style **avg/max ascent or descent rates** — prefer **dive** row from **`DiveSummaryMesg`**; **UDDF** has no FIT-style record stream, so ascent is already derived into **`avgAscentRateMetersPerSecond`** on **`DiveActivity`** from waypoints.

### DiveActivity — future fields to consider (post-MVP)

- `gasType` — air, nitrox, trimix, etc.
- `tankPressureStartBar` / `tankPressureEndBar` — air consumption tracking
- `visibility` — user-reported or sensor-derived
- `diveBuddy` — string or relationship to a future `Contact` model
- `photos` — array of asset references for post-dive media
- `tags` — free-form user labels (e.g. "wreck", "night dive")

---

### DiveProfile (`Models/DiveProfile.swift`)

**Status:** `DiveProfilePoint` SwiftData `@Model` implemented with canonical field names (Garmin maps in at import time).

**What was built:**
- `DiveProfilePoint` with `timestamp`, `depthMeters`, and optional `temperatureCelsius`, `ascentRateMetersPerSecond`, `ndlSeconds`, `timeToSurfaceSeconds`
- `@Relationship(inverse: \DiveActivity.profilePoints)` to parent `DiveActivity`

**Pending:**
- [ ] Decide on storage strategy for very large time-series arrays (SwiftData relationship vs. external store) if profiles become a performance issue
- [ ] Wire `DiveProfilePoint` into `ModelContainer` in `GoDiveMVPApp.swift` when `Item` template is replaced with GoDive schema

---

## Mock Data

### MockDiveActivity (`MockData/MockDiveActivity`)

**Status:** File exists but is empty.

**Pending:**
- [ ] Create at least one realistic `DiveActivity` sample using `.garminMK3` device source
- [ ] Add a corresponding array of `DiveProfilePoint` mock data for profile chart testing
- [ ] Use mock data in SwiftUI previews

---

## Views

### App Shell Baseline

**Status:** Bare-bones app navigation and visual structure established.

**What was built:**
- Bottom tab workflow navigation
- Only Home shows the GoDive `AppHeader` at the tab root; other tabs are headerless at root
- Home uses a fixed `AppHeader` with a `ScrollView` below for home content
- Tab bar hidden while viewing pushed secondary flows; restored when popping back to a root tab
- `SecondaryDestinationChrome` helpers (`hidesBottomTabBarWhenPushed`, `SecondaryDestinationBackButton`)
- Simple page wrappers for standard and headerless pages
- Centered `GoDive` branding and small upper-right icon actions
- Lightweight theme tokens for future UI consistency

**Pending:**
- [ ] Preserve the current look, navigation, and simplicity in future page changes unless a redesign is explicitly requested
- [ ] Apply `hidesBottomTabBarWhenPushed()` to any new screens pushed from tab roots

---

### ContentView (`Views/ContentView.swift`)

**Status:** Bottom-tab shell created for GoDive workflow pages.

**Pending:**
- [ ] Replace placeholder content with a dive log list (`List` of `DiveActivity`)
- [ ] Add a detail view that shows all fields for a selected `DiveActivity`
- [ ] Add empty state UI for when no dives have been imported
- [ ] Surface key metrics per row: date, max depth, duration, site name

**Future views (post-MVP):**
- Dive profile chart view (depth vs. time)
- Import flow / Garmin connection screen
- Dive site map view using `DiveCoordinate`
- Stats / insights dashboard

---

### AppPage (`Views/AppPage.swift`)

**Status:** Lightweight wrapper created for standard app pages.

**What was built:**
- Shared `AppHeader` placement for normal workflow pages
- Optional upper-right header content for small icon navigation links
- Custom header back button support for pushed standard pages
- Hidden system navigation bar for pages that use `AppHeader`
- `AppHeaderlessPage` opt-out path for pages that should not show the standard header
- Current header exceptions: `ExploreView` and `ProfileView`

**Pending:**
- [ ] Use `AppPage` for new standard workflow pages
- [ ] Use `AppHeaderlessPage` for new headerless full-page experiences

---

### AppTheme (`Views/AppTheme.swift`)

**Status:** Basic reusable design tokens created.

**What was built:**
- Dynamic light/dark semantic color tokens for surfaces, text, accents, icons, tabs, and header gradients
- Shared spacing tokens for consistent padding
- Shared header typography token
- Compact shared header styling with fixed `GoDive` app name

**Pending:**
- [ ] Reuse `AppTheme` tokens in new SwiftUI views
- [ ] Add new tokens only when multiple pages need the same styling
- [ ] Consider moving color tokens to asset catalog named colors later if the palette grows or design tooling needs it

---

### LaunchScreen (`LaunchScreen.storyboard`)

**Status:** Basic branded launch screen created.

**What was built:**
- `GoDiveLogoPin` image (Assets) above centered title, 128×128, aspect fit, 24pt spacing
- Centered `GoDive` launch text
- Bold system title styling with the primary ocean-blue brand color

**Pending:**
- [ ] Revisit if launch branding moves to asset catalog colors or a dedicated launch asset

---

### App Summary (`cursor/app_summary.md`)

**Status:** Summary documentation created.

**What was built:**
- Markdown overview of current app shell, pages, wrappers, theme, launch screen, and rules

**Pending:**
- [ ] Update this summary when major app structure or design conventions change

---

## App Entry Point

### GoDiveMVPApp (`GoDiveMVPApp.swift`)

**Pending:**
- [ ] Configure `ModelContainer` with `DiveActivity` and `DiveProfilePoint` (replace template `Item` schema)
- [ ] Inject container into environment so views can use `@Query` and `@Environment(\.modelContext)`
- [ ] Remove temporary launch seeding spinner overlay (`SeedingLaunchOverlay`) after mock-data loading/debug work is complete

---

## Deferred (Post-MVP)

These are explicitly out of scope until after MVP validation per rules.md:

- Garmin import / parsing logic
- CloudKit sync
- Media upload
- Marine life ontology
- Social features
- Equipment and tank tracking
