# Continuous Integration

This document describes the CI workflow for GoDiveMVP.

## Overview

The `ios-ci.yml` workflow runs on:
- Every push to `main`
- Every pull request targeting `main`
- Manual trigger via `workflow_dispatch`

It consists of two jobs:

1. **Build & Test** — builds the iOS app and runs unit tests on a macOS runner with Xcode 27.1
2. **Firebase Rules Tests** — runs Firestore and Storage security rules tests using the Firebase emulator

## Build & Test Job

Runs on `xcode-27` (preview image) with Xcode 27.1.

### Steps

1. **Checkout** — clones the repository
2. **Select Xcode** — pins Xcode 27.1 using `maxim-lobanov/setup-xcode`
3. **Create placeholder plists** — generates fake `GoogleService-Info.plist` and `GoogleMapsSecrets.plist` for compilation (see below)
4. **Cache SPM** — caches Swift Package Manager dependencies keyed on `project.pbxproj`
5. **Resolve packages** — runs `xcodebuild -resolvePackageDependencies`
6. **Build** — builds the app and test targets for iOS 26 Simulator
7. **Test** — runs `GoDiveMVPTests` unit tests with parallel testing enabled
8. **Upload results** — on failure, uploads `.xcresult` bundle for inspection

### Test Target Dependency

The test target requires PR #60 (`cursor/xcode-27-upgrade-3f93`) for Swift 6 actor isolation fixes. Until that PR merges, CI builds on this branch alone will fail at the test compilation step.

## Firebase Rules Tests Job

Runs on `ubuntu-latest` with Node 20 and Java 21.

### Steps

1. **Check for tests** — skips cleanly if `catalog-cdn/rules-tests/` doesn't exist
2. **Setup Node/Java** — installs Node 20 (with npm cache) and Temurin Java 21
3. **Install dependencies** — runs `npm ci` in `catalog-cdn/rules-tests`
4. **Run Firestore tests** — validates Firestore security rules
5. **Run Storage tests** — validates Storage security rules

## Placeholder Plist Approach

`GoogleService-Info.plist` and `GoogleMapsSecrets.plist` are gitignored because they contain API keys. For CI builds to compile, the workflow creates placeholder files with clearly fake values:

- **Project ID**: `demo-godive-ci`
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

# Build for testing (iOS 26 simulator)
xcodebuild build-for-testing \
  -project GoDiveMVP.xcodeproj \
  -scheme GoDiveMVP \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.0'

# Run unit tests with parallel testing
xcodebuild test-without-building \
  -project GoDiveMVP.xcodeproj \
  -scheme GoDiveMVP \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.0' \
  -parallel-testing-enabled YES \
  -only-testing:GoDiveMVPTests
```

### Firebase Rules Tests

```bash
cd catalog-cdn/rules-tests

# Install dependencies
npm ci

# Run all rules tests
npm test

# Or run individually
npm run test:firestore
npm run test:storage
```

## Configuration

- **Concurrency**: Cancels superseded runs per branch
- **Timeout**: 45 minutes (Build & Test), 15 minutes (Firebase Rules)
- **Permissions**: `contents: read` only
- **Secrets**: None required
- **Actions**: All pinned to commit SHAs for reproducibility
