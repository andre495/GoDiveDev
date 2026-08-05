---
name: shacl-constraints
description: >-
  Author and edit SHACL shapes graphs to validate RDF data: node shapes, property
  shapes, targets, cardinality, datatypes, class constraints, closed shapes, and
  validation reports. Use when writing SHACL, restrictions, constraints, validation,
  sh:targetClass, sh:property, or checking GoDive marine ontology instance data
  (Species, Sighting, DiveActivity, Site) against expected structure. Prefer
  SHACL 1.2 Core; use SPARQL extensions only when Core cannot express the rule.
---

# SHACL Constraints (Restrictions)

Grounded in W3C:

- [SHACL 1.2 Core](https://www.w3.org/TR/shacl12-core/)
- Classic [SHACL](https://www.w3.org/TR/shacl/) where still referenced
- SPARQL escape hatch: [SHACL 1.2 SPARQL Extensions](https://www.w3.org/TR/shacl-sparql/)

Shapes live in `marine life ontology/shapes/`. Data under validation: `data/` (+ types from `ontology/`).

## Roles

| Graph | Role |
|-------|------|
| **Shapes graph** | Constraints (`shapes/**/*.ttl`) |
| **Data graph** | Instance RDF to validate |

SHACL validates structure (and can inform UI/codegen). It does **not** replace RDFS meaning — use both: RDFS for vocabulary, SHACL for enforceable restrictions.

**SHACL vs RDFS inferencing:** By default SHACL does not require RDFS entailment. `sh:targetClass` / `sh:class` walk `rdf:type` + `rdfs:subClassOf` in the **data graph** (or configured subclass graph). Materialize types from R2RML (`rr:class`) so targets fire without relying on entailment engines.

## GoDive edit workflow

When adding or tightening restrictions:

1. Confirm the term exists in `ontology/` (skill `rdf-12-ontology`).
2. Edit `shapes/scuba-shapes.ttl` — prefer `sh:NodeShape` + `sh:targetClass`.
3. Set path, cardinality, `sh:datatype` or `sh:class` / `sh:nodeKind`.
4. Add `sh:message` for non-obvious rules.
5. After R2RML rematerialization, ensure catalog output still conforms.
6. Never silently weaken shapes to hide bad source data — call that out.

## Validation process (Core)

From SHACL 1.2 Core:

1. Collect **focus nodes** from targets (or nested `sh:node`).
2. For each focus node, evaluate all constraints on the shape (unless `sh:deactivated`).
3. Property shapes take **value nodes** along `sh:path` (or `sh:values` / `sh:defaultValue` expressions in 1.2).
4. Emit a **validation report** (`sh:ValidationReport`).

Ill-formed shapes → validation result is undefined; processors SHOULD fail. Fix syntax first.

## Minimal shape pattern

```turtle
PREFIX rdf:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX xsd:  <http://www.w3.org/2001/XMLSchema#>
PREFIX sh:   <http://www.w3.org/ns/shacl#>
PREFIX mlo:  <https://www.godiveios.com/marine-life/>

mlo:SpeciesShape
    a sh:NodeShape ;
    sh:targetClass mlo:Species ;
    sh:property [
        sh:path mlo:commonName ;
        sh:nodeKind sh:Literal ;
        sh:minCount 1 ;
        sh:name "common name" ;
        sh:message "Species should have at least one common name."@en ;
    ] ;
    sh:property [
        sh:path mlo:scientificName ;
        sh:datatype xsd:string ;
        sh:maxCount 1 ;
    ] ;
    sh:property [
        sh:path mlo:classifiedAs ;
        sh:class mlo:Taxon ;
        sh:maxCount 1 ;
    ] .
```

## Essential vocabulary

### Shape types

- `sh:NodeShape` — constraints on focus nodes
- `sh:PropertyShape` — constraints on values along `sh:path`
- `sh:ShapeClass` — shortcut: both `rdfs:Class` and node shape (instances auto-targeted). Prefer **separate** shape IRIs in this project.

### Targets → focus nodes

| Property | Selects |
|----------|---------|
| `sh:targetClass` | SHACL instances of a class |
| `sh:targetNode` | Explicit nodes |
| `sh:targetSubjectsOf` | Subjects of a predicate |
| `sh:targetObjectsOf` | Objects of a predicate |
| `sh:targetWhere` | Nodes conforming to a filter shape (SHACL 1.2) |

Implicit: a shape that is also an `rdfs:Class` (or `sh:ShapeClass`) targets its instances. Blank-node class+shape combo is **ill-formed** — use an IRI.

### High-value Core constraints

| Parameter | Meaning |
|-----------|---------|
| `sh:path` | Property path (required on property shapes) |
| `sh:minCount` / `sh:maxCount` | Cardinality |
| `sh:datatype` | Literal datatype |
| `sh:class` | Value is SHACL instance of class |
| `sh:nodeKind` | IRI / BlankNode / Literal / combinations |
| `sh:in` | Enumeration |
| `sh:pattern` (+ optional `sh:flags`) | Regex |
| `sh:minInclusive` / `sh:maxInclusive` / exclusive variants | Numeric/date ranges |
| `sh:minLength` / `sh:maxLength` | String length |
| `sh:node` | Nested node shape on values |
| `sh:closed` + `sh:ignoredProperties` | Only listed properties allowed |
| `sh:hasValue` | Must include a specific value |
| `sh:uniqueLang` | At most one value per language tag |
| `sh:and` / `sh:or` / `sh:xone` / `sh:not` | Boolean combinations |

Multiple single-parameter constraints of the same kind on one shape are **conjoined**. Multi-parameter components (e.g. `sh:pattern` + `sh:flags`) must not have duplicate conflicting parameter values — that is ill-formed.

## Validation report reading

- `sh:conforms false` → at least one disallowed-severity result (default severity `sh:Violation`)
- Each `sh:ValidationResult`: `sh:focusNode`, `sh:resultPath`, `sh:value`, `sh:sourceConstraintComponent`, `sh:resultMessage`, `sh:resultSeverity`

Fix **data** or **shape** deliberately.

## Authoring checklist

- [ ] Shapes in `shapes/`, not mixed into instance dumps
- [ ] Every property shape has `sh:path`
- [ ] Cardinality stated where the domain requires it
- [ ] IRIs vs literals distinguished (`sh:class` vs `sh:datatype` / `sh:nodeKind`)
- [ ] `sh:message` on non-obvious constraints
- [ ] Avoid ill-formed shapes (literal `sh:targetClass`, missing path, bad multi-parameter components)
- [ ] Closed shapes only when the property set is truly fixed
- [ ] XOR-style rules (e.g. dive vs snorkel activity link) use `sh:xone` / `sh:or` carefully

## Do / don't

| Do | Don't |
|----|--------|
| Mirror ontology classes with separate node shapes | Duplicate the full RDFS hierarchy inside every shape |
| Use Core first | Jump to SPARQL for simple cardinality |
| Keep reusable named property shapes when shared | Weaken shapes silently for bad catalog rows |
| Validate after R2RML materialization | Assume DB nullability equals RDF conformance |

## Additional resources

- Constraint catalog, paths, severity: [reference.md](reference.md)
- Ontology modeling: skill `rdf-12-ontology`
- Mapping DB → RDF: skill `r2rml-mapping`
