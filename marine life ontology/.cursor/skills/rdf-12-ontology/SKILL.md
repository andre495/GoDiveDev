---
name: rdf-12-ontology
description: >-
  Author and edit RDF 1.2 ontologies and instance graphs in Turtle using RDFS
  classes/properties, IRIs, literals, blank nodes, triple terms, and annotations.
  Use when creating or changing ontology classes/properties, writing Turtle/TriG,
  knowledge graphs, provenance via rdf:reifies, or editing the GoDive scuba marine
  life ontology (mlo:, OrganismConcept, Sighting, DiveActivity, SnorkelActivity).
---

# RDF 1.2 Ontology Authoring

Grounded in W3C:

- [RDF 1.2 Concepts](https://www.w3.org/TR/rdf12-concepts/)
- [RDF 1.2 Schema](https://www.w3.org/TR/rdf12-schema/)
- [RDF 1.2 Turtle](https://www.w3.org/TR/rdf12-turtle/)
- [RDF 1.2 Primer](https://www.w3.org/TR/rdf12-primer/)
- [What’s New in RDF 1.2](https://www.w3.org/TR/rdf12-new/)

Before editing, also read `marine life ontology/.cursor/rules/marine-kg-project.mdc`.

## Project layout

All paths relative to `marine life ontology/`:

| Path | Contents |
|------|----------|
| `ontology/` | TBox — classes, properties, RDFS axioms (`scuba-core.ttl`, `godive-activity.ttl`, seeds) |
| `data/` | ABox — instance graphs |
| `shapes/` | SHACL — use skill `shacl-constraints` |
| `mappings/` | R2RML — use skill `r2rml-mapping` |
| `sparql/` | Similarity / query examples |

Prefer **Turtle** (`.ttl`). Use TriG only when named graphs are required.

## GoDive edit workflow

When changing vocabulary for the app:

1. Map the change to Swift models under `GoDiveMVP/Models/` (especially `MarineLife`, dive/snorkel activities, sites, sightings).
2. Edit TBox in `ontology/` first (`scuba-core.ttl` / `godive-activity.ttl`).
3. Update SHACL in `shapes/scuba-shapes.ttl` (skill `shacl-constraints`).
4. Update R2RML + rematerialize if catalog/DB-backed (`mappings/`, skill `r2rml-mapping`).
5. Keep instance examples in `data/` in sync when they illustrate the term.
6. Do **not** put `sh:` or `rr:` terms in ontology TBox files except documented imports.

Delivery order: vocabulary → shapes → mappings.

## Core data model (must follow)

An RDF graph is a set of **triples** `(subject, predicate, object)`.

| Position | Allowed terms (RDF 1.2) |
|----------|-------------------------|
| Subject | IRI, blank node |
| Predicate | IRI |
| Object | IRI, blank node, literal, **triple term** |

**Term kinds:**

1. **IRI** — global identity; same IRI = same resource
2. **Literal** — lexical form + datatype; or language-tagged / directional language-tagged string
3. **Blank node** — local existential; never use as a stable public ID
4. **Triple term** — a triple used as an object; denotes a proposition (`rdfs:Proposition`)

RDFS `domain` / `range` are **entailment axioms**, not closed validation. Multiple domain/range values are **conjoined** (subjects/objects are instances of *all* stated classes). Enforce cardinality/datatype with SHACL.

## RDFS modeling primitives

Use these for the TBox:

| Term | Role |
|------|------|
| `rdfs:Class` | Class of classes |
| `rdf:Property` | Class of properties |
| `rdf:type` (`a`) | Instance membership |
| `rdfs:subClassOf` | Class hierarchy (transitive) |
| `rdfs:subPropertyOf` | Property hierarchy (transitive) |
| `rdfs:domain` / `rdfs:range` | Entailment on subjects / objects |
| `rdfs:label` / `rdfs:comment` | Human documentation |
| `rdfs:seeAlso` / `rdfs:isDefinedBy` | Links |

Light OWL is OK for ontology headers (`owl:Ontology`, `owl:versionInfo`, `owl:sameAs` to external authorities). Prefer RDFS for everyday class/property modeling unless the user asks for OWL restrictions.

## Turtle conventions

```turtle
PREFIX rdf:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX xsd:  <http://www.w3.org/2001/XMLSchema#>
PREFIX mlo:  <https://example.org/marine-life/>
BASE <https://example.org/marine-life/>

mlo:Species a rdfs:Class ;
    rdfs:subClassOf mlo:OrganismConcept ;
    rdfs:label "species"@en ;
    rdfs:comment "Species-level organism concept (GoDive MarineLife rows)."@en .

mlo:scientificName a rdf:Property ;
    rdfs:range rdfs:Literal ;
    rdfs:label "scientific name"@en .
```

Rules:

- New files: `PREFIX` / `BASE` / `VERSION` (SPARQL-aligned), not `@prefix`.
- Use `a` for `rdf:type`.
- Project prefix: `mlo:` → `https://example.org/marine-life/`.
- **Vocabulary** terms: `mlo:TermName`.
- **Instances**: `BASE` + relative IRI — `<species/TigerShark>`, never `mlo:species/Tiger` (slash breaks prefixed names).
- Typed literals: `"42"^^xsd:integer`, dates `xsd:date` / `xsd:dateTime`.
- Language tags: `"Tiger shark"@en`.

## RDF 1.2: reification and annotations

- Triple term: `<<( :s :p :o )>>`
- Reifying: `:r rdf:reifies <<( :s :p :o )>>` (does **not** assert the inner triple)
- Annotation asserts the triple **and** attaches metadata:

```turtle
VERSION "1.2"
PREFIX mlo: <https://example.org/marine-life/>
PREFIX prov: <http://www.w3.org/ns/prov#>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>

mlo:species/GaleocerdoCuvier mlo:occursIn mlo:region/CoralSea
    ~ mlo:obs/42 {|
        prov:wasAttributedTo mlo:agent/AIMS ;
        mlo:observedOn "2024-03-15"^^xsd:date
    |} .
```

Use annotations for provenance, confidence, and source — not for every taxonomy fact.

| Version label | Meaning |
|---------------|---------|
| `"1.2"` | Full RDF 1.2 (triple terms) |
| `"1.2-basic"` | RDF 1.2 without triple terms |
| `"1.1"` | RDF 1.1 compatible |

Announce `VERSION` only when using 1.2-specific features.

## Domain modeling priorities (GoDive)

Primary: `Sighting`, `InWaterActivity` → `DiveActivity` / `SnorkelActivity`, `Site`, depth, conditions, observers, media.

Supporting: `OrganismConcept` / `Species`, `Taxon`, ranks, physical traits for ID.

Bridge file: `ontology/godive-activity.ttl`.

## Authoring checklist

- [ ] Stable `mlo:` namespace; labels/comments on public terms
- [ ] Classes `rdfs:Class`; properties `rdf:Property` with useful domain/range
- [ ] Instance IRIs use `BASE` + relative paths
- [ ] External taxa linked (`owl:sameAs`, `rdfs:seeAlso`, AphiaID) — do not mint silent duplicates of WoRMS
- [ ] TBox/ABox separated; SHACL owns validation
- [ ] RDF 1.2 features only when justified

## Do / don't

| Do | Don't |
|----|--------|
| Separate `ontology/` from `data/` | Mix `rr:` / `sh:` into TBox |
| Reuse well-known vocabs (PROV, SKOS, Darwin Core) when they fit | Expect RDFS domain/range to reject bad data |
| Align terms with GoDive Swift field names in comments | Use `mlo:path/with/slashes` as prefixed names |
| Annotate contested/sourced statements | Reify every triple by default |

## Additional resources

- Vocabulary, IRI patterns, syntax notes: [reference.md](reference.md)
- Constraints: skill `shacl-constraints`
- Relational loading: skill `r2rml-mapping`
