#!/usr/bin/env python3
"""
Extract the Scientific Name Index from Mickey Charteris's Caribbean Reef Life ebook.

The book's full glossary is not published online; use your purchased PDF or EPUB
(iBooks often unpacks to a folder named *.epub on the Desktop).

Usage:
  python3 GoDiveMVP/Scripts/extract_caribbean_reef_life_reference.py --epub ~/Desktop/Caribbean\ Reef\ Life\ 4.epub
  python3 GoDiveMVP/Scripts/extract_caribbean_reef_life_reference.py --pdf ~/Downloads/CaribbeanReefLife.pdf
"""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

from caribbean_reef_life_catalog_utils import (
    extract_crl_reference_from_epub,
    extract_crl_reference_from_pdf,
)
from fishbase_catalog_utils import PROJECT_DIR, load_config

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_CONFIG_PATH = SCRIPT_DIR / "caribbean_reef_life_config.json"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG_PATH)
    parser.add_argument("--pdf", type=Path, help="Path to Caribbean Reef Life PDF")
    parser.add_argument(
        "--epub",
        type=Path,
        help="Path to Caribbean Reef Life EPUB (.epub zip or unpacked iBooks folder)",
    )
    args = parser.parse_args()

    if args.pdf and args.epub:
        print("Pass only one of --pdf or --epub.", file=sys.stderr)
        return 1

    config = load_config(args.config)
    cache_path = PROJECT_DIR / config["reference_cache_csv"]

    if args.epub:
        source_path = args.epub.expanduser()
        source_kind = "epub"
    elif args.pdf:
        source_path = args.pdf.expanduser()
        source_kind = "pdf"
    else:
        default_epub = config.get("default_epub_path")
        if default_epub:
            source_path = Path(default_epub).expanduser()
            if not source_path.is_absolute():
                source_path = PROJECT_DIR / source_path
            source_kind = "epub"
        else:
            source_path = (PROJECT_DIR / config["default_pdf_path"]).expanduser()
            source_kind = "pdf"

    if source_kind == "epub":
        if not source_path.exists():
            print(f"EPUB not found: {source_path}", file=sys.stderr)
            print(
                "Pass --epub /path/to/Caribbean\\ Reef\\ Life\\ 4.epub "
                "(iBooks unpacked folders are supported).",
                file=sys.stderr,
            )
            return 1
        print(f"Extracting scientific names from EPUB {source_path}...")
        rows = extract_crl_reference_from_epub(source_path)
    else:
        if not source_path.is_file():
            print(f"PDF not found: {source_path}", file=sys.stderr)
            print(
                "Place your Caribbean Reef Life ebook PDF at MockData/CaribbeanReefLife.pdf "
                "or pass --pdf /path/to/file.pdf",
                file=sys.stderr,
            )
            return 1
        print(f"Extracting scientific names from PDF {source_path}...")
        rows = extract_crl_reference_from_pdf(source_path)

    if not rows:
        print("No species extracted. Check that the ebook contains readable index text.", file=sys.stderr)
        return 1

    cache_path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = ["scientificName", "match_key", "genus", "source"]
    with cache_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    sources = {}
    for row in rows:
        sources[row["source"]] = sources.get(row["source"], 0) + 1

    print(f"Wrote {len(rows)} names to {cache_path}")
    for source, count in sorted(sources.items()):
        print(f"  {source}: {count}")
    print(config.get("attribution", ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
