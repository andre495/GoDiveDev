---
name: mainactor-responsibly
description: >-
  Use Swift MainActor responsibly in GoDive: keep UI mutations on main, move
  PhotoKit/SwiftData/CloudKit/compute off-main with nonisolated helpers,
  Task.detached, background ModelContext, coalesced schedules, and batched
  XPC fetches. Use when fixing tap lag or hangs, adding launch/maintenance
  work, PhotoKit prune/backfill, CloudKit reconcile side effects, @MainActor
  isolation warnings, or any heavy work near navigation/launch/foreground.
---

# Use MainActor responsibly

Complements always-on rules:

- **`.cursor/rules/swift-mainactor-usage.mdc`** — when `@MainActor` is correct
- **`.cursor/rules/swiftui-snappy-navigation.mdc`** — first frame / navigation

This skill is the **practice playbook**: traps, patterns, and a proven launch case.

## Core rule

**MainActor = UI state and hit-testing only.**

If work does not mutate `@State` / `@Observable` / sheets / tabs / bindings, it
probably should not run on MainActor — even if it is `async`.

Apple’s bar: Main Thread busy for **>~50–100 ms** feels sticky. Multi-second
PhotoKit / CloudKit work on main feels frozen.

## What belongs on MainActor

- Writing `@State`, `@Binding`, `@Observable` / `@Published`
- SwiftUI / UIKit control updates, navigation/sheet/tab flags
- **One** batched apply after async work (`self.cache = built`)
- Cheap snapshots of IDs / Sendable values before detaching

## What must stay off MainActor

| Work | Prefer |
|---|---|
| Sort / aggregate / chart derivation | `Task.detached` + Sendable snapshot |
| SwiftData bulk fetch / scan | Background `ModelContext(container)` |
| PhotoKit `PHAsset.fetch*` / prune / backfill | `nonisolated` + detached; **batch** fetches |
| CloudKit identity side effects (prune, heavy sync) | `schedule(...)` — never inline in reconcile |
| File / JSON decode / CDN | Utility detached task |
| Loops of `assetExists(localIdentifier:)` | One `existingLocalIdentifiers(in:)` |

## Traps (read carefully)

### 1. `async` ≠ off MainActor

SwiftUI views and many app types are MainActor-isolated by default
(`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`). Then:

- `Task { }` inside a view inherits MainActor
- `await heavy()` on a MainActor type still runs on main unless the function is
  **`nonisolated`** or you use **`Task.detached`**

### 2. `Task.detached` that immediately hops back

Calling a MainActor-isolated method from detached work undoes the win.
Mark the **whole perform path** `nonisolated` (schedule, wait, perform, helpers).

### 3. Side effects on MainActor event handlers

`scenePhase`, CloudKit import notifications, identity reconcile, `onAppear` —
these often run on main. From them: **only** `SomeMaintenance.schedule(container:)`.
Do not inline PhotoKit / full-table scans.

### 4. Early “deferred” tiers still fight first taps

A **2 s** post-attach tier is still inside the first-interaction window.
Put XPC-heavy PhotoKit prune later (chrome + longer quiet window).

### 5. N× XPC calls

Hundreds of `PHAsset.fetchAssets(withLocalIdentifiers: [one])` will hang even
off-main and can still contend with UI. Batch identifiers into one fetch.

### 6. TTFF ≠ tap responsiveness

Organizer / xctrace time-to-first-draw can look fine while Main Thread hangs
after first paint still freeze taps. Profile **Hangs / Time Profiler**, not only TTFF.

## Default pattern: snapshot → detach → one apply

```swift
@MainActor
func refresh() async {
    let input = snapshotFromModels() // cheap
    let built = await Task.detached(priority: .utility) {
        Builder.build(from: input) // nonisolated / Sendable
    }.value
    guard !Task.isCancelled else { return }
    self.displayCache = built // one UI write
}
```

## Default pattern: coalesced background maintenance

Use when work is triggered from several MainActor sites (launch, foreground,
CloudKit import) but must run at most once at a time:

