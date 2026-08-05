# SHACL Reference

Primary: [SHACL 1.2 Core](https://www.w3.org/TR/shacl12-core/)

Related family (use only when needed):

- [SHACL 1.2 SPARQL Extensions](https://www.w3.org/TR/shacl-sparql/)
- [SHACL 1.2 Node Expressions](https://www.w3.org/TR/shacl12-node-expr/)
- [SHACL 1.2 Rules](https://www.w3.org/TR/shacl12-rules/)

Namespace: `http://www.w3.org/ns/shacl#` (`sh:`)

## Well-formedness

A shapes graph is **ill-formed** if nodes violate SHACL syntax rules (Core appendix). Processors must signal failure. Common mistakes:

- `sh:targetClass` value that is not an IRI
- Property shape missing `sh:path`
- More than one value for any parameter of a multi-parameter component (e.g. conflicting `sh:pattern` / `sh:flags`)
- Blank node that is both a shape and an `rdfs:Class` (IRI required)
- Importing incompatible shape-graph versions via `owl:versionIRI` / `owl:incompatibleWith`

## Path expressions (Core)

`sh:path` may be:

| Kind | Form |
|------|------|
| Predicate | IRI |
| Sequence | RDF list: `sh:path ( ex:p1 ex:p2 )` |
| Alternative | `[ sh:alternativePath ( ex:p1 ex:p2 ) ]` |
| Inverse | `[ sh:inversePath ex:p ]` |
| Zero-or-more | `[ sh:zeroOrMorePath ex:p ]` |
| One-or-more | `[ sh:oneOrMorePath ex:p ]` |
| Zero-or-one | `[ sh:zeroOrOnePath ex:p ]` |

Prefer simple predicate paths unless the marine model needs multi-hop navigation.

## Severity and messages

| Term | Use |
|------|-----|
| `sh:Violation` | Default; fails conformance |
| `sh:Warning` | Softer; processor policy may still treat as non-conforming if configured |
| `sh:Info` | Informational |

```turtle
sh:property [
    sh:path mlo:aphiaId ;
    sh:datatype xsd:integer ;
    sh:minCount 1 ;
    sh:message "Species instances should link a WoRMS AphiaID."@en ;
    sh:severity sh:Warning ;
] .
```

## Closed shapes

```turtle
mlo:StrictSightingShape
    a sh:NodeShape ;
    sh:targetClass mlo:Sighting ;
    sh:closed true ;
    sh:ignoredProperties ( rdf:type ) ;
    sh:property [
        sh:path mlo:sightedOrganism ;
        sh:class mlo:OrganismConcept ;
        sh:minCount 1 ;
        sh:maxCount 1 ;
    ] .
```

Use for tightly curated records. Avoid closing broad taxonomic classes early.

## Shape vs class patterns

**Separate (default for this project):**

```turtle
mlo:Species a rdfs:Class .
mlo:SpeciesShape a sh:NodeShape ; sh:targetClass mlo:Species .
```

**Coupled (`sh:ShapeClass`):**

```turtle
mlo:Species a sh:ShapeClass ;
    sh:property [ sh:path mlo:scientificName ; sh:minCount 1 ] .
```

Prefer separate IRIs so ontology and validation evolve independently. If using `sh:ShapeClass`, consider `owl:imports` of the SHACL namespace so SHACL-unaware tools still see an `rdfs:Class`.

## Subclass graph note

`sh:class` and `sh:targetClass` need `rdf:type` / `rdfs:subClassOf` available to the processor. Options:

1. Materialize concrete types in instance data (`rr:class mlo:Species`) — preferred here
2. Include ontology axioms in the data graph or configured subclass graph
3. `sh:entailment` only if the validation stack supports the regime

## SPARQL extensions (escape hatch)

Use when Core cannot express the rule (cross-property comparisons, complex joins):

- `sh:sparql` with `sh:select`
- Custom constraint components

Keep SPARQL shapes isolated in `shapes/sparql/` if introduced.

## Suggested scuba shape set

| Shape | Target | Typical constraints |
|-------|--------|---------------------|
| Species | `mlo:Species` | commonName; scientificName; optional depth/size; classifiedAs |
| Taxon | `mlo:Taxon` | scientificName; hasRank; optional broaderTaxon |
| Country | `mlo:Country` | countryName; optional countryCode |
| BodyOfWater | `mlo:BodyOfWater` | waterName |
| Site | `mlo:Site` | siteName; inCountry; locatedInWater; siteWaterType; catalog depth; hasSiteReport; hasSighting |
| SiteReport | `mlo:SiteReport` | reportForSite; optional fromActivity; reported depth/conditions |
| InWaterActivity | `mlo:InWaterActivity` | activityDate; atSite; activityType |
| DiveActivity | `mlo:DiveActivity` | scuba fields (gas, tank, visibility, …) |
| SnorkelActivity | `mlo:SnorkelActivity` | snorkel fields |
| Sighting | `mlo:Sighting` | sightedOrganism; duringDive XOR duringSnorkel; optional sightingSite |
| MediaAsset | `mlo:MediaAsset` | mediaUrl; optional mediaType |

Controlled individuals: `ontology/dive-vocab-seed.ttl`.

Canonical shapes: `shapes/scuba-shapes.ttl`. Validate R2RML output against them before publishing.
