# GoDive Cursor Rules

## Project Overview

GoDive is an iOS application built using Swift, SwiftUI, and SwiftData.

The goal of the MVP is to:
- Import dive data from Garmin MK3
- Normalize dive data into a canonical schema
- Display dive history and basic insights
- Preserve dive profile (time-series) data

This is an MVP build. Focus on simplicity, clarity, and speed of iteration.

---

## Platform Requirements

This project targets:

**iOS 26 (latest iOS version)**

All generated code must:
- Be compatible with iOS 26
- Use modern Swift, SwiftUI, and SwiftData APIs
- Avoid legacy or deprecated patterns

Do NOT include:
- Backward compatibility for older iOS versions
- Availability checks (e.g., @available)
- Legacy UIKit-based implementations

---

## Core Development Principles

### 1. Keep It Minimal
Only implement what is required for the MVP.

Do not add extra features, fields, or abstractions “just in case.”

For UI pages, do not invent or scaffold page content beyond requested structure. Only create concrete content/components when the user explicitly specifies what to add.

---

### 2. Prefer Clarity Over Cleverness
Use explicit, readable naming.

Examples:
- maxDepthMeters
- durationMinutes
- averageDepthMeters

Avoid:
- ambiguous names like `depth`, `time`, or `value`

---

### 3. Normalize Data Internally
The app uses a **canonical internal schema**.

Do NOT use Garmin-specific field names in models.

Garmin data should be mapped into GoDive models, not define them.

---

### 4. Separate Responsibilities

- `DiveActivity` = summary-level dive data
- `DiveProfilePoint` = time-series data

Do NOT mix these responsibilities.

---

### 5. Use Optional Fields Correctly
If data may not exist, use optionals.

Do NOT use:
- empty strings
- fake defaults
- placeholder values

---

### 6. Avoid Overengineering
Do NOT introduce:
- service layers
- repositories
- networking layers
- dependency injection frameworks

The goal is fast iteration, not production architecture.

---

## Data Model Requirements

### DiveActivity

Must include:

- id
- source (DiveSource; persisted column migrated from deviceSource)
- sourceDiveId
- startTime
- durationMinutes
- maxDepthMeters
- averageDepthMeters
- bottomTimeSeconds
- surfaceIntervalSeconds
- diveNumber
- waterTempAvgCelsius
- waterTempMaxCelsius
- waterTempMinCelsius
- avgAscentRateMetersPerSecond
- siteName
- locationName
- coordinate
- notes
- rawImportVersion

---

### DiveProfilePoint

Must include:

- timestamp
- depthMeters
- temperatureCelsius
- ascentRateMetersPerSecond
- ndlSeconds
- timeToSurfaceSeconds

---

### Supporting Types

Include only:

- DiveSource
- DiveCoordinate

---

## Swift / SwiftData Guidelines

- Use Swift and SwiftUI
- Use SwiftData-compatible models
- Use modern Swift syntax
- Keep models simple and compile-ready
- Avoid unnecessary annotations or complexity

---

## File Organization

- Models go in `/Models`
- Views go in `/Views`
- Mock data goes in `/MockData`

Each file should have a single clear responsibility.

---

## SwiftUI Page Structure

**Agent default (see also `.cursor/rules/headerless-pages-default.mdc`):** New tab roots and new full-page views should use **`AppHeaderlessPage`** unless the user or product pattern explicitly calls for **`AppPage`** / **`AppHeader`**.

The current app shell is intentionally bare-bones: bottom tab navigation, simple workflow pages, **GoDive** branding on **Home only** ( **`AppHeader`** with a **status-bar-only** **`AppStatusBarEdgeScrim`** — no full-row frosted band), small upper-right icon actions where needed, and minimal chrome elsewhere. Future UI changes should preserve this look, navigation model, and simplicity unless the user explicitly asks to redesign it.

Only **Home** (`LogOverviewView`) shows `AppHeader` at the tab root. Home uses a `ZStack` with an **in-scroll spacer** (not outer `padding` on the `ScrollView`) so content can draw **under** the **GoDive** title row; **`AppStatusBarEdgeScrim`** only covers the **status bar**; `scrollContentBackground(.hidden)` keeps bubbles visible through the scroll layer.