```swift
enum SomeMaintenance: Sendable {
    nonisolated private static let scheduledTaskSlot =
        OSAllocatedUnfairLock<Task<Void, Never>?>(initialState: nil)

    nonisolated static func schedule(container: ModelContainer) {
        let shouldStart = scheduledTaskSlot.withLock { slot -> Bool in
            if slot != nil { return false }
            slot = Task.detached(priority: .utility) {
                defer { scheduledTaskSlot.withLock { $0 = nil } }
                await run(container: container)
            }
            return true
        }
        _ = shouldStart
    }

    nonisolated private static func run(container: ModelContainer) async {
        // optional: wait for UI quiet / chrome
        let context = ModelContext(container)
        // heavy work — helpers must be nonisolated too
    }
}
```

Locking: prefer **`OSAllocatedUnfairLock`**. Avoid `NSLock` on MainActor-isolated
statics from async contexts (isolation warnings + footguns).

## Soft-first UI

When showing media or heavy lists:

1. Show cheap local data immediately (soft JPEG, cached rows, skeleton/quiet chrome).
2. Upgrade in place after a quiet window.
3. Do not block the interactive surface on high-res PhotoKit / full rebuilds.
4. Avoid misleading empty CTAs while an index is still resolving (quiet placeholder OK).

## Case study: PhotoKit prune (do not regress)

Proven on device Time Profiler — multi-second Main Thread hangs after launch.

**Fix that worked:**

1. **`DiveMediaPhotoKitLaunchMaintenance`** — wait for Home chrome, then **+8 s**,
   then prune/backfill on a **background `ModelContext`** (coalesced).
2. **Removed MainActor prune** from CloudKit identity reconcile (big hang source).
3. **Removed prune/backfill** from the **2 s** deferred maintenance tier.
4. **Batched** `PHAsset` existence via **`existingLocalIdentifiers`** (one fetch instead of N).

Broken media pointers still get cleaned up — just later, without blocking early taps.

| Timing | Role |
|---|---|
| `deferredMaintenanceDelaySeconds` (~2) | CDN / track / non-PhotoKit |
| `deferredPhotoKitMaintenanceDelaySeconds` (~8) **after chrome** | PhotoKit prune / cloud-id backfill |
| `AccountSession.isHomeLaunchChromeReady` | Gate before PhotoKit tier |

Canonical files:

- `GoDiveMVP/Data/DiveMediaPhotoKitLaunchMaintenance.swift`
- `GoDiveMVP/Data/DiveMediaReferencePruning.swift`
- `GoDiveMVP/Data/DiveMediaReferenceLoader.swift`
- `GoDiveMVP/Data/AppLaunchPostOverlayPresentation.swift`
- `GoDiveMVP/Data/AccountSessionCloudKitIdentityObserver.swift`

## Review checklist

- [ ] Does this code **write UI state**, or is it on MainActor by accident?
- [ ] Is every `Task { }` actually off-main where needed (`detached` / `nonisolated`)?
- [ ] One batched UI apply — not updates inside a tight loop?
- [ ] MainActor handlers only **schedule** heavy work?
- [ ] PhotoKit / XPC sweeps **batched** and **deferred** past first interaction?
- [ ] Would this block tab switch / sheet / first taps? → defer or detach.
- [ ] Isolation warnings fixed with real `nonisolated` / type placement — not blanket `@preconcurrency`?

## Verify

1. Instruments **Time Profiler** / **Hangs** on device while tapping after the trigger.
2. Grep build log for MainActor / isolation **`warning:`** (`xcode-fix-build-warnings.mdc`).
3. For launch paths: `[LaunchTimeline]` chrome/overlay marks; MetricKit TTFF is separate.

## Tests

- Pure timing / batch helpers: `nonisolated` + `#expect` (no UI).
- UI/session: `@MainActor` tests only when touching `AccountSession` / view state.
- When changing defer constants, update `AppLaunchPostOverlayPresentation` expectations.
