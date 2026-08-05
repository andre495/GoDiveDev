# Handoff: Marine ontology → GoDiveMVP iOS

**Implement in the GoDive project using this doc (synced):**  
`/Users/andrdugas/Desktop/GoDiveMVP/docs/ontology-similarity-handoff.md`

SiteReport is **1:1 with each dive/snorkel activity** (mint on create/import); tagged marine life sightings link via `duringSiteReport` / opaque `siteReportId`.

That file is the working handoff for Cursor in `godivemvp` (Phase 1 biology similar UI + Phase 2 sighting write-back / occasional score refresh).

This ontology repo remains the lab/reference:

| Piece | Path |
|-------|------|
| Scorer to port | `visualizer/similarity.py` |
| SPARQL examples | `sparql/similarity-*.rq` |
| Catalog RDF | `data/catalog/marine_life_species.ttl`, `dive_sites.ttl` |
| Juvenile name cleanup at seed | `mappings/materialize_marine_life.py` → `clean_common_name()` |
| Vocab | `ontology/scuba-core.ttl`, `godive-activity.ttl` |

Open the GoDive copy for full weights, extension points, export JSON shape, architecture diagram, and paste-ready Phase 1 / Phase 2 prompts.
