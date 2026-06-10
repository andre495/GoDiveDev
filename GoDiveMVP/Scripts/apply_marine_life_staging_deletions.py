#!/usr/bin/env python3
"""
Remove staging rows marked markForDeletion=yes from the Caribbean catalog workflow.

Deletes matching rows from marine_life_caribbean_staging.csv, optional bundled JPEGs,
manifest entries, and (with --sync-json) drops uuids from marine_life_sample.json.

Usage:
  GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/apply_marine_life_staging_deletions.py --dry-run
  GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/apply_marine_life_staging_deletions.py --sync-json
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

from download_marine_life_images import (
    DEFAULT_MANIFEST,
    DEFAULT_OUTPUT_DIR,
    DEFAULT_STAGING,
    load_staging_rows,
    write_staging_csv,
)
from fishbase_catalog_utils import PROJECT_DIR, staging_row_marked_for_deletion
from marine_life_bundle_image_utils import bundle_photo_filename

SCRIPT_DIR = Path(__file__).resolve().parent
SYNC_SCRIPT = SCRIPT_DIR / "sync_marine_life_staging_to_json.py"
DEFAULT_JSON = PROJECT_DIR / "MockData/marine_life_sample.json"


def marked_rows(rows: list[dict[str, str]]) -> list[dict[str, str]]:
    return [row for row in rows if staging_row_marked_for_deletion(row)]


def remove_uuids_from_json(json_path: Path, uuids: list[str], *, dry_run: bool) -> int:
    if not uuids or not json_path.exists():
        return 0
    remove_set = set(uuids)
    catalog = json.loads(json_path.read_text(encoding="utf-8"))
    filtered = [row for row in catalog if row.get("uuid") not in remove_set]
    removed_count = len(catalog) - len(filtered)
    if removed_count and not dry_run:
        with json_path.open("w", encoding="utf-8") as handle:
            json.dump(filtered, handle, indent=2, ensure_ascii=False)
            handle.write("\n")
    return removed_count


def apply_staging_deletions(
    *,
    staging_path: Path,
    photos_dir: Path,
    manifest_path: Path,
    json_path: Path,
    delete_photos: bool,
    sync_json: bool,
    dry_run: bool,
) -> dict[str, Any]:
    rows = load_staging_rows(staging_path)
    to_remove = marked_rows(rows)
    remove_uuids = [(row.get("uuid") or "").strip() for row in to_remove]
    remove_uuids = [uuid for uuid in remove_uuids if uuid]

    kept_rows = [row for row in rows if not staging_row_marked_for_deletion(row)]
    photo_paths = [photos_dir / bundle_photo_filename(uuid) for uuid in remove_uuids]

    manifest: dict[str, Any] = {}
    if manifest_path.exists():
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))

    removed_photos: list[str] = []
    for photo_path in photo_paths:
        if photo_path.exists():
            try:
                removed_photos.append(str(photo_path.relative_to(PROJECT_DIR)))
            except ValueError:
                removed_photos.append(str(photo_path))
            if not dry_run:
                photo_path.unlink()

    removed_manifest_keys = [uuid for uuid in remove_uuids if uuid in manifest]
    removed_from_json = 0
    if sync_json:
        removed_from_json = remove_uuids_from_json(json_path, remove_uuids, dry_run=dry_run)

    if not dry_run:
        for uuid in removed_manifest_keys:
            manifest.pop(uuid, None)
        if removed_manifest_keys or (manifest and not manifest_path.exists()):
            manifest_path.parent.mkdir(parents=True, exist_ok=True)
            with manifest_path.open("w", encoding="utf-8") as handle:
                json.dump(manifest, handle, indent=2, ensure_ascii=False)
                handle.write("\n")
        write_staging_csv(staging_path, kept_rows)

    return {
        "removed_count": len(to_remove),
        "removed_uuids": remove_uuids,
        "remaining_count": len(kept_rows),
        "removed_photos": removed_photos,
        "removed_manifest_keys": removed_manifest_keys,
        "removed_from_json": removed_from_json,
    }


def run_sync_json(*, include_all: bool) -> int:
    command = [sys.executable, str(SYNC_SCRIPT)]
    if include_all:
        command.append("--all")
    completed = subprocess.run(command, check=False)
    return completed.returncode


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--staging", type=Path, default=DEFAULT_STAGING)
    parser.add_argument("--photos-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--json", type=Path, default=DEFAULT_JSON, dest="json_path")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument(
        "--keep-photos",
        action="store_true",
        help="Leave bundled JPEGs on disk (staging + manifest only)",
    )
    parser.add_argument(
        "--sync-json",
        action="store_true",
        help="Run sync_marine_life_staging_to_json.py after removing staging rows",
    )
    parser.add_argument(
        "--all",
        action="store_true",
        help="Pass --all to sync script (ship full catalog after deletions)",
    )
    args = parser.parse_args()

    if not args.staging.exists():
        print(f"Staging CSV not found: {args.staging}", file=sys.stderr)
        return 1

    summary = apply_staging_deletions(
        staging_path=args.staging,
        photos_dir=args.photos_dir,
        manifest_path=args.manifest,
        json_path=args.json_path,
        delete_photos=not args.keep_photos,
        sync_json=args.sync_json,
        dry_run=args.dry_run,
    )

    prefix = "Would remove" if args.dry_run else "Removed"
    print(f"{prefix} {summary['removed_count']} staging row(s); {summary['remaining_count']} remain.")
    if summary["removed_photos"]:
        print(f"{prefix} {len(summary['removed_photos'])} bundled photo(s).")
    if summary["removed_manifest_keys"]:
        print(f"{prefix} {len(summary['removed_manifest_keys'])} manifest entry(ies).")
    if summary["removed_from_json"]:
        print(f"{prefix} {summary['removed_from_json']} species from {args.json_path.name}.")

    for uuid in summary["removed_uuids"][:12]:
        print(f"  - {uuid}")
    if len(summary["removed_uuids"]) > 12:
        print(f"  … and {len(summary['removed_uuids']) - 12} more")

    if args.dry_run:
        print("Dry run: no files written.")
        return 0

    if summary["removed_count"] == 0:
        print("Nothing marked for deletion.")
        return 0

    if args.sync_json:
        print(f"Running sync: {SYNC_SCRIPT.name}" + (" --all" if args.all else ""))
        return run_sync_json(include_all=args.all)

    print("Tip: run with --sync-json --all to refresh marine_life_sample.json after deletions.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
