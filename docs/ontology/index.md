# Marine life ontology

GoDive’s marine-life knowledge graph describes species, dive sites, sightings, and site reports used for Field Guide **Similar species** and opt-in community similarity.

These pages are for developers and curious divers who want to inspect the vocabulary — they are not part of the day-to-day logbook UI.

**Namespace:** `mlo:` → [`https://www.godiveios.com/marine-life/`](https://www.godiveios.com/marine-life/)  
Example species IRI: `https://www.godiveios.com/marine-life/species/marine-life-french-angelfish`

## Browse

| Resource | What you’ll find |
|----------|------------------|
| [Vocabulary documentation](vocabulary/){target=_blank} | Human-readable class and property docs (generated with pyLODE) |
| [Ontology visualizer](visualizer/){target=_blank} | Interactive graph: ontology overview, species search, 2-hop neighborhoods, biology similarity |

!!! note "Static snapshot"
    The public visualizer is a **static** export of the ontology lab. Biology similarity runs in your browser; sighting similarity uses demo SiteReport data only. Live custom SPARQL over every Turtle file still runs locally in the ontology lab.

## In the app

- Field Guide species pages show **Similar species** (on-device biology, plus community scores when you opt in).
- Settings → **Contribute sightings to community** (on by default) shares anonymized SiteReports and tagged sightings for the scheduled similarity cache — never your name, photos, notes, or exact GPS.
