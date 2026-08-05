---
name: r2rml-mapping
description: >-
  Author R2RML mappings that transform relational tables, views, and SQL queries
  into RDF triples aligned with the GoDive marine ontology. Use when writing
  R2RML, triples maps, rr:logicalTable, rr:subjectMap, rr:predicateObjectMap,
  joins via rr:parentTriplesMap, R2RML views, materialize_marine_life.py,
  or populating catalog Turtle from marine_life.json / dive sites.
---

# R2RML Mapping

Grounded in the W3C Recommendation [R2RML: RDB to RDF Mapping Language](https://www.w3.org/TR/r2rml/) (27 September 2012).

Mappings are Turtle under `marine life ontology/mappings/`. Namespace: `http://www.w3.org/ns/r2rml#` (`rr:`).

Companion (not used by default): [Direct Mapping](https://www.w3.org/TR/rdb-direct-mapping/) — automatic default graph; this project prefers **custom R2RML** for controlled `mlo:` vocabulary.

## Role in this project

```
JSON/SQLite  --R2RML-->  RDF data graph  --SHACL-->  validated KG
                  \                         ^
                   \---- uses terms from ontology/
```

1. Ontology terms exist in `ontology/` first (skill `rdf-12-ontology`).
2. R2RML produces instance triples using those IRIs.
3. SHACL validates the output (skill `shacl-constraints`).

## GoDive edit workflow

Catalog pipeline (marine life):

1. Source: `GoDiveMVP/Resources/Catalog/marine_life.json` (path may vary by checkout)
2. Load SQLite table `marine_life` (R2RML needs a logical table)
3. Mapping: `mappings/marine_life.r2rml.ttl`
4. Materializer: `python mappings/materialize_marine_life.py`
5. Output: `data/catalog/marine_life_species.ttl`
6. Re-check `shapes/scuba-shapes.ttl`

Dive sites: `mappings/dive_sites.r2rml.ttl` + `materialize_dive_sites.py` → `data/catalog/dive_sites.ttl`.

When changing a mapped predicate: update ontology → shapes → R2RML column/template → rematerialize.

## Workflow (generic)

1. Inventory tables/columns/PKs/FKs (and SQL for derived fields).
2. Choose IRI templates matching ontology URI patterns.
3. One **triples map** per logical entity (or per table when 1:1).
4. Map columns → predicates; set `rr:termType`, `rr:datatype`, `rr:language`.
5. Link entities with `rr:parentTriplesMap` + `rr:joinCondition`, or an `rr:sqlQuery` view.
6. Materialize; run SHACL on the RDF result.

## Anatomy of a triples map

Every triples map **must** have:

- exactly one `rr:logicalTable`
- exactly one subject map (`rr:subjectMap` or shortcut `rr:subject`)

And may have zero or more `rr:predicateObjectMap` entries.

All `rr:column` / template `{COLUMN}` names must exist in that logical table.

### Logical table kinds

| Form | When |
|------|------|
| `rr:tableName` | Base table or DB view (optionally schema-qualified) |
| `rr:sqlQuery` | R2RML view (SQL in the mapping); optional `rr:sqlVersion` |

### Term maps

Subject, predicate, and object maps are **term maps**. Each uses exactly one of:

| Property | Meaning |
|----------|---------|
| `rr:constant` | Fixed IRI/literal |
| `rr:column` | Cell value from named column |
| `rr:template` | String with `{COLUMN}` placeholders |

Optional: `rr:termType` (`rr:IRI` \| `rr:BlankNode` \| `rr:Literal`), `rr:datatype`, `rr:language`, `rr:class` (on subject maps → `rdf:type`).

Defaults (spec): templates/columns for subjects default toward IRIs; set `rr:termType rr:Literal` when a template should produce a literal.

## Template pattern (marine)

```turtle
PREFIX rr:  <http://www.w3.org/ns/r2rml#>
PREFIX mlo: <https://www.godiveios.com/marine-life/>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>

<#MarineLifeSpeciesMap>
    a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "marine_life" ] ;
    rr:subjectMap [
        rr:template "https://www.godiveios.com/marine-life/species/{uuid}" ;
        rr:class mlo:Species ;
    ] ;
    rr:predicateObjectMap [
        rr:predicate mlo:scientificName ;
        rr:objectMap [
            rr:column "scientific_name" ;
            rr:datatype xsd:string ;
        ] ;
    ] ;
    rr:predicateObjectMap [
        rr:predicate mlo:commonName ;
        rr:objectMap [
            rr:column "common_name" ;
            rr:language "en" ;
        ] ;
    ] .
```

## Joining related entities

```turtle
<#ObservationMap>
    rr:logicalTable [ rr:tableName "observation" ] ;
    rr:subjectMap [
        rr:template "https://www.godiveios.com/marine-life/sighting/{obs_id}" ;
        rr:class mlo:Sighting ;
    ] ;
    rr:predicateObjectMap [
        rr:predicate mlo:sightedOrganism ;
        rr:objectMap [
            rr:parentTriplesMap <#SpeciesMap> ;
            rr:joinCondition [
                rr:child "species_id" ;
                rr:parent "species_id" ;
            ] ;
        ] ;
    ] .
```

`rr:child` / `rr:parent` are column **name strings** in the child and parent logical tables.

## R2RML view (computed columns)

```turtle
<#SpeciesWithStats>
    rr:sqlQuery """
        SELECT s.uuid, s.scientific_name,
               COUNT(o.obs_id) AS obs_count
        FROM marine_life s
        LEFT JOIN observation o ON o.species_id = s.uuid
        GROUP BY s.uuid, s.scientific_name
    """ .
```

Use views for aggregates, filters, and normalization SQL should own.

## NULL and IRI-safe rules (spec-critical)

- If a column/template value is SQL **NULL**, **no RDF term** is generated → that POM emits no triple for the row. Align SHACL `sh:minCount` with sparse sources.
- For `rr:termType rr:IRI`, template substitutions use the **IRI-safe** form (percent-encode characters outside RFC 3987 `iunreserved`).
- Prefer opaque keys (`uuid`) in IRIs over display names.
- Invalid generated IRIs are **data errors** per R2RML.

## Authoring checklist

- [ ] Target predicates/classes exist in `ontology/`
- [ ] IRI templates match `https://www.godiveios.com/marine-life/...` policy
- [ ] `rr:class` aligns with SHACL `sh:targetClass`
- [ ] Literals get `rr:datatype` or `rr:language`
- [ ] NULL → no triple accounted for in shapes
- [ ] Joins cover needed FK relationships
- [ ] Mapping is valid Turtle using only `rr:` for mapping structure
- [ ] Rematerialize and spot-check output Turtle

## Do / don't

| Do | Don't |
|----|--------|
| Align templates with ontology IRI policy | Invent ad-hoc IRIs that diverge from `ontology/` |
| Push heavy transforms into SQL views when clearer | Mega-templates for logic SQL should own |
| Validate output with SHACL | Treat successful R2RML execution as semantic quality |
| One triples map per clear subject type | Overload one map with unrelated entities |
| Stay on the W3C `rr:` vocabulary | Vendor-specific mapping properties |

## Additional resources

- Vocabulary index and edge cases: [reference.md](reference.md)
- Target terms: skill `rdf-12-ontology`
- Output validation: skill `shacl-constraints`
