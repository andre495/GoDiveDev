#!/usr/bin/env python3
"""
Keep Caribbean staging rows whose scientific name appears in REEF.org lists.

By default only **fish** rows are filtered against REEF; all other categories
(invertebrates, marine mammals, etc.) are kept unchanged.

Usage:
  python3 GoDiveMVP/Scripts/filter_marine_life_by_reef.py --dry-run
  python3 GoDiveMVP/Scripts/filter_marine_life_by_reef.py --apply --sync-json --all
"""

from __future__ import annotations

import argparse
import csv
import json
import subprocess
import sys
import urllib.request
from collections import Counter
from pathlib import Path
from typing import Any

from fishbase_catalog_utils import (
    PROJECT_DIR,
    load_config,
    normalize_scientific_name_for_match,
    parse_reef_species_export,
    read_staging_rows,
    staging_fieldnames_for_path,
)

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_CONFIG_PATH = SCRIPT_DIR / "reef_caribbean_config.json"
SYNC_SCRIPT = SCRIPT_DIR / "sync_marine_life_staging_to_json.py"


def fetch_reef_region_csv(url: str) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": "GoDiveMVP/1.0"})
    with urllib.request.urlopen(request, timeout=120) as response:
        return response.read().decode("utf-8")


def load_reef_reference(config: dict[str, Any], *, refresh: bool) -> tuple[list[dict[str, str]], set[str]]:
    cache_path = PROJECT_DIR / config["reference_cache_csv"]
    regions: list[str] = config.get("reef_regions") or ["TWA"]
    url_template = config.get(
        "reef_export_url_template",
        "https://www.reef.org/db/reports/species/export?region_code={region}",
    )

    if cache_path.is_file() and not refresh:
        with cache_path.open(encoding="utf-8", newline="") as handle:
            cached = list(csv.DictReader(handle))
        match_keys = {
            row["match_key"]
            for row in cached
            if (row.get("match_key") or "").strip()
        }
        return cached, match_keys

    combined: list[dict[str, str]] = []
    seen_keys: set[str] = set()
    for region in regions:
        url = url_template.format(region=region)
        print(f"Fetching REEF {region} species list...")
        parsed = parse_reef_species_export(fetch_reef_region_csv(url))
        for row in parsed:
            row["reef_region"] = region
            key = row["match_key"]
            if key in seen_keys:
                continue
            seen_keys.add(key)
            combined.append(row)
        print(f"  {region}: {len(parsed)} rows ({len(combined)} unique names so far)")

    cache_path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "reef_region",
        "reef_species_id",
        "reef_common_name",
        "scientificName",
        "match_key",
        "reef_family_common",
        "reef_family_scientific",
        "reef_is_invertebrate",
    ]
    with cache_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(combined)

    print(f"Cached REEF reference to {cache_path}")
    return combined, seen_keys


def filter_staging_rows(
    staging_rows: list[dict[str, str]],
    reef_match_keys: set[str],
    *,
    fish_only: bool = True,
) -> tuple[list[dict[str, str]], list[dict[str, str]], Counter[str], Counter[str]]:
    kept: list[dict[str, str]] = []
    removed: list[dict[str, str]] = []
    kept_by_category: Counter[str] = Counter()
    removed_by_category: Counter[str] = Counter()

    for row in staging_rows:
        category = (row.get("category") or "").strip() or "unknown"
        if fish_only and category != "fish":
            kept.append(row)
            kept_by_category[category] += 1
            continue

        match_key = normalize_scientific_name_for_match(row.get("scientificName"))
        if match_key and match_key in reef_match_keys:
            kept.append(row)
            kept_by_category[category] += 1
        else:
            removed.append(row)
            removed_by_category[category] += 1

    return kept, removed, kept_by_category, removed_by_category


def write_staging_csv(path: Path, rows: list[dict[str, str]]) -> None:
    fieldnames = staging_fieldnames_for_path(path)
    for row in rows:
        for field in fieldnames:
            row.setdefault(field, "")
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def run_sync(json_path: Path, include_all: bool) -> None:
    command = [sys.executable, str(SYNC_SCRIPT), "--json", str(json_path)]
    if include_all:
        command.append("--all")
    subprocess.run(command, check=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG_PATH)
    parser.add_argument("--refresh-reef", action="store_true", help="Re-download REEF CSV exports")
    parser.add_argument("--apply", action="store_true", help="Write filtered staging CSV")
    parser.add_argument("--sync-json", action="store_true", help="Re-run staging → JSON sync after filtering")
    parser.add_argument("--all", action="store_true", help="Pass --all to sync (include rows without aboutText)")
    parser.add_argument(
        "--all-species",
        action="store_true",
        help="Filter every category against REEF (default: fish only)",
    )
    parser.add_argument("--dry-run", action="store_true", help="Preview counts only (default without --apply)")
    args = parser.parse_args()

    if args.apply:
        args.dry_run = False
    elif not args.sync_json:
        args.dry_run = True

    config = load_config(args.config)
    staging_path = PROJECT_DIR / config["output_staging_csv"]
    json_path = PROJECT_DIR / config.get("output_json", "MockData/marine_life_sample.json")

    if not staging_path.is_file():
        print(f"Staging CSV not found: {staging_path}", file=sys.stderr)
        return 1

    _, reef_keys = load_reef_reference(config, refresh=args.refresh_reef)
    fieldnames, staging_rows = read_staging_rows(staging_path)
    fish_only = not args.all_species and config.get("fish_only", True)
    kept, removed, kept_by_category, removed_by_category = filter_staging_rows(
        staging_rows,
        reef_keys,
        fish_only=fish_only,
    )

    print(f"REEF match keys: {len(reef_keys)}")
    mode = "fish only" if fish_only else "all categories"
    print(f"Filter mode: {mode}")
    print(f"Staging rows: {len(staging_rows)} → keep {len(kept)}, remove {len(removed)}")
    print("Kept by category:")
    for category, count in kept_by_category.most_common():
        print(f"  {category}: {count}")
    print("Removed by category:")
    for category, count in removed_by_category.most_common():
        print(f"  {category}: {count}")

    if args.dry_run:
        print("Dry run — no files written.")
        return 0

    write_staging_csv(staging_path, kept)
    print(f"Wrote {len(kept)} rows to {staging_path}")

    if args.sync_json:
        run_sync(json_path, args.all)
        print(f"Synced JSON to {json_path}")

    report_path = PROJECT_DIR / "MockData/reef_filter_report.json"
    report = {
        "fish_only": fish_only,
        "reef_match_keys": len(reef_keys),
        "kept": len(kept),
        "removed": len(removed),
        "kept_by_category": dict(kept_by_category),
        "removed_by_category": dict(removed_by_category),
    }
    with report_path.open("w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2)
        handle.write("\n")
    print(f"Report: {report_path}")
    print(config.get("attribution", ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
