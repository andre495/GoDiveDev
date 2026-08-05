#!/usr/bin/env python3
"""Load GoDive marine_life.json → SQLite, apply R2RML, write Species individuals.

Usage (from project root or mappings/):
  python mappings/materialize_marine_life.py

Optional:
  --catalog PATH   Override path to marine_life.json
  --out PATH       Output Turtle (default: data/catalog/marine_life_species.ttl)
"""

from __future__ import annotations

import argparse
import json
import re
import sqlite3
import sys
from pathlib import Path
from urllib.parse import quote

from rdflib import Graph, Literal, Namespace, URIRef, RDF, XSD
from rdflib.namespace import RDFS

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_CATALOG = Path(
    "/Users/andrdugas/Desktop/godivemvp/GoDiveMVP/Resources/Catalog/marine_life.json"
)
DEFAULT_MAPPING = Path(__file__).resolve().parent / "marine_life.r2rml.ttl"
DEFAULT_DB = Path(__file__).resolve().parent / ".cache" / "marine_life_catalog.sqlite"
DEFAULT_OUT = ROOT / "data" / "catalog" / "marine_life_species.ttl"

RR = Namespace("http://www.w3.org/ns/r2rml#")
MLO = Namespace("https://www.godiveios.com/marine-life/")

COLUMNS = [
    "uuid",
    "common_name",
    "scientific_name",
    "category",
    "subcategory",
    "family_name",
    "description",
    "distinctive_features",
    "feature_image_resource",
    "feature_image",
    "feature_model",
    "max_size",
    "min_depth",
    "max_depth",
    "abundance",
    "habitat_behavior",
    "diver_reaction",
]

# Catalog quality fix: strip life-stage suffix from display common names
_JUVENILE_IN_NAME = re.compile(r"\s*\(\s*juvenile\s*\)\s*", re.IGNORECASE)


def clean_common_name(name: str | None) -> str | None:
    """Remove '(juvenile)' from common names; collapse leftover whitespace."""
    if name is None:
        return None
    text = str(name).strip()
    if not text:
        return None
    cleaned = _JUVENILE_IN_NAME.sub(" ", text)
    cleaned = re.sub(r"\s+", " ", cleaned).strip(" -")
    return cleaned or None


def load_json_to_sqlite(catalog_path: Path, db_path: Path) -> int:
    rows = json.loads(catalog_path.read_text(encoding="utf-8"))
    if not isinstance(rows, list):
        raise ValueError(f"Expected JSON array in {catalog_path}")

    db_path.parent.mkdir(parents=True, exist_ok=True)
    if db_path.exists():
        db_path.unlink()

    conn = sqlite3.connect(db_path)
    try:
        cols_sql = ", ".join(f'"{c}" TEXT' for c in COLUMNS)
        conn.execute(f'CREATE TABLE marine_life ({cols_sql})')
        for row in rows:
            values = []
            for c in COLUMNS:
                v = row.get(c)
                if c == "common_name":
                    v = clean_common_name(v if v not in (None, "") else None)
                if v is None or v == "":
                    values.append(None)
                else:
                    values.append(str(v))
            placeholders = ", ".join("?" for _ in COLUMNS)
            col_names = ", ".join(f'"{c}"' for c in COLUMNS)
            conn.execute(
                f"INSERT INTO marine_life ({col_names}) VALUES ({placeholders})",
                values,
            )
        conn.commit()
    finally:
        conn.close()
    return len(rows)


def _first(g: Graph, s, p):
    return next(g.objects(s, p), None)


def _expand_template(template: str, row: dict[str, str | None]) -> str | None:
    """R2RML IRI-safe template: omit triple if any referenced column is NULL."""

    def repl(match: re.Match[str]) -> str:
        col = match.group(1)
        val = row.get(col)
        if val is None:
            raise ValueError("null")
        # uuid/slug values are already IRI-safe; still escape reserved chars
        return quote(val, safe="-._~")

    try:
        return re.sub(r"\{([^}]+)\}", repl, template)
    except ValueError:
        return None


