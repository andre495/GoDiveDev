#!/usr/bin/env python3
"""
Find CC0 / CC BY hero images for marine life staging rows.

Primary source: Wikimedia Commons (File namespace, license metadata).
Fallback: Openverse API (same licenses, broader providers).

Writes featureImageURL plus workflow metadata columns on the staging CSV.
Does not overwrite rows that already have images unless --overwrite is set.
Skips species that already have feature_image in marine_life_sample.json by default.

Usage:
  GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/fetch_marine_life_images.py --dry-run --limit 20
  GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/fetch_marine_life_images.py
  GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/fetch_marine_life_images.py --refetch-gaps
  GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/sync_marine_life_staging_to_json.py --all
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path
from typing import Any

from fishbase_catalog_utils import DEFAULT_CONFIG_PATH, PROJECT_DIR, STAGING_FIELDNAMES, load_config
from marine_life_image_utils import (
    CACHE_VERSION,
    ImageCandidate,
    find_species_image,
    license_is_cc0,
)


IMAGE_WORKFLOW_FIELDNAMES = [
    "imageLicense",
    "imageAttribution",
    "imageSource",
    "imageNeedsReview",
]

STAGING_WITH_IMAGE_FIELDS = STAGING_FIELDNAMES + [
    field for field in IMAGE_WORKFLOW_FIELDNAMES if field not in STAGING_FIELDNAMES
]

DEFAULT_STAGING = PROJECT_DIR / "MockData/marine_life_caribbean_staging.csv"
DEFAULT_JSON = PROJECT_DIR / "MockData/marine_life_sample.json"
DEFAULT_CACHE = PROJECT_DIR / "MockData/marine_life_image_cache.json"


def load_staging_rows(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        rows = list(reader)
    for row in rows:
        for field in STAGING_WITH_IMAGE_FIELDS:
            row.setdefault(field, "")
    return rows


def load_json_images(path: Path) -> dict[str, str]:
    if not path.exists():
        return {}
    with path.open(encoding="utf-8") as handle:
        data = json.load(handle)
    by_uuid: dict[str, str] = {}
    for entry in data:
        uuid = str(entry.get("uuid") or "").strip()
        image = str(entry.get("feature_image") or "").strip()
        if uuid and image:
            by_uuid[uuid] = image
    return by_uuid


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
        "featureImageURL": candidate.thumbnail_url,
        "imageLicense": candidate.license,
        "imageAttribution": candidate.attribution,
        "imageSource": candidate.source,
        "imageNeedsReview": "yes" if candidate.needs_review else "",
        "fullImageURL": candidate.url,
        "score": str(candidate.score),
    }


def cached_candidate(
    cached: dict[str, Any],
    *,
    common_name: str,
    scientific_name: str,
) -> ImageCandidate | None:
    if cached.get("cacheVersion") != CACHE_VERSION:
        return None
    if not cached.get("featureImageURL"):
        return None
    return ImageCandidate(
        url=str(cached.get("fullImageURL") or cached.get("featureImageURL")),
        thumbnail_url=str(cached["featureImageURL"]),
        title=common_name or scientific_name,
        license=str(cached.get("imageLicense") or ""),
        license_url="",
        attribution=str(cached.get("imageAttribution") or ""),
        source=str(cached.get("imageSource") or "cache"),
        width=0,
        height=0,
        score=int(cached.get("score") or 0),
        needs_review=str(cached.get("imageNeedsReview") or "").lower() == "yes",
    )


def cached_score(cached: dict[str, Any] | None) -> int:
    if not cached or cached.get("cacheVersion") != CACHE_VERSION:
        return 0
    try:
        return int(cached.get("score") or 0)
    except (TypeError, ValueError):
        return 0


def row_needs_refetch(row: dict[str, str]) -> bool:
    if not (row.get("featureImageURL") or "").strip():
        return True
    return (row.get("imageNeedsReview") or "").strip().lower() == "yes"


def should_replace_existing(
    row: dict[str, str],
    candidate: ImageCandidate,
    *,
    old_score: int,
) -> bool:
    if not (row.get("featureImageURL") or "").strip():
        return True
    if (row.get("imageNeedsReview") or "").strip().lower() == "yes":
        if not candidate.needs_review:
            return True
        return candidate.score > old_score
    return candidate.score > old_score + 5


def apply_candidate(row: dict[str, str], candidate: ImageCandidate) -> None:
    row["featureImageURL"] = candidate.thumbnail_url
    row["imageLicense"] = candidate.license
    row["imageAttribution"] = candidate.attribution
    row["imageSource"] = candidate.source
    row["imageNeedsReview"] = "yes" if candidate.needs_review else ""


def should_skip_row(
    row: dict[str, str],
    *,
    overwrite: bool,
    refetch_gaps: bool,
    improve_reviewed: bool,
    respect_bundled_images: bool,
    bundled_images: dict[str, str],
) -> bool:
    if overwrite:
        return False
    if improve_reviewed:
        return (row.get("imageNeedsReview") or "").strip().lower() != "yes"
    if refetch_gaps and row_needs_refetch(row):
        return False
    if (row.get("featureImageURL") or "").strip():
        return True
    if respect_bundled_images:
        uuid = (row.get("uuid") or "").strip()
        if uuid and bundled_images.get(uuid):
            return True
    return False


def write_staging_csv(path: Path, rows: list[dict[str, str]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=STAGING_WITH_IMAGE_FIELDS, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    config = load_config()
    image_cfg = config.get("marine_life_images", {})

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--staging", type=Path, default=PROJECT_DIR / config.get("output_staging_csv", DEFAULT_STAGING.name))
    parser.add_argument("--json", type=Path, default=DEFAULT_JSON, dest="json_path")
    parser.add_argument("--cache", type=Path, default=DEFAULT_CACHE)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--limit", type=int, default=0, help="Process only the first N eligible rows")
    parser.add_argument("--overwrite", action="store_true", help="Replace existing staging image URLs")
    parser.add_argument(
        "--refetch-gaps",
        action="store_true",
        help="Re-query rows missing images or flagged imageNeedsReview=yes",
    )
    parser.add_argument(
        "--improve-reviewed",
        action="store_true",
        help="Re-query only imageNeedsReview=yes rows and replace when a better match is found",
    )
    parser.add_argument(
        "--no-respect-bundled",
        action="store_true",
        help="Fetch even when marine_life_sample.json already has feature_image",
    )
    parser.add_argument(
        "--cc0-only",
        action="store_true",
        help="Allow only CC0 / public-domain licenses (skip CC BY)",
    )
    args = parser.parse_args()

    if not args.staging.exists():
        print(f"Staging CSV not found: {args.staging}", file=sys.stderr)
        return 1

    allow_cc_by = not args.cc0_only and bool(image_cfg.get("allow_cc_by", True))
    commons_delay = float(image_cfg.get("commons_request_delay_seconds", 0.2))
    openverse_delay = float(image_cfg.get("openverse_request_delay_seconds", 1.0))
    search_suffixes = tuple(image_cfg.get("search_suffixes") or ("underwater", "diver", "scuba"))

    rows = load_staging_rows(args.staging)
    bundled_images = load_json_images(args.json_path)
    cache = load_cache(args.cache)

    eligible = [
        row
        for row in rows
        if not should_skip_row(
            row,
            overwrite=args.overwrite,
            refetch_gaps=args.refetch_gaps,
            improve_reviewed=args.improve_reviewed,
            respect_bundled_images=not args.no_respect_bundled,
            bundled_images=bundled_images,
        )
    ]
    if args.limit > 0:
        eligible = eligible[: args.limit]

    print(f"Staging rows: {len(rows)}")
    print(f"Eligible for image fetch: {len(eligible)}")
    print(f"License mode: {'CC0/public domain only' if not allow_cc_by else 'CC0 first, then CC BY'}")
    print(f"Search suffixes: {', '.join(search_suffixes)}")

    matched = 0
    cc0_count = 0
    by_count = 0
    review_count = 0
    missed = 0
    kept_existing = 0
    improved = 0

    for index, row in enumerate(eligible, start=1):
        scientific_name = (row.get("scientificName") or "").strip()
        common_name = (row.get("commonName") or "").strip()
        if not scientific_name:
            missed += 1
            continue

        cache_key = scientific_name
        cached_entry = cache.get(cache_key, {})
        old_score = cached_score(cached_entry)
        bypass_cache = args.overwrite or args.refetch_gaps or args.improve_reviewed

        candidate: ImageCandidate | None = None
        if not bypass_cache:
            candidate = cached_candidate(
                cached_entry,
                common_name=common_name,
                scientific_name=scientific_name,
            )

        if candidate is None:
            candidate = find_species_image(
                scientific_name,
                common_name=common_name,
                allow_cc_by=allow_cc_by,
                search_suffixes=search_suffixes,
                commons_sleep_seconds=commons_delay,
                openverse_sleep_seconds=openverse_delay if index % 5 == 0 else 0.0,
            )
            if candidate:
                cache[cache_key] = candidate_to_cache_entry(candidate)

        if candidate is None:
            missed += 1
            print(f"[{index}/{len(eligible)}] miss  {common_name} ({scientific_name})")
            continue

        if (row.get("featureImageURL") or "").strip() and not should_replace_existing(
            row,
            candidate,
            old_score=old_score,
        ):
            kept_existing += 1
            print(
                f"[{index}/{len(eligible)}] keep  {common_name} "
                f"({scientific_name}) existing score {old_score} >= {candidate.score}"
            )
            continue

        if (row.get("featureImageURL") or "").strip():
            improved += 1

        matched += 1
        if license_is_cc0(candidate.license):
            cc0_count += 1
        else:
            by_count += 1
        if candidate.needs_review:
            review_count += 1

        if not args.dry_run:
            apply_candidate(row, candidate)

        flag = "review" if candidate.needs_review else "ok"
        print(
            f"[{index}/{len(eligible)}] {flag:6} {common_name} "
            f"({scientific_name}) -> {candidate.source} {candidate.license} "
            f"score={candidate.score}"
        )

    print(
        f"\nSummary: matched={matched}, improved={improved}, kept_existing={kept_existing}, "
        f"missed={missed}, cc0={cc0_count}, cc_by={by_count}, needs_review={review_count}"
    )

    if args.dry_run:
        print("Dry run: staging CSV not written.")
        return 0

    if not args.cache.parent.exists():
        args.cache.parent.mkdir(parents=True, exist_ok=True)
    save_cache(args.cache, cache)
    write_staging_csv(args.staging, rows)
    print(f"Wrote {args.staging}")
    print(f"Wrote {args.cache}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
