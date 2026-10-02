# GoDiveMVP ← Marine ontology: Similar species + sighting write-back

**Use this doc in the GoDive Cursor project to implement.**  
Ontology lab (reference / scorer prototype): `/Users/andrdugas/Desktop/marine life ontology`  
Synced copy: `marine life ontology/docs/godive-ios-similarity-handoff.md`

---

## Product goal

1. **v1 — Biology “Similar species”** on Field Guide detail (on-device, no RDF). **Shipped.**
2. **v1.1 — Juvenile name cleanup** in common names. **Shipped.**
3. **v2 — Community anonymized sightings + scheduled similarity**: opt-in Firebase staging → public mirror → daily CDN `sightingScore` cache → app merges with biology. **Shipped** (Settings default **off**).

---

## Ontology reference (already built)

| Piece | Path |
|-------|------|
| Scorer (port this) | `/Users/andrdugas/Desktop/marine life ontology/visualizer/similarity.py` |
| Biology / sighting SPARQL examples | `…/sparql/similarity-biology.rq`, `similarity-sighting.rq` |
| Species RDF seed | `…/data/catalog/marine_life_species.ttl` |
| Sites RDF seed | `…/data/catalog/dive_sites.ttl` |
| Vocab | `…/ontology/scuba-core.ttl`, `godive-activity.ttl` |
| Juvenile strip at seed | `…/mappings/materialize_marine_life.py` → `clean_common_name()` |
| Local API prototype | `GET http://127.0.0.1:8765/api/similar?iri=&mode=biology\|sighting\|both` |

### Biology weights

| Signal | Weight | GoDive field |
|--------|-------:|--------------|
| familyName | 4.0 | `familyName` |
| classifiedAs | 4.0 | (sparse) |
| physicalTrait | 3.5 | structured traits (sparse) |
| subcategory | 3.0 | `subcategory` |
| bodyShape | 2.5 | `distinctiveFeatures` starting with `Body shape:` |
| colorOverlap | 2.5 | color words in `aboutText` |
| sizeOverlap / sizeSimilar | 2.5 / 2.0 | min/max size meters |
| category | 1.5 | `category` |
| depthOverlap | 1.0 | min/max depth meters |

### Sighting weights

| Signal | Weight | GoDive join |
|--------|-------:|-------------|
| sameActivity | 5 | same `diveActivity` / `snorkelActivity` |
| sameSite | 4 | same `diveSiteID` |
| sameWaterBody | 3 | site → body of water / seaName |
| sameTimeOfDay | 2 | activity time-of-day |
| similarDepth | 2 | `sightingDepth` within ~5 m |
| sameLifeStage | 1 | life stage on sighting |

### Golden test

**French angelfish** (`marine-life-french-angelfish`) → top biology: Blue angelfish, queen angelfish, rock beauty (~16.5), then other Pomacanthidae (~14.5).

---

## GoDive extension points (existing code)

| Concern | Path |
|---------|------|
| Catalog model | `GoDiveMVP/Models/MarineLife.swift` |
| Sightings | `GoDiveMVP/Models/SightingInstance.swift` |
| Snapshots | `GoDiveMVP/Data/FieldGuidePresentation.swift` → `MarineLifeCatalogSnapshot` |
| Search | `FieldGuideMarineLifeSearch` |
| Fishial name match | `FishialMarineLifeCatalogMatching` (keep; complement with biology similar) |
| Detail UI | `Views/Pages/field_guide_marine_life_detail_view.swift` |
| Common names | `MarineLifeCommonNameFormatting` |
| Seeder | `MarineLifeCatalogSeeder` + `Resources/Catalog/marine_life.json` |
| Stores | `AppSwiftDataStorePartition` — catalog vs user; **link by UUID only** |

---

## Phase 1 — Implement now (on-device biology)

### 1. Scorer

Add `GoDiveMVP/Data/MarineLifeBiologySimilarity.swift` (name flexible):

- Input: seed `MarineLifeCatalogSnapshot` + full catalog snapshots  
- Output: ranked `[(uuid, score, evidence)]`  
- Mirror `similarity.py` biology path (hard facets + soft color/size/depth)  
- Weights as constants  
- **No** RDF/SPARQL/rdflib in the app  

Tests: French angelfish golden case in `GoDiveMVPTests`.

### 2. Juvenile common-name fix

Strip `\(\s*juvenile\s*\)` (case-insensitive) in `MarineLifeCommonNameFormatting` and/or catalog upsert/seed.  
Ontology RDF seed already does this; **app JSON/SwiftData still shows “(juvenile)”** until fixed (~34 rows).

### 3. UI

On Field Guide species detail:

- Section **Similar species**
- Catalog thumbnail + common name + optional score/evidence
- Tap → navigate by `uuid` / `FieldGuideSpeciesBinding.catalog`

### Phase 1 Cursor prompt

```text
Implement on-device “Similar species” for the Field Guide using
docs/ontology-similarity-handoff.md and port biology ranking from
/Users/andrdugas/Desktop/marine life ontology/visualizer/similarity.py

1. MarineLifeBiologySimilarity over MarineLifeCatalogSnapshot
2. Strip "(juvenile)" from common names (app pipeline)
3. UI section on field_guide_marine_life_detail_view
4. Unit tests: French angelfish golden seed
5. No RDF runtime; do not persist similarity on catalog SwiftData rows
```

