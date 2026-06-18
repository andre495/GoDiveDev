#!/usr/bin/env python3
"""
Build the GoDive marine life staging catalog from Caribbean Reef Life (EPUB).

Uses the book's scientific index + species profile pages as the source-of-truth
species list, enriches rows from FishBase / SeaLifeBase when names match, and
prefers book common names and field-guide descriptions.

Usage:
  python3 GoDiveMVP/Scripts/build_marine_life_catalog_from_crl.py --epub ~/Desktop/Caribbean\\ Reef\\ Life\\ 4.epub
  python3 GoDiveMVP/Scripts/build_marine_life_catalog_from_crl.py --sync-json --all
"""

from __future__ import annotations

import argparse
import csv
import subprocess
import sys
from pathlib import Path

import duckdb

from caribbean_reef_life_catalog_utils import extract_crl_master_species_from_epub
from fishbase_catalog_utils import (
    PROJECT_DIR,
    STAGING_WITH_IMAGE_FIELDS,
    cm_to_meters,
    depth_meters,
    empty_image_workflow_fields,
    load_config,
    make_uuid,
    normalize_scientific_name_for_match,
    prose_fields_from_fishbase,
    read_staging_rows,
    staging_fieldnames_for_path,
)

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_CONFIG_PATH = SCRIPT_DIR / "caribbean_reef_life_config.json"
FISH_CONFIG_PATH = SCRIPT_DIR / "fishbase_caribbean_config.json"
SLB_CONFIG_PATH = SCRIPT_DIR / "sealifebase_caribbean_config.json"
SYNC_SCRIPT = SCRIPT_DIR / "sync_marine_life_staging_to_json.py"
GENERATE_TAXONOMY_SCRIPT = SCRIPT_DIR / "generate_field_guide_taxonomy_swift.py"


def parquet_url(base: str, table: str) -> str:
    return f"{base}/{table}.parquet"


def build_fishbase_lookup_sql(base: str) -> str:
    return f"""
    WITH preferred_english_names AS (
        SELECT SpecCode, ComName AS common_name
        FROM (
            SELECT
                SpecCode,
                ComName,
                row_number() OVER (
                    PARTITION BY SpecCode
                    ORDER BY PreferredName DESC NULLS LAST, length(ComName) DESC, ComName
                ) AS rn
            FROM read_parquet('{parquet_url(base, "comnames")}')
            WHERE lower(trim(Language)) = 'english'
              AND ComName IS NOT NULL
              AND trim(ComName) <> ''
        )
        WHERE rn = 1
    )
    SELECT
        lower(trim(s.Genus) || ' ' || trim(s.Species)) AS match_key,
        s.SpecCode AS spec_code,
        coalesce(nullif(trim(s.FBname), ''), pen.common_name, trim(s.Genus) || ' ' || trim(s.Species)) AS common_name,
        trim(s.Genus) || ' ' || trim(s.Species) AS scientific_name,
        coalesce(nullif(trim(f.Family), ''), '') AS family_name,
        s.Length AS max_length_cm,
        s.DepthRangeShallow AS depth_shallow_m,
        s.DepthRangeDeep AS depth_deep_m,
        trim(s.Comments) AS comments,
        trim(s.BodyShapeI) AS body_shape
    FROM read_parquet('{parquet_url(base, "species")}') AS s
    LEFT JOIN preferred_english_names AS pen ON s.SpecCode = pen.SpecCode
    LEFT JOIN read_parquet('{parquet_url(base, "families")}') AS f ON s.FamCode = f.FamCode
    WHERE s.Saltwater = 1
      AND coalesce(s.Fresh, 0) = 0
      AND trim(s.Genus) <> ''
      AND trim(s.Species) <> ''
    """


def build_sealifebase_lookup_sql(base: str) -> str:
    return f"""
    WITH preferred_english_names AS (
        SELECT SpecCode, ComName AS common_name
        FROM (
            SELECT
                SpecCode,
                ComName,
                row_number() OVER (
                    PARTITION BY SpecCode
                    ORDER BY PreferredName DESC NULLS LAST, length(ComName) DESC, ComName
                ) AS rn
            FROM read_parquet('{parquet_url(base, "comnames")}')
            WHERE lower(trim(Language)) = 'english'
              AND ComName IS NOT NULL
              AND trim(ComName) <> ''
        )
        WHERE rn = 1
    )
    SELECT
        lower(trim(s.Genus) || ' ' || trim(s.Species)) AS match_key,
        s.SpecCode AS spec_code,
        coalesce(nullif(trim(s.FBname), ''), pen.common_name, trim(s.Genus) || ' ' || trim(s.Species)) AS common_name,
        trim(s.Genus) || ' ' || trim(s.Species) AS scientific_name,
        coalesce(nullif(trim(f.Family), ''), '') AS family_name,
        coalesce(nullif(trim(f.Order), ''), '') AS order_name,
        coalesce(nullif(trim(cl.Class), ''), '') AS class_name,
        s.Length AS max_length_cm,
        s.DepthRangeShallow AS depth_shallow_m,
        s.DepthRangeDeep AS depth_deep_m,
        trim(s.Comments) AS comments,
        trim(s.BodyShapeI) AS body_shape
    FROM read_parquet('{parquet_url(base, "species")}') AS s
    LEFT JOIN preferred_english_names AS pen ON s.SpecCode = pen.SpecCode
    LEFT JOIN read_parquet('{parquet_url(base, "families")}') AS f ON s.FamCode = f.FamCode
    LEFT JOIN read_parquet('{parquet_url(base, "classes")}') AS cl ON f.ClassNum = cl.ClassNum
    WHERE s.Saltwater = 1
      AND coalesce(s.Fresh, 0) = 0
      AND trim(s.Genus) <> ''
      AND trim(s.Species) <> ''
    """


