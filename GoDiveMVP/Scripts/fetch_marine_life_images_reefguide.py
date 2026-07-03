#!/usr/bin/env python3
"""
Find hero images on reefguide.org for marine life staging rows.

reefguide.org (Florent Charpin) is a high-quality Caribbean reef photo guide, but
photos are copyrighted — redistribution requires express written permission.
See https://reefguide.org/about.html

This script stages direct image URLs + attribution on marine_life_caribbean_staging.csv
with imageNeedsReview=yes. Review in marine_life_image_review.html and obtain
permission before shipping bundled photos in the app.

Usage:
  GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/fetch_marine_life_images_reefguide.py --dry-run --limit 10
  GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/fetch_marine_life_images_reefguide.py
  GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/fetch_marine_life_images_reefguide.py --bundle
  GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/sync_marine_life_staging_to_json.py --all
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import urllib.error
from pathlib import Path
from typing import Any

from download_marine_life_images import DEFAULT_OUTPUT_DIR, DEFAULT_STAGING, load_staging_rows, write_staging_csv
from fishbase_catalog_utils import PROJECT_DIR, load_config, staging_row_marked_for_deletion
from reefguide_image_utils import (
    CACHE_VERSION,
    REEFGUIDE_ABOUT_URL,
    ReefGuideImageCandidate,
    find_reefguide_image,
    load_caribbean_catalog,
)

DEFAULT_CACHE = PROJECT_DIR / "MockData/reefguide_image_cache.json"
SCRIPT_DIR = Path(__file__).resolve().parent
DOWNLOAD_SCRIPT = SCRIPT_DIR / "download_marine_life_images.py"


def load_cache(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def save_cache(path: Path, cache: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(cache, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def candidate_to_cache_entry(candidate: ReefGuideImageCandidate) -> dict[str, str]:
    return {
        "cacheVersion": CACHE_VERSION,
        "featureImageURL": candidate.url,
        "imageLicense": candidate.license,
        "imageAttribution": candidate.attribution,
        "imageSource": candidate.source,
        "imageNeedsReview": "yes",
        "speciesPageURL": candidate.species_page_url,
        "photoPageURL": candidate.photo_page_url,
        "score": str(candidate.score),
    }


def cached_candidate(cached: dict[str, Any], *, scientific_name: str) -> ReefGuideImageCandidate | None:
    if cached.get("cacheVersion") != CACHE_VERSION or not cached.get("featureImageURL"):
        return None
    return ReefGuideImageCandidate(
        url=str(cached["featureImageURL"]),
        species_page_url=str(cached.get("speciesPageURL") or ""),
        photo_page_url=str(cached.get("photoPageURL") or ""),
        location="",
        title=scientific_name,
        license=str(cached.get("imageLicense") or ""),
        attribution=str(cached.get("imageAttribution") or ""),
        source=str(cached.get("imageSource") or "reefguide"),
        needs_review=True,
        score=int(cached.get("score") or 0),
    )


def apply_candidate(row: dict[str, str], candidate: ReefGuideImageCandidate) -> None:
    row["featureImageURL"] = candidate.url
    row["imageLicense"] = candidate.license
    row["imageAttribution"] = candidate.attribution
    row["imageSource"] = candidate.source
    row["imageNeedsReview"] = "yes"


def should_skip_row(
    row: dict[str, str],
    *,
    overwrite: bool,
    refetch_gaps: bool,
    only_reefguide: bool,
) -> bool:
    if staging_row_marked_for_deletion(row):
        return True
    if only_reefguide and (row.get("imageSource") or "").strip().lower() != "reefguide":
        return True
    if overwrite:
        return False
    if refetch_gaps:
        if not (row.get("featureImageURL") or "").strip():
            return False
        return (row.get("imageNeedsReview") or "").strip().lower() != "yes"
    return bool((row.get("featureImageURL") or "").strip())


def run_bundle_download(*, staging: Path, photos_dir: Path, limit: int) -> int:
    command = [
        sys.executable,
        str(DOWNLOAD_SCRIPT),
        "--staging",
        str(staging),
        "--photos-dir",
        str(photos_dir),
        "--overwrite",
    ]
    if limit > 0:
        command.extend(["--limit", str(limit)])
    print("\nBundling JPEGs via download_marine_life_images.py …")
    completed = subprocess.run(command, check=False)
    return int(completed.returncode)


def main() -> int:
    config = load_config()
    image_cfg = config.get("marine_life_images", {})

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--staging", type=Path, default=DEFAULT_STAGING)
    parser.add_argument("--cache", type=Path, default=DEFAULT_CACHE)
    parser.add_argument("--photos-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument(
        "--refetch-gaps",
        action="store_true",
        help="Re-query rows missing images or flagged imageNeedsReview=yes",
    )
    parser.add_argument(
        "--refresh-catalog",
        action="store_true",
        help="Re-download reefguide.org scientific-name indexes",
    )
    parser.add_argument(
        "--only-reefguide",
        action="store_true",
        help="Refresh rows that already have imageSource=reefguide (use with --overwrite)",
    )
    parser.add_argument(
        "--bundle",
        action="store_true",
        help="After staging URLs, run download_marine_life_images.py --overwrite",
    )
    args = parser.parse_args()

    if not args.staging.exists():
        print(f"Staging CSV not found: {args.staging}", file=sys.stderr)
        return 1

    request_delay = float(image_cfg.get("reefguide_request_delay_seconds", 0.3))

    print("reefguide.org image fetch")
    print(f"License note: photos are © Florent Charpin — get written permission before app bundle.")
    print(f"About: {REEFGUIDE_ABOUT_URL}")

    catalog = load_caribbean_catalog(refresh=args.refresh_catalog, request_delay_seconds=request_delay)
    print(f"Caribbean catalog entries: {len(catalog)}")

    rows = load_staging_rows(args.staging)
    cache = load_cache(args.cache)
    eligible = [
        row
        for row in rows
        if not should_skip_row(
            row,
            overwrite=args.overwrite or args.only_reefguide,
            refetch_gaps=args.refetch_gaps,
            only_reefguide=args.only_reefguide,
        )
    ]
    if args.limit > 0:
        eligible = eligible[: args.limit]

    print(f"Staging rows: {len(rows)}")
    print(f"Eligible for reefguide fetch: {len(eligible)}")

    matched = 0
    missed = 0
    bypass_cache = args.overwrite or args.refetch_gaps or args.only_reefguide

    for index, row in enumerate(eligible, start=1):
        scientific_name = (row.get("scientificName") or "").strip()
        common_name = (row.get("commonName") or "").strip()
        if not scientific_name:
            missed += 1
            continue

        cache_key = scientific_name
        cached_entry = cache.get(cache_key, {})
        candidate = None if bypass_cache else cached_candidate(cached_entry, scientific_name=scientific_name)

        if candidate is None:
            try:
                candidate = find_reefguide_image(
                    scientific_name,
                    common_name=common_name,
                    catalog=catalog,
                    request_delay_seconds=request_delay,
                )
            except (urllib.error.HTTPError, urllib.error.URLError, ValueError, RuntimeError) as error:
                missed += 1
                print(f"[{index}/{len(eligible)}] error {common_name} ({scientific_name}): {error}")
                continue

            if candidate:
                cache[cache_key] = candidate_to_cache_entry(candidate)

        if candidate is None:
            missed += 1
            print(f"[{index}/{len(eligible)}] miss  {common_name} ({scientific_name})")
            continue

        matched += 1
        if not args.dry_run:
            apply_candidate(row, candidate)

        print(
            f"[{index}/{len(eligible)}] review {common_name} ({scientific_name}) "
            f"score={candidate.score} -> {candidate.url}"
        )

    print(f"\nSummary: matched={matched}, missed={missed}, needs_review={matched}")

    if args.dry_run:
        print("Dry run: staging CSV not written.")
        return 0

    save_cache(args.cache, cache)
    write_staging_csv(args.staging, rows)
    print(f"Wrote {args.staging}")
    print(f"Wrote {args.cache}")

    if args.bundle and matched > 0:
        return run_bundle_download(staging=args.staging, photos_dir=args.photos_dir, limit=args.limit)

    if matched > 0:
        print("Next: review in marine_life_image_review.html, then optionally:")
        print(f"  {sys.executable} {DOWNLOAD_SCRIPT}")
        print("  GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/sync_marine_life_staging_to_json.py --all")
    return 0


if __name__ == "__main__":
    sys.exit(main())
