# Catalog CDN publish (Phase 4 / 4b)

Firebase **Hosting** serves manifests + catalog JSON. Firebase **Storage** serves marine life photos / USDZ. The iOS app uses plain `URLSession` (no Firebase SDK). User dive data never goes here.

## Layout

```text
Hosting:
  {base}/catalog/v1/manifest.json
  {base}/catalog/v1/marine_life.json
  {base}/catalog/v1/dive_sites.json   # OpenDiveMap snapshot shape (~3k rows)

Storage:
  gs://{bucket}/catalog/v1/marine_life/photos/{resource}.jpg
  gs://{bucket}/catalog/v1/marine_life/models/{Name}.usdz
```

Example base: `https://godive-1cff8.web.app`  
Example bucket: `godive-1cff8.firebasestorage.app`

## Rebuild + upload

From `catalog-cdn/`:

```bash
# Rewrite Hosting JSON (ODM sites + Storage URLs in marine_life.json)
python3 scripts/build_catalog_cdn.py --catalog-version 2

# Upload photos + USDZ (uses firebase-tools login token)
python3 scripts/build_catalog_cdn.py --catalog-version 2 --upload

# Deploy Hosting + Storage rules
npx firebase-tools@latest deploy --only hosting,storage --project godive-1cff8
```

- Bump **`catalogVersion`** whenever JSON or asset pointers change.
- **`dive_sites.json`** must be OpenDiveMap reference shape (`id`, `name`, `country`, …) — not `DiveSiteDTO`.
- Storage rules: public **read** only under `catalog/v1/**` (`storage.rules`).

## App config

1. Copy **`GoDiveMVP/Config/CatalogCDNSecrets.example.plist`** → **`CatalogCDNSecrets.plist`** (gitignored).
2. Set **`ManifestBaseURL`** to the Hosting origin (HTTPS).
3. Launch: bundled Marine Life seed + bundled OpenDiveMap, then CDN refresh when configured.

## Client behavior

| Data | Source |
|------|--------|
| OpenDiveMap All Sites | Hosting JSON → Application Support cache (fallback: bundled) |
| User / My Sites | CloudKit `UserDiveSite` |
| Photos / USDZ | Bundled first → disk cache → Storage URL |

## Out of scope (this document)

App Store binary thinning (removing bundled assets), Android. Social profiles (Auth + Firestore) are documented in **`cursor/firebase_user_profiles.md`**.
