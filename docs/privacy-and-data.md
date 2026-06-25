# Privacy & data

GoDive is designed as a **local-first** dive log. This page summarizes what stays on your iPhone and what may touch the network.

## Stored on your device

The following live in GoDive’s on-device database and local app storage:

- Dive logs, profile samples, and import metadata (not the original `.fit` / `.uddf` files)  
- Dive site catalog and your custom sites  
- Buddy roster, trips, tags, and equipment  
- Certifications and profile name  
- **References** to Photos library items (local identifier + optional small preview JPEG)  
- Marine life catalog and your tagged sightings  
- App settings (units, tank default, renumber, auto-upload)  

There is **no CloudKit or multi-device sync** in the current MVP. Your log does not upload to a GoDive server for backup.

## Sign in with Apple

GoDive uses **Sign in with Apple** to associate data with your Apple ID on this device. GoDive does not implement its own username/password system.

Sign out clears the active session; local data for that profile remains until you remove the app or its data.

## Photos library

When you attach media or enable **auto-upload**:

- GoDive reads **metadata and thumbnails** through Apple’s PhotoKit APIs.  
- Full-resolution frames load on demand for viewing, export, or identification.  
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
| **iCloud Photos** | Apple’s PhotoKit may fetch originals | When you view media not stored locally on the device |

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
- No automatic cloud backup of dives  
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
