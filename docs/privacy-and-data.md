# Privacy Policy

**Last updated:** July 18, 2026  
**Applies to:** the GoDive website ([godiveios.com](https://godiveios.com)) and the GoDive iOS app  
**Operator:** Primo Software (“we,” “us,” or “our”)

This Privacy Policy explains what information we collect, how we use it, and the choices you have. GoDive is built as a **local-first** dive log: your dive data is meant to stay under **your** control on your iPhone (and, when you use iCloud, across **your** Apple devices via Apple CloudKit). We do not run a GoDive-operated dive-log backup server.

If you have questions, contact us through [godiveios.com](https://godiveios.com).

---

## 1. Scope

This policy covers:

- **Website** — browsing [godiveios.com](https://godiveios.com) and joining the launch waitlist  
- **GoDive iOS app** — Sign in with Apple, dive logging, media, maps, optional catalog refresh, optional fish identification, optional crash reporting, and optional diagnostic-event sharing  

It does **not** cover third-party websites or services you open from links (for example Fishial, Google, Apple, Wix, or Firebase), which have their own policies.

This page is the **single** Privacy Policy for the website and the app (also published in the GoDive user guide).

---

## 2. Website and waitlist

### What we collect

If you join the waitlist, we collect the **email address** you submit (and any other fields you choose to fill in on that form).

We may also receive standard website technical data from our hosting provider (**Wix**), such as approximate location derived from IP, browser type, device type, pages viewed, and similar analytics or security logs, depending on how the site is configured.

### How we use it

- To notify you when GoDive becomes available  
- To send occasional launch-related updates about GoDive  
- To operate, secure, and improve the website  

We do **not** sell waitlist emails. We do **not** use them for unrelated marketing lists.

### Who processes it

Waitlist submissions are collected and stored through **Wix** (our website platform). Wix processes that data on our behalf under their terms and privacy practices.

### Your choices

You can ask us to remove your email from the waitlist by contacting us through [godiveios.com](https://godiveios.com). You can also unsubscribe from any future email using the unsubscribe link if we provide one.

---

## 3. The GoDive iOS app

GoDive stores your dive log primarily **on your device**. In the current product:

- There is **no** GoDive-operated cloud account that stores your full dive log on our servers  
- When you are signed into **iCloud**, your dive log and related structured data can sync across **your** Apple devices using Apple’s **private CloudKit** database (your iCloud account — not a GoDive public feed)  
- There is **no** public dive feed for the whole internet  
- You can **connect with friends** via QR code or invite link (Profile → menu → Friends). When you share dives with friends (on by default once you have friends), a **friend-visible copy** of dive details is stored in **Firebase** so they can read them. **Notes** and **photo previews** stay private unless you turn those Settings on. Your private CloudKit log remains the source of truth on your devices  
- A lightweight **social directory** profile (display name, optional photo, activity interests) is stored in **Firebase** for friends features  
- We do **not** sell your dive log or share it with third parties for advertising  

Most of the app works **offline** after install. Some optional features use the network (described below).

---

## 4. Information stored on your device

Depending on how you use the app, GoDive may store locally:

- Dive logs and import metadata (**not** the original `.fit` / `.uddf` files after import)  
- Depth/profile chart samples (stored on this device for charts; the full depth track also syncs with each dive through your private CloudKit as a compact blob, not as hundreds of thousands of separate records)  
- Dive sites (reference catalog cache and sites you add or snapshot)  
- Buddy roster, trips, tags, and equipment  
- Certifications and profile display name (and optional profile photo)  
- References to items in your Photos library (device-local identifiers, cross-device Photos cloud identifiers, and optional small preview JPEGs)  
- Marine life catalog data and your tagged sightings  
- App settings (units, defaults, preferences)  
- Crash reports (technical diagnostics; see below)  
- Diagnostic events (short security-related journal entries; see below)  

Deleting the app (or clearing its data) removes this local storage from that device, subject to how iOS manages app data. Data that previously synced via your private CloudKit may still exist in **your** iCloud until Apple finishes mirroring deletes or you clear iCloud data for the app.

---

## 5. Sign in with Apple

GoDive uses **Sign in with Apple** to associate your local profile with your Apple ID on that device. We do not run a separate username/password system.

Apple may provide a stable identifier for your Apple ID and, if you choose, a name and/or email relay address under Apple’s Sign in with Apple rules. That information is used to keep your session and local profile tied to you on the device. Session identifiers are stored in the iOS **Keychain** and are cleared when you sign out or delete your account.

Signing out ends the active session. Local dive data for that profile remains on the device until you delete the app, its data, or your account.

### Social directory and friends (Firebase)

When Sign in with Apple succeeds (and Firebase is configured in the build), GoDive may create or update a **social directory** profile: display name, activity interests (scuba / free diving / snorkeling), and an optional profile photo. For new accounts, GoDive typically waits until you finish the profile photo step (upload or skip) before writing that directory entry.

**Friends:** you connect via QR code or invite link (not a public browseable directory). When **Share dives with friends** is on, GoDive mirrors **friend-visible dive details** to Firebase so accepted friends can read them, and updates those copies when you edit shared dive fields. **Notes** and **photo previews** are included only if you enable those Settings. Your private CloudKit / on-device log remains the source of truth. Deleting your account removes friendships, invites, and shared projections.

If you allow notifications, GoDive may store an **FCM device token** under your Firebase user (owner-only) so we can alert you when someone accepts your friend invite. Tokens are removed on sign-out from this device.

Your **featured Profile header media** (tagged photo or video) may be uploaded to Firebase so friends can see it on your friend profile page.

### Delete account

**Settings → Delete account** permanently removes your GoDive account after confirmation and a second Sign in with Apple. That process:

- Revokes Sign in with Apple for GoDive and deletes the Firebase Auth user (when Firebase is configured)  
- Deletes your Firebase social directory, friendships, invites, and friend-visible dive projections (and opt-in shared media previews)  
- Deletes your on-device dive log and related user data (including the diagnostic-events journal for your account); private CloudKit sync mirrors those deletes when enabled  
- Clears Keychain session identifiers and signs you out  

Catalog reference data that ships with the app may remain on the device. Local crash reports live in a separate diagnostics store — clear them under **Settings → Crash Reports** if you want them removed.

---

## 6. Photos

If you grant Photos access:

- GoDive can attach photos and videos to dives and optionally auto-match library items whose capture time falls within a dive window  
- The app stores **references** to library assets (and may store small preview JPEGs for faster display), not a full copy of your camera roll  
- Full-resolution media loads on demand for viewing, export, or optional identification  
- With iCloud Photos, GoDive syncs a pointer (and small preview) with your dive log so media can remap on each of your devices  

GoDive does **not** bulk-upload your entire Photos library. If you delete an original from Photos, GoDive removes the stale reference when it detects it.

You can revoke Photos access in **iOS Settings → Privacy & Security → Photos**. Features that need Photos will stop working until access is restored.

---

## 7. Contacts

Contacts access is optional. If you link a dive buddy to a contact, GoDive may read that contact’s name and photo to display and keep the buddy avatar in sync. Contact data is stored locally for that purpose and is **not** uploaded to a GoDive dive-log server.

You can revoke Contacts access in **iOS Settings → Privacy & Security → Contacts**.

---

## 8. When the app uses the network

Most of GoDive works offline after install. The app may use the network only for the features below.

### Maps

Explore, dive maps, and the site picker may request map tiles and limited geocoding through **Apple MapKit** and/or **Google Maps**, depending on the build. Basic map display uses map providers’ tile services. It does **not** sign you into Google with your personal Google account or upload your dive log contents for advertising. See Apple’s and Google’s privacy materials for how their map services process requests.

### Fish ID (Fishial)

If this feature is available in your build, identification is **user-initiated**. When you run **Identify** after cropping a fish image, the app may send one cropped JPEG still per request, and may include optional dive coordinates in a request header. There is no background batch upload of your Photos library. Requests are rate-limited on device. Species suggestions come from Fishial’s service; you confirm before a tag is saved. Use of that feature is also subject to [Fishial’s terms and privacy practices](https://docs.fishial.ai/api).

A future update may move Fishial authentication behind a GoDive server so recognition secrets are not shipped inside the app; that change is not required for current use.

### Catalog CDN (optional)

When the build includes catalog CDN configuration, the app may fetch Marine Life / dive-site manifests and assets over **HTTPS** to refresh the on-device reference catalog. Payloads are **checksum-verified**; a mismatched payload is discarded rather than applied.

### Remote catalog images and models

When a Field Guide species uses a remote image fallback, the app may fetch that image over **HTTPS** from public hosts. Downloadable 3D catalog models are limited to GoDive’s CDN / Firebase Storage hosts.

### Firebase social directory and friends

Display name, activity interests, and optional profile photo may be sent to Firebase as described in §5. When you use Friends, invite/friendship records and **friend-visible dive projections** (notes and media only if you opt in) may also be stored so friends can read what you share. This is not a public dive feed and is not a replacement for your private CloudKit log.

### iCloud dive-log sync (CloudKit)

When you are signed into iCloud on the device, structured dive-log data may sync through Apple CloudKit’s **private** database across your Apple devices. That includes a compact depth-profile track with each dive (so charts can rebuild on your other devices); individual chart sample rows are kept locally for performance. Sync can use **Wi‑Fi or cellular**. GoDive also schedules brief background sync windows so mirroring can continue when the app is not open (subject to iOS Background App Refresh and system conditions). You can turn off cellular for iCloud or GoDive in **Settings → Cellular** if you prefer Wi‑Fi only.

### iCloud Photos

When you view media that is not fully available on-device, Apple’s PhotoKit may fetch originals from iCloud Photos.

### Shared crash reports (optional)

If the app crashes or quits unexpectedly, GoDive may save a local report (crash type, call stack, app/iOS versions, and a short trail of recent UI context such as which screen you were on). Reports are not intended to include dive log text, photo contents, location details, or account credentials. Reports stay on your device by default and are viewable under **Settings → Crash Reports**.

**Share crash reports** is **off by default**. Turning it on uploads pending reports to us via Apple CloudKit’s **public** database so we can fix bugs. Before upload, GoDive **scrubs** common sensitive fragments (for example emails, tokens, and coordinate-like numbers). You can also share an individual report manually.

### Shared diagnostic events (optional)

GoDive keeps a short on-device journal of security-related events (for example sign-in, sign-out, rejected imports, catalog refresh issues). Entries use coarse technical tokens — not dive notes, photos, or account identifiers in developer uploads. The journal can sync with your dive account across your Apple devices via private CloudKit.

**Share diagnostic events** is **off by default**. Turning it on uploads scrubbed events to us via CloudKit’s public database. Uploaded records do not include your profile ID. You can review, export, or clear entries under **Settings → Diagnostic Events**.

---

## 9. How we protect your data

| Practice | What it means for you |
|----------|------------------------|
| **Keychain session** | Sign-in session identifiers are stored in the iOS Keychain and cleared on sign-out or account deletion. |
| **Profile scoping** | Dive data is tied to your signed-in profile. On a shared device, GoDive avoids claiming another person’s orphaned log without a safe single-owner check. |
| **Import checks** | FIT/UDDF files are size- and content-checked; suspicious or oversized files are rejected. Original file bytes are not kept after parse. |
| **Catalog integrity** | Optional CDN updates use HTTPS, restricted paths, and checksum verification. |
| **Remote URL gates** | Remote Field Guide images require HTTPS to public hosts; model downloads are limited to CDN / Firebase Storage hosts. |
| **Transport security** | App Transport Security stays on by default (no blanket allow-insecure-HTTP exception for the app). |
| **Diagnostics backup** | Local crash / diagnostic dumps are marked excluded from device backup where possible. |
| **Opt-in developer sharing** | Crash reports and diagnostic events leave your devices only if you turn the matching Settings toggles on. |

Deferred hardening tracked for later (not required for current use): Fishial API secret held only on a server, Firebase App Check, signed CDN manifests, and TLS certificate pinning.

---

## 10. What we do not do

- Sell information pertaining to you or your dive log  
- Automatically back up your full dive log to a **GoDive-operated** cloud account (sync uses **your** Apple iCloud CloudKit private database)  
- Store your full dive log as a GoDive-operated backup in Firebase (Firebase holds social directory, friends graph, and **opt-in friend-visible projections** only — your private CloudKit log remains authoritative on your devices)  
- Run a public social feed of your dives  
- Keep the original imported FIT/UDDF file bytes after parsing  
- Automatically upload crash reports or diagnostic events (both opt-in, off by default)  
- Render dive notes or user text as web pages or Markdown that could execute markup  

Feature availability (for example Fishial, Google Maps, or catalog CDN) can depend on how a given app build is configured.

---

## 11. Children’s privacy

GoDive is not directed at children under 13 (or the equivalent minimum age in your region). We do not knowingly collect personal information from children. If you believe a child has submitted information through the waitlist or app, contact us through [godiveios.com](https://godiveios.com) and we will take appropriate steps to delete it.

---

## 12. Data retention

| Data | Retention |
|------|-----------|
| **Waitlist emails** | Kept until you ask to be removed, we close the waitlist, or we no longer need them for launch communication |
| **On-device app data** | Retained on your iPhone until you delete it (or delete the app / its data / your account) |
| **Private CloudKit dive sync** | Controlled by your Apple iCloud account and Apple’s retention for that service; deletes you make in-app are mirrored when sync is available; may use cellular or Wi‑Fi and continue in background when iOS allows |
| **Firebase social directory + friends** | Kept while your account exists; removed when you delete your GoDive account (when Firebase is configured) |
| **Shared crash reports** | Retained only as long as reasonably needed to diagnose and improve the app |
| **Shared diagnostic events** | Retained only as long as reasonably needed to diagnose and improve the app |

---

## 13. Your rights and choices

Depending on where you live, you may have rights to access, correct, delete, or restrict certain personal information, or to object to certain processing. For waitlist data, contact us through [godiveios.com](https://godiveios.com). For on-device dive data, you control it primarily on the device (including deleting the app or using **Delete account**).

You can also:

- Decline Photos or Contacts permissions  
- Leave **Share crash reports** and **Share diagnostic events** off  
- Avoid using optional Identify / map / catalog-refresh features that require network access  
- Sign out of the app session  
- Delete your account from Settings  

---

## 14. International users

We are based in the United States. If you use the website or app from elsewhere, your information may be processed in the United States or other countries where our service providers (such as Wix, Apple, Google map services, Firebase, or Fishial) operate. Those locations may have different data-protection laws than your home country.

---

## 15. Changes to this policy

We may update this Privacy Policy as the product or site changes. We will post the updated version on this page (and on the user guide) and revise the **Last updated** date. Continued use of the website or app after changes means you accept the updated policy, except where applicable law requires otherwise.

---

Third-party data sources and SDKs used by the app are listed on [Acknowledgments & external resources](acknowledgments.md).
