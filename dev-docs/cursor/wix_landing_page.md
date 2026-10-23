# GoDive Wix landing page — copy + build guide

Marketing homepage for Wix + GoDaddy. User guide stays on GitHub Pages; link it from the footer.

- **Wix site:** GoDive (GoDive iOS) — ID `c516e45b-79ff-4ead-a3f3-e9841685fb23` — **Premium**
- **Custom domain:** **godiveios.com** (GoDaddy) — connected in Wix as **POINTING** / primary
- **User guide:** https://andre495.github.io/GoDiveDev/
- **Privacy (guide):** https://andre495.github.io/GoDiveDev/privacy-and-data/
- **Primary CTA (until App Store):** waitlist / “Coming soon” — form **GoDive Waitlist** (`f5adc141-c66b-492f-b087-b6223cc5e711`)
- **Brand colors (Wix theme):** teal primary `#00897B`–`#009688`, cyan accent `#00BCD4` (match Material teal/cyan); deep ocean navy for text on light backgrounds

### GoDaddy DNS (from Wix Connected Domain Setup Info)

Keep GoDaddy nameservers (`ns11` / `ns12.domaincontrol.com`). In **DNS Management**, set:

| Type | Host | Value | TTL |
|------|------|--------|-----|
| **A** | `@` | `185.230.63.107` | 1 Hour (or 3600) |
| **CNAME** | `www` | `pointing.wixdns.net` | 1 Hour (or 3600) |

Remove any conflicting A/CNAME/forwarding for `@` or `www`. Propagation can take up to 48 hours; then confirm HTTPS on `https://godiveios.com` and `https://www.godiveios.com`.

---

## Paste-ready copy

### SEO (Wix → Settings → SEO)

| Field | Value |
|--------|--------|
| **Page title** | GoDive — iPhone dive log |
| **Meta description** | Log every dive. Explore marine life. GoDive is a local-first dive log for iPhone — import from your dive computer, tag species, and keep trips and buddies organized. |
| **Social share title** | GoDive — Log every dive. Explore marine life. |
| **Social share description** | An iPhone dive log that stays on your device. Coming soon on the App Store. |

### Hero (first viewport only)

**Brand / wordmark:** GoDive

**Headline:**  
Log every dive. Explore marine life.

**Supporting sentence:**  
An iPhone dive log that stays on your device — import from your computer, tag species, and keep trips and buddies organized.

**Primary button label:**  
Join the waitlist

**Secondary text under button (optional):**  
Coming soon on the App Store

**Alt later (when store live):**  
Download on the App Store  
*(replace button link; remove waitlist or keep as secondary)*

### Waitlist form

**Form heading:** Get notified at launch

**Email field placeholder:** you@email.com

**Submit button:** Notify me

**Success message:** You’re on the list. We’ll email you when GoDive is available.

**Form helper (optional):** No spam. Launch updates only.

### Features section heading

Built for divers

### Feature blocks (headline + one sentence each)

**Import your log**  
Bring in Garmin `.fit` files and MacDive / UDDF exports — depth and tank profiles ready to explore.

**Field Guide**  
Browse a marine life catalog and tag species on your dive photos.

**Dive detail that goes deep**  
Scrub depth and pressure charts, browse media, and see where you dove on the map.

**Explore dive sites**  
Browse sites on a map or list, and link sites when you import.

**Trips, buddies & gear**  
Plan trips, tag dive buddies, track certifications, and keep your equipment locker in one place.

**Private by design**  
Your log stays on your iPhone. Sign in with Apple — no GoDive cloud account required.

### How it works (optional)

**Section heading:** How it works

1. **Sign in** — Use Sign in with Apple to set up your profile on this device.  
2. **Import or log** — Add dives from your computer or start building your logbook.  
3. **Explore & tag** — Open the Field Guide, map sites, and tag what you saw.

### Closing strip (above footer)

**Headline:** Ready when you are  

**Body:** GoDive is coming to the App Store. Join the waitlist and be first to know.  

**Button:** Join the waitlist  
*(same as hero — scroll to form or duplicate form action)*

### Footer

**Links:**  
- User guide → `https://andre495.github.io/GoDiveDev/`  
- Privacy → `https://andre495.github.io/GoDiveDev/privacy-and-data/` (canonical **Privacy Policy** for website + app — keep Wix footer linked here; update Wix page body to match `docs/privacy-and-data.md` when the site hosts a full paste)

**Copyright (edit legal name as needed):**  
© PrimoSoftware. All rights reserved.

**Optional short line:**  
GoDive is not affiliated with Garmin, PADI, or other brands mentioned in product materials unless noted.

---

## Assets checklist (before / during Wix build)

| Asset | Action |
|--------|--------|
| Domain | Confirm exact GoDaddy domain name |
| Logo | Export pin / GoDive mark as transparent PNG; use as favicon too |
| Hero | One full-bleed ocean or dive photo, **or** phone mockup showing Home |
| Screenshots | Home, dive detail (chart), Field Guide, Explore — 3–5 images |
| Contact email | Inbox that will receive Wix form notifications |

Use Wix stock underwater images only as temporary placeholders; replace before sharing publicly.

---

## Phase 3 — Wix build checklist

Do these in order. Publish to a free `*.wixsite.com` URL **before** connecting the domain.

### A. Create the site

