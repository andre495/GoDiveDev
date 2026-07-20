# Secrets & communication handling (Phase 3)

**Branch:** `feature/owasp-secure-coding`  
**Parent plan:** `owasp_secure_coding_hardening_plan.md`  
**Policy:** `owasp_access_control_policy.md`  
**Agent rule:** `.cursor/rules/godive-secrets-release-gates.mdc`

Anything shipped inside the IPA can be extracted. Prefer **restricted keys**, **short-lived tokens**, and **server-side secrets** over long-lived client secrets.

---

## Inventory

| Secret / config | Location | Treat as | Restriction / notes |
|-----------------|----------|----------|---------------------|
| Google Maps SDK key | `Config/GoogleMapsSecrets.plist` (gitignored); template `GoogleMapsSecrets.example.plist` | Extractable API key | Google Cloud → restrict to **iOS apps** + bundle **`PrimoSoftware.GoDiveMVP`**; enable **Maps SDK for iOS** (+ **Maps Static API** if trip share snapshots use it) |
| Fishial Client ID + **Client Secret** | `Config/FishialSecrets.plist` (gitignored); template `FishialSecrets.example.plist` | **High risk** — secret is in the IPA today | Portal key hygiene + rate limits; **never log** tokens / Authorization. **Follow-up:** Cloud Function / App Check proxy so the secret leaves the client |
| Firebase `GoogleService-Info.plist` | gitignored; template `GoogleService-Info.example.plist` | **Expected client config** (not a vault secret) | Still gitignored; restrict the Firebase iOS API key per `firebase_user_profiles.md` |
| Catalog CDN base URL | `CatalogCDNSecrets.plist` | Non-secret endpoint | HTTPS only; path allowlist + SHA-256 fail-closed (Phase 2) |
| SIWA / Firebase session ids | Keychain (Phase 1) | Sensitive identifiers | Clear on sign-out / delete |

---

## Do / do not

### Do

- Commit only **`.example.plist`** templates with `YOUR_*` placeholders.
- Log auth/network failures with **`Logger`** and **`.private`** (or omit) for UIDs, names, paths that can identify users.
- Keep **ATS defaults** — no `NSAppTransportSecurity` / `NSAllowsArbitraryLoads` without a written exception in this doc + Release gate R3.
- Keep CDN **SHA-256 fail-closed** (`CatalogCDNRefresh` → `.skippedChecksumMismatch`).

### Do not

- Log Apple identity tokens, Firebase ID tokens, Fishial bearer tokens, `Authorization` headers, or client secrets.
- Commit real Maps / Fishial / Firebase plists.
- Add TLS **certificate pinning** until a proxy exists and pin rotation is operationally safe.
- Assume Firebase App Check is required before social abuse is a real threat — enable later when directory abuse appears.

---

## Fishial proxy (follow-up)

**Goal:** Remove `ClientSecret` from the IPA.

**Sketch:** App Check–attested (or SIWA-backed) Cloud Function holds the Fishial secret, returns a short-lived recognition token or proxies `/v2/recognize`. Client keeps only a non-secret config (function URL). Until then, in-app bearer cache stays **memory-only** (`FishialAPIClient`) with a **client-side recognize rate limit**.

---

## Firebase App Check (follow-up)

Add SPM **`FirebaseAppCheck`** + DeviceCheck/App Attest when friends/directory abuse or Fishial proxy needs attestation. Not required for Phase 3 exit.

---

## Signed CDN manifests (follow-up)

Checksums already fail closed. Optional later: Ed25519 / CMS-signed manifests for stronger publisher authenticity.
