# OWASP secure coding — GoDive hardening plan

**Branch:** `feature/owasp-secure-coding` (from `main`)  
**Reference:** [A guide to OWASP's secure coding (LevelBlue)](https://www.levelblue.com/blogs/levelblue-blog/a-guide-to-owasps-secure-coding)  
**Related docs:** `owasp_access_control_policy.md` (Phase 0), `hybrid_cloud_sync_boundaries.md`, `firebase_user_profiles.md`, `catalog_cdn_publish.md`

This plan adapts the OWASP secure-coding checklist (web-oriented in the article) to GoDive’s real stack: **iOS SwiftUI / SwiftData**, **Sign in with Apple**, **private CloudKit dive log**, **Firebase Auth + Firestore/Storage (social)**, **catalog CDN**, **FIT/UDDF import**, **PhotoKit media refs**, **Fishial / Maps** client APIs.

Work lands on this branch in **phased PRs**. Prefer smallest correct controls + tests over large rewrites. Do **not** mix unrelated product features into this branch.

---

## Principles (GoDive-specific)

1. **Trust boundaries stay hybrid:** dive log / media bytes stay on-device + private CloudKit; Firebase is directory/social only (`hybrid_cloud_sync_boundaries.md`).
2. **Client is hostile:** any AuthZ that matters for other users must live in **Firestore/Storage rules** (and Apple/CloudKit account isolation), not UI filters alone.
3. **Secrets in the IPA are extractable:** prefer backend proxies / restricted API keys / short-lived tokens over long-lived client secrets.
4. **Fail closed** for security config (missing rules, bad CDN URL, unsigned catalog) — soft-fail only where product already documents offline-first (e.g. SIWA credential check when offline).
5. **Release must not enable** UITest roots, mock launch seeding, or debug-only map/force flags.

**Agent enforcement:** Phase 0–2 policy is encoded in Cursor rules — **`godive-hybrid-trust-boundaries.mdc`**, **`godive-owner-scoped-data.mdc`**, **`godive-secrets-release-gates.mdc`**, **`godive-session-keychain.mdc`**, **`godive-input-import-hardening.mdc`**. Extend those rules when later phases ship new controls.

---

## Current hotspot inventory (baseline)

| Area | Status / risk |
|------|----------------|
| SIWA + `AccountSession` | Solid gate; session restore uses **UserDefaults** profile UUID (not Keychain) |
| Ownership | UI `@Query` by `ownerProfileID`; **`claimUnowned*`** can adopt orphan rows on shared devices |
| Secrets | Maps / Fishial / Firebase plists gitignored but **bundled**; Fishial **client secret** in app |
| Network | HTTPS + ATS default; **no pinning**; CDN has SHA-256 after fetch |
| Firestore/Storage | Auth users can **read** directory profiles; avatars **world-readable** |
| Import | Security-scoped FIT/UDDF; need stricter size/time/schema guards |
| Logging | Some `.public` Firebase UID; SIWA `print`; opt-in crash → **public** CloudKit |
| Debug | UITest launch args / DEBUG seed — keep Release-safe |

---

## Phase map (OWASP category → GoDive work)

### Phase 0 — Threat model & policy (docs only) ✅

**OWASP:** Access control policy, system configuration inventory.

- [x] Write a short **Access Control Policy** — see **`owasp_access_control_policy.md`** (SwiftData / CloudKit / Firestore / Storage / CDN matrix).
- [x] Freeze **in-scope / out-of-scope** for this branch (§4 of the policy doc).
- [x] Checklist of **Release gates** (§5 of the policy doc).

**Exit:** Policy reviewed; no app code required. **Done 2026-07-18.**

---

### Phase 1 — AuthN, session, access control (high priority) ✅

**OWASP:** Authentication & password management, Session management, Access control.

| Item | Action |
|------|--------|
| Session storage | **Done** — profile id, returning hints, Firebase UID in **`GoDiveKeychainStore`** (UserDefaults migrate-once) |
| Sign-out / delete | **Done** — clears Keychain session + Firebase UID; delete also clears returning hints |
| Unowned claim | **Done** — **`DiveUnownedClaimGate`** skips when another profile owns rows |
| Owner predicates | **Done** — `activities` / `buddies` use `#Predicate` by `ownerProfileID` |
| Auth errors | **Done** — privacy-aware `Logger`; generic failure string; Firebase fail message scrubbed |
| Firebase Auth | **Confirmed** — Firestore upsert requires `Auth.auth().currentUser` |

**Exit:** Keychain session restore; safer unowned claim; tests. **Done 2026-07-18.** Cursor rule: **`godive-session-keychain.mdc`**.

---

### Phase 2 — Input validation & import hardening ✅

**OWASP:** Input validation, File management (partial), Database security (client store).

| Item | Status |
|------|--------|
| Central validators | **Done** — **`GoDiveInputSanitization`** / **`DiveNotesValidation`**; site / display / DAN / buddy / notes |
| FIT/UDDF caps | **Done** — **`DiveFileImportLimits`** (100 MB, uncapped dive count, 50k samples/dive, **600 s** parse+build deadline with XML abort); content magic / `<uddf` |
| File types | **Done** — UTType allow-list + post-pick content validation |
| CDN URLs | **Done** — HTTPS-only base; **`catalog/v1/`** path allowlist; same-host HTTPS redirects; response size cap |
| XML (UDDF) | **Done** — `shouldResolveExternalEntities = false`; reject DOCTYPE/ENTITY prefix |

**Exit:** Import size/time limits + validation unit tests. **Done 2026-07-18.** Cursor rule: **`godive-input-import-hardening.mdc`**.

---

### Phase 3 — Secrets, crypto, communication

**OWASP:** Cryptographic practices, Communication security, Data protection (transit).

| Item | Action |
|------|--------|
| Fishial | **Done (client):** memory-only bearer; never log tokens; **`minimumRecognizeInterval`**; secret remains in-IPA until proxy. **Follow-up:** Cloud Function / App Check proxy |
| Maps | **Done (docs):** restrict key to iOS + **`PrimoSoftware.GoDiveMVP`**; example plist; rotate if ever committed |
| Firebase | **Done (docs):** `GoogleService-Info` = expected client config; App Check deferred until social abuse / proxy |
| TLS | **Done** — ATS defaults; **`AppTransportSecurityPolicy`** + Info.plist gate test; no arbitrary HTTP |
| Pinning | Deferred — ops cost; only after proxy |
| CDN integrity | **Confirmed** — SHA-256 fail-closed (`.skippedChecksumMismatch`); signed manifests follow-up |
| Logging | **Done** — **`GoDiveSecretLogging`**; Firebase / social sync failures use `.private` |

**Exit:** Documented secret handling (**`owasp_secrets_handling.md`**); Fishial proxy planned as follow-up; no new plaintext secrets in repo. **Done 2026-07-18.** Cursor rule: **`godive-secrets-release-gates.mdc`**.

---

### Phase 4 — Data protection at rest & least privilege

**OWASP:** Data protection, Database security, System configuration.

| Item | Action |
|------|--------|
| SwiftData | **Done (docs)** — container default Complete-Until-First-Auth; do not lower (`GoDiveDataProtectionPolicy`) |
| Diagnostics backup | **Done** — exclude `cloudkit-open-diagnostics.txt` + diagnostics store family (`GoDiveFileBackupPolicy`) |
| Crash reports | **Done** — **`CrashReportPayloadScrubber`** on CloudKit upload; share default **off** (R7) |
| Temp files | **Done** — trip share under temp + cleanup; **`TripShareTempFilePolicy`** |
| Firestore / Storage | **Reviewed** — **`owasp_phase4_firestore_storage_review.md`** (no deploy; friends-only deferred) |
| Debug / Release gates | **Done** — **`GoDiveReleaseConfigurationGates`** (R1/R2/R7) |

**Exit:** Crash scrubbing; backup/exclusion policy; rules review notes. **Done 2026-07-18.**

---

### Phase 5 — Logging, errors, memory/resources

**OWASP:** Error handling & logging, Memory management.

| Item | Action |
|------|--------|
| Logging policy | **Done** — privacy-aware Logger; **`HomeMediaCarouselDebug`** DEBUG-only; launch maintenance uses Logger not `print` |
| Security events | **Done** — **`GoDiveSecurityEvent`** + user-store **`SecurityEventRecord`** journal (private CloudKit); opt-in scrubbed public share |
| User-facing errors | **Done** — **`GoDiveUserFacingError`**; account deletion / unexpected import no longer surface `String(describing:)` |
| Resources | **Confirmed** — FIT/UDDF cancel + rollback already covered; CDN ephemeral timeouts; no new unbounded decode buffers |

**Exit:** Logging audit pass + security-event helper. **Done 2026-07-18.** Cursor rule: **`godive-security-logging.mdc`**.

---

### Phase 6 — Output encoding & “XSS-class” (mobile analogs)

**OWASP:** Output encoding.

| Item | Action |
|------|--------|
| Attributed / Markdown | **Done** — no Markdown/HTML sinks; Fishial name uses **`Text(verbatim:)`** / **`GoDivePlainText`** |
| Share / export | **Confirmed** — plain text / PNG only; no UDDF/CSV writers; trip share UUID filenames |
| Remote URLs | **Done** — **`GoDiveRemoteURLPolicy`** gates AsyncImage + Storage/CDN downloads |
| WebView | **Confirmed absent** — rule forbids `loadHTMLString` of user content without review |

**Exit:** Audit complete (**`cursor/owasp_phase6_output_encoding_audit.md`**). **Done 2026-07-18.** Cursor rule: **`godive-output-encoding.mdc`**.

---

## Suggested implementation order

```text
Phase 0 (policy)
  → Phase 1 (session Keychain + ownership)
  → Phase 2 (import/validation)
  → Phase 3 (secrets docs + ATS + Fishial hygiene; proxy follow-up)
  → Phase 4 (crash scrub + Release gates)
  → Phase 5 (logging)
  → Phase 6 (encoding audit)
```

---

## Testing expectations

Per repo rules: each phase adds/updates **`GoDiveMVPTests`** (prefer unit) for:

- Keychain restore / clear on sign-out  
- `claimUnowned` policy  
- Import reject oversize / timeout  
- CDN checksum fail closed  
- Secret redaction / ATS Info.plist defaults / Fishial recognize interval  
- Crash payload scrubbing  
- Release configuration flags (seed / UITest)

Run **`xcodebuild`** only when asked to test/commit/push.

---

## Explicit non-goals (this branch unless re-scoped)

- Full OWASP ASVS Level 2 certification  
- Jailbreak detection / binary obfuscation  
- Replacing CloudKit or Firebase wholesale  
- Antivirus scan of every PhotoKit asset (rely on iOS + allow-listed imports)  
- Shipping the stashed Top Sites / performance WIP (separate branch/commit)

---

## Ops notes

- **Stash:** `stash@{0}: wip before owasp security branch` holds prior main WIP (Top Sites + perf). Restore with `git checkout main && git stash pop` when ready — do not mix into this branch.  
- **Firebase rules:** editing `catalog-cdn/firestore.rules` / `storage.rules` requires deploy per `.cursor/rules/firebase-rules-deploy.mdc`.  
- **Changelog:** append meaningful hardening to the open section when code ships; keep this plan doc updated as phases complete.

---

## Decision log (fill as we go)

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-07-18 | Branch `feature/owasp-secure-coding` from `main` | Isolate OWASP hardening from product WIP |
| 2026-07-18 | Phase 0: publish `owasp_access_control_policy.md` | Freeze AuthZ matrix, branch scope, Release gates before code changes |
| 2026-07-18 | Friends-only Firestore reads deferred | Product change; not required for Phases 1–2 |
| 2026-07-18 | Encode Phase 0 policy as Cursor rules | Hybrid boundaries, owner scoping, secrets/Release gates always guide agents |
| 2026-07-18 | Phase 1: Keychain + `DiveUnownedClaimGate` | Shared-device-safe orphan claims; session ids leave UserDefaults |
| 2026-07-18 | Cursor rule `godive-session-keychain.mdc` | Agents keep session identifiers off UserDefaults |
| 2026-07-18 | Phase 2: import/CDN/input caps | `DiveFileImportLimits`, HTTPS CDN paths, sanitization |
| 2026-07-18 | Cursor rule `godive-input-import-hardening.mdc` | Agents keep import/CDN validation fail-closed |
| 2026-07-18 | Phase 3: secrets hygiene without Fishial proxy | Docs + ATS gate + in-memory Fishial token + rate limit; proxy/App Check/pinning follow-up |
| 2026-07-18 | Publish `owasp_secrets_handling.md` | Inventory + do/don’t for Maps/Fishial/Firebase/CDN |
| 2026-07-18 | Defer Fishial proxy / App Check / pinning / signed CDN | Track in `todo.md`; do not block Phase 4 |
| 2026-07-18 | Phase 4: crash scrub + backup exclusion + rules review | CloudKit upload scrubber; diagnostics excluded from backup; no Firestore deploy |
| 2026-07-18 | Phase 5: security events + generic user errors | `GoDiveSecurityEvent`, `GoDiveUserFacingError`; DEBUG-only carousel verbose logs |
| 2026-07-18 | Phase 5+: security journal + opt-in share | `SecurityEventRecord` / Settings Diagnostic Events; `shareSecurityEvents` public CloudKit |
| 2026-07-18 | Phase 6: output encoding audit + fixes | Plain-text Fishial label; remote URL policy; UUID trip-share names; audit note |
