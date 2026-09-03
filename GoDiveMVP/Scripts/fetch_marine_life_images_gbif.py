#!/usr/bin/env python3
"""
Find CC0 / CC BY hero images on GBIF occurrence records for catalog species.

Matches staging scientificName via /v1/species/match, then searches
occurrence still images. Keeps only photos whose media.license is CC0 or
CC BY (not the occurrence-level license facet). Writes featureImageURL plus
workflow metadata with imageSource=gbif. Default processes every staging row;
existing URLs are kept when GBIF has no shippable photo.

Usage:
  GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/fetch_marine_life_images_gbif.py --dry-run --limit 20
  GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/fetch_marine_life_images_gbif.py
  GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/fetch_marine_life_images_gbif.py --missing-only
  GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/fetch_marine_life_images_gbif.py --bundle
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
from gbif_image_utils import CACHE_VERSION, GBIF_API, find_gbif_image
from marine_life_bundle_image_utils import bundle_photo_filename
from marine_life_image_utils import ImageCandidate, license_is_cc0

DEFAULT_CACHE = PROJECT_DIR / "CatalogAuthoring/gbif_image_cache.json"
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


def candidate_to_cache_entry(candidate: ImageCandidate) -> dict[str, str]:
    return {
        "cacheVersion": CACHE_VERSION,
        "featureImageURL": candidate.url,
        "imageLicense": candidate.license,
        "imageAttribution": candidate.attribution,
        "imageSource": candidate.source,
        "imageNeedsReview": "yes" if candidate.needs_review else "",
        "score": str(candidate.score),
    }


def cached_candidate(cached: dict[str, Any], *, scientific_name: str) -> ImageCandidate | None:
    if cached.get("cacheVersion") != CACHE_VERSION or not cached.get("featureImageURL"):
        return None
    return ImageCandidate(
        url=str(cached["featureImageURL"]),
        thumbnail_url=str(cached["featureImageURL"]),
        title=scientific_name,
        license=str(cached.get("imageLicense") or ""),
        license_url="",
        attribution=str(cached.get("imageAttribution") or ""),
        source=str(cached.get("imageSource") or "gbif"),
        width=0,
        height=0,
        score=int(cached.get("score") or 0),
        needs_review=str(cached.get("imageNeedsReview") or "").lower() == "yes",
    )


def apply_candidate(row: dict[str, str], candidate: ImageCandidate) -> None:
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
    missing_only: bool,
) -> bool:
    if staging_row_marked_for_deletion(row):
        return True
    if not missing_only:
        return False
    has_url = bool((row.get("featureImageURL") or "").strip())
    has_bundle = row_has_bundled_photo(row, photos_dir=photos_dir)
    return has_url or has_bundle


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
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Ignore the image cache and re-query GBIF for every eligible row",
    )
    parser.add_argument(
        "--missing-only",
        action="store_true",
        help="Skip rows that already have featureImageURL or a bundled JPEG",
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

    allow_cc_by = not args.cc0_only and bool(image_cfg.get("allow_cc_by", True))
    request_delay = float(image_cfg.get("gbif_request_delay_seconds", 0.25))

    print("GBIF occurrence image fetch")
    print(f"Source: {GBIF_API}")
    print(f"License mode: {'CC0/public domain only' if not allow_cc_by else 'CC0 + CC BY (media.license)'}")
    print(f"Scope: {'missing images only' if args.missing_only else 'all catalog species'}")

    rows = load_staging_rows(args.staging)
    cache = load_cache(args.cache)
    eligible = [
        row
        for row in rows
        if not should_skip_row(
            row,
            photos_dir=args.photos_dir,
            missing_only=args.missing_only,
        )
    ]
    if args.limit > 0:
        eligible = eligible[: args.limit]

    print(f"Staging rows: {len(rows)}")
    print(f"Eligible for GBIF fetch: {len(eligible)}")

    matched = 0
    missed = 0
    review_count = 0
    cc0_count = 0
    by_count = 0
    bypass_cache = args.overwrite

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
                candidate = find_gbif_image(
                    scientific_name,
                    common_name=common_name,
                    allow_cc_by=allow_cc_by,
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
        if license_is_cc0(candidate.license):
            cc0_count += 1
        else:
            by_count += 1
        if not args.dry_run:
            apply_candidate(row, candidate)

        flag = "review" if candidate.needs_review else "ok"
        print(
            f"[{index}/{len(eligible)}] {flag:6} {common_name} ({scientific_name}) "
            f"score={candidate.score} {candidate.license} -> {candidate.url}"
        )

        if not args.dry_run and index % 25 == 0:
            save_cache(args.cache, cache)
            write_staging_csv(args.staging, rows)
            print(f"  checkpoint {index}/{len(eligible)} wrote staging + cache")

    print(
        f"\nSummary: matched={matched}, missed={missed}, "
        f"cc0={cc0_count}, cc_by={by_count}, needs_review={review_count}"
    )

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
