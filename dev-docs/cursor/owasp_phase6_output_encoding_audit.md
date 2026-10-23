# OWASP Phase 6 — Output encoding audit

**Date:** 2026-07-18  
**Branch:** `feature/owasp-secure-coding`

## Scope

Mobile analogs of XSS / injection at **output** boundaries: Markdown/`LocalizedStringKey`, WebView HTML, structured export embedding, remote URL loading.

## Findings

| Area | Result |
|------|--------|
| Markdown / `AttributedString(markdown:)` / HTML attributed strings | **Absent** — no hits in `GoDiveMVP/` |
| Dive notes, site/buddy/tag titles | **Safe** — plain `Text` / `TextEditor` / `UILabel.text` |
| `WKWebView` / `loadHTMLString` / Safari VC of user content | **Absent** |
| UDDF / CSV / XML **export** of notes | **N/A** — import-only UDDF; no CSV/XML writers |
| Crash / security event share | **Safe** — plain text lines |
| Trip share | **Safe** — PNG via `ImageRenderer`; filename UUID-only after this phase |
| Fishial scientific name in UI | **Fixed** — `Text(verbatim:)` via `GoDivePlainText` |
| Catalog `AsyncImage` URLs | **Hardened** — `GoDiveRemoteURLPolicy.sanitizedCatalogImageURL` (HTTPS + public DNS host) |
| USDZ / Storage downloads | **Hardened** — `sanitizedCatalogDownloadURL` (Firebase / CDN hosts only) |

## Residual / deferred

- Catalog photo hosts remain diverse (Wikimedia, museums, etc.) until signed CDN is universal — policy blocks unsafe schemes/hosts, not a full museum allowlist.
- Signed CDN manifests / Fishial proxy tracked in **`todo.md`** (Phase 3 follow-ups).
- If WebView, Markdown rendering, or UDDF export is added later: re-open Phase 6 for that surface.

## Helpers

- **`GoDivePlainText`**
- **`GoDiveRemoteURLPolicy`**
- Cursor rule: **`godive-output-encoding.mdc`**
