# R2RML Reference

Normative: [R2RML](https://www.w3.org/TR/r2rml/) (W3C Recommendation 27 September 2012)

Vocabulary IRI: `http://www.w3.org/ns/r2rml#` — [term index](https://www.w3.org/ns/r2rml)

Companion: [A Direct Mapping of Relational Data to RDF](https://www.w3.org/TR/rdb-direct-mapping/)

## Core classes

| Class | Meaning |
|-------|---------|
| `rr:TriplesMap` | Row → triples rule |
| `rr:LogicalTable` | Abstract; `rr:BaseTableOrView` or `rr:R2RMLView` |
| `rr:SubjectMap` | Generates subjects (+ optional types/graphs) |
| `rr:PredicateMap` | Generates predicates |
| `rr:ObjectMap` | Generates objects |
| `rr:PredicateObjectMap` | Pairs predicate and object maps |
| `rr:RefObjectMap` | Object from parent triples map + join |
| `rr:Join` | `rr:child` / `rr:parent` column pair |
| `rr:GraphMap` | Named graph IRI for generated triples |

## Properties quick index

| Property | On | Notes |
|----------|-----|-------|
| `rr:logicalTable` | Triples map | Exactly one |
| `rr:tableName` | Base table/view | SQL identifier; may be schema-qualified `catalog.schema.table` |
| `rr:sqlQuery` | R2RML view | SELECT query; result columns become `rr:column` targets |
| `rr:sqlVersion` | Optional | SQL version IRI |
| `rr:subjectMap` / `rr:subject` | Triples map | Subject term map or constant shortcut |
| `rr:predicateObjectMap` | Triples map | Zero or more |
| `rr:predicateMap` / `rr:predicate` | POM | |
| `rr:objectMap` / `rr:object` | POM | |
| `rr:parentTriplesMap` | Ref object map | |
| `rr:joinCondition` | Ref object map | One or more joins |
| `rr:child` / `rr:parent` | Join | Column names (strings) |
| `rr:template` | Term map | `{COLUMN}` placeholders |
| `rr:column` | Term map | |
| `rr:constant` | Term map | |
| `rr:termType` | Term map | IRI / BlankNode / Literal |
| `rr:datatype` | Literal term map | XSD or other datatype IRI |
| `rr:language` | Literal term map | BCP47 tag |
| `rr:class` | Subject map | One or more `rdf:type` values |
| `rr:graph` / `rr:graphMap` | Subject or POM | Named graph |
| `rr:inverseExpression` | Term map | Optional reverse mapping hint |

## Shortcuts

Constant shortcuts:

```turtle
rr:predicate ex:name ;
rr:object "SMITH" ;
```

equivalent to predicate/object maps with `rr:constant`.

## NULL handling

If a term map uses `rr:column` or a template referencing a NULL column, **no RDF term** (and thus no triple for that POM) is generated for that row. Design SHACL `sh:minCount` accordingly.

## IRI-safe templates

From R2RML §7.3: for term type `rr:IRI`, each substituted value is transformed so characters outside RFC 3987 `iunreserved` are percent-encoded.

Guidance:

- Prefer opaque keys (`uuid`) over display names in IRIs
- Separate multi-column templates with safe separators (`/`, `-`, or sub-delims)
- Keep hosts/paths consistent with the ontology base IRI `https://example.org/marine-life/`

Invalid IRIs produced by term maps are **data errors**.

## Named graphs

By default triples go to the **default graph**. Use `rr:graph` / `rr:graphMap` when separating sources (e.g. per dataset). Default graph is fine for a single curated marine KG.

## Default mappings

An R2RML processor MAY generate a Direct Mapping–style default mapping for customization. This project authors mappings by hand against `mlo:`.

## Processor expectations

R2RML processors may materialize RDF dumps, offer virtual SPARQL over the DB, or expose Linked Data HTTP. Keep mappings portable Turtle; document any vendor extensions in-repo.

## Mapping files (this repo)

```
mappings/
  marine_life.r2rml.ttl          # catalog → mlo:Species
  dive_sites.r2rml.ttl           # sites → Site + Country + BodyOfWater
  materialize_marine_life.py
  materialize_dive_sites.py
```

### Marine life catalog pipeline

1. Source JSON (GoDive catalog)
2. SQLite table `marine_life`
3. Mapping `marine_life.r2rml.ttl`
4. Output `data/catalog/marine_life_species.ttl`

```bash
cd "marine life ontology"
python mappings/materialize_marine_life.py
```

### Dive sites characteristic graph pipeline

1. Source: `catalog-cdn/public/catalog/v1/dive_sites.json`
2. SQLite: `dive_sites`, `countries`, `bodies_of_water`, `dive_site_tags`
3. Mapping `dive_sites.r2rml.ttl` → Site + `inCountry` + `locatedInWater` + water type + depth
4. Output `data/catalog/dive_sites.ttl`

```bash
cd "marine life ontology"
python mappings/materialize_dive_sites.py
```
