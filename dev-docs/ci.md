# Continuous Integration

This document describes the CI workflow for GoDiveMVP.

## Overview

The `ios-ci.yml` workflow runs on:
- Every push to `main`
- Every pull request targeting `main`
- Nightly schedule (3am UTC) for full regression
- Manual trigger via `workflow_dispatch` (with optional `full_suite` flag)

It consists of three jobs:

1. **Select Tests** — determines which test suites to run based on changed files
2. **Build & Test** — builds the iOS app and runs unit tests on a macOS runner with Xcode 27.1
3. **Firebase Rules Tests** — runs Firestore and Storage security rules tests (only when `catalog-cdn/` changes)

## Selective Testing

PRs run only the test suites relevant to their changed files, reducing CI time. The full suite runs on:
- Pushes to `main`
- Nightly schedule
- Manual triggers with `full_suite: true`
- PRs that touch core paths

### How It Works

1. The **Select Tests** job runs `ci/select-tests.sh` to diff changed files against the merge base
2. Changed paths are matched against patterns in `ci/test-map.yml`
3. Matching test suites are combined and passed to `xcodebuild -only-testing:` flags

### Core Paths

These paths always trigger the full suite (fail-safe):
- `GoDiveMVP.xcodeproj/**` — project configuration
- `GoDiveMVP/Data/AccountSession*.swift` — auth infrastructure
- `GoDiveMVP/Data/GoDiveFirebase*.swift` — Firebase setup
- `GoDiveMVP/Data/AppModelContainer.swift` — SwiftData container
- `GoDiveMVP/Models/**` — shared data models
- `GoDiveMVPTests/*TestSupport.swift` — test infrastructure
- `.github/workflows/ios-ci.yml` — CI itself
- `ci/**` — test selection logic

### Adding Mappings

To add a new mapping in `ci/test-map.yml`:

```yaml
- pattern: "GoDiveMVP/Data/MyFeature*.swift"
  suites:
    - MyFeatureTests
    - MyFeatureIntegrationTests
```

Verify with the self-test:
```bash
ci/select-tests.sh --self-test
```

### Viewing Selection Results

The job summary shows which suites ran and why. For debugging locally:
```bash
# See what would run for your current changes
ci/select-tests.sh

# Test with specific files
ci/select-tests.sh --files GoDiveMVP/Data/TripStore.swift

# Generate markdown summary
ci/select-tests.sh --summary
```

## Build & Test Job

Runs on `xcode-27` (preview image) with Xcode 27.1.

### Steps

1. **Checkout** — clones the repository
2. **Select Xcode** — pins Xcode 27.1 using `maxim-lobanov/setup-xcode`
3. **Create placeholder plists** — generates fake `GoogleService-Info.plist` and `GoogleMapsSecrets.plist` for compilation (see below)
4. **Cache SPM** — caches Swift Package Manager dependencies keyed on `project.pbxproj`
5. **Resolve packages** — runs `xcodebuild -resolvePackageDependencies`
6. **Build** — builds the app and test targets for iOS 27 Simulator
7. **Test** — runs `GoDiveMVPTests` unit tests with parallel testing enabled
8. **Upload results** — on failure, uploads `.xcresult` bundle for inspection

### Test Target Dependency

The test target requires PR #60 (`cursor/xcode-27-upgrade-3f93`) for Swift 6 actor isolation fixes. Until that PR merges, CI builds on this branch alone will fail at the test compilation step.

## Firebase Rules Tests Job

Runs on `ubuntu-latest` with Node 20 and Java 21.

**Conditional execution**: This job only runs when `catalog-cdn/` files change, or on pushes to main, nightly schedules, and manual triggers. PRs that don't touch Firebase rules skip this job.

### Steps

1. **Check for tests** — skips cleanly if `catalog-cdn/rules-tests/` doesn't exist
2. **Setup Node/Java** — installs Node 20 (with npm cache) and Temurin Java 21
3. **Install dependencies** — runs `npm ci` in `catalog-cdn/rules-tests`
4. **Run Firestore tests** — validates Firestore security rules
5. **Run Storage tests** — validates Storage security rules

## Placeholder Plist Approach

`GoogleService-Info.plist` and `GoogleMapsSecrets.plist` are gitignored because they contain API keys. For CI builds to compile, the workflow creates placeholder files with clearly fake values:

- **Project ID**: `demo-godive-ci`
- **API keys**: `YOUR_API_KEY`, `CI_PLACEHOLDER_MAPS_API_KEY` (patterns detected by app to skip Firebase init)
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
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0'

# Run unit tests with parallel testing
xcodebuild test-without-building \
  -project GoDiveMVP.xcodeproj \
  -scheme GoDiveMVP \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' \
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
