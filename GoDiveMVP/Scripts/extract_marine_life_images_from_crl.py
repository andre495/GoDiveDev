#!/usr/bin/env python3
"""
Pull species photos out of the Caribbean Reef Life (Mickey Charteris) EPUB and match
them to marine-life staging rows that currently have no image.

The EPUB stores ~2,200 photos in `OEBPS/image/`, named by scientific or common name.
This script indexes those filenames, matches them to staging rows by scientific name
(preferred) then common name, and — with `--bundle` — center-crops each match to the
960×720 4:3 mosaic aspect and writes `Resources/MarineLifePhotos/{uuid}.jpg`, exactly
like the other image pipelines.

LICENSING: CRL photos are © Mickey Charteris and require written permission before you
ship them in the app. Every staged row is flagged `imageSource=caribbean-reef-life`,
`imageLicense="© Mickey Charteris — permission required"`, and `imageNeedsReview=yes`.
This script never writes marine_life_sample.json — run sync_marine_life_staging_to_json.py
yourself only once you have permission and have reviewed the matches.

Usage:
  # Preview coverage without touching any files (default is a dry run):
  GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/extract_marine_life_images_from_crl.py

  # Actually crop + bundle JPEGs and stage metadata (needs Pillow):
  GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/extract_marine_life_images_from_crl.py --bundle

  # Re-match rows that already have any image (replace with CRL photo):
  GoDiveMVP/Scripts/.venv/bin/python GoDiveMVP/Scripts/extract_marine_life_images_from_crl.py --bundle --overwrite
"""

from __future__ import annotations

import argparse
import sys
import zipfile
from pathlib import Path
from typing import Any

from caribbean_reef_life_catalog_utils import resolve_epub_oebps_dir
from caribbean_reef_life_image_utils import (
    CRL_IMAGE_ATTRIBUTION,
    CRL_IMAGE_LICENSE,
    CRL_IMAGE_SOURCE,
    build_epub_image_index,
    is_species_image_filename,
    match_image_for_row,
    provenance_marker,
)
from download_marine_life_images import (
    DEFAULT_MANIFEST,
    DEFAULT_OUTPUT_DIR,
    DEFAULT_STAGING,
    load_manifest,
    load_staging_rows,
    save_manifest,
    write_staging_csv,
)
from fishbase_catalog_utils import (
    PROJECT_DIR,
    SCRIPT_DIR,
    load_config,
    staging_row_marked_for_deletion,
)
from marine_life_bundle_image_utils import (
    bundle_resource_name,
    process_image_bytes,
    sha256_hex,
    write_bundle_photo,
)

IMAGE_SUBDIR_NAMES = ("image", "images")
CRL_CONFIG_PATH = SCRIPT_DIR / "caribbean_reef_life_config.json"


class CRLImageStore:
    """Reads CRL species photos from an unpacked EPUB directory or a `.epub` zip."""

    def __init__(self, epub_path: Path) -> None:
        self._zip: zipfile.ZipFile | None = None
        self._zip_members: dict[str, str] = {}
        self._dir: Path | None = None
        oebps = resolve_epub_oebps_dir(epub_path)

        if oebps.suffix.lower() == ".epub":
            self._zip = zipfile.ZipFile(oebps)
            for member in self._zip.namelist():
                normalized = member.replace("\\", "/")
                base = normalized.rsplit("/", 1)[-1]
                if "/image" in normalized.lower() and is_species_image_filename(base):
                    self._zip_members.setdefault(base, member)
            return

        for name in IMAGE_SUBDIR_NAMES:
            candidate = oebps / name
            if candidate.is_dir():
                self._dir = candidate
                break
        if self._dir is None:
            raise FileNotFoundError(f"No image directory under {oebps}")

    def filenames(self) -> list[str]:
        if self._zip is not None:
            return sorted(self._zip_members)
        assert self._dir is not None
        return sorted(
            path.name for path in self._dir.iterdir() if is_species_image_filename(path.name)
        )

    def read_bytes(self, filename: str) -> bytes:
        if self._zip is not None:
            return self._zip.read(self._zip_members[filename])
        assert self._dir is not None
        return (self._dir / filename).read_bytes()

    def close(self) -> None:
        if self._zip is not None:
            self._zip.close()


def resolve_epub_path(crl_config: dict[str, Any], override: Path | None) -> Path:
    if override is not None:
        return override
    configured = str(crl_config.get("default_epub_path") or "")
    if not configured:
        raise FileNotFoundError(
            "No EPUB path configured; pass --epub or set default_epub_path in "
            "caribbean_reef_life_config.json."
        )
    path = Path(configured)
    if not path.is_absolute():
        path = PROJECT_DIR / configured
    return path


def row_needs_image(row: dict[str, str], *, overwrite: bool) -> bool:
    if staging_row_marked_for_deletion(row):
        return False
    if overwrite:
        return True
    has_resource = bool((row.get("featureImageResourceName") or "").strip())
    has_url = bool((row.get("featureImageURL") or "").strip())
    return not (has_resource or has_url)


def apply_crl_metadata(row: dict[str, str], filename: str) -> None:
    row["imageSource"] = CRL_IMAGE_SOURCE
    row["imageLicense"] = CRL_IMAGE_LICENSE
    row["imageAttribution"] = CRL_IMAGE_ATTRIBUTION
    row["imageNeedsReview"] = "yes"


