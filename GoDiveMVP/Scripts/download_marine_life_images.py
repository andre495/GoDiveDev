#!/usr/bin/env python3
"""
Download approved staging URLs into bundled offline JPEGs for Field Guide.

Reads featureImageURL from marine_life_caribbean_staging.csv, center-crops to the
same 4:3 mosaic aspect used in-app, resizes to 960×720, and writes:

  GoDiveMVP/Resources/MarineLifePhotos/{uuid}.jpg

Sets featureImageResourceName on each successful row, then run
sync_marine_life_staging_to_json.py --all to ship feature_image_resource.

Usage:
  GoDiveMVP/Scripts/.venv/bin/pip install Pillow
  GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/download_marine_life_images.py --dry-run --limit 5
  GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/download_marine_life_images.py
  GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/download_marine_life_images.py --overwrite
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
import time
import urllib.error
from pathlib import Path
from typing import Any

from fishbase_catalog_utils import (
    PROJECT_DIR,
    STAGING_WITH_IMAGE_FIELDS,
    load_config,
    staging_row_marked_for_deletion,
)
from marine_life_bundle_image_utils import (
    bundle_resource_name,
    download_and_process_species_photo,
    write_bundle_photo,
)

try:
    from PIL import UnidentifiedImageError
except ImportError:  # pragma: no cover
    UnidentifiedImageError = Exception  # type: ignore[misc, assignment]

DEFAULT_STAGING = PROJECT_DIR / "MockData/marine_life_caribbean_staging.csv"
DEFAULT_OUTPUT_DIR = PROJECT_DIR / "Resources/MarineLifePhotos"
DEFAULT_MANIFEST = PROJECT_DIR / "MockData/marine_life_bundle_photos_manifest.json"

def load_staging_rows(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        rows = list(reader)
    for row in rows:
        for field in STAGING_WITH_IMAGE_FIELDS:
            row.setdefault(field, "")
    return rows


def write_staging_csv(path: Path, rows: list[dict[str, str]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=STAGING_WITH_IMAGE_FIELDS, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def load_manifest(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def save_manifest(path: Path, manifest: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def should_process_row(
    row: dict[str, str],
    *,
    output_dir: Path,
    overwrite: bool,
    only_missing: bool,
) -> bool:
    if staging_row_marked_for_deletion(row):
        return False

    source_url = (row.get("featureImageURL") or "").strip()
    if not source_url:
        return False

    uuid = (row.get("uuid") or "").strip()
    if not uuid:
        return False

    destination = output_dir / f"{uuid}.jpg"
    if overwrite:
        return True
    if only_missing and destination.exists():
        if not (row.get("featureImageResourceName") or "").strip():
            return True
        return False
    if destination.exists() and (row.get("featureImageResourceName") or "").strip():
        return False
    return True


def main() -> int:
    config = load_config()
    bundle_cfg = config.get("marine_life_bundle_photos", {})

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--staging", type=Path, default=DEFAULT_STAGING)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument("--overwrite", action="store_true", help="Re-download even when JPEG exists")
    parser.add_argument(
        "--only-missing",
        action="store_true",
        help="Skip rows that already have a bundled JPEG (default when not overwriting)",
    )
    parser.add_argument("--sleep-seconds", type=float, default=1.0)
    args = parser.parse_args()

    if not args.staging.exists():
        print(f"Staging CSV not found: {args.staging}", file=sys.stderr)
        return 1

    only_missing = args.only_missing or not args.overwrite
    rows = load_staging_rows(args.staging)
    manifest = load_manifest(args.manifest)

    eligible = [
        row
        for row in rows
        if should_process_row(
            row,
            output_dir=args.output_dir,
            overwrite=args.overwrite,
            only_missing=only_missing,
        )
    ]
    if args.limit > 0:
        eligible = eligible[: args.limit]

    print(f"Staging rows: {len(rows)}")
    print(f"Eligible for bundle download: {len(eligible)}")
    print(f"Output directory: {args.output_dir}")

    downloaded = 0
    skipped = 0
    failed = 0

    for index, row in enumerate(eligible, start=1):
        uuid = row["uuid"].strip()
        common_name = (row.get("commonName") or "").strip()
        scientific_name = (row.get("scientificName") or "").strip()
        source_url = row["featureImageURL"].strip()
        label = common_name or scientific_name or uuid

        if args.dry_run:
            print(f"[{index}/{len(eligible)}] would download {label} -> {uuid}.jpg")
            continue

        try:
            jpeg_bytes, digest = download_and_process_species_photo(
                source_url,
                output_width=int(bundle_cfg.get("output_width", 960)),
                output_height=int(bundle_cfg.get("output_height", 720)),
                jpeg_quality=int(bundle_cfg.get("jpeg_quality", 82)),
            )
            destination = write_bundle_photo(args.output_dir, uuid, jpeg_bytes)
            row["featureImageResourceName"] = bundle_resource_name(uuid)
            manifest[uuid] = {
                "sourceURL": source_url,
                "sha256": digest,
                "bytes": len(jpeg_bytes),
                "path": str(destination.relative_to(PROJECT_DIR)),
            }
            downloaded += 1
            print(f"[{index}/{len(eligible)}] saved  {label} -> {destination.name} ({len(jpeg_bytes) // 1024} KB)")
        except (urllib.error.URLError, urllib.error.HTTPError, UnidentifiedImageError, ValueError, RuntimeError) as error:
            failed += 1
            print(f"[{index}/{len(eligible)}] failed {label}: {error}", file=sys.stderr)

        if args.sleep_seconds > 0:
            time.sleep(args.sleep_seconds)

    if args.dry_run:
        print("Dry run: no files or CSV changes written.")
        return 0

    if downloaded:
        write_staging_csv(args.staging, rows)
        save_manifest(args.manifest, manifest)
        print(f"Updated staging CSV: {args.staging}")
        print(f"Wrote manifest: {args.manifest}")

    print(
        f"\nSummary: downloaded={downloaded}, skipped={skipped}, failed={failed}, "
        f"eligible={len(eligible)}"
    )
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
