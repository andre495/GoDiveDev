# RDF 1.2 Reference

Normative / informative W3C sources:

| Document | URL |
|----------|-----|
| Concepts | https://www.w3.org/TR/rdf12-concepts/ |
| Semantics | https://www.w3.org/TR/rdf12-semantics/ |
| Schema | https://www.w3.org/TR/rdf12-schema/ |
| Turtle | https://www.w3.org/TR/rdf12-turtle/ |
| Primer | https://www.w3.org/TR/rdf12-primer/ |
| What’s New | https://www.w3.org/TR/rdf12-new/ |

## Standard prefixes

| Prefix | IRI |
|--------|-----|
| `rdf` | `http://www.w3.org/1999/02/22-rdf-syntax-ns#` |
| `rdfs` | `http://www.w3.org/2000/01/rdf-schema#` |
| `xsd` | `http://www.w3.org/2001/XMLSchema#` |
| `owl` | `http://www.w3.org/2002/07/owl#` |
| `skos` | `http://www.w3.org/2004/02/skos/core#` |
| `prov` | `http://www.w3.org/ns/prov#` |
| `sh` | `http://www.w3.org/ns/shacl#` |
| `rr` | `http://www.w3.org/ns/r2rml#` |
| `dcterms` | `http://purl.org/dc/terms/` |
| `vann` | `http://purl.org/vocab/vann/` |

Project: `mlo:` → `https://www.godiveios.com/marine-life/` (placeholder until finalized).

## RDFS class hierarchy (essentials)

From RDF Schema:

- `rdfs:Resource` — everything
- `rdfs:Class` — class of classes; `rdfs:Resource` is an instance of `rdfs:Class`
- `rdfs:Literal` — class of literal values
- `rdfs:Datatype` — class of datatypes; each datatype is a subclass of `rdfs:Literal`
- `rdf:Property` — class of properties
- `rdfs:Proposition` — class of propositions denoted by triple terms (RDF 1.2)

## Domain / range semantics (entailment)

```
P rdfs:domain C   →  subjects of P are instances of C
P rdfs:range C    →  objects of P are instances of C
```

Multiple domain/range statements on the same property are **conjoined**. They do **not** provide local class-specific restrictions (use OWL or SHACL for that).

## Triple-term reification (RDF 1.2 Schema)

- `rdf:reifies` — associates a resource with a proposition (`rdfs:Proposition`)
- Legacy `rdf:Statement` / `rdf:subject` / `rdf:predicate` / `rdf:object` exist but prefer triple terms + `rdf:reifies` for new work

### Reification vs annotation

| Construct | Asserts inner triple? | Typical use |
|-----------|----------------------|-------------|
| `rdf:reifies` + triple term only | No | Claims, hypotheses, quoted statements |
| Annotation `{\| ... \|}` | Yes | Provenance on facts also in the graph |

```turtle
VERSION "1.2"

# Unasserted claim
_:r rdf:reifies <<( :s :p :o )>> .

# Reified triple sugar
<< :s :p :o ~ :r >> :accordingTo :alice .

# Annotation (asserts + metadata)
:s :p :o ~ :r {| :accordingTo :alice |} .
```

## Version announcement

| Label | Meaning |
|-------|---------|
| `1.2` | Full RDF 1.2 including triple terms |
| `1.2-basic` | RDF 1.2 without triple terms |
| `1.1` | RDF 1.1 compatible |

```turtle
VERSION "1.2"
```

HTTP: `Content-Type: text/turtle; version=1.2`

## Concrete syntax choice

| Format | Use |
|--------|-----|
| Turtle | Default for ontology + data |
| TriG | Named graphs / datasets |
| N-Triples / N-Quads | Line-oriented interchange |
| JSON-LD | Web/API interchange |
| RDF/XML | Legacy only |

## Suggested IRI patterns (GoDive / scuba)

```turtle
PREFIX mlo: <https://www.godiveios.com/marine-life/>
BASE <https://www.godiveios.com/marine-life/>

mlo:Sighting a rdfs:Class .           # vocabulary
<species/TigerShark> a mlo:Species .  # instance
<sighting/42> a mlo:Sighting .
<site/SSYongala> a mlo:Site .
<country/Australia> a mlo:Country .
<water/CoralSea> a mlo:BodyOfWater .
<report/2024-03-15-Yongala> a mlo:SiteReport .
<taxon/Chordata> a mlo:Taxon .
```

Patterns: `species/{id}`, `taxon/{Name}`, `sighting/{id}`, `dive/{id}`, `snorkel/{id}`, `site/{id}`, `country/{slug}`, `water/{slug}`, `report/{id}`, `diver/{id}`, `trait/{id}`, `rank/{Rank}`.

Site characteristic graph: `Site` —`inCountry`→ `Country`, —`locatedInWater`→ `BodyOfWater`, —`siteWaterType`→ `WaterType`, catalog `siteMaxDepthM`; visit layer via `SiteReport` / `hasSighting`.

Link external authorities with `owl:sameAs`, `rdfs:seeAlso`, or project properties (e.g. AphiaID), rather than copying foreign IRIs as local primary keys without agreement.

## Canonical ontology files

| File | Role |
|------|------|
| `ontology/scuba-core.ttl` | Core scuba/marine vocabulary |
| `ontology/godive-activity.ttl` | Bridge to GoDive activity models |
| `ontology/taxonomy-seed.ttl` | Rank / taxonomy seeds |
| `ontology/dive-vocab-seed.ttl` | Controlled individuals (certainty, life stage, …) |

## Related stack

- **SHACL** — structural validation (`shapes/`)
- **R2RML** — RDB/JSON-via-SQLite → RDF (`mappings/`)
- **SPARQL** — query / similarity (`sparql/`)