def print_license_banner() -> None:
    print("Caribbean Reef Life image extraction")
    print(
        "License note: photos are © Mickey Charteris — get written permission before "
        "shipping. Rows are flagged imageNeedsReview=yes; JSON is not synced by this script."
    )


def main() -> int:
    fish_config = load_config()
    crl_config = load_config(CRL_CONFIG_PATH)
    bundle_cfg = fish_config.get("marine_life_bundle_photos", {})

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--epub", type=Path, default=None, help="Path to CRL EPUB (dir or .epub)")
    parser.add_argument("--staging", type=Path, default=DEFAULT_STAGING)
    parser.add_argument("--photos-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument(
        "--bundle",
        action="store_true",
        help="Crop + write JPEGs and stage metadata (default: dry-run preview only)",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Match rows that already have an image (replace with the CRL photo)",
    )
    args = parser.parse_args()

    print_license_banner()

    try:
        epub_path = resolve_epub_path(crl_config, args.epub)
    except FileNotFoundError as error:
        print(str(error), file=sys.stderr)
        return 1
    if not epub_path.exists():
        print(f"EPUB not found: {epub_path}", file=sys.stderr)
        print("Pass --epub /path/to/'Caribbean Reef Life 4.epub'", file=sys.stderr)
        return 1

    if not args.staging.exists():
        print(f"Staging CSV not found: {args.staging}", file=sys.stderr)
        return 1

    try:
        store = CRLImageStore(epub_path)
    except FileNotFoundError as error:
        print(str(error), file=sys.stderr)
        return 1

    try:
        image_filenames = store.filenames()
        index = build_epub_image_index(image_filenames)
        print(f"EPUB: {epub_path}")
        print(f"Indexed CRL images: {index.count}")

        rows = load_staging_rows(args.staging)
        manifest = load_manifest(args.manifest)
        eligible = [row for row in rows if row_needs_image(row, overwrite=args.overwrite)]
        print(f"Staging rows: {len(rows)}")
        print(f"Rows needing an image: {len(eligible)}")

        matched: list[tuple[dict[str, str], str, str]] = []
        for row in eligible:
            result = match_image_for_row(
                (row.get("scientificName") or "").strip(),
                (row.get("commonName") or "").strip(),
                index,
            )
            if result is not None:
                matched.append((row, result.filename, result.match_kind))

        if args.limit > 0:
            matched = matched[: args.limit]

        sci_matches = sum(1 for _row, _fn, kind in matched if kind == "scientific")
        common_matches = len(matched) - sci_matches
        print(
            f"Matched to CRL photos: {len(matched)} "
            f"(scientific={sci_matches}, common={common_matches})"
        )

        if not args.bundle:
            print("\nDry run (default): no files written. Sample matches:")
            for row, filename, kind in matched[:15]:
                label = (row.get("commonName") or row.get("scientificName") or row.get("uuid") or "").strip()
                print(f"  [{kind:10}] {label[:34]:34} -> {filename}")
            print(f"\nRe-run with --bundle to crop + write {len(matched)} JPEGs and stage metadata.")
            return 0

        bundled = 0
        failed = 0
        for index_position, (row, filename, _kind) in enumerate(matched, start=1):
            uuid = (row.get("uuid") or "").strip()
            label = (row.get("commonName") or row.get("scientificName") or uuid).strip()
            if not uuid:
                failed += 1
                continue
            try:
                raw = store.read_bytes(filename)
                jpeg_bytes = process_image_bytes(
                    raw,
                    output_width=int(bundle_cfg.get("output_width", 960)),
                    output_height=int(bundle_cfg.get("output_height", 720)),
                    jpeg_quality=int(bundle_cfg.get("jpeg_quality", 82)),
                )
                destination = write_bundle_photo(args.photos_dir, uuid, jpeg_bytes)
                row["featureImageResourceName"] = bundle_resource_name(uuid)
                apply_crl_metadata(row, filename)
                manifest[uuid] = {
                    "sourceURL": provenance_marker(filename),
                    "sha256": sha256_hex(jpeg_bytes),
                    "bytes": len(jpeg_bytes),
                    "path": str(destination.relative_to(PROJECT_DIR)),
                }
                bundled += 1
                print(f"[{index_position}/{len(matched)}] saved {label[:34]:34} -> {destination.name}")
            except Exception as error:  # noqa: BLE001 - report per-file, keep going
                failed += 1
                print(f"[{index_position}/{len(matched)}] failed {label}: {error}", file=sys.stderr)

        if bundled:
            write_staging_csv(args.staging, rows)
            save_manifest(args.manifest, manifest)
            print(f"\nUpdated staging CSV: {args.staging}")
            print(f"Wrote manifest: {args.manifest}")

        print(f"\nSummary: bundled={bundled}, failed={failed}, matched={len(matched)}")
        print(
            "Next: review in marine_life_image_review.html. Only after you have "
            "permission: sync_marine_life_staging_to_json.py --all"
        )
        return 0 if failed == 0 else 1
    finally:
        store.close()


if __name__ == "__main__":
    sys.exit(main())
