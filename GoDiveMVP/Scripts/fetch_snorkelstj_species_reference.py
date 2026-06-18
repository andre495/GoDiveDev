#!/usr/bin/env python3
"""
Fetch Caribbean species common/scientific names from snorkelstj.com.

Crawls the All Species List and coral/fish/creature gallery pages, parses each
species profile <title>, and caches results for fuzzy-match validation.

Usage:
  python3 GoDiveMVP/Scripts/fetch_snorkelstj_species_reference.py
  python3 GoDiveMVP/Scripts/fetch_snorkelstj_species_reference.py --refresh
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

from fishbase_catalog_utils import PROJECT_DIR, load_config, normalize_scientific_name_for_match
from snorkelstj_catalog_utils import (
    SNORKELSTJ_NAV_PAGES,
    common_name_tokens,
    normalize_common_name_for_match,
    parse_snorkelstj_title,
)

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_CONFIG_PATH = SCRIPT_DIR / "snorkelstj_caribbean_config.json"
LINK_PATTERN = re.compile(r'href="([a-z0-9-]+\.html)"', re.IGNORECASE)
TITLE_PATTERN = re.compile(r"<title>([^<]+)</title>", re.IGNORECASE)


def fetch_text(url: str) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": "GoDiveMVP/1.0"})
    with urllib.request.urlopen(request, timeout=120) as response:
        return response.read().decode("utf-8", errors="replace")


def discover_species_slugs(base_url: str, seed_pages: list[str]) -> list[str]:
    slugs: set[str] = set()
    for page in seed_pages:
        html = fetch_text(f"{base_url}/{page}")
        for match in LINK_PATTERN.findall(html):
            if match not in SNORKELSTJ_NAV_PAGES and match != page:
                slugs.add(match)
    return sorted(slugs)


def crawl_snorkelstj_reference(config: dict, *, refresh: bool) -> list[dict[str, str]]:
    cache_path = PROJECT_DIR / config["reference_cache_csv"]
    if cache_path.is_file() and not refresh:
        with cache_path.open(encoding="utf-8", newline="") as handle:
            return list(csv.DictReader(handle))

    base_url = config["base_url"].rstrip("/")
    delay = float(config.get("request_delay_seconds", 0.05))
    slugs = discover_species_slugs(base_url, config.get("seed_pages") or ["list-species.html"])
    print(f"Discovered {len(slugs)} candidate species pages.")

    rows: list[dict[str, str]] = []
    seen_slugs: set[str] = set()
    failures = 0

    for index, slug in enumerate(slugs, start=1):
        if slug in seen_slugs:
            continue
        seen_slugs.add(slug)
        url = f"{base_url}/{slug}"
        try:
            html = fetch_text(url)
        except urllib.error.HTTPError:
            failures += 1
            continue
        except urllib.error.URLError as exc:
            print(f"Failed to fetch {url}: {exc}", file=sys.stderr)
            failures += 1
            continue

        title_match = TITLE_PATTERN.search(html)
        if not title_match:
            failures += 1
            continue

        common, scientific = parse_snorkelstj_title(title_match.group(1).strip())
        if not common:
            failures += 1
            continue

        rows.append(
            {
                "slug": slug,
                "commonName": common,
                "scientificName": scientific,
                "common_norm": normalize_common_name_for_match(common),
                "common_tokens": common_name_tokens(common),
                "match_key": normalize_scientific_name_for_match(scientific),
                "source_url": url,
            }
        )

        if index % 100 == 0:
            print(f"  fetched {index}/{len(slugs)} pages...")
        if delay:
            time.sleep(delay)

    cache_path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "slug",
        "commonName",
        "scientificName",
        "common_norm",
        "common_tokens",
        "match_key",
        "source_url",
    ]
    with cache_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"Cached {len(rows)} species to {cache_path} ({failures} pages skipped).")
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG_PATH)
    parser.add_argument("--refresh", action="store_true", help="Re-crawl snorkelstj.com")
    args = parser.parse_args()

    config = load_config(args.config)
    rows = crawl_snorkelstj_reference(config, refresh=args.refresh)
    with_sci = sum(1 for row in rows if (row.get("scientificName") or "").strip())
    print(f"Parsed names: {len(rows)} ({with_sci} with scientific names)")
    print(config.get("attribution", ""))
    return 0 if rows else 1


if __name__ == "__main__":
    sys.exit(main())