def _term_from_object_map(
    g: Graph, obj_map, row: dict[str, str | None]
) -> URIRef | Literal | None:
    constant = _first(g, obj_map, RR.constant)
    if constant is not None:
        if isinstance(constant, Literal):
            return constant
        return URIRef(str(constant))

    column = _first(g, obj_map, RR.column)
    template = _first(g, obj_map, RR.template)
    term_type = _first(g, obj_map, RR.termType)
    datatype = _first(g, obj_map, RR.datatype)
    language = _first(g, obj_map, RR.language)

    value: str | None
    if column is not None:
        value = row.get(str(column))
    elif template is not None:
        value = _expand_template(str(template), row)
    else:
        return None

    if value is None or value == "":
        return None

    if term_type == RR.IRI or (
        term_type is None and column is None and template is not None and str(template).startswith("http")
    ):
        # column mapped as IRI (e.g. feature_image URL)
        if term_type == RR.IRI:
            return URIRef(value)
        return URIRef(value)

    if term_type == RR.IRI:
        return URIRef(value)

    if language is not None:
        return Literal(value, lang=str(language))
    if datatype is not None:
        return Literal(value, datatype=URIRef(str(datatype)))
    return Literal(value)


def materialize(mapping_path: Path, db_path: Path) -> Graph:
    mapping = Graph()
    mapping.parse(mapping_path, format="turtle")

    out = Graph()
    out.bind("mlo", MLO)
    out.bind("rdf", RDF)
    out.bind("rdfs", RDFS)
    out.bind("xsd", XSD)

    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    try:
        for triples_map in mapping.subjects(RDF.type, RR.TriplesMap):
            logical = _first(mapping, triples_map, RR.logicalTable)
            table = _first(mapping, logical, RR.tableName)
            sql = _first(mapping, logical, RR.sqlQuery)
            if table is not None:
                query = f'SELECT * FROM "{table}"'
            elif sql is not None:
                query = str(sql)
            else:
                raise ValueError(f"No logical table for {triples_map}")

            subject_map = _first(mapping, triples_map, RR.subjectMap)
            subject_template = _first(mapping, subject_map, RR.template)
            classes = list(mapping.objects(subject_map, RR["class"]))

            pom_list = list(mapping.objects(triples_map, RR.predicateObjectMap))

            cur = conn.execute(query)
            for raw in cur.fetchall():
                row = {k: raw[k] for k in raw.keys()}
                subject_iri = _expand_template(str(subject_template), row)
                if subject_iri is None:
                    continue
                subject = URIRef(subject_iri)
                for cls in classes:
                    out.add((subject, RDF.type, URIRef(str(cls))))

                for pom in pom_list:
                    predicate = _first(mapping, pom, RR.predicate)
                    obj_map = _first(mapping, pom, RR.objectMap)
                    if predicate is None or obj_map is None:
                        # constant shortcuts
                        continue
                    obj = _term_from_object_map(mapping, obj_map, row)
                    if obj is not None:
                        out.add((subject, URIRef(str(predicate)), obj))
    finally:
        conn.close()
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description="Materialize marine life Species via R2RML")
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG)
    parser.add_argument("--mapping", type=Path, default=DEFAULT_MAPPING)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    if not args.catalog.is_file():
        print(f"Catalog not found: {args.catalog}", file=sys.stderr)
        return 1
    if not args.mapping.is_file():
        print(f"Mapping not found: {args.mapping}", file=sys.stderr)
        return 1

    print(f"Loading {args.catalog} → {args.db}")
    n = load_json_to_sqlite(args.catalog, args.db)
    print(f"  {n} rows in marine_life")

    print(f"Applying {args.mapping.name}")
    graph = materialize(args.mapping, args.db)
    print(f"  {len(graph)} triples, {len(set(graph.subjects()))} subjects")

    args.out.parent.mkdir(parents=True, exist_ok=True)
    # Prefixed Turtle for readability
    ttl = graph.serialize(format="turtle")
    header = (
        "# Generated by mappings/materialize_marine_life.py — do not edit by hand.\n"
        f"# Source: {args.catalog}\n"
        f"# Mapping: {args.mapping.name}\n\n"
    )
    args.out.write_text(header + ttl, encoding="utf-8")
    print(f"Wrote {args.out} ({args.out.stat().st_size:,} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
