# Continuous Integration

This document describes the CI workflow for GoDiveMVP.

## Overview

The `ios-ci.yml` workflow runs on every pull request to `main` and can be triggered manually via `workflow_dispatch`. It consists of two jobs:

1. **Build & Test** — builds the iOS app and runs unit tests on a macOS runner
2. **Firebase Emulator Tests** — runs Firestore rules and function tests using the Firebase emulator

## Build & Test Job

Runs on `macos-15` with Xcode 27.1.

### Steps

1. **Checkout** — clones the repository
2. **Select Xcode** — pins Xcode 27.1 using `maxim-lobanov/setup-xcode`
3. **Create placeholder plists** — generates fake `GoogleService-Info.plist` and `GoogleMapsSecrets.plist` for compilation (see below)
4. **Cache SPM** — caches Swift Package Manager dependencies keyed on `project.pbxproj`
5. **Resolve packages** — runs `xcodebuild -resolvePackageDependencies`
6. **Build** — builds the app and test targets for iOS Simulator
7. **Test** — runs `GoDiveMVPTests` unit tests
8. **Upload results** — on failure, uploads `.xcresult` bundle for inspection

### Runtime

- Full run (cold cache): ~15-25 minutes
- With SPM cache hit: ~8-12 minutes

## Firebase Emulator Tests Job

Runs on `ubuntu-latest` with Node 20 and Java 21.

### Steps

1. **Check for tests** — skips cleanly if `catalog-cdn/functions/speciesSimilarity.test.js` doesn't exist
2. **Setup Node/Java** — installs Node 20 and Temurin Java 21
3. **Install Firebase CLI** — installs `firebase-tools` globally
4. **Install dependencies** — runs `npm ci` in `catalog-cdn/functions`
5. **Run tests** — executes tests via `firebase emulators:exec`

### Runtime

- Typical run: ~3-5 minutes

## Placeholder Plist Approach

`GoogleService-Info.plist` and `GoogleMapsSecrets.plist` are gitignored because they contain API keys. For CI builds to compile, the workflow creates placeholder files with clearly fake values:

- **Project ID**: `godive-ci-demo-placeholder`
- **API keys**: `CI_PLACEHOLDER_API_KEY`, `CI_PLACEHOLDER_MAPS_API_KEY`
- **GCM Sender ID**: `000000000000`
- All optional features disabled

These values allow the app to compile but will not connect to any real Firebase project. This is intentional—CI validates that the code builds and tests pass, not that production services are reachable.

## Running Locally

### iOS Build & Test

```bash
# Resolve packages
xcodebuild -resolvePackageDependencies \
  -project GoDiveMVP.xcodeproj \
  -scheme GoDiveMVP

# Build for testing
xcodebuild build-for-testing \
  -project GoDiveMVP.xcodeproj \
  -scheme GoDiveMVP \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest'

# Run unit tests
xcodebuild test-without-building \
  -project GoDiveMVP.xcodeproj \
  -scheme GoDiveMVP \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -only-testing:GoDiveMVPTests
```

### Firebase Emulator Tests

```bash
cd catalog-cdn

# Install dependencies
cd functions && npm ci && cd ..

# Run tests with emulator
firebase emulators:exec \
  --project godive-ci-demo-placeholder \
  "node functions/speciesSimilarity.test.js"
```

## Known Issues

- **FishialAPITestSupport** (tracked in [#28](https://github.com/andre495/GoDiveDev/issues/28)): This test target may fail to build. If it does, exclude it with `-skip-testing:FishialAPITestSupport`.
- **Warnings**: Build warnings are logged but do not fail the workflow. Review them periodically.
