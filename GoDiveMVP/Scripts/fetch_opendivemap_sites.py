#!/usr/bin/env python3
"""Fetch all dive sites from the OpenDiveMap API (paginated GeoJSON)."""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.parse
import urllib.request

from opendivemap_catalog_utils import API_BASE, DEFAULT_PAGE_SIZE, feature_to_reference_row


def fetch_page(*, limit: int, offset: int, timeout: float) -> dict:
    query = urllib.parse.urlencode({"limit": limit, "offset": offset})
    url = f"{API_BASE}/sites?{query}"
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/json",
            "User-Agent": "GoDiveMVP/1.0 (catalog-builder; +https://github.com/andre495/GoDiveDev)",
        },
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


def fetch_all_sites(*, page_size: int, timeout: float) -> list[dict]:
    offset = 0
    rows: list[dict] = []
    total_matched: int | None = None

    while True:
        payload = fetch_page(limit=page_size, offset=offset, timeout=timeout)
        features = payload.get("features") or []
        if total_matched is None:
            total_matched = int(payload.get("numberMatched") or 0)
        for feature in features:
            row = feature_to_reference_row(feature)
            if row.get("id") and row.get("name"):
                rows.append(row)
        offset += len(features)
        if not features or offset >= total_matched:
            break

    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description="Fetch OpenDiveMap dive sites.")
    parser.add_argument(
        "--output",
        type=str,
        default="GoDiveMVP/MockData/opendivemap_dive_sites_reference.json",
        help="Output JSON path (reference rows for the app bundle).",
    )
    parser.add_argument("--page-size", type=int, default=DEFAULT_PAGE_SIZE)
    parser.add_argument("--timeout", type=float, default=60.0)
    args = parser.parse_args()

    try:
        rows = fetch_all_sites(page_size=args.page_size, timeout=args.timeout)
    except urllib.error.URLError as exc:
        print(f"Fetch failed: {exc}", file=sys.stderr)
        return 1

    rows.sort(key=lambda row: (row.get("name") or "").lower())
    output_path = args.output
    with open(output_path, "w", encoding="utf-8") as handle:
        json.dump(rows, handle, ensure_ascii=False, indent=2)
        handle.write("\n")

    print(f"Wrote {len(rows)} sites to {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
