#!/usr/bin/env python3
"""
Cross-reference the staging catalog against Caribbean Reef Life (Mickey Charteris).

Extract the book's Scientific Name Index first:
  python3 GoDiveMVP/Scripts/extract_caribbean_reef_life_reference.py --epub ~/Desktop/Caribbean\\ Reef\\ Life\\ 4.epub

Then validate (report only by default; fish-only unless --all-species):
  python3 GoDiveMVP/Scripts/validate_marine_life_by_crl.py
  python3 GoDiveMVP/Scripts/validate_marine_life_by_crl.py --apply --sync-json --all
"""

from __future__ import annotations

import argparse
import csv
import json
import subprocess
import sys
from collections import Counter
from pathlib import Path
from typing import Any

from fishbase_catalog_utils import (
    PROJECT_DIR,
    load_config,
    normalize_scientific_name_for_match,
    read_staging_rows,
    staging_fieldnames_for_path,
)

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_CONFIG_PATH = SCRIPT_DIR / "caribbean_reef_life_config.json"
SYNC_SCRIPT = SCRIPT_DIR / "sync_marine_life_staging_to_json.py"


def load_crl_reference(cache_path: Path) -> tuple[list[dict[str, str]], set[str]]:
    if not cache_path.is_file():
        return [], set()
    with cache_path.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))
    keys = {(row.get("match_key") or "").strip() for row in rows if (row.get("match_key") or "").strip()}
    return rows, keys


def classify_staging_rows(
    staging_rows: list[dict[str, str]],
    crl_keys: set[str],
    *,
    fish_only: bool,
) -> tuple[list[dict[str, str]], list[dict[str, str]], Counter[str], Counter[str]]:
    matched: list[dict[str, str]] = []
    unmatched: list[dict[str, str]] = []
    matched_by_category: Counter[str] = Counter()
    unmatched_by_category: Counter[str] = Counter()

    for row in staging_rows:
        category = (row.get("category") or "").strip() or "unknown"
        if fish_only and category != "fish":
            matched.append(row)
            matched_by_category[category] += 1
            continue

        key = normalize_scientific_name_for_match(row.get("scientificName"))
        if key and key in crl_keys:
            matched.append(row)
            matched_by_category[category] += 1
        else:
            unmatched.append(row)
            unmatched_by_category[category] += 1

    return matched, unmatched, matched_by_category, unmatched_by_category


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
    parser.add_argument("--apply", action="store_true", help="Keep only matched rows in staging")
    parser.add_argument("--sync-json", action="store_true")
    parser.add_argument("--all", action="store_true", help="Pass --all to JSON sync")
    parser.add_argument(
        "--all-species",
        action="store_true",
        help="Validate every category against CRL (default: fish only)",
    )
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if args.apply:
        args.dry_run = False
    elif not args.sync_json:
        args.dry_run = True

    config = load_config(args.config)
    staging_path = PROJECT_DIR / config["output_staging_csv"]
    json_path = PROJECT_DIR / config.get("output_json", "MockData/marine_life_sample.json")
    cache_path = PROJECT_DIR / config["reference_cache_csv"]
    pdf_path = PROJECT_DIR / config.get("default_pdf_path", "MockData/CaribbeanReefLife.pdf")

    if not staging_path.is_file():
        print(f"Staging CSV not found: {staging_path}", file=sys.stderr)
        return 1

    _, crl_keys = load_crl_reference(cache_path)
    if not crl_keys:
        print(f"CRL reference not found: {cache_path}", file=sys.stderr)
        print(
            "Extract the book index first:\n"
            "  python3 GoDiveMVP/Scripts/extract_caribbean_reef_life_reference.py "
            f"--epub {config.get('default_epub_path', '/path/to/Caribbean Reef Life 4.epub')}",
            file=sys.stderr,
        )
        return 1

    fish_only = not args.all_species and config.get("fish_only", True)
    _, staging_rows = read_staging_rows(staging_path)
    matched, unmatched, matched_by_category, unmatched_by_category = classify_staging_rows(
        staging_rows,
        crl_keys,
        fish_only=fish_only,
    )

    mode = "fish only" if fish_only else "all categories"
    print(f"Caribbean Reef Life reference names: {len(crl_keys)}")
    print(f"Validation mode: {mode}")
    print(f"Staging rows: {len(staging_rows)}")
    print(f"  matched: {len(matched)}")
    print(f"  not in book: {len(unmatched)}")
    print("Matched by category:")
    for category, count in matched_by_category.most_common():
        print(f"  {category}: {count}")
    if unmatched_by_category:
        print("Not in book by category:")
        for category, count in unmatched_by_category.most_common():
            print(f"  {category}: {count}")

    report_path = PROJECT_DIR / "MockData/caribbean_reef_life_validation_report.json"
    report = {
        "fish_only": fish_only,
        "crl_reference_names": len(crl_keys),
        "staging_rows": len(staging_rows),
        "matched": len(matched),
        "not_in_book": len(unmatched),
        "matched_by_category": dict(matched_by_category),
        "not_in_book_by_category": dict(unmatched_by_category),
        "sample_not_in_book": [
            {
                "commonName": row.get("commonName", ""),
                "scientificName": row.get("scientificName", ""),
                "category": row.get("category", ""),
            }
            for row in unmatched[:25]
        ],
    }
    with report_path.open("w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2)
        handle.write("\n")
    print(f"Report: {report_path}")

    if args.dry_run:
        print("Dry run — staging CSV unchanged.")
        return 0

    write_staging_csv(staging_path, matched)
    print(f"Wrote {len(matched)} rows to {staging_path}")

    if args.sync_json:
        run_sync(json_path, args.all)
        print(f"Synced JSON to {json_path}")

    print(config.get("attribution", ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
