#!/usr/bin/env python3
"""
Merge marine_life_caribbean_staging.csv into marine_life_sample.json.

Default: only rows with non-empty aboutText ship to the app bundle (your
description workflow). Existing JSON entries are preserved; matching uuid rows
get FishBase facts refreshed but keep your prose unless you changed the CSV.

Usage:
  # After filling aboutText for some rows:
  GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/sync_marine_life_staging_to_json.py

  # Preview counts without writing:
  GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/sync_marine_life_staging_to_json.py --dry-run

  # Ship all facts-only rows (large catalog; descriptions still empty):
  GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/sync_marine_life_staging_to_json.py --all
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path

from fishbase_catalog_utils import (
    PROJECT_DIR,
    STAGING_FIELDNAMES,
    staging_row_to_json,
)


DEFAULT_STAGING = PROJECT_DIR / "MockData/marine_life_caribbean_staging.csv"
DEFAULT_JSON = PROJECT_DIR / "MockData/marine_life_sample.json"

PROSE_FIELDS_STAGING = [
    "aboutText",
    "distinctiveFeatures",
    "Abundance",
    "habitatBehavior",
    "diverReaction",
    "featureImageURL",
]


def load_json_catalog(path: Path) -> list[dict]:
    if not path.exists():
        return []
    with path.open(encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, list):
        raise ValueError(f"Expected JSON array in {path}")
    return data


def load_staging_rows(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        missing = [field for field in STAGING_FIELDNAMES if field not in reader.fieldnames]
        if missing:
            raise ValueError(f"Staging CSV missing columns: {missing}")
        return list(reader)


def row_is_ready(row: dict[str, str], include_all: bool) -> bool:
    if include_all:
        return True
    about = (row.get("aboutText") or "").strip()
    return bool(about)


def merge_prose(
    json_row: dict,
    csv_row: dict[str, str] | None,
    existing_json: dict | None,
) -> dict:
    """Keep user prose from CSV first, else preserve existing bundled JSON."""
    mapping = {
        "description": ("aboutText", "description"),
        "distinctive_features": ("distinctiveFeatures", "distinctive_features"),
        "abundance": ("Abundance", "abundance"),
        "habitat_behavior": ("habitatBehavior", "habitat_behavior"),
        "diver_reaction": ("diverReaction", "diver_reaction"),
        "feature_image": ("featureImageURL", "feature_image"),
    }
    for json_key, (csv_key, existing_key) in mapping.items():
        csv_val = (csv_row or {}).get(csv_key, "")
        if isinstance(csv_val, str) and csv_val.strip():
            json_row[json_key] = csv_val.strip()
            continue
        existing_val = (existing_json or {}).get(existing_key, "")
        if isinstance(existing_val, str) and existing_val.strip():
            json_row[json_key] = existing_val.strip()
    return json_row


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--staging", type=Path, default=DEFAULT_STAGING)
    parser.add_argument("--json", type=Path, default=DEFAULT_JSON, dest="json_path")
    parser.add_argument("--all", action="store_true", help="Include rows without aboutText")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if not args.staging.exists():
        print(f"Staging CSV not found: {args.staging}", file=sys.stderr)
        print("Run extract_fishbase_caribbean.py first.", file=sys.stderr)
        return 1

    staging_rows = load_staging_rows(args.staging)
    existing_json = load_json_catalog(args.json_path)
    existing_by_uuid = {row["uuid"]: row for row in existing_json if "uuid" in row}

    ready_rows = [row for row in staging_rows if row_is_ready(row, args.all)]
    print(f"Staging rows: {len(staging_rows)}; shipping: {len(ready_rows)}")

    merged_by_uuid = dict(existing_by_uuid)

    for row in ready_rows:
        uuid = row["uuid"].strip()
        json_row = staging_row_to_json(row)
        json_row = merge_prose(json_row, row, existing_by_uuid.get(uuid))
        merged_by_uuid[uuid] = json_row

    merged = sorted(
        merged_by_uuid.values(),
        key=lambda item: (item.get("common_name") or item.get("uuid") or "").lower(),
    )

    if args.dry_run:
        print(f"Dry run: would write {len(merged)} species to {args.json_path}")
        return 0

    with args.json_path.open("w", encoding="utf-8") as handle:
        json.dump(merged, handle, indent=2, ensure_ascii=False)
        handle.write("\n")

    print(f"Wrote {len(merged)} species to {args.json_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
