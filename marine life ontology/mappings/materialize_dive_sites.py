#!/usr/bin/env python3
"""Load GoDive dive_sites.json → SQLite, apply R2RML, write Site characteristic graph.

Emits mlo:Site individuals plus linked mlo:Country and mlo:BodyOfWater resources.

Usage (from project root or mappings/):
  python mappings/materialize_dive_sites.py

Optional:
  --catalog PATH   Override path to dive_sites.json
  --out PATH       Output Turtle (default: data/catalog/dive_sites.ttl)
"""

from __future__ import annotations

import argparse
import json
import re
import sqlite3
import sys
import unicodedata
from pathlib import Path

# Reuse the shared R2RML materializer from the marine-life pipeline
sys.path.insert(0, str(Path(__file__).resolve().parent))
from materialize_marine_life import materialize  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
REPO_ROOT = ROOT.parent
DEFAULT_CATALOG = REPO_ROOT / "catalog-cdn" / "public" / "catalog" / "v1" / "dive_sites.json"
DEFAULT_MAPPING = Path(__file__).resolve().parent / "dive_sites.r2rml.ttl"
DEFAULT_DB = Path(__file__).resolve().parent / ".cache" / "dive_sites_catalog.sqlite"
DEFAULT_OUT = ROOT / "data" / "catalog" / "dive_sites.ttl"

WATER_TYPE = {
    "saltwater": "https://www.godiveios.com/marine-life/waterType/Saltwater",
    "freshwater": "https://www.godiveios.com/marine-life/waterType/Freshwater",
}
FRESH_ENV = {"lake", "river", "quarry", "freshwater", "cenote", "spring", "cave"}

SITE_COLUMNS = [
    "id",
    "name",
    "country",
    "country_code",
    "country_slug",
    "latitude",
    "longitude",
    "max_depth_m",
    "entry",
    "environment",
    "sea_name",
    "water_slug",
    "water_type_iri",
]


def _water_type_iri(environment: str | None) -> str:
    env = (environment or "").strip().lower()
    if env in FRESH_ENV:
        return WATER_TYPE["freshwater"]
    return WATER_TYPE["saltwater"]


def _clean_text(value) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def slugify(value: str) -> str:
    """Stable ASCII slug for country/{slug} and water/{slug} IRIs."""
    text = unicodedata.normalize("NFKD", value)
    text = text.encode("ascii", "ignore").decode("ascii")
    text = re.sub(r"[^A-Za-z0-9]+", "-", text).strip("-")
    if not text:
        return "unknown"
    # Title-case segments for readable IRIs (Red-Sea → Red-Sea kept; red sea → Red-Sea)
    parts = [p[:1].upper() + p[1:] if p else p for p in text.split("-")]
    return "-".join(parts)


def load_json_to_sqlite(catalog_path: Path, db_path: Path) -> tuple[int, int, int, int]:
    rows = json.loads(catalog_path.read_text(encoding="utf-8"))
    if not isinstance(rows, list):
        raise ValueError(f"Expected JSON array in {catalog_path}")

    db_path.parent.mkdir(parents=True, exist_ok=True)
    if db_path.exists():
        db_path.unlink()

    conn = sqlite3.connect(db_path)
    tag_count = 0
    countries: dict[str, tuple[str, str | None]] = {}  # slug → (name, code)
    waters: dict[str, str] = {}  # slug → name
    try:
        cols_sql = ", ".join(f'"{c}" TEXT' for c in SITE_COLUMNS)
        conn.execute(f"CREATE TABLE dive_sites ({cols_sql})")
        conn.execute(
            'CREATE TABLE dive_site_tags ("site_id" TEXT, "tag" TEXT)'
        )
        conn.execute(
            'CREATE TABLE countries ("slug" TEXT PRIMARY KEY, "name" TEXT, "code" TEXT)'
        )
        conn.execute(
            'CREATE TABLE bodies_of_water ("slug" TEXT PRIMARY KEY, "name" TEXT)'
        )

        for row in rows:
            site_id = _clean_text(row.get("id"))
            if not site_id:
                continue

            country = _clean_text(row.get("country"))
            country_code = _clean_text(row.get("countryCode"))
            country_slug = slugify(country) if country else None
            if country and country_slug:
                prev = countries.get(country_slug)
                if prev is None:
                    countries[country_slug] = (country, country_code)
                elif country_code and not prev[1]:
                    countries[country_slug] = (prev[0], country_code)

            sea_name = _clean_text(row.get("seaName"))
            water_slug = slugify(sea_name) if sea_name else None
            if sea_name and water_slug:
                waters.setdefault(water_slug, sea_name)

            values = {
                "id": site_id,
                "name": _clean_text(row.get("name")),
                "country": country,
                "country_code": country_code,
                "country_slug": country_slug,
                "latitude": None
                if row.get("latitude") is None
                else str(row.get("latitude")),
                "longitude": None
                if row.get("longitude") is None
                else str(row.get("longitude")),
                "max_depth_m": None
                if row.get("maxDepthMeters") is None
                else str(row.get("maxDepthMeters")),
                "entry": _clean_text(row.get("entry")),
                "environment": _clean_text(row.get("environment")),
                "sea_name": sea_name,
                "water_slug": water_slug,
                "water_type_iri": _water_type_iri(row.get("environment")),
            }
            placeholders = ", ".join("?" for _ in SITE_COLUMNS)
            col_names = ", ".join(f'"{c}"' for c in SITE_COLUMNS)
            conn.execute(
                f"INSERT INTO dive_sites ({col_names}) VALUES ({placeholders})",
                [values[c] for c in SITE_COLUMNS],
            )

            for tag in row.get("topologies") or []:
                cleaned = _clean_text(tag)
                if not cleaned:
                    continue
                conn.execute(
                    'INSERT INTO dive_site_tags ("site_id", "tag") VALUES (?, ?)',
                    (site_id, cleaned),
                )
                tag_count += 1

        for slug, (name, code) in sorted(countries.items()):
            conn.execute(
                'INSERT INTO countries ("slug", "name", "code") VALUES (?, ?, ?)',
                (slug, name, code),
            )
        for slug, name in sorted(waters.items()):
            conn.execute(
                'INSERT INTO bodies_of_water ("slug", "name") VALUES (?, ?)',
                (slug, name),
            )

        conn.commit()
        site_count = conn.execute("SELECT COUNT(*) FROM dive_sites").fetchone()[0]
    finally:
        conn.close()
    return site_count, tag_count, len(countries), len(waters)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Materialize dive Site characteristic graph via R2RML"
    )
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
    n_sites, n_tags, n_countries, n_waters = load_json_to_sqlite(args.catalog, args.db)
    print(
        f"  {n_sites} sites, {n_tags} topology tags, "
        f"{n_countries} countries, {n_waters} bodies of water"
    )

    print(f"Applying {args.mapping.name}")
    graph = materialize(args.mapping, args.db)
    site_count = len(set(graph.subjects()))
    print(f"  {len(graph)} triples, {site_count} subjects")

    args.out.parent.mkdir(parents=True, exist_ok=True)
    ttl = graph.serialize(format="turtle")
    header = (
        "# Generated by mappings/materialize_dive_sites.py — do not edit by hand.\n"
        f"# Source: {args.catalog}\n"
        f"# Mapping: {args.mapping.name}\n\n"
    )
    args.out.write_text(header + ttl, encoding="utf-8")
    print(f"Wrote {args.out} ({args.out.stat().st_size:,} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
