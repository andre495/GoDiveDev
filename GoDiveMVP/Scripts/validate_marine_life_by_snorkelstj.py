#!/usr/bin/env python3
"""
Fuzzy-match staging catalog common names against snorkelstj.com.

Fetch reference data first:
  python3 GoDiveMVP/Scripts/fetch_snorkelstj_species_reference.py

Validate (report only by default):
  python3 GoDiveMVP/Scripts/validate_marine_life_by_snorkelstj.py

Optional filter + JSON sync:
  python3 GoDiveMVP/Scripts/validate_marine_life_by_snorkelstj.py --apply --sync-json --all
"""

from __future__ import annotations

import argparse
import csv
import json
import subprocess
import sys
from collections import Counter
from pathlib import Path

from fishbase_catalog_utils import PROJECT_DIR, load_config, read_staging_rows, staging_fieldnames_for_path
from snorkelstj_catalog_utils import match_staging_row

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_CONFIG_PATH = SCRIPT_DIR / "snorkelstj_caribbean_config.json"
SYNC_SCRIPT = SCRIPT_DIR / "sync_marine_life_staging_to_json.py"
FETCH_SCRIPT = SCRIPT_DIR / "fetch_snorkelstj_species_reference.py"


def load_reference(cache_path: Path) -> list[dict[str, str]]:
    if not cache_path.is_file():
        return []
    with cache_path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle))


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


def classify_rows(
    staging_rows: list[dict[str, str]],
    reference_rows: list[dict[str, str]],
    threshold: float,
) -> tuple[list[dict], list[dict], Counter[str], Counter[str], Counter[str]]:
    matched_rows: list[dict] = []
    unmatched_rows: list[dict] = []
    matched_by_category: Counter[str] = Counter()
    unmatched_by_category: Counter[str] = Counter()
    method_counts: Counter[str] = Counter()

    for row in staging_rows:
        category = (row.get("category") or "").strip() or "unknown"
        hit, score, method = match_staging_row(
            row.get("commonName", ""),
            row.get("scientificName", ""),
            reference_rows,
            threshold=threshold,
        )
        enriched = dict(row)
        enriched["_snorkelstj_match_score"] = f"{score:.3f}"
        enriched["_snorkelstj_match_method"] = method
        if hit:
            enriched["_snorkelstj_commonName"] = hit.get("commonName", "")
            enriched["_snorkelstj_scientificName"] = hit.get("scientificName", "")
            enriched["_snorkelstj_url"] = hit.get("source_url", "")
            matched_rows.append(enriched)
            matched_by_category[category] += 1
            method_counts[method] += 1
        else:
            unmatched_rows.append(enriched)
            unmatched_by_category[category] += 1

    return (
        matched_rows,
        unmatched_rows,
        matched_by_category,
        unmatched_by_category,
        method_counts,
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG_PATH)
    parser.add_argument("--refresh", action="store_true", help="Re-crawl snorkelstj.com before validating")
    parser.add_argument("--threshold", type=float, help="Fuzzy common-name threshold (0-1)")
    parser.add_argument("--apply", action="store_true", help="Keep only matched rows in staging")
    parser.add_argument("--sync-json", action="store_true")
    parser.add_argument("--all", action="store_true", help="Pass --all to JSON sync")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if args.apply:
        args.dry_run = False
    elif not args.sync_json:
        args.dry_run = True

    config = load_config(args.config)
    cache_path = PROJECT_DIR / config["reference_cache_csv"]
    staging_path = PROJECT_DIR / config["output_staging_csv"]
    json_path = PROJECT_DIR / config.get("output_json", "MockData/marine_life_sample.json")
    threshold = args.threshold if args.threshold is not None else float(config.get("fuzzy_match_threshold", 0.88))

    if args.refresh:
        subprocess.run([sys.executable, str(FETCH_SCRIPT), "--refresh"], check=True)

    reference_rows = load_reference(cache_path)
    if not reference_rows:
        print(f"Reference not found: {cache_path}", file=sys.stderr)
        print(f"Run: python3 {FETCH_SCRIPT}", file=sys.stderr)
        return 1

    if not staging_path.is_file():
        print(f"Staging CSV not found: {staging_path}", file=sys.stderr)
        return 1

    _, staging_rows = read_staging_rows(staging_path)
    matched, unmatched, matched_by_category, unmatched_by_category, method_counts = classify_rows(
        staging_rows,
        reference_rows,
        threshold,
    )

    print(f"snorkelstj.com reference species: {len(reference_rows)}")
    print(f"Fuzzy match threshold: {threshold:.2f}")
    print(f"Staging rows: {len(staging_rows)}")
    print(f"  matched: {len(matched)}")
    print(f"  no match: {len(unmatched)}")
    print("Match methods:")
    for method, count in method_counts.most_common():
        print(f"  {method}: {count}")
    print("Matched by category:")
    for category, count in matched_by_category.most_common():
        print(f"  {category}: {count}")
    if unmatched_by_category:
        print("No match by category:")
        for category, count in unmatched_by_category.most_common():
            print(f"  {category}: {count}")

    report_path = PROJECT_DIR / "MockData/snorkelstj_validation_report.json"
    report = {
        "reference_species": len(reference_rows),
        "threshold": threshold,
        "staging_rows": len(staging_rows),
        "matched": len(matched),
        "unmatched": len(unmatched),
        "matched_by_category": dict(matched_by_category),
        "unmatched_by_category": dict(unmatched_by_category),
        "match_methods": dict(method_counts),
        "sample_matches": [
            {
                "commonName": row.get("commonName", ""),
                "scientificName": row.get("scientificName", ""),
                "category": row.get("category", ""),
                "snorkelstj_commonName": row.get("_snorkelstj_commonName", ""),
                "snorkelstj_scientificName": row.get("_snorkelstj_scientificName", ""),
                "score": row.get("_snorkelstj_match_score", ""),
                "method": row.get("_snorkelstj_match_method", ""),
                "url": row.get("_snorkelstj_url", ""),
            }
            for row in matched[:30]
        ],
        "sample_unmatched": [
            {
                "commonName": row.get("commonName", ""),
                "scientificName": row.get("scientificName", ""),
                "category": row.get("category", ""),
                "best_score": row.get("_snorkelstj_match_score", ""),
            }
            for row in unmatched[:30]
        ],
    }
    with report_path.open("w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2)
        handle.write("\n")
    print(f"Report: {report_path}")

    if args.dry_run:
        print("Dry run — staging CSV unchanged.")
        return 0

    cleaned = []
    for row in matched:
        row = dict(row)
        for key in list(row):
            if key.startswith("_snorkelstj_"):
                del row[key]
        cleaned.append(row)

    write_staging_csv(staging_path, cleaned)
    print(f"Wrote {len(cleaned)} rows to {staging_path}")

    if args.sync_json:
        run_sync(json_path, args.all)
        print(f"Synced JSON to {json_path}")

    print(config.get("attribution", ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
