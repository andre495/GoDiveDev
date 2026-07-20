# Firestore / Storage rules review (OWASP Phase 4)

**Date:** 2026-07-18  
**Branch:** `feature/owasp-secure-coding`  
**Files:** `catalog-cdn/firestore.rules`, `catalog-cdn/storage.rules`  
**Deploy:** only when rules change — follow `.cursor/rules/firebase-rules-deploy.mdc`.

---

## Current posture (intentional for MVP social directory)

### Firestore (`users/{userId}`)

| Access | Rule | Notes |
|--------|------|--------|
| Read | Any signed-in user | Public social directory fields (`displayName`, `interests`, `photoURL`) |
| Write / delete | Owner only (`request.auth.uid == userId`) | |
| `users/{uid}/private/*` | Owner only | Apple link — never in public reads |

**Deny-by-default** catch-all remains for all other paths (no dive-log documents).

### Storage

| Path | Read | Write |
|------|------|--------|
| `catalog/v1/**` | Public | Denied (Hosting / Admin only) |
| `users/{userId}/**` | Public | Owner + image + &lt; 5 MB |

Avatar public-read is required so `photoURL` tokens work for friends UI.

---

## Decisions (this pass)

1. **No rule deploy in Phase 4** — current rules match the access matrix; tightening to friends-only is a **product** change, not a security emergency while the directory is small.
2. **Friends-only / field-level redaction** — deferred (policy out of scope until friends graph ships). Track in `todo.md` under social when product starts.
3. **No world-writable buckets** — confirmed: catalog write denied; user write is owner-scoped with size/type checks.
4. **Hybrid boundary** — rules still must never admit dive-log collections; client code must not write dive models to Firebase (`godive-hybrid-trust-boundaries.mdc`).

---

## When to revisit

- Shipping a browsable **friends directory** at scale → friends-only reads or limited projection fields.
- Enabling **Fishial proxy / App Check** → optionally require App Check on Storage/Firestore (separate follow-up).
- Any new Storage prefix → deny by default; never grant public write.