---

## Phase 2 — Community anonymized sightings + scheduled similarity (**shipped**)

### Locked decisions

- **Shared community graph** of anonymized sighting events (not personal-only, not aggregates-only).
- **Settings opt-in** (default **off**). Contribute only when on **and** Firebase Auth signed-in.
- **Similar species UI does not recompute on each tag.** A scheduled Cloud Function refreshes a published cache; the app merges on catalog/CDN refresh.

### Architecture

```text
Activity create/import → SiteReport (1:1 with dive/snorkel)
        │  opt-in + Firebase Auth
        ▼
users/{uid}/ontologySiteReportContributions/{activityUUID}
        │  mirrorOntologySiteReportContribution
        ▼
communitySiteReports/{contributionId}

Tag add/remove → SightingInstance (+ siteReportId → that report)
        │
        ▼
users/{uid}/ontologySightingContributions/{sightingUUID}
        │  mirrorOntologySightingContribution
        ▼
communitySightings/{contributionId}   (includes siteReportId)
        │
        │  rebuildSpeciesSimilarityCache (daily; sameSiteReport weight)
        ▼
catalog/v1/species_similarity.json (+ SHA meta)
        │
        ▼
SpeciesSimilarityCDNCache → Field Guide Similar species
        = MarineLifeBiologySimilarity + CDN sightingScore
```

**Why private staging then CF?** Client never writes the shared collection; opt-out/delete can remove the public row via Admin SDK without putting `uid` on the public doc.

### iOS modules

| Concern | Path |
|---------|------|
| Settings (default on) | `AppUserSettings.contributeCommunitySightings` + Settings **Contribute sightings to community** |
| Export mapper | `SightingGraphExport` (v3 + `siteReportId`) + `SiteReportGraphExport` |
| Sync | `OntologySiteReportContributionSync` (activity 1:1) + `OntologySightingContributionSync` |
| Untag | `MarineLifeSightingRecorder.untagSpecies*` + tag-sheet toggle-off |
| CDN cache | `SpeciesSimilarityCDNCache` + optional manifest `speciesSimilarity` |
| Merge | `MarineLifeBiologySimilarity.merge(biology:sightingScoresByUUID:)` |

### Staging / public fields

- `contributionId` (opaque, stable), `marineLifeUUID`
- `odmSiteId` / `diveSiteCatalogUUID`, `waterBody`, `country`, `region` when known (site from sighting, else activity; catalog + **`UserDiveSite`**)
- `sightingDepthM`, `timeOfDay`, `sightingDate` (local civil date / hour when activity or site TZ offset known; else UTC)
- `activityKind`: `dive` | `snorkel`
- `status`: `active` | `deleted`
- schemaVersion **2**
- **Never** on public docs: Firebase UID, profile ID, media, notes, lat/lon, site name, exact timestamps

### Scorer (backend)

`catalog-cdn/functions/speciesSimilarity.js` — weights aligned with ontology `similarity.py` sighting section, emphasizing **sameSite / sameWaterBody / similarDepth / sameTimeOfDay / co-occurrence** (same-activity across users is impossible). Writes Storage `catalog/v1/species_similarity.json` + meta; Hosting bootstrap empty file from `build_catalog_cdn.py`.

### Out of scope (still)

- On-device RDF/SPARQL  
- Identifiable community graph  
- Recomputing Similar species on every tag  
- Mutating `marine_life.json` from sightings  
- Community graph for users who never opt in  

---

## ID crosswalk

| Ontology | GoDive |
|----------|--------|
| `…/species/{uuid}` | `MarineLife.uuid` |
| `mlo:commonName` | `commonName` |
| `mlo:familyName` | `familyName` |
| `mlo:distinctiveFeatures` | `distinctiveFeatures` |
| `mlo:aboutText` | about / description |
| `mlo:minSizeM` / `maxSizeM` | size meters |
| `…/site/{id}` | `dive_sites.json` `id` / ODM |
| `Sighting` → `sightedOrganism` | `SightingInstance.marineLifeUUID` |
| `duringDiveActivity` / `duringSnorkelActivity` | dive / snorkel activity UUID |

---

## Out of scope (remaining)

- On-device RDF/SPARQL engine  
- ML / embedding visual similarity  
- Mutating catalog rows with similarity scores  
- Publishing identifiable / raw personal sightings  
- Live Firestore or SPARQL in the Similar species UI  

---

## Verify in ontology lab (optional)

```bash
cd "/Users/andrdugas/Desktop/marine life ontology/visualizer"
.venv/bin/python server.py
# Search French Angelfish, then /api/similar?mode=biology
```

---

## Shipped order in GoDive

1. Juvenile name cleanup + unit tests  
2. Biology scorer + Field Guide “Similar species” UI + French angelfish test  
3. Community opt-in staging + ingest CF + scheduled `species_similarity.json` + CDN merge UI
