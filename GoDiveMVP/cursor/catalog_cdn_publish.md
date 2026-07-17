# Catalog CDN publish (Phase 4)

Firebase **Hosting** serves a public HTTPS catalog for GoDive. The iOS app uses plain `URLSession` (no Firebase SDK). User dive data never goes here.

## Layout

```text
{base}/catalog/v1/manifest.json
{base}/catalog/v1/marine_life.json
```

Example base: `https://your-project.web.app`

## Manifest

```json
{
  "schemaVersion": 1,
  "catalogVersion": 1,
  "minimumAppVersion": "1.0",
  "generatedAt": "2026-07-17T00:00:00Z",
  "marineLife": {
    "format": "full",
    "path": "catalog/v1/marine_life.json",
    "sha256": "<lowercase hex SHA-256 of marine_life.json bytes>",
    "itemCount": 1319
  }
}
```

- Bump **`catalogVersion`** whenever `marine_life.json` changes.
- **`marine_life.json`** is the same snake_case array shape as bundled **`marine_life_sample.json`**.
- Compute SHA-256 (lowercase hex), e.g. `shasum -a 256 marine_life.json`.

## Hosting

1. Create / use a Firebase project.
2. Enable Hosting; deploy the `catalog/v1/` files (Firebase Console or `firebase deploy --only hosting`).
3. Prefer short cache for `manifest.json` and long cache for versioned payload paths when you add Cache-Control headers.

## App config

1. Copy **`GoDiveMVP/Config/CatalogCDNSecrets.example.plist`** → **`CatalogCDNSecrets.plist`** (gitignored).
2. Set **`ManifestBaseURL`** to the Hosting origin (HTTPS).
3. Add the plist to the **GoDiveMVP** app target if Xcode does not pick it up automatically.
4. Launch: after bundled seed, the app fetches the manifest when the URL is configured; offline / missing URL keeps the bundled catalog.

## Out of scope (Phase 4b)

Dive site / OpenDiveMap CDN, Marine Life photo / USDZ CDN, Android client.
