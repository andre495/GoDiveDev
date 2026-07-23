# GoDive Access Control Policy (Phase 0)

**Branch:** `feature/owasp-secure-coding`  
**Status:** Phase 0 complete (policy freeze)  
**Parent plan:** `owasp_secure_coding_hardening_plan.md`  
**Architecture source of truth:** `hybrid_cloud_sync_boundaries.md`, `firebase_user_profiles.md`  
**OWASP mapping:** Access control policy + system configuration inventory ([LevelBlue / OWASP secure coding guide](https://www.levelblue.com/blogs/levelblue-blog/a-guide-to-owasps-secure-coding))

This document freezes **who may read/write what**, what is **in scope** for the OWASP hardening branch, and **Release gates** that must stay green. Client UI filters are a convenience layer; **authoritative AuthZ** for multi-user systems is CloudKit account isolation, Firestore/Storage rules, and Apple platform data protection.

### Cursor agent rules (keep in sync)

When this policy changes, update the matching **`.cursor/rules/`** files so future agent work stays aligned:

| Rule | Enforces |
|------|----------|
| **`godive-hybrid-trust-boundaries.mdc`** | CloudKit vs Firebase split; no dive data in Firebase; media bytes in Photos |
| **`godive-owner-scoped-data.mdc`** | `ownerProfileID` scoping; **`DiveUnownedClaimGate`** for orphan claims |
| **`godive-secrets-release-gates.mdc`** | Secrets, Release gates, logging privacy |
| **`godive-session-keychain.mdc`** | Keychain session / returning hints / Firebase UID; clear on sign-out/delete |
| **`godive-input-import-hardening.mdc`** | Sanitizers, FIT/UDDF caps, CDN HTTPS + path allowlist |
| **`firebase-rules-deploy.mdc`** | Deploy Firestore/Storage rules when `catalog-cdn/*.rules` change |

Add or extend rules as later OWASP phases land (import caps, crash scrubbing, etc.).

---

## 1. Identities

| Identity | Stable key | Used for |
|----------|------------|----------|
| Apple user | Sign in with Apple `user` / `appleUserIdentifier` | Dive-log account; local `UserProfile`; CloudKit private DB |
| Local profile | SwiftData `UserProfile.id` (UUID) | `ownerProfileID` on dives, buddies, trips, gear, etc. |
| Firebase Auth | Firebase UID | Social directory only (`users/{uid}`); **never** dive ownership |
| iCloud account | Apple ID / CloudKit container | Private CloudKit dive-log sync boundary |
| Device Photos | PhotoKit local + `PHCloudIdentifier` | Media bytes (not GoDive servers) |

**Rules**

- Dive-log ownership is **`ownerProfileID` → CloudKit `UserProfile`**, not Firebase UID.
- One signed-in Apple account ↔ one canonical local profile after identity merge (`UserProfileCloudKitIdentityMerge`).
- Buddy-to-buddy shared dive editing is **out of policy** until a separate CloudKit Sharing design exists.

---

## 2. Access matrix

### 2.1 On-device SwiftData

| Store | Contents | Who can read/write | Sync |
|-------|----------|--------------------|------|
| **User** (`GoDiveUser`) | Profiles, dives, buddies, media pointers/previews, sightings, equipment, certifications, trips, `UserDiveSite` / `UserMarineLife`, synced prefs | Process of the signed-in app user; UI and helpers **must** scope by `ownerProfileID` of the current profile | Private CloudKit |
| **Catalog** (`GoDiveCatalog`) | Bundled/CDN `MarineLife`, reference `DiveSite`, catalog metadata | App process (read/write for cache upsert); not user-private | Local only |
| **Diagnostics** (`GoDiveDiagnostics`) | `CrashReportRecord` | App process; user opts into upload | Local; optional public CloudKit upload |

**Client obligations**

- Prefer `#Predicate` / fetches filtered to the current `ownerProfileID`.
- Do not expose other profiles’ rows in Logbook, Home, Search, or export without an explicit product decision.
- **`claimUnowned*`** (orphan rows with nil owner) uses **`DiveUnownedClaimGate`**: claim only when no other profile already owns dives/buddies on the device (shared-device safe).

### 2.2 Apple CloudKit

| Database | Data | Access |
|----------|------|--------|
| **Private** `iCloud.PrimoSoftware.GoDiveMVP` | User store mirror (dive log) | Only the signed-in iCloud account’s devices |
| **Public** (crash uploader) | Opt-in crash reports | Anyone who can query public records **if** uploaded; payloads must be scrubbed (Phase 4) |

**Never** put full photo/video bytes or FIT/UDDF source files in CloudKit by default.

### 2.3 Firebase Auth + Firestore

| Path | Read | Write / delete |
|------|------|----------------|
| `users/{uid}` (public profile) | Any **authenticated** Firebase user | Owner only (`request.auth.uid == uid`) |
| `users/{uid}/private/{doc}` | Owner only | Owner only |
| `users/{uid}/sharedDives/{diveId}` | Owner or **active friend** | Owner only |
| `friendInvites/{token}` | Any authenticated (token must be known) | Creator create/revoke; redeeming user may mark redeemed |
| `friendships/{sortedPair}` | Members | Create via valid open invite; members may delete |
| All other paths | **Deny** | **Deny** |

**Public profile may include:** `displayName`, `handle` (reserved), `photoURL`, `interests`, `discoverable`, timestamps, `schemaVersion`.  
**Private only:** `appleUserIdentifier` (and future sensitive account linkage).

**Friend-visible dive projections** may include structured dive fields (site, depths, times, conditions, tags, sightings, capped depth track, etc.). **Notes** and **media preview URLs** are included only when the owner opts in (Settings). FIT/UDDF source files and full Photos library bytes must not appear in Firestore.

**Policy notes**

- The owner’s private CloudKit dive log remains source of truth; Firestore projections are a **friends-readable mirror**, not a second dive-log account.
- Soft-fail Firebase Auth must not invent Firestore write rights; local SIWA session alone does not authorize directory writes.

Rules file: `catalog-cdn/firestore.rules` (deploy via project Firebase workflow).

### 2.4 Firebase Storage

| Path | Read | Write / delete |
|------|------|----------------|
| `catalog/v1/**` | Public | **Deny** (CI/admin publish only) |
| `users/{uid}/**` (avatars + opt-in shared media previews) | Public (download URL / friends UI) | Owner only; ≤ 5 MB; `image/*` |
| Other paths | Default deny (unmatched) | Default deny |

Rules file: `catalog-cdn/storage.rules`.

**Never** upload FIT/UDDF originals or full-resolution Photos library assets. Opt-in friend media uses **preview JPEGs** only under `users/{uid}/sharedMedia/…`.

### 2.5 Catalog CDN (Firebase Hosting)

| Asset | Read | Write |
|-------|------|-------|
| Manifests + catalog JSON (HTTPS) | App clients; SHA-256 verified after download | GoDive publish pipeline only |
| Secrets | `CatalogCDNSecrets.plist` optional; HTTPS base URL only | Not in git |

Fail closed on checksum mismatch / non-HTTPS base URL (Phase 2/3 may harden redirects further).

### 2.6 Third-party APIs (client)

| Service | Credential location | Access intent |
|---------|---------------------|---------------|
| Google Maps | Bundled API key (bundle-ID restricted) | Map tiles / SDK only |
| Fishial | Bundled client id/secret (extractable) | Species ID; **Phase 3** aims to remove secret from IPA |
| PhotoKit / Contacts | System permission prompts | Least privilege; media bytes stay in Photos |

### 2.7 UserDefaults / Keychain (session-adjacent)

| Data | Current (Phase 0 baseline) | Target (Phase 1+) |
|------|----------------------------|-------------------|
| Restored profile UUID / returning-account hints | **Keychain** (`GoDiveKeychainStore`) | Done Phase 1 — UserDefaults migrate-once |
| Units, tank, renumber, UI prefs | UserDefaults / synced `UserPreferences` | Non-sensitive OK in UserDefaults |
| `shareCrashReports` | Local UserDefaults only | Remains local (not CloudKit-synced) |
| `shareSecurityEvents` | Local UserDefaults only | Remains local (not CloudKit-synced); journal rows sync privately |
| Cached Firebase UID | **Keychain** | Cleared on sign-out / account delete |

---

## 3. Business rules (authorization criteria)

1. **Signed out:** No dive-log UI over owner data; no Firebase directory writes; catalogs may still load offline from bundle/cache.
2. **Signed in (SIWA):** Full dive-log CRUD for **own** `ownerProfileID` rows; CloudKit private sync for that iCloud account.
3. **Firebase linked:** May upsert own `users/{uid}` and avatar; may read other users’ **public** profiles when authenticated.
4. **Account delete:** Must revoke Apple token (when required), delete Firebase Auth user + Firestore/Storage owner docs, wipe local user store (CloudKit mirrors), clear session/hints, sign out.
5. **Deny by default** on Firestore/Storage for undeclared paths.
6. If security configuration cannot be loaded (e.g. missing Firebase rules in production), **do not** open broader client-side access — fail soft on social features, keep dive log local/CloudKit.

---

## 4. Branch scope freeze (`feature/owasp-secure-coding`)

### In scope

| Phase | Work |
|-------|------|
| **0** | This policy, scope freeze, Release gates (docs) |
| **1** | Keychain session restore; sign-out/delete clears secrets; tighten `claimUnowned*`; ownership fetch audit; generic auth errors / privacy-aware logging |
| **2** | Centralized input sanitizers; FIT/UDDF size/time/schema caps; CDN URL/redirect hardening; UDDF XML risk review |
| **3** | Secrets inventory/docs; ATS gate; Fishial memory-only token + rate limit; no secret logging (proxy / App Check / pinning = follow-up) |
| **4** | Crash scrub + backup exclusion + Release gates helper + Firestore/Storage **review notes** (**done** — no rule deploy) |
| **5** | Logging policy + **`GoDiveSecurityEvent`** + generic user-facing errors (**done**) |
| **6** | Output-encoding audit (Markdown/export/WebView analogs) |

### Out of scope (unless explicitly re-scoped)

- Full Fishial **backend proxy** / App Check (may start design in Phase 3; shipping proxy can be a follow-up PR)
- TLS certificate pinning (optional later; ops cost)
- Handle uniqueness / directory search (product); App Check when friends abuse appears
- CloudKit Sharing / multi-user dive editing
- Jailbreak detection, binary obfuscation, ASVS Level 2 certification
- Replacing CloudKit or Firebase
- Antivirus scanning of PhotoKit assets
- Merging stashed Top Sites / performance WIP onto this branch

### Phase 3 stance

**Shipped (client hygiene):** secret inventory + handling doc; Maps/Fishial **`.example`** templates; ATS defaults enforced via **`AppTransportSecurityPolicy`**; Fishial bearer **memory-only** + client recognize rate limit; no token/`Authorization` logging (**`GoDiveSecretLogging`**); CDN SHA-256 remains fail-closed.

**Follow-up (not blocking Phase 4+):** Fishial Cloud Function proxy (remove client secret from IPA), Firebase App Check, TLS pinning, signed CDN manifests. Tracked in **`cursor/todo.md`**.

### Phase 4 stance

**Shipped:** CloudKit crash upload scrubbing; diagnostics backup exclusion; documented Data Protection default; Release gate helpers; trip-share temp URL policy; Firestore/Storage review without rule deploy (friends-only deferred).

---

## 5. Release gates checklist

Ship / Archive / TestFlight Release builds must satisfy:

| # | Gate | How to verify |
|---|------|----------------|
| R1 | Mock launch seeding **off** | `MockDataSeeding.isLaunchSeedingEnabled == false` |
| R2 | UITest root **inert** without launch flag | `GoDiveUITestConfiguration.isActive` only via `-GoDiveUITest` / env; production `ContentView` path when inactive |
| R3 | No ATS exceptions without review | `Info.plist` has no `NSAppTransportSecurity` allow-arbitrary-loads (or documented exception) |
| R4 | Secret plists not committed | `.gitignore` covers Maps / Fishial / CDN / `GoogleService-Info.plist`; only `.example` templates in git |
| R5 | DEBUG-only verbose paths | Fishial/Maps force args and verbose `*Debug` loggers do not change Release security posture |
| R6 | Hybrid boundaries | No dive-log models written to Firestore/Storage from app code |
| R7 | Crash share default | Sharing remains **opt-in**; uploads scrubbed via **`CrashReportPayloadScrubber`** |
| R8 | Firebase rules deployed when changed | Follow `.cursor/rules/firebase-rules-deploy.mdc` |

Phase 4/5 may add automated tests that fail CI/local preflight if R1–R2 regress.

---

## 6. System configuration inventory (assets)

| Component | Location / id |
|-----------|----------------|
| iOS app | `PrimoSoftware.GoDiveMVP` |
| CloudKit container | `iCloud.PrimoSoftware.GoDiveMVP` |
| Firebase project | `godive-1cff8` |
| Firestore rules | `catalog-cdn/firestore.rules` |
| Storage rules | `catalog-cdn/storage.rules` |
| Entitlements | `GoDiveMVP.entitlements` (SIWA + iCloud) |
| Client configs (gitignored) | `Config/GoogleMapsSecrets.plist`, `FishialSecrets.plist`, `CatalogCDNSecrets.plist`, `GoogleService-Info.plist` |

---

## 7. Phase 0 exit criteria

- [x] Access control matrix documented (this file §§1–3)
- [x] In-scope / out-of-scope frozen (§4)
- [x] Release gates checklist frozen (§5)
- [x] Linked from `owasp_secure_coding_hardening_plan.md`

**Next:** Phase 1 — Keychain session + ownership hardening.