Other primary tabs (Logbook, Field Guide, Explore) use `AppHeaderlessPage` at the root. **Logbook** reuses **`AppHeader`** with **`showsBrandWordmark: false`** and a trailing **+** so the top matches **Home** (status scrim + layout) without the wordmark. **Optional status-bar scrim:** when a headerless page needs scroll-under top controls **without** **`AppHeader`**, add **`AppStatusBarEdgeScrim(safeAreaTop:)`** from the root **`GeometryReader`** in a **`ZStack`** above the scroll surface and below the control row. Use **`AppHeaderMetrics.HeightKey`** + an **in-scroll spacer** (e.g. first `List` row) and **`ignoresSafeArea(edges: .top)`** on scroll content where needed. Omit the scrim when the screen does not need scroll-under (e.g. static placeholder). Explore may keep lightweight top actions (e.g. icons) without the GoDive header bar.

Use `AppPage(title:content:)` for pushed screens that need the shared header with optional `trailingContent` (e.g. Settings, Trip Planner). Pass header icon links through its `trailingContent` closure when needed. `AppPage` uses the same `ZStack` + **`AppHeader`** overlay as Home (**status-only** scrim + title row).

For pushed standard pages, use `AppPage(..., showsBackButton: true, ...)`. Do not rely on SwiftUI's default navigation bar when a page uses `AppHeader`; `AppPage` owns hiding the system navigation bar so root pages and pushed pages stay visually consistent. **`navigationInteractivePopGestureForHiddenNavBar()`** (see `NavigationInteractivePopGestureEnabler.swift`) restores the system **leading-edge** swipe-to-pop, which UIKit otherwise disables when the bar is hidden.

`AppHeaderlessPage` hides the default nav bar and applies the same **interactive pop** helpers for pushed flows (Profile, dive detail, etc.).

Only skip both `AppPage` and `AppHeaderlessPage` for views that are not full page screens.

---

## SwiftUI text fields and keyboard

For **any** text entry on a screen (`TextField`, `TextEditor`, etc.):

- Use **`@FocusState`** and attach **`.focused(...)`** to the control.
- On the **same screen’s** root view (or appropriate container), add **`.toolbar { ToolbarItemGroup(placement: .keyboard) { … } }`** with a **Done** button that clears focus (`false` or `nil` for multi-field `enum?`). That placement draws the accessory **above** the keyboard and dismisses it when focus ends.
- Style **Done** consistently (e.g. semibold body + `AppTheme.Colors.tabSelected`).
- Prefer this SwiftUI focus pattern over UIKit `resignFirstResponder` unless focus cannot be used.

---

## SwiftUI Design Theme

Use `AppTheme` for shared colors, spacing, and typography in SwiftUI views.

Keep color implementation centralized in `AppTheme.Colors`. Use semantic color tokens such as `surface`, `primaryText`, `accent`, `headerGradientStart`, and `iconPrimary`; do not add one-off RGB colors directly in page views.

Color tokens should support both light mode and dark mode. The current MVP strategy is Swift dynamic colors in code, not asset catalog color sets.

Avoid hard-coded colors, repeated padding values, or one-off font choices when an `AppTheme` token already exists.

Keep the theme lightweight: add tokens only when they are reused by multiple views or needed to keep the app visually consistent.

---

## What NOT to Build Yet

Do NOT implement:

- Full Garmin device sync / proprietary import pipelines beyond the current **`.fit` file** MVP (no MK3 USB/XML pipeline, no cloud device pairing here).
- CloudKit sync
- media upload systems
- marine life ontology
- social features
- equipment or tank tracking

These are explicitly deferred until after MVP validation.

---

## Output Expectations

When generating code:

- Provide complete, compile-ready Swift code
- Keep implementations minimal and clean
- Do not include placeholders like “TODO”
- Do not add extra architecture

If unsure, choose the simplest correct solution.

---

## Tracking Changes in todo.md

After every edit — new model, new view, new field, or structural change — update `/cursor/todo.md`.

Rules for updating todo.md:

- Add a section for any new file or model created
- Record what was built and its current status
- List concrete pending tasks using `- [ ]` checkboxes
- Note any future fields or features deferred until post-MVP
- Mark items complete with `- [x]` once done

Do NOT skip this step. `todo.md` is the single source of truth for project state.

---

## Change log and app summary

When adding a **new numbered section** to `cursor/change_log.md` for work being **pushed to git**, update **`cursor/app_summary.md`** in the same change so the high-level architecture summary stays accurate. Follow **`.cursor/rules/changelog-app-summary-sync.mdc`**.

---

## Code changes and tests

Non-trivial edits under **`GoDiveMVP/`** should include new or updated tests in **`GoDiveMVPTests`** (unit) or **`GoDiveMVPUITests`** (UI), per **`.cursor/rules/code-changes-require-tests.mdc`**.

---

## Guiding Principle

Prioritize:

**speed → clarity → correctness → scalability**

in that order.