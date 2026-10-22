---
name: run-on-simulator
description: >-
  Build GoDiveMVP and launch it on the latest-generation iPhone simulator,
  fix project build errors and warnings with child agents, then relaunch and
  capture a short privacy-safe run trace (launch intervals, network counts).
  Use when the user wants to test the app, run on sim, or run on the simulator.
  Do not use for the unit-test suite, commit/push preflight, or Dre's Phone.
---

# Run GoDive on the simulator

This skill **overrides** the ordinary build path in **`xcode-workflow.mdc`** (stop after build; do not fix warnings; no simulator install/launch) and the default ban on spawning subagents. Commit/push preflight, unit tests, and Dre's Phone still follow **`xcode-workflow.mdc`**.

Do not commit. Do not update the changelog.

## Setup

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
XCBUILD="$DEVELOPER_DIR/usr/bin/xcodebuild"
PROJECT="/Users/andrdugas/Desktop/GoDiveMVP/GoDiveMVP.xcodeproj"
SCHEME="GoDiveMVP"
BUNDLE_ID="PrimoSoftware.GoDiveMVP"
```

Use full Xcode. If `xcodebuild` is missing, stop and say so.

## 1. Pick the latest iPhone simulator

```bash
$XCBUILD -project "$PROJECT" -scheme "$SCHEME" -showdestinations
```

Choose the **highest iPhone generation** (the number in `iPhone 17`, not Pro/Plus/Air/e). Prefer that plain name with the newest OS. If the plain name is absent, use the highest-numbered iPhone that is listed. Report the name and OS you used.

Resolve its UDID from `xcrun simctl list devices available`, boot it, and open Simulator:

```bash
xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b
open -a Simulator --args -CurrentDeviceUDID "$UDID"
```

If boot or destination fails, stop. Do not repair the simulator runtime.

## 2. Build

No `clean` unless the previous sim build failed for a stale-product reason.

```bash
DEST="platform=iOS Simulator,name=${SIM_NAME},OS=latest"
$XCBUILD -project "$PROJECT" -scheme "$SCHEME" \
  -destination "$DEST" -configuration Debug \
  build 2>&1 | tee /tmp/godive-sim-build.log
```

Collect `error:` and `warning:` lines. Drop `appintentsmetadataprocessor` noise and warnings whose path is an unchanged Swift package (FITSwiftSDK, GoogleMaps, and similar). Those are report-only.

**Project diagnostics** are the rest, in `GoDiveMVP/`, `GoDiveMVPTests/`, `GoDiveMVPUITests/`, and the Xcode project.

## 3. Fix with child agents, then rebuild

If there are **no** project errors or warnings, skip to launch.

Otherwise spawn **`generalPurpose`** Task agents (`environment: local`, `run_in_background: false`, model inherit). One agent per source file. Cap at **4** in parallel; queue the rest. Send them in one message. Do not launch the app until they finish and a later build is clean.

Each prompt must include the exact diagnostic lines, the file path, and:

- Smallest fix only. No refactors, no drive-by edits in other files.
- Follow repo rules already in context (MainActor, secrets logging, owner scope).
- Warning-only fixes (unused, isolation, deprecation) do not need a new test. Behavior changes do, per **`code-changes-require-tests.mdc`**. Author tests; do not run `xcodebuild`.
- Do not commit.

When every agent has returned, rebuild with the same command. If project diagnostics remain, run **one** more agent wave on whatever is left, then rebuild again. After that second rebuild, stop and report the remaining lines. Do not start a third wave.

## 4. Install and launch

Only after a build with **zero** project errors and warnings.

```bash
APP_PATH=$($XCBUILD -project "$PROJECT" -scheme "$SCHEME" \
  -destination "$DEST" -configuration Debug -showBuildSettings \
  | awk -F ' = ' '/TARGET_BUILD_DIR/ {dir=$2} /FULL_PRODUCT_NAME/ {name=$2} END {print dir "/" name}')
xcrun simctl install "$UDID" "$APP_PATH"
```

Capture the trace in the same step as launch (below). Leave Simulator in the foreground.

## 5. Run trace

Record what the existing app already emits. Do not add Firebase Analytics, a proxy, or certificate pinning for this.

**Why this set:** Simulator MetricKit payloads are usually empty (Apple delivers them later, and reliably on device). A MITM proxy would see Maps/Fishial tokens. A 20-second unified-log window plus the app's own signposts is enough to compare cold launches without new product code.

```bash
RUN_DIR="/tmp/godive-sim-run-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RUN_DIR"
xcrun simctl spawn "$UDID" log stream --style compact --level info \
  --predicate 'subsystem == "PrimoSoftware.GoDiveMVP" AND category == "Performance"' \
  > "$RUN_DIR/signposts.log" &
SIGN_PID=$!
xcrun simctl spawn "$UDID" log stream --style compact --level info \
  --predicate 'subsystem == "com.apple.network" AND processImagePath CONTAINS "GoDiveMVP"' \
  > "$RUN_DIR/network.log" &
NET_PID=$!
START=$(date +%s)
xcrun simctl launch "$UDID" "$BUNDLE_ID" | tee "$RUN_DIR/launch.txt"
sleep 20
kill "$SIGN_PID" "$NET_PID" 2>/dev/null || true
```

Then, if the file exists, copy it into `$RUN_DIR`:

`…/Library/Application Support/GoDiveDiagnostics/metrickit-launch-summary.txt`

from `xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data`. Missing file is normal. Say so.

**Scrub before quoting logs.** Drop query strings, `Authorization`, tokens, `client_secret`, emails, and GPS. Keep host, status, duration, and error domain only.

### What to report

- Destination (name, OS, UDID) and whether the build was clean on the first try
- Child agents used, files they touched, and that the relaunch build was clean
- Wall clock from `simctl launch` through the 20s window
- Signpost intervals present (`LaunchContainerLoad`, `LaunchSessionRestore`, `LaunchSessionValidation`, `LaunchEssentialMaintenance`, `LaunchMarineLifeSeed`, `HomeOverviewRebuild`). Note any begin without an end
- Network: request count, distinct hosts, failures. No URLs with queries
- MetricKit summary line, or "not delivered this session"
- `$RUN_DIR` path

Deeper Instruments (`xctrace` App Launch or Network) only if the user asks.
