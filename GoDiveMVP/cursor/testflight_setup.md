# TestFlight setup (GoDive)

Reference for putting **GoDive** (`PrimoSoftware.GoDiveMVP`) on Apple **TestFlight**. This is distribution prep — not App Store public release (same upload path; store listing / review come later).

Related:

- Release gates — **`owasp_access_control_policy.md`** §5, **`.cursor/rules/godive-secrets-release-gates.mdc`**
- Push (APNs / FCM) — **`friend_invite_push_notifications.md`**, **`buddy_activity_push_notifications.md`**
- Secrets — **`owasp_secrets_handling.md`**
- Hybrid boundaries — **`hybrid_cloud_sync_boundaries.md`**

---

## Identifiers (quick reference)

| Item | Value |
|------|--------|
| Bundle ID | `PrimoSoftware.GoDiveMVP` |
| CloudKit container | `iCloud.PrimoSoftware.GoDiveMVP` |
| Firebase project | `godive-1cff8` |
| Friend invite links | `https://links.godiveios.com/invite/{token}` |
| Dre’s Phone (dev install) | `platform=iOS,id=00008130-001241C118A1401C` — local **Run**, not TestFlight |

---

## 1. Apple Developer + App Store Connect (one-time)

1. **Apple Developer Program** membership active for the team that owns the app.
2. **Certificates, Identifiers & Profiles**
   - App ID **`PrimoSoftware.GoDiveMVP`** exists with capabilities used in production: **Sign in with Apple**, **iCloud** (CloudKit container above), **Push Notifications**, **Associated Domains** (invite Universal Links), etc.