def load_database_lookups(fish_config: dict, slb_config: dict) -> tuple[dict[str, dict], dict[str, dict]]:
    fish_columns = [
        "match_key",
        "spec_code",
        "common_name",
        "scientific_name",
        "family_name",
        "max_length_cm",
        "depth_shallow_m",
        "depth_deep_m",
        "comments",
        "body_shape",
    ]
    slb_columns = [
        "match_key",
        "spec_code",
        "common_name",
        "scientific_name",
        "family_name",
        "order_name",
        "class_name",
        "max_length_cm",
        "depth_shallow_m",
        "depth_deep_m",
        "comments",
        "body_shape",
    ]

    fish_rows = duckdb.sql(build_fishbase_lookup_sql(fish_config["parquet_base_url"])).fetchall()
    slb_rows = duckdb.sql(build_sealifebase_lookup_sql(slb_config["parquet_base_url"])).fetchall()

    fish_by_key: dict[str, dict] = {}
    for row in fish_rows:
        record = dict(zip(fish_columns, row))
        key = str(record.get("match_key") or "").strip()
        if key and key not in fish_by_key:
            fish_by_key[key] = record

    slb_by_key: dict[str, dict] = {}
    for row in slb_rows:
        record = dict(zip(slb_columns, row))
        key = str(record.get("match_key") or "").strip()
        if key and key not in slb_by_key:
            slb_by_key[key] = record

    return fish_by_key, slb_by_key


def stable_spec_code(match_key: str) -> int:
    return abs(hash(match_key)) % 900_000 + 100_000


def build_staging_row(
    book_row: dict[str, str],
    *,
    fish_hit: dict | None,
    slb_hit: dict | None,
    existing_by_key: dict[str, dict[str, str]],
    used_uuids: set[str],
) -> dict[str, str]:
    match_key = book_row["match_key"]
    existing = existing_by_key.get(match_key, {})

    category = (book_row.get("category") or "").strip()
    subcategory = (book_row.get("subCategory") or "").strip()
    family_name = ""
    spec_code = ""
    common_name = (book_row.get("commonName") or "").strip()
    scientific_name = (book_row.get("scientificName") or "").strip()
    max_size = (book_row.get("maxSizeMeters") or "").strip()
    min_depth = ""
    max_depth = ""
    prose = {
        "featureImageURL": "",
        "aboutText": (book_row.get("description") or "").strip(),
        "distinctiveFeatures": "",
        "Abundance": "",
        "habitatBehavior": "",
        "diverReaction": "",
        "minSizeMeters": "",
    }

    if fish_hit:
        spec_code = str(int(fish_hit["spec_code"]))
        family_name = str(fish_hit.get("family_name") or "").strip()
        if not common_name:
            common_name = str(fish_hit.get("common_name") or scientific_name).strip()
        if not max_size:
            max_size = cm_to_meters(fish_hit.get("max_length_cm"))
        min_depth = depth_meters(fish_hit.get("depth_shallow_m"))
        max_depth = depth_meters(fish_hit.get("depth_deep_m"))
        fb_prose = prose_fields_from_fishbase(
            fish_hit.get("comments"),
            fish_hit.get("body_shape"),
            None,
        )
        if not prose["aboutText"]:
            prose = fb_prose
        else:
            prose["distinctiveFeatures"] = fb_prose.get("distinctiveFeatures", "")
    elif slb_hit:
        spec_code = str(int(slb_hit["spec_code"]))
        family_name = str(slb_hit.get("family_name") or "").strip()
        if not common_name:
            common_name = str(slb_hit.get("common_name") or scientific_name).strip()
        if not max_size:
            max_size = cm_to_meters(slb_hit.get("max_length_cm"))
        min_depth = depth_meters(slb_hit.get("depth_shallow_m"))
        max_depth = depth_meters(slb_hit.get("depth_deep_m"))
        fb_prose = prose_fields_from_fishbase(
            slb_hit.get("comments"),
            slb_hit.get("body_shape"),
            None,
        )
        if not prose["aboutText"]:
            prose = fb_prose
        else:
            prose["distinctiveFeatures"] = fb_prose.get("distinctiveFeatures", "")

    if not common_name:
        common_name = scientific_name

    if not category:
        category = "fishes" if fish_hit else "invertebrates"

    if not spec_code:
        spec_code = f"crl-{stable_spec_code(match_key)}"

    uuid = (existing.get("uuid") or "").strip()
    if not uuid:
        uuid = make_uuid(common_name, stable_spec_code(match_key), used_uuids)
    else:
        used_uuids.add(uuid)

    row = {
        "uuid": uuid,
        "fishbase_spec_code": spec_code,
        "commonName": common_name,
        "scientificName": scientific_name,
        "category": category,
        "subCategory": subcategory,
        "familyName": family_name,
        "maxSizeMeters": max_size,
        "minDepthMeters": min_depth,
        "maxDepthMeters": max_depth,
        "needs_subcategory": "" if subcategory else "yes",
        **prose,
        **empty_image_workflow_fields(),
    }

    for field in (
        "featureImageURL",
        "featureImageResourceName",
        "imageLicense",
        "imageAttribution",
        "imageSource",
        "imageNeedsReview",
    ):
        existing_value = (existing.get(field) or "").strip()
        if existing_value:
            row[field] = existing_value

    return row


