# GoDive — Backlog

Ideas and future directions that are **not** committed work yet. For in-flight tasks and known gaps, see **`todo.md`**. For shipped work, see **`change_log.md`**.

Add items as bullets or short sections. Move to **`todo.md`** when you are ready to implement.

---

## Ideas

### Logbook filters

Add a **filter component** on **Logbook** so divers can narrow the dive list to activities that match selected criteria. Possible dimensions (mix-and-match or combined):

- **Site** — dive site name (and/or matched catalog **`DiveSite`** when linked)
- **Country** — from location / site metadata when available
- **Depth** — e.g. min/max depth range
- **Air used** — pressure drop, SAC/RMV bands, or gas consumed (when data exists)
- **Custom tags** — user-defined labels on dives (would need a tags model + UI to assign)

**UX notes:** Filter chip bar or sheet above the list; show active filter count; clear-all; persist last-used filters optionally. Empty state when no dives match.

**Dependencies / gaps today:** **`DiveActivity`** has **`siteName`** / **`locationName`** but no country field, no dive tags, and no **`@Relationship`** to **`DiveSite`** yet — some filters may need model work first.
