# Privacy & data

GoDive is designed as a **local-first** dive log. This page summarizes what stays on your iPhone and what may touch the network.

## Stored on your device

The following live in GoDive’s on-device database and local app storage:

- Dive logs, profile samples, and import metadata (not the original `.fit` / `.uddf` files)  
- Dive site catalog and your custom sites  
- Buddy roster, trips, tags, and equipment  
- Certifications and profile name  
- **References** to Photos library items (device-local identifier, cross-device Photos cloud identifier, and optional small preview JPEG)  
- Marine life catalog and your tagged sightings  
- App settings (units, tank default, renumber, auto-upload)  
- Crash reports (technical diagnostics captured when the app crashes)  

There is **no GoDive server backup** of your dive log. On devices signed into **iCloud**, GoDive may sync your **dive log and related structured data** across **your** Apple devices using Apple’s **private CloudKit** (your iCloud account). That includes trips, gear, certifications, buddies, **sites you’ve logged** (including snapshots of OpenDiveMap places you’ve visited), and most **Settings** preferences (units, tank default, renumber, auto-upload, and related options). **Share crash reports** stays on-device. The full Explore **All Sites** reference catalog stays on-device and is not uploaded to your private database. Crash reports are separate (see below). Opt-in **crash diagnostics** upload uses CloudKit’s **public** database when you turn on **Settings → Share crash reports**.

## Sign in with Apple

GoDive uses **Sign in with Apple** to associate data with your Apple ID on this device. GoDive does not implement its own username/password system.

Sign out clears the active session; local data for that profile remains until you remove the app or its data. Multi-device sync follows your **iCloud** account availability on each device. After reinstall, GoDive matches your Apple ID to the synced account so your existing log comes back under the same sign-in (it may take a moment for iCloud to finish downloading).

## Photos library

When you attach media or enable **auto-upload**:

- GoDive reads **metadata and thumbnails** through Apple’s PhotoKit APIs.  
- Full-resolution frames load on demand for viewing, export, or identification.  
- Dive media stays in **your Photos / iCloud Photos** library — GoDive syncs a **pointer** (and a small preview) with your dive log, then remaps that pointer on each device.  
- If the original asset is deleted from Photos, GoDive removes the stale reference.

GoDive does **not** bulk-upload your entire camera roll — only items you attach or that match a dive window when auto-upload runs.

## Contacts

Optional. If you link a buddy to a **Contact**, GoDive reads name and photo for that contact to display and sync the buddy avatar. Contact data is not sent to GoDive servers.

## Network use

Most of GoDive works **offline** after install. Network may be used for:

| Feature | What goes out | When |
|---------|---------------|------|
| **Maps** | Map tile and geocoding requests | Explore, dive maps, site picker — via Apple MapKit or Google Maps when configured in the app build |
| **Fishial identify** (optional) | One **JPEG still** per identification request, optional dive coordinates in a header | Only when you tap identify on a cropped fish photo and the feature is configured |
| **Remote species images** | HTTP fetch for catalog URLs | Field Guide when a species uses a remote image fallback |
| **iCloud dive-log sync** | Structured dive data via Apple CloudKit private database | When signed into iCloud on the device; syncs across your Apple devices |
| **iCloud Photos** | Apple’s PhotoKit may fetch originals | When you view media not stored locally on the device |
| **Crash reports** (optional) | Technical crash diagnostics via Apple CloudKit | Only when **Settings → Share crash reports** is on |

### Crash reports

GoDive records a report when the app crashes or quits unexpectedly (using Apple's MetricKit diagnostics). Reports contain the crash type, call stack, app/iOS versions, and a short **breadcrumb trail** of recent UI context (which tab/screen you were on, dive IDs, open sheets) — **no dive log text, photo contents, location details, or account data**.

- Reports are stored **on your device** and viewable under **Settings → Crash Reports**.
- Sharing is **opt-in**: the **Share crash reports** toggle uploads them to the developer through Apple's CloudKit; it is off by default.
- You can also share a single report manually from the Crash Reports page at any time.

### Fishial fish identification

If enabled in your build:

- You must explicitly run **Identify** after cropping a fish in the editor.  
- No background batch upload of your library.  
- Results are species name candidates; you confirm before a tag is saved.  
- Subject to [Fishial’s API terms](https://docs.fishial.ai/api) and your developer account limits.

### Google Maps

When the app includes a Google Maps API key, map views may use Google tile services. Basic map display does **not** sign you into Google or send dive log contents to Google. Features that would require Google account access are not part of the current MVP.

## What GoDive does not do (MVP)

- No selling or sharing your dive log with third parties  
- No GoDive-operated cloud backup server (sync uses **your** Apple iCloud private database)  
- No social feed or public profile  
- No retaining imported FIT/UDDF file bytes after parse  

## Permissions summary

| Apple permission | Purpose |
|------------------|---------|
| Photos | Attach and auto-match dive media |
| Contacts | Optional buddy linking |
| Sign in with Apple | Account gate |

You can revoke Photos or Contacts in **Settings → Privacy** on iPhone; GoDive features that depend on them will stop working until access is restored.

## Questions

For app-specific privacy practices before a public release, review Apple’s App Store disclosure requirements alongside this guide. Feature availability (Fishial, Google Maps) depends on how the app was built and configured on your device.

Third-party data sources and SDKs are listed on [Acknowledgments & external resources](acknowledgments.md).
