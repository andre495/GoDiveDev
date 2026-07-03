#!/usr/bin/env python3
"""
Find hero images on WoRMS (World Register of Marine Species) for staging gaps.

Uses the WoRMS REST API to resolve AphiaIDs, then reads the taxon photogallery
on marinespecies.org. Direct JPEG URLs live on images.marinespecies.org.

Many WoRMS photos are CC BY-NC or CC BY-NC-SA (not shippable in GoDive without
permission). By default this script stages all gallery matches with
imageNeedsReview=yes when the license is not CC0/CC BY. Pass --shippable-only
to skip NC photos entirely.

Usage:
  GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/fetch_marine_life_images_worms.py --dry-run --limit 20
  GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/fetch_marine_life_images_worms.py
  GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/fetch_marine_life_images_worms.py --shippable-only
  GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/fetch_marine_life_images_worms.py --bundle
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
from marine_life_bundle_image_utils import bundle_photo_filename
from worms_image_utils import (
    CACHE_VERSION,
    WORMS_BASE_URL,
    WormsImageCandidate,
    find_worms_image,
)

DEFAULT_CACHE = PROJECT_DIR / "MockData/worms_image_cache.json"
DEFAULT_JSON = PROJECT_DIR / "MockData/marine_life_sample.json"
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


def candidate_to_cache_entry(candidate: WormsImageCandidate) -> dict[str, str]:
    return {
        "cacheVersion": CACHE_VERSION,
        "featureImageURL": candidate.url,
        "imageLicense": candidate.license,
        "imageAttribution": candidate.attribution,
        "imageSource": candidate.source,
        "imageNeedsReview": "yes" if candidate.needs_review else "",
        "aphiaID": str(candidate.aphia_id),
        "picID": candidate.pic_id,
        "taxonPageURL": candidate.taxon_page_url,
        "imagePageURL": candidate.image_page_url,
        "score": str(candidate.score),
    }


def cached_candidate(cached: dict[str, Any], *, scientific_name: str) -> WormsImageCandidate | None:
    if cached.get("cacheVersion") != CACHE_VERSION or not cached.get("featureImageURL"):
        return None
    try:
        aphia_id = int(cached.get("aphiaID") or 0)
    except (TypeError, ValueError):
        aphia_id = 0
    return WormsImageCandidate(
        url=str(cached["featureImageURL"]),
        aphia_id=aphia_id,
        pic_id=str(cached.get("picID") or ""),
        taxon_page_url=str(cached.get("taxonPageURL") or ""),
        image_page_url=str(cached.get("imagePageURL") or ""),
        title=scientific_name,
        license=str(cached.get("imageLicense") or ""),
        license_url="",
        attribution=str(cached.get("imageAttribution") or ""),
        source=str(cached.get("imageSource") or "worms"),
        needs_review=str(cached.get("imageNeedsReview") or "").lower() == "yes",
        score=int(cached.get("score") or 0),
    )


def apply_candidate(row: dict[str, str], candidate: WormsImageCandidate) -> None:
    row["featureImageURL"] = candidate.url
    row["imageLicense"] = candidate.license
    row["imageAttribution"] = candidate.attribution
    row["imageSource"] = candidate.source
    row["imageNeedsReview"] = "yes" if candidate.needs_review else ""


def row_has_bundled_photo(row: dict[str, str], *, photos_dir: Path) -> bool:
    uuid = (row.get("uuid") or "").strip()
    if not uuid:
        return False
    return (photos_dir / bundle_photo_filename(uuid)).exists()


def should_skip_row(
    row: dict[str, str],
    *,
    photos_dir: Path,
    overwrite: bool,
    refetch_gaps: bool,
    missing_only: bool,
) -> bool:
    if staging_row_marked_for_deletion(row):
        return True
    has_url = bool((row.get("featureImageURL") or "").strip())
    has_bundle = row_has_bundled_photo(row, photos_dir=photos_dir)
    if missing_only and not overwrite:
        if has_url or has_bundle:
            return True
        return False
    if overwrite:
        return False
    if refetch_gaps:
        if not has_url and not has_bundle:
            return False
        return (row.get("imageNeedsReview") or "").strip().lower() != "yes"
    return has_url


def run_bundle_download(*, staging: Path, photos_dir: Path, limit: int) -> int:
    command = [
        sys.executable,
        str(DOWNLOAD_SCRIPT),
        "--staging",
        str(staging),
        "--photos-dir",
        str(photos_dir),
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
        "--missing-only",
        action="store_true",
        default=True,
        help="Only species without featureImageURL and without bundled JPEG (default)",
    )
    parser.add_argument(
        "--all-rows",
        action="store_true",
        help="Process rows even when an image URL or bundle already exists",
    )
    parser.add_argument(
        "--shippable-only",
        action="store_true",
        help="Skip CC BY-NC / BY-NC-SA WoRMS photos (default stages them with imageNeedsReview=yes)",
    )
    parser.add_argument(
        "--cc0-only",
        action="store_true",
        help="Allow only CC0 / public-domain licenses",
    )
    parser.add_argument(
        "--bundle",
        action="store_true",
        help="After staging URLs, run download_marine_life_images.py",
    )
    args = parser.parse_args()

    if not args.staging.exists():
        print(f"Staging CSV not found: {args.staging}", file=sys.stderr)
        return 1

    missing_only = not args.all_rows
    allow_cc_by = not args.cc0_only and bool(image_cfg.get("allow_cc_by", True))
    include_restricted_licenses = not args.shippable_only
    request_delay = float(image_cfg.get("worms_request_delay_seconds", 0.25))

    print("WoRMS image fetch")
    print(f"Source: {WORMS_BASE_URL}")
    if args.shippable_only:
        license_mode = "CC0/public domain only" if args.cc0_only else "CC0 + CC BY only"
    else:
        license_mode = "All WoRMS gallery licenses (NC flagged for review)"
    print(f"License mode: {license_mode}")

    rows = load_staging_rows(args.staging)
    cache = load_cache(args.cache)
    eligible = [
        row
        for row in rows
        if not should_skip_row(
            row,
            photos_dir=args.photos_dir,
            overwrite=args.overwrite,
            refetch_gaps=args.refetch_gaps,
            missing_only=missing_only,
        )
    ]
    if args.limit > 0:
        eligible = eligible[: args.limit]

    print(f"Staging rows: {len(rows)}")
    print(f"Eligible for WoRMS fetch: {len(eligible)}")

    matched = 0
    missed = 0
    review_count = 0
    bypass_cache = args.overwrite or args.refetch_gaps

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
                candidate = find_worms_image(
                    scientific_name,
                    common_name=common_name,
                    allow_cc_by=allow_cc_by,
                    include_restricted_licenses=include_restricted_licenses,
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
        if candidate.needs_review:
            review_count += 1
        if not args.dry_run:
            apply_candidate(row, candidate)

        flag = "review" if candidate.needs_review else "ok"
        print(
            f"[{index}/{len(eligible)}] {flag:6} {common_name} ({scientific_name}) "
            f"score={candidate.score} {candidate.license} -> {candidate.url}"
        )

    print(f"\nSummary: matched={matched}, missed={missed}, needs_review={review_count}")

    if args.dry_run:
        print("Dry run: staging CSV not written.")
        return 0

    save_cache(args.cache, cache)
    if matched > 0:
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
