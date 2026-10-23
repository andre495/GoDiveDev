# Friend invites — `links.godiveios.com`

HTTPS invites and Universal Links for Profile → Friends QR / share.

## Architecture

| Piece | Location |
|--------|-----------|
| Invite URLs | `https://links.godiveios.com/invite/{token}` |
| Hosting site | Firebase **`godive-links`** → `public-links/` (invite + AASA only) |
| Catalog JSON | Separate site **`godive-1cff8`** → `public/` — **not** on `links.godiveios.com` |
| App parsing + preferred URL | `GoDiveFriendInviteURL` |
| Universal Link delivery | `AppSessionRootView` — `onContinueUserActivity(NSUserActivityTypeBrowsingWeb)` |
| Entitlement | `applinks:links.godiveios.com` in `GoDiveMVP.entitlements` |

Marketing site **godiveios.com** (Wix) is unchanged.

## Custom domain (important)

Attach **`links.godiveios.com`** only to the **`godive-links`** Hosting site — **not** the default `godive-1cff8` site (that site serves catalog JSON for the app).

Firebase Console → **Hosting** → select site **godive-links** → **Add custom domain** → `links.godiveios.com`.

If the domain is still on the default site, remove it there first, then add it on **godive-links**. Update GoDaddy **CNAME** `links` to the hostname Firebase shows for **godive-links** (often `godive-links.web.app`).

## One-time setup checklist

### 1. GoDaddy DNS

CNAME **links** → Firebase target for site **godive-links**. Wait for **Connected** + SSL.

### 2. Apple Developer — App ID

Enable **Associated Domains** on **PrimoSoftware.GoDiveMVP**.

### 3. Deploy Hosting (both sites)

```bash
cd catalog-cdn
npx firebase-tools@latest deploy --only hosting:links,hosting:catalog --project godive-1cff8
```

Invite-only changes: `deploy --only hosting:links`. Catalog publish: `hosting:catalog` (see **`catalog_cdn_publish.md`**).

### 4. Verify web

- `https://links.godiveios.com/` — short invite helper text only (no catalog index).
- `https://links.godiveios.com/.well-known/apple-app-site-association` — JSON.
- `https://godive-1cff8.web.app/catalog/v1/manifest.json` — catalog (app CDN base; not linked from `links`).

### 5. Build & test on a physical iPhone

New invite from **Friends → QR**; tap link or scan QR.

## Deploy when invite / AASA files change

```bash
cd catalog-cdn && npx firebase-tools@latest deploy --only hosting:links --project godive-1cff8
```
