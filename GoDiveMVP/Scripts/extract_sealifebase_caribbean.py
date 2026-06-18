#!/usr/bin/env python3
"""
Extract Caribbean saltwater invertebrates and other non-fish marine life from SeaLifeBase.

SeaLifeBase is the FishBase sister database for non-fish marine species (same parquet
layout). By default this **appends** to the existing fish staging CSV without touching
fish rows.

Usage (from repo root):
  python3 GoDiveMVP/Scripts/extract_sealifebase_caribbean.py
  python3 GoDiveMVP/Scripts/extract_sealifebase_caribbean.py --replace-inverts
"""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

import duckdb

from fishbase_catalog_utils import (
    PROJECT_DIR,
    build_diver_visibility_where_clause,
    build_sealifebase_taxon_where_clause,
    apply_diver_visibility_bypass,
    cm_to_meters,
    depth_meters,
    empty_image_workflow_fields,
    empty_user_fields,
    load_config,
    make_uuid,
    prose_fields_from_fishbase,
    read_staging_rows,
    resolve_sealifebase_taxonomy,
    staging_fieldnames_for_path,
)

DEFAULT_CONFIG_PATH = Path(__file__).resolve().parent / "sealifebase_caribbean_config.json"


def parquet_url(base: str, table: str) -> str:
    return f"{base}/{table}.parquet"


def build_extract_sql(
    base: str,
    caribbean_region: str,
    config: dict,
    include_descriptions: bool = False,
) -> str:
    diver_filter = config.get("diver_visibility_filter")
    diver_where = build_diver_visibility_where_clause(diver_filter)
    diver_where = apply_diver_visibility_bypass(
        diver_where,
        config.get("bypass_diver_visibility_classes"),
        config.get("bypass_diver_visibility_orders"),
    )
    taxon_where = build_sealifebase_taxon_where_clause(config)
    needs_ecology = bool(diver_where) or include_descriptions
    reef_flag = int((diver_filter or {}).get("ecology_coral_reefs_flag_value", 1))

    ecology_cte = ""
    ecology_join = ""
    if needs_ecology:
        ecology_columns = [
            "SpecCode",
            f"max(CASE WHEN CoralReefs = {reef_flag} THEN 1 ELSE 0 END) AS CoralReefs",
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
                    ORDER BY PreferredName DESC NULLS LAST, length(ComName) DESC, ComName
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
        coalesce(nullif(trim(f.Order), ''), '') AS order_name,
        coalesce(nullif(trim(cl.Class), ''), '') AS class_name,
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
    LEFT JOIN read_parquet('{parquet_url(base, "classes")}') AS cl ON f.ClassNum = cl.ClassNum
    {ecology_join}
    WHERE s.Saltwater = 1
      AND coalesce(s.Fresh, 0) = 0
      {taxon_where}
      {diver_where}
    ORDER BY common_name COLLATE NOCASE, scientific_name COLLATE NOCASE
    """


def row_to_staging_dict(
    row: tuple,
    include_descriptions: bool,
    config: dict,
    used_uuids: set[str],
    existing_spec_codes: set[str],
) -> dict[str, str] | None:
    if include_descriptions:
        (
            spec_code,
            common_name,
            scientific_name,
            family_name,
            order_name,
            class_name,
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
            order_name,
            class_name,
            max_length_cm,
            depth_shallow_m,
            depth_deep_m,
            comments,
            body_shape,
        ) = row
        add_rems = None

    spec_key = str(spec_code)
    if spec_key in existing_spec_codes:
        return None

    common = (common_name or scientific_name or f"Species {spec_code}").strip()
    family = (family_name or "").strip()
    category, subcategory = resolve_sealifebase_taxonomy(
        class_name, order_name, family, config
    )

    staging = {
        "uuid": make_uuid(common, int(spec_code), used_uuids),
        "fishbase_spec_code": spec_key,
        "commonName": common,
        "scientificName": scientific_name.strip(),
        "category": category,
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
        **empty_image_workflow_fields(),
    }
    return staging


def main() -> int:
    parser = argparse.ArgumentParser(description="Extract Caribbean non-fish marine life from SeaLifeBase.")
    parser.add_argument(
        "--replace-inverts",
        action="store_true",
        help="Drop existing non-fish rows before writing (fish rows are kept).",
    )
    parser.add_argument(
        "--config",
        type=Path,
        default=DEFAULT_CONFIG_PATH,
        help="Path to sealifebase_caribbean_config.json",
    )
    args = parser.parse_args()

    config = load_config(args.config)
    base = config["parquet_base_url"]
    region = config["caribbean_region_filter"]
    include_descriptions = bool(config.get("include_sealifebase_descriptions", False))

    output_path = PROJECT_DIR / config["output_staging_csv"]
    output_path.parent.mkdir(parents=True, exist_ok=True)

    fieldnames, existing_rows = read_staging_rows(output_path)
    if args.replace_inverts:
        kept_rows = [row for row in existing_rows if (row.get("category") or "").strip() == "fish"]
        if kept_rows:
            print(f"Keeping {len(kept_rows)} fish rows; replacing non-fish staging rows.")
        existing_rows = kept_rows
    elif existing_rows:
        print(f"Appending to {len(existing_rows)} existing staging rows.")

    used_uuids = {row["uuid"] for row in existing_rows if row.get("uuid")}
    existing_spec_codes = {
        (row.get("fishbase_spec_code") or "").strip()
        for row in existing_rows
        if (row.get("fishbase_spec_code") or "").strip()
    }

    diver_filter = config.get("diver_visibility_filter")
    if diver_filter and diver_filter.get("enabled", True):
        print(
            "Diver visibility filter: "
            f"max depth {diver_filter.get('max_depth_meters', 'none')} m"
        )
    if include_descriptions:
        print("Including SeaLifeBase placeholder descriptions (species.Comments + BodyShapeI).")

    print(
        f"Querying SeaLifeBase {config.get('sealifebase_version', 'unknown')} "
        f"({region} saltwater invertebrates)..."
    )
    rows = duckdb.sql(build_extract_sql(base, region, config, include_descriptions)).fetchall()
    print(f"Found {len(rows)} candidate species.")

    new_rows: list[dict[str, str]] = []
    mapped_subcategory = 0
    needs_subcategory = 0
    skipped_existing = 0

    for row in rows:
        staging = row_to_staging_dict(
            row,
            include_descriptions,
            config,
            used_uuids,
            existing_spec_codes,
        )
        if staging is None:
            skipped_existing += 1
            continue
        if staging["subCategory"]:
            mapped_subcategory += 1
        else:
            needs_subcategory += 1
        new_rows.append(staging)

    write_fieldnames = staging_fieldnames_for_path(output_path)
    for row in new_rows + existing_rows:
        for field in write_fieldnames:
            row.setdefault(field, "")

    combined = existing_rows + new_rows
    with output_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=write_fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(combined)

    print(f"Wrote {len(combined)} rows to {output_path} (+{len(new_rows)} new non-fish).")
    if skipped_existing:
        print(f"Skipped {skipped_existing} rows already present (matching fishbase_spec_code).")
    print(f"Subcategory mapped: {mapped_subcategory}; needs_subcategory: {needs_subcategory}")
    print(config.get("attribution", ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
