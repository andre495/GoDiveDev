"""Helpers for OpenDiveMap dive site reference catalog and fuzzy matching."""

from __future__ import annotations

import math
import re
from difflib import SequenceMatcher
from typing import Any

API_BASE = "https://api.opendivemap.com/v1"
DEFAULT_PAGE_SIZE = 1000

# Strip parenthetical suffixes like "(Stern Courier)" or country hints.
PAREN_SUFFIX = re.compile(r"\s*\([^)]*\)\s*")
NON_ALNUM = re.compile(r"[^a-z0-9 ]+")


def normalize_site_name_for_match(name: str | None) -> str:
    if not name:
        return ""
    text = name.lower().strip()
    text = PAREN_SUFFIX.sub(" ", text)
    text = NON_ALNUM.sub(" ", text)
    return re.sub(r"\s+", " ", text).strip()


def site_name_tokens(name: str | None) -> str:
    return " ".join(sorted(normalize_site_name_for_match(name).split()))


def name_similarity(left: str, right: str) -> float:
    left_norm = normalize_site_name_for_match(left)
    right_norm = normalize_site_name_for_match(right)
    if not left_norm or not right_norm:
        return 0.0
    if left_norm == right_norm:
        return 1.0
    if left_norm in right_norm or right_norm in left_norm:
        return 0.85
    ratio = SequenceMatcher(None, left_norm, right_norm).ratio()
    token_ratio = SequenceMatcher(None, site_name_tokens(left), site_name_tokens(right)).ratio()
    return max(ratio, token_ratio)


def haversine_distance_meters(
    lat1: float,
    lon1: float,
    lat2: float,
    lon2: float,
) -> float:
    radius_m = 6_371_000.0
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    d_phi = math.radians(lat2 - lat1)
    d_lambda = math.radians(lon2 - lon1)
    a = math.sin(d_phi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(d_lambda / 2) ** 2
    return 2 * radius_m * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def coordinate_factor(distance_meters: float | None) -> float:
    if distance_meters is None:
        return 1.0
    if distance_meters <= 500:
        return 1.0
    if distance_meters <= 2_000:
        return 0.95
    if distance_meters <= 10_000:
        return 0.85
    if distance_meters <= 50_000:
        return 0.7
    return 0.5


def combined_match_score(
    import_name: str | None,
    import_lat: float | None,
    import_lon: float | None,
    reference_name: str,
    reference_lat: float | None,
    reference_lon: float | None,
) -> float:
    name_score = name_similarity(import_name or "", reference_name) if import_name else 0.0

    distance_m: float | None = None
    if (
        import_lat is not None
        and import_lon is not None
        and reference_lat is not None
        and reference_lon is not None
    ):
        distance_m = haversine_distance_meters(import_lat, import_lon, reference_lat, reference_lon)

    if import_name and import_lat is not None and import_lon is not None:
        if name_score < 0.6:
            return 0.0
        return name_score * coordinate_factor(distance_m)

    if import_name and (import_lat is None or import_lon is None):
        return name_score

    if not import_name and import_lat is not None and import_lon is not None and distance_m is not None:
        if distance_m <= 500:
            return 0.95
        if distance_m <= 2_000:
            return 0.85
        if distance_m <= 10_000:
            return 0.7
        return 0.0

    return 0.0


def feature_to_reference_row(feature: dict[str, Any]) -> dict[str, Any]:
    geometry = feature.get("geometry") or {}
    coords = geometry.get("coordinates") or []
    properties = feature.get("properties") or {}
    lon = coords[0] if len(coords) >= 2 else None
    lat = coords[1] if len(coords) >= 2 else None
    topologies = properties.get("topologies") or []
    return {
        "id": properties.get("id") or "",
        "name": properties.get("name") or "",
        "country": properties.get("country_name") or "",
        "countryCode": properties.get("country_code") or "",
        "latitude": lat,
        "longitude": lon,
        "maxDepthMeters": properties.get("max_depth"),
        "entry": properties.get("entry") or "",
        "environment": properties.get("environment") or "",
        "topologies": topologies,
        "seaName": properties.get("sea_name") or "",
    }


def best_reference_match(
    import_name: str | None,
    import_lat: float | None,
    import_lon: float | None,
    reference_rows: list[dict[str, Any]],
    *,
    minimum_score: float,
) -> tuple[dict[str, Any] | None, float]:
    best_row: dict[str, Any] | None = None
    best_score = 0.0
    for row in reference_rows:
        score = combined_match_score(
            import_name,
            import_lat,
            import_lon,
            row.get("name") or "",
            row.get("latitude"),
            row.get("longitude"),
        )
        if score > best_score:
            best_score = score
            best_row = row
    if best_row and best_score >= minimum_score:
        return best_row, best_score
    return None, best_score
