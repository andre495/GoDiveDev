# Development Setup

Local development prerequisites for GoDive, verified against the repository.

## Xcode

- **Xcode 27.x** with the iOS 27 simulator runtime
- Install the simulator runtime: Xcode > Settings > Components
- Deployment target: **iOS 26.0** (per `project.pbxproj`)

## JDK (for Firebase Local Emulator Suite)

The Firebase Local Emulator Suite requires JDK 21 or later.

```bash
brew install openjdk@21
```

After installation, Homebrew prints a note about adding the JDK to your PATH. Follow the symlink or PATH instructions for your shell:

```bash
sudo ln -sfn "$(brew --prefix)/opt/openjdk@21/libexec/openjdk.jdk" /Library/Java/JavaVirtualMachines/openjdk-21.jdk
```

Verify:

```bash
java -version
```

## Node.js

Node 20 is required (per `catalog-cdn/functions/package.json` engines).

Install via your preferred method (e.g., `nvm`, Homebrew, or the official installer).

## Firebase CLI

Install the Firebase CLI globally or use the repo's local version:

```bash
npm install -g firebase-tools
```

Authenticate once:

```bash
firebase login
```

### Running function unit tests

The `catalog-cdn/functions/` directory contains unit tests for Cloud Functions helpers:

```bash
cd catalog-cdn/functions
node speciesSimilarity.test.js
```

### Emulator for rules testing

To run the Firebase emulators locally (Auth, Firestore, Storage):

```bash
cd catalog-cdn
firebase emulators:start --project demo-godive-rules
```

The emulators use a demo project ID (`demo-` prefix) and do not require production credentials.

### Running security rules unit tests

```bash
cd catalog-cdn/rules-tests
npm install
npm test
```

Tests run against temporary emulator instances and verify Firestore and Storage security rules.

## GoogleService-Info.plist

This file is **gitignored** and must be obtained separately:

1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Select the project and navigate to Project Settings > Your apps > iOS
3. Download `GoogleService-Info.plist`
4. Place it at `GoDiveMVP/Config/GoogleService-Info.plist`

This is client configuration (not a secret), but it stays out of the public repository.

## No service-account keys

**No service-account or Admin SDK key is needed or allowed locally.** The Firebase emulators use a demo project ID and do not require production credentials.

The `.gitignore` explicitly blocks service-account files:

```
*adminsdk*.json
*service-account*.json
*serviceAccount*.json
firebase-admin*.json
```

Do not create, commit, or request these files for local development.

## Swift Package Manager

SPM dependencies resolve automatically when you open the project in Xcode. No manual `swift package resolve` is required.

## DEBUG Launch Arguments

The following launch arguments are available in **DEBUG builds only** (compiled out of Release):

| Argument | Description |
|---|---|
| `-GoDiveUITest` | Activates UITest mode: shows stub `GoDiveUITestRootView` instead of the real app, disables animations, skips network/CloudKit. |
| `-GoDiveOpenExploreMap` | Opens Explore → Map → All Sites on launch with real catalog sites. Bypasses onboarding and the UITest stub. Use for testing the map view with worldwide data. Combine with `-GoDiveMockSeed` to populate sample data. |
| `-GoDiveMockSeed` | Seeds mock dive/site data from bundled JSON on launch (requires `MockDataSeeding.isLaunchSeedingEnabled = true` in code). |

### Testing the Explore Map (Issue #53)

To manually verify that the Map tab handles worldwide catalog sites without crashing:

1. Set scheme arguments in Xcode: Product > Scheme > Edit Scheme > Run > Arguments
2. Add `-GoDiveOpenExploreMap` and `-GoDiveMockSeed`
3. Build and run (DEBUG configuration)
4. The app should open directly to the Explore tab with Map view and All Sites scope
5. The map should display the world view without crashing

The UI test `testExploreMapTab_allSitesScope_doesNotCrash` exercises this path automatically.