3. **[App Store Connect](https://appstoreconnect.apple.com)**
   - Create the app record if missing (same bundle ID).
   - Complete **App Information** (name, primary language, category, privacy policy URL when ready).
   - Accept **Agreements, Tax, and Banking** (required before external TestFlight / App Store distribution).
4. **Users and Access** — add Internal testers as App Store Connect users (roles that can access TestFlight).

---

## 2. Machine prep before Archive

Archive on a Mac with a full Xcode install and the **Release** signing team configured.

### Signing (Xcode)

1. Target **GoDiveMVP** → **Signing & Capabilities**.
2. Select the correct **Team**.
3. Prefer **Automatically manage signing** for App Store / TestFlight (Distribution certificate + profile).
4. Confirm **Push Notifications** and other capabilities match entitlements (`GoDiveMVP.entitlements`).

### Gitignored secrets (must be on disk for the archive)

These are **not** in git. Missing files soft-fail features or break social/maps/identify in the TestFlight build:

| File | Purpose |
|------|---------|
| `GoDiveMVP/Config/GoogleService-Info.plist` | Firebase |
| `GoDiveMVP/Config/GoogleMapsSecrets.plist` | Google Maps SDK |
| `GoDiveMVP/Config/FishialSecrets.plist` | Fishial identify |
| `GoDiveMVP/Config/CatalogCDNSecrets.plist` | Catalog CDN base / checksums |

Only **`.example`** templates are committed. Restrict Maps / API keys to this iOS bundle ID in the vendor consoles.

### Release gates (verify before Archive)

| Gate | Expectation |
|------|-------------|
| Mock launch seeding | `MockDataSeeding.isLaunchSeedingEnabled == false` |
| UITest root | Only via `-GoDiveUITest` / env — production path otherwise |
| ATS | No undocumented `NSAllowsArbitraryLoads` |
| Secrets | Secret plists gitignored; never commit real keys |
| Hybrid | No dive-log models written to Firestore / Firebase Storage |
| Crash share | Opt-in only; scrubbed uploads |
| Firebase rules | Deployed if rules changed (`firebase-rules-deploy.mdc`) |

Full checklist: **`owasp_access_control_policy.md`** §5.

### Push (if testers should get notifications)

TestFlight / App Store builds use **production APNs**.

1. Apple Developer → **Keys** → APNs Auth Key (`.p8`); note Key ID + Team ID.
2. Firebase Console → **`godive-1cff8`** → Project settings → **Cloud Messaging** → Apple app → upload the key.
3. Confirm Push Notifications capability on the target.

---

## 3. Archive and upload

### Xcode UI (usual path)

1. Scheme **GoDiveMVP**, destination **Any iOS Device (arm64)** — not a simulator.
2. **Product → Archive**.
3. Organizer → select archive → **Distribute App** → **App Store Connect** → **Upload**.
4. Wait for processing in App Store Connect (email / build status). Processing can take several minutes to an hour.

### Notes

- First upload may prompt for encryption / export compliance answers in App Store Connect after the build appears.
- Uploading a build does **not** by itself invite testers — configure TestFlight next.

---

## 4. TestFlight configuration

In App Store Connect → app → **TestFlight**:

1. Select the processed build.
2. Answer **Export Compliance** (and any missing compliance questions). Most apps that only use standard HTTPS/TLS choose the standard “uses encryption / exempt” path — confirm if unsure.
3. Add **What to Test** notes (known issues, Sign in with Apple, iCloud required for dive sync, etc.).
4. **Internal testing**
   - Group includes App Store Connect team members.
   - No Beta App Review.
   - Fastest path for you / Dre via TestFlight app.
5. **External testing**
   - Create an external group; add emails or enable a public link.
   - First external build typically needs **Beta App Review**.
   - Provide demo / SIWA instructions for reviewers if needed.
6. Testers install **TestFlight** from the App Store, accept the invite, install **GoDive**.

### Internal vs external

| | Internal | External |
|---|----------|----------|
| Who | ASC team roles | Anyone with invite / public link |
| Limit | Up to 100 | Up to 10,000 |
| Review | None | Beta App Review (first / when required) |
| Best for | Smoke + day-to-day | Friends / wider beta |

---

## 5. What to smoke-test on a TestFlight build

- Cold launch → Sign in with Apple → Home / Logbook not empty if dives exist on device / CloudKit.
- iCloud signed in (private CloudKit dive sync).
- Friends invite link / QR (Universal Links).
- Buddy Feed + like/comment if social is in scope for the build.
- Push: invite accepted / buddy activity (requires APNs key in Firebase).
- Maps / Fishial only if secret plists were present at archive time.
- Crash Reports sharing stays **off** unless a tester opts in.

---

## 6. Suggested sequence

1. App record + agreements in App Store Connect.
2. Confirm signing, secrets on disk, release gates, APNs in Firebase.
3. Archive → Upload.
4. Internal TestFlight first.
5. External group + Beta Review when outsiders should install.
6. Later: full App Store listing, screenshots, privacy nutrition labels, App Review for public release.

---

## 7. Common pitfalls

| Symptom | Likely cause |
|---------|----------------|
| Build missing in TestFlight | Still processing, or upload failed |
| Social / Firebase broken | Missing `GoogleService-Info.plist` in the archive machine’s tree |
| Maps / Fishial missing | Missing Maps / Fishial secret plists at archive |
| Pushes never arrive | APNs key not in Firebase, or Push capability missing; TestFlight uses **production** APNs |
| Empty dive log after install | Fresh install + no CloudKit restore yet, or tester not signed into iCloud / SIWA |
| External testers stuck | Beta App Review not submitted / not approved; agreements incomplete |
| Mock / UITest shell in Release | Release gate regression — do not ship with launch seeding or UITest root active |

---

## 8. Out of scope for this doc

- Public **App Store** marketing screenshots, age rating questionnaire, and final App Review.
- Automating CI upload (`xcodebuild archive` + `altool` / Transporter / Fastlane) — same gates apply if you add that later.
- Local device install via **`devicectl`** / Xcode Run (see **`.cursor/rules/xcode-run-dres-phone.mdc`**) — different from TestFlight.
