# GoDive

GoDive is an iPhone dive log app built with **SwiftUI** and **SwiftData**.

## Architecture (hybrid cloud)

GoDive is **local-first** with an Apple-native hybrid cloud split:

| Layer | Technology | Holds |
|-------|------------|--------|
| **Dive log sync** | **Apple CloudKit** (private DB via SwiftData) | Dives, profile, trips, buddies, gear, certs, media pointers/previews, user sites/species, most Settings |
| **Media bytes** | **Photos / iCloud Photos** | Full photos and videos (not uploaded to GoDive or CloudKit as full assets) |
| **Social directory** | **Firebase Auth + Firestore + Storage** | Friends-ready profile (`users/{uid}` + avatar); **not** the dive log |
| **App catalogs** | **Firebase Hosting / Storage** (optional CDN) + on-device cache | Marine Life + OpenDiveMap reference data |

Developer docs: [`GoDiveMVP/cursor/app_summary.md`](GoDiveMVP/cursor/app_summary.md), [`GoDiveMVP/cursor/hybrid_cloud_sync_boundaries.md`](GoDiveMVP/cursor/hybrid_cloud_sync_boundaries.md), [`GoDiveMVP/cursor/firebase_user_profiles.md`](GoDiveMVP/cursor/firebase_user_profiles.md).

### Notable dependencies

- **CloudKit** — system framework + iCloud entitlement (`iCloud.PrimoSoftware.GoDiveMVP`)
- **Firebase iOS SDK** (SPM) — `FirebaseCore`, `FirebaseAuth`, `FirebaseFirestore`, `FirebaseStorage`
- **FITSwiftSDK**, **Google Maps SDK**, optional **Fishial.AI** — see app summary

Secrets (gitignored — copy from `.example` templates): `GoogleService-Info.plist`, optional `CatalogCDNSecrets.plist`, `GoogleMapsSecrets.plist`, `FishialSecrets.plist`.

**Secret handling / OWASP Phase 3:** restrict Maps keys to this iOS bundle; Fishial client secret remains in-IPA until a proxy — see [`GoDiveMVP/cursor/owasp_secrets_handling.md`](GoDiveMVP/cursor/owasp_secrets_handling.md). Never commit real secret plists.

## User guide

The public user guide is published with GitHub Pages:

**https://andre495.github.io/GoDiveDev/**