def run_sync(json_path: Path, include_all: bool) -> None:
    command = [sys.executable, str(SYNC_SCRIPT), "--json", str(json_path)]
    if include_all:
        command.append("--all")
    subprocess.run(command, check=True)


def run_generate_taxonomy(epub_path: Path) -> None:
    command = [sys.executable, str(GENERATE_TAXONOMY_SCRIPT), "--epub", str(epub_path)]
    subprocess.run(command, check=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG_PATH)
    parser.add_argument("--epub", type=Path, help="Path to Caribbean Reef Life EPUB")
    parser.add_argument("--sync-json", action="store_true")
    parser.add_argument("--all", action="store_true", help="Pass --all to JSON sync")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    config = load_config(args.config)
    fish_config = load_config(FISH_CONFIG_PATH)
    slb_config = load_config(SLB_CONFIG_PATH)

    epub_path = args.epub
    if epub_path is None:
        default_epub = config.get("default_epub_path")
        if not default_epub:
            print("Pass --epub or set default_epub_path in caribbean_reef_life_config.json", file=sys.stderr)
            return 1
        epub_path = Path(default_epub)
        if not epub_path.is_absolute():
            epub_path = PROJECT_DIR / epub_path
    epub_path = epub_path.expanduser()

    if not epub_path.exists():
        print(f"EPUB not found: {epub_path}", file=sys.stderr)
        return 1

    if not args.dry_run:
        print("Generating FieldGuideTaxonomy from book TOC...")
        run_generate_taxonomy(epub_path)

    staging_path = PROJECT_DIR / config["output_staging_csv"]
    json_path = PROJECT_DIR / config.get("output_json", "MockData/marine_life_sample.json")
    reference_path = PROJECT_DIR / config["reference_cache_csv"]

    print(f"Extracting master species list from {epub_path}...")
    book_rows = extract_crl_master_species_from_epub(epub_path)
    profile_count = sum(1 for row in book_rows if "description" in row and row.get("description"))
    print(f"Book species: {len(book_rows)} ({profile_count} with profile descriptions)")

    reference_path.parent.mkdir(parents=True, exist_ok=True)
    reference_fields = [
        "scientificName",
        "match_key",
        "genus",
        "commonName",
        "description",
        "bookPage",
        "indexSection",
        "category",
        "subCategory",
        "source",
    ]
    with reference_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=reference_fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(book_rows)
    print(f"Wrote reference cache: {reference_path}")

    print("Querying FishBase + SeaLifeBase for scientific-name matches...")
    fish_by_key, slb_by_key = load_database_lookups(fish_config, slb_config)

    _, existing_rows = read_staging_rows(staging_path)
    existing_by_key = {
        normalize_scientific_name_for_match(row.get("scientificName")): row
        for row in existing_rows
        if normalize_scientific_name_for_match(row.get("scientificName"))
    }
    used_uuids = {row.get("uuid", "") for row in existing_rows if row.get("uuid")}

    matched_fish = matched_slb = book_only = 0
    output_rows: list[dict[str, str]] = []
    for book_row in book_rows:
        key = book_row["match_key"]
        fish_hit = fish_by_key.get(key)
        slb_hit = None if fish_hit else slb_by_key.get(key)
        if fish_hit:
            matched_fish += 1
        elif slb_hit:
            matched_slb += 1
        else:
            book_only += 1
        output_rows.append(
            build_staging_row(
                book_row,
                fish_hit=fish_hit,
                slb_hit=slb_hit,
                existing_by_key=existing_by_key,
                used_uuids=used_uuids,
            )
        )

    print(f"Enrichment: FishBase {matched_fish}, SeaLifeBase {matched_slb}, book-only {book_only}")

    if args.dry_run:
        print("Dry run — staging CSV unchanged.")
        return 0

    fieldnames = staging_fieldnames_for_path(staging_path) or STAGING_WITH_IMAGE_FIELDS
    for row in output_rows:
        for field in fieldnames:
            row.setdefault(field, "")

    with staging_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(output_rows)

    print(f"Wrote {len(output_rows)} rows to {staging_path}")

    if args.sync_json:
        run_sync(json_path, args.all)
        print(f"Synced JSON to {json_path}")

    print(config.get("attribution", ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
