# App Privacy Manifest

Privacy manifest documentation for App Store Connect submission. This combines GoDive's own declarations with third-party SDK declarations from Xcode's Privacy Report.

## GoDive App Declarations

Data types declared in `GoDiveMVP/PrivacyInfo.xcprivacy`:

| Data Type | Linked to User | Used for Tracking | Purpose | Destination |
|---|---|---|---|---|
| Precise Location | Yes | No | App Functionality | Firestore `sharedDives` projections |
| Photos or Videos | Yes | No | App Functionality | Firebase Storage (friend share previews) |
| User ID | Yes | No | App Functionality | Firestore user docs, FCM token docs |
| Name | Yes | No | App Functionality | Firestore social profile |
| Fitness | Yes | No | App Functionality | Firestore `sharedDives` projections |
| Other User Content | Yes | No | App Functionality | Firestore (notes, anonymized sightings) |
| Other Diagnostic Data | No | No | App Functionality | CloudKit public (opt-in crash reports) |
| Device ID | Yes | No | App Functionality | Firestore FCM token storage |

### Required-Reason APIs

| API Category | Reason Code | Usage |
|---|---|---|
| User Defaults | CA92.1 | App preferences, crash breadcrumbs, session state |
| System Boot Time | 35F9.1 | Launch timeline metrics |
| File Timestamp | C617.1 | Photo/video capture date extraction |

## Third-Party SDK Declarations

From Xcode Privacy Report (Release archive). All SDKs declare **Tracking: No**.

### Google Maps SDK

| Data Type | Linked to User | Purpose |
|---|---|---|
| Device ID | Yes | Analytics, App Functionality |
| Product Interaction | No | Analytics |
| Crash Data | No | Analytics |
| Performance Data | No | Analytics |
| Other Data Types | Yes | Analytics |

### Firebase SDK

| Module | Data Type | Linked to User | Purpose |
|---|---|---|---|
| Firebase Auth | User ID | Yes | App Functionality |
| Firebase Messaging | Device ID | No | App Functionality |
| Firebase Installations | Other Diagnostic Data | No | Analytics |
| Firebase Auth | Other Diagnostic Data | No | Analytics |
| Firebase Firestore | Other Diagnostic Data | No | Analytics |
| Firebase Messaging | Other Diagnostic Data | No | Analytics |
| GoogleDataTransport | Other Diagnostic Data | No | Analytics |

**Note:** Firebase Auth does not declare Email as a collected data type. GoDive does not store email addresses.

## App Store Connect Privacy Questionnaire

Combined checklist of data types to select, based on GoDive + SDK declarations:

### Identifiers

- [x] **User ID** — GoDive (linked, App Functionality) + Firebase Auth (linked, App Functionality)
- [x] **Device ID** — GoDive (linked, App Functionality) + Google Maps (linked, Analytics + App Functionality) + Firebase Messaging (not linked, App Functionality)

### Location

- [x] **Precise Location** — GoDive only (linked, App Functionality)

### User Content

- [x] **Photos or Videos** — GoDive only (linked, App Functionality)
- [x] **Other User Content** — GoDive only (linked, App Functionality)

### Health & Fitness

- [x] **Fitness** — GoDive only (linked, App Functionality)

### Contact Info

- [ ] **Name** — GoDive only (linked, App Functionality)
- [ ] **Email Address** — Not declared by GoDive or Firebase Auth

### Diagnostics

- [x] **Crash Data** — Google Maps only (not linked, Analytics)
- [x] **Performance Data** — Google Maps only (not linked, Analytics)
- [x] **Other Diagnostic Data** — GoDive (not linked, App Functionality) + Firebase modules (not linked, Analytics)

### Usage Data

- [x] **Product Interaction** — Google Maps only (not linked, Analytics)

### Other Data

- [x] **Other Data Types** — Google Maps only (linked, Analytics)

## Purposes Summary

| Purpose | Data Types |
|---|---|
| **App Functionality** | Location, Photos, User ID, Device ID, Name, Fitness, Other User Content, Other Diagnostic Data (GoDive crash reports) |
| **Analytics** | Device ID, Product Interaction, Crash Data, Performance Data, Other Diagnostic Data, Other Data Types (all from Google Maps / Firebase SDKs) |

## Notes

- **Tracking:** All declarations (GoDive and SDKs) set Tracking to No.
- **Analytics purpose items:** Sourced from Google Maps SDK and Firebase SDK telemetry, not from GoDive app code.
- **Email:** Not collected. Only the hashed `appleUserIdentifier` from Sign in with Apple is stored, not the email address.
- **Contacts:** Not collected. Contact data stays on-device in local SwiftData storage.
