#!/usr/bin/env python3
"""
Extract Caribbean saltwater fish facts from FishBase parquet snapshots.

Outputs MockData/marine_life_caribbean_staging.csv with FishBase-sourced fields
filled (including placeholder descriptions when enabled) and user prose left
empty when descriptions are disabled.

Usage (from repo root):
  GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/extract_fishbase_caribbean.py
"""

from __future__ import annotations

import csv
import sys
from pathlib import Path

import duckdb

from fishbase_catalog_utils import (
    DEFAULT_CONFIG_PATH,
    PROJECT_DIR,
    STAGING_FIELDNAMES,
    build_diver_visibility_where_clause,
    cm_to_meters,
    depth_meters,
    empty_user_fields,
    load_config,
    make_uuid,
    prose_fields_from_fishbase,
)


def parquet_url(base: str, table: str) -> str:
    return f"{base}/{table}.parquet"


def build_extract_sql(
    base: str,
    caribbean_region: str,
    diver_visibility_filter: dict | None = None,
    include_descriptions: bool = False,
) -> str:
    diver_where = build_diver_visibility_where_clause(diver_visibility_filter)
    needs_ecology = bool(diver_where) or include_descriptions
    ecology_cte = ""
    ecology_join = ""
    if needs_ecology:
        ecology_columns = [
            "SpecCode",
            "max(CASE WHEN CoralReefs = -1 THEN 1 ELSE 0 END) AS CoralReefs",
        ]
        if include_descriptions:
            ecology_columns.append("max(nullif(trim(AddRems), '')) AS add_rems")
        ecology_select = ",\n            ".join(ecology_columns)
        ecology_cte = f""",
    ecology_agg AS (
        SELECT
            {ecology_select}
        FROM read_parquet('{parquet_url(base, "ecology")}')
        GROUP BY SpecCode
    )"""
        ecology_join = "LEFT JOIN ecology_agg AS ecol ON s.SpecCode = ecol.SpecCode"

    return f"""
    WITH caribbean_codes AS (
        SELECT C_Code
        FROM read_parquet('{parquet_url(base, "countref")}')
        WHERE Region = '{caribbean_region}'
    ),
    caribbean_marine_species AS (
        SELECT DISTINCT c.SpecCode
        FROM read_parquet('{parquet_url(base, "country")}') AS c
        INNER JOIN caribbean_codes AS cc ON c.C_Code = cc.C_Code
        WHERE c.Saltwater = 1
    ),
    preferred_english_names AS (
        SELECT SpecCode, ComName AS common_name
        FROM (
            SELECT
                SpecCode,
                ComName,
                row_number() OVER (
                    PARTITION BY SpecCode
                    ORDER BY
                        CASE WHEN lower(trim(ComName)) = 'angelfish' THEN 1 ELSE 0 END,
                        PreferredName DESC NULLS LAST,
                        length(ComName) DESC,
                        ComName
                ) AS rn
            FROM read_parquet('{parquet_url(base, "comnames")}')
            WHERE lower(trim(Language)) = 'english'
              AND ComName IS NOT NULL
              AND trim(ComName) <> ''
        )
        WHERE rn = 1
    ){ecology_cte}
    SELECT
        s.SpecCode AS spec_code,
        coalesce(
            nullif(trim(s.FBname), ''),
            pen.common_name,
            trim(s.Genus) || ' ' || trim(s.Species)
        ) AS common_name,
        trim(s.Genus) || ' ' || trim(s.Species) AS scientific_name,
        coalesce(nullif(trim(f.Family), ''), '') AS family_name,
        s.Length AS max_length_cm,
        s.DepthRangeShallow AS depth_shallow_m,
        s.DepthRangeDeep AS depth_deep_m,
        trim(s.Comments) AS comments,
        trim(s.BodyShapeI) AS body_shape
        {", trim(ecol.add_rems) AS add_rems" if include_descriptions else ""}
    FROM read_parquet('{parquet_url(base, "species")}') AS s
    INNER JOIN caribbean_marine_species AS cms ON s.SpecCode = cms.SpecCode
    LEFT JOIN preferred_english_names AS pen ON s.SpecCode = pen.SpecCode
    LEFT JOIN read_parquet('{parquet_url(base, "families")}') AS f ON s.FamCode = f.FamCode
    {ecology_join}
    WHERE s.Saltwater = 1
      AND coalesce(s.Fresh, 0) = 0
      {diver_where}
    ORDER BY common_name COLLATE NOCASE, scientific_name COLLATE NOCASE
    """


def main() -> int:
    config = load_config()
    base = config["parquet_base_url"]
    region = config["caribbean_region_filter"]
    family_map: dict[str, str] = config.get("family_to_subcategory", {})

    output_path = PROJECT_DIR / config["output_staging_csv"]
    output_path.parent.mkdir(parents=True, exist_ok=True)

    diver_filter = config.get("diver_visibility_filter")
    include_descriptions = bool(config.get("include_fishbase_descriptions", False))
    if diver_filter and diver_filter.get("enabled", True):
        print(
            "Diver visibility filter: reef/demersal/neritic habitats "
            f"+ max depth {diver_filter.get('max_depth_meters', 'none')} m"
        )
    if include_descriptions:
        print("Including FishBase placeholder descriptions (species.Comments + BodyShapeI).")
    print(f"Querying FishBase {config.get('fishbase_version', 'unknown')} ({region} saltwater fish)...")
    rows = duckdb.sql(
        build_extract_sql(base, region, diver_filter, include_descriptions)
    ).fetchall()
    print(f"Found {len(rows)} species.")

    used_uuids: set[str] = set()
    mapped_subcategory = 0
    needs_subcategory = 0

    with output_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=STAGING_FIELDNAMES)
        writer.writeheader()

        for row in rows:
            if include_descriptions:
                (
                    spec_code,
                    common_name,
                    scientific_name,
                    family_name,
                    max_length_cm,
                    depth_shallow_m,
                    depth_deep_m,
                    comments,
                    body_shape,
                    add_rems,
                ) = row
            else:
                (
                    spec_code,
                    common_name,
                    scientific_name,
                    family_name,
                    max_length_cm,
                    depth_shallow_m,
                    depth_deep_m,
                    comments,
                    body_shape,
                ) = row
                add_rems = None
            common = (common_name or scientific_name or f"Fish {spec_code}").strip()
            family = (family_name or "").strip()
            subcategory = family_map.get(family, "")
            if subcategory:
                mapped_subcategory += 1
            else:
                needs_subcategory += 1

            row = {
                "uuid": make_uuid(common, int(spec_code), used_uuids),
                "fishbase_spec_code": str(spec_code),
                "commonName": common,
                "scientificName": scientific_name.strip(),
                "category": "fish",
                "subCategory": subcategory,
                "familyName": family,
                "maxSizeMeters": cm_to_meters(max_length_cm),
                "minDepthMeters": depth_meters(depth_shallow_m),
                "maxDepthMeters": depth_meters(depth_deep_m),
                "needs_subcategory": "" if subcategory else "yes",
                **(
                    prose_fields_from_fishbase(comments, body_shape, add_rems)
                    if include_descriptions
                    else empty_user_fields()
                ),
            }
            writer.writerow(row)

    print(f"Wrote {output_path}")
    print(f"Subcategory mapped: {mapped_subcategory}; needs_subcategory: {needs_subcategory}")
    print(config.get("attribution", ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