1. Go to [wix.com](https://www.wix.com) → sign up / log in.  
2. **Create New Site**.  
3. Choose a **simple app / product landing** template (one long page, large hero). Avoid busy magazine or multi-column dashboards.  
4. Open the editor (Wix Editor or Studio — either is fine for a one-pager).

### B. Brand chrome

5. Site name: **GoDive**.  
6. Upload logo → header (keep header minimal: logo + optional “User guide” text link).  
7. Favicon: same pin/logo square.  
8. Theme colors: teal / cyan as above; white or soft ocean gradient backgrounds; dark navy body text.  
9. Prefer full-bleed hero media; avoid boxed “card” collage in the first viewport.

### C. Paste content

10. Hero: brand, headline, supporting sentence, **Join the waitlist** button (anchor-scroll to form).  
11. Below fold: **Built for divers** + six feature blocks (use screenshots next to 2–3 of them if you have them).  
12. Optional: **How it works** three steps.  
13. Closing strip + waitlist form.  
14. Footer: User guide + Privacy links + copyright.

### D. Waitlist form

15. Add **Wix Forms** → email field + submit.  
16. Form settings → send submissions to your contact email (and enable confirmation if available).  
17. Paste success / helper copy from above.  
18. Submit a **test** entry from the published preview and confirm the email arrives.

### E. Mobile + publish

19. Switch to **mobile** view in the editor; fix oversized headlines, stacked buttons, and image crop.  
20. **Preview** desktop + mobile.  
21. **Publish** → note your free URL (`yoursite.wixsite.com/...`).  
22. Open that URL on your iPhone; confirm hero + CTA are readable without horizontal scroll.

Do **not** add a fake App Store button until you have a real App Store or TestFlight URL.

---

## Phase 4 — GoDaddy DNS → Wix

**Prefer:** keep nameservers at GoDaddy; only change A / CNAME records Wix lists.  
**Source of truth:** Wix **Settings → Domains → Connect a domain you already own** — use the exact IPs/hostnames Wix shows (they can change).

### A. Start connection in Wix

1. Wix Dashboard → select the GoDive site.  
2. **Settings** → **Domains**.  
3. **Connect a domain you already own** (not “Buy a domain”).  
4. Enter your GoDaddy domain → continue.  
5. Choose **I’ll update DNS myself** / connect via DNS records at current provider (wording varies).  
6. Leave this panel open — copy the **A** record(s) and **CNAME** for `www`.

Typical pattern (replace with Wix’s values):

| Type | Host / Name | Value | TTL |
|------|-------------|--------|-----|
| A | `@` | *(Wix IP, e.g. often starts with 185.x or similar — use Wix’s)* | 600 or 1 hour |
| CNAME | `www` | *(hostname Wix provides)* | 600 or 1 hour |

Some setups ask for multiple A records — add all of them.

### B. Update GoDaddy

7. GoDaddy → **My Products** → Domains → your domain → **DNS** / **Manage DNS**.  
8. If an existing **A** for `@` or **CNAME**/forwarding for `www` points elsewhere, **edit or delete** those so they don’t conflict.  
9. Add the A record(s) and CNAME exactly as Wix shows.  
10. Save. Do **not** change nameservers unless you intentionally chose “point nameservers to Wix.”

### C. Finish in Wix

11. Return to Wix Domains → **I've updated my DNS** / verify.  
12. Wait for Wix to show the domain as **connected** (often minutes; up to 24–48 hours).  
13. Set the connected domain as the **primary** domain.  
14. Prefer one canonical host: either apex → `www` or `www` → apex (Wix usually offers a redirect).  
15. Confirm SSL/HTTPS shows as active (Wix provisions this after DNS verifies).

### D. Verify

16. Visit `https://yourdomain.com` and `https://www.yourdomain.com` — both should load the landing page with a padlock.  
17. If DNS fails: re-check host names (`@` vs blank vs `www`), remove duplicate A/CNAME, wait, then re-verify in Wix. Paste errors into chat if stuck.

### Nameserver alternative (only if DNS records keep failing)

- Wix will show nameservers to paste into GoDaddy → Domain → **Nameservers** → Custom.  
- After switching nameservers, manage DNS in Wix. Reconfigure GoDaddy email (MX) in Wix if you use GoDaddy email.

---

## Phase 5 — Soft launch checklist

Complete before sharing the URL publicly:

- [ ] Hero + CTA readable on iPhone Safari (published custom domain)  
- [ ] Waitlist form test email received  
- [ ] User guide footer link opens https://andre495.github.io/GoDiveDev/  
- [ ] Privacy footer link opens https://andre495.github.io/GoDiveDev/privacy-and-data/  
- [ ] Apex and `www` both work; one redirects to the other  
- [ ] HTTPS padlock valid (no certificate warning)  
- [ ] No App Store / Download button unless the store URL is real  
- [ ] Wix SEO title + meta description set (see table above)  
- [ ] Optional: Google Search Console property for the domain  

### After App Store release

1. Replace primary CTA with **Download on the App Store** + store URL.  
2. Keep or remove waitlist (or retarget copy to “Get updates”).  
3. Optionally add a second button: **User guide**.

---

## Quick paste summary

```
GoDive
Log every dive. Explore marine life.
An iPhone dive log that stays on your device — import from your computer, tag species, and keep trips and buddies organized.
[Join the waitlist]
Coming soon on the App Store
```
