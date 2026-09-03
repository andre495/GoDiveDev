"""Find CC0 / CC BY hero images on GBIF occurrence records."""

from __future__ import annotations

import time
import urllib.error
import urllib.parse
from typing import Any

from marine_life_image_utils import (
    ImageCandidate,
    build_attribution,
    http_get_json,
    license_allowed,
    pick_best_candidate,
    score_image_candidate,
)

GBIF_API = "https://api.gbif.org/v1"
CACHE_VERSION = "1-occurrence-still"
SKIP_BASIS_OF_RECORD = frozenset(
    {
        "PRESERVED_SPECIMEN",
        "FOSSIL_SPECIMEN",
        "LIVING_SPECIMEN",
        "MATERIAL_SAMPLE",
    }
)
MIN_MATCH_CONFIDENCE = 80
OCCURRENCE_PAGE_SIZE = 20

__all__ = [
    "CACHE_VERSION",
    "GBIF_API",
    "candidates_from_occurrence",
    "find_gbif_image",
    "gbif_license_label",
    "match_gbif_taxon_key",
    "media_license_allowed",
]


def gbif_license_label(raw: str | None) -> str:
    """Map a GBIF enum, Creative Commons URL, or label to a short license string."""
    if not raw:
        return ""
    text = " ".join(str(raw).strip().lower().split())
    if not text or "unspecified" in text or "unsupported" in text or "usage conditions" in text:
        return ""
    compact = text.replace(" ", "_").replace("-", "_")
    if "by_nc" in compact or "by-nc" in text or "/by-nc" in text:
        return "CC BY-NC"
    if "by_sa" in compact or "by-sa" in text or "/by-sa" in text:
        return "CC BY-SA"
    if "by_nd" in compact or "by-nd" in text or "/by-nd" in text:
        return "CC BY-ND"
    if "cc0" in compact or "publicdomain/zero" in text or "publicdomain/zero" in compact:
        return "CC0 1.0"
    if compact.startswith("cc_by_") or compact.startswith("cc_by") or "/licenses/by/" in text:
        return "CC BY 4.0"
    if text.startswith("cc by") and "nc" not in text and "sa" not in text and "nd" not in text:
        return "CC BY 4.0"
    return str(raw).strip()


def media_license_allowed(raw: str | None, *, allow_cc_by: bool) -> bool:
    label = gbif_license_label(raw)
    if not label:
        return False
    return license_allowed(label, allow_cc_by=allow_cc_by)


def _https_identifier(raw: str | None) -> str:
    url = str(raw or "").strip()
    if url.startswith("https://"):
        return url
    return ""


def _gbif_get_json(url: str, *, sleep_seconds: float, retries: int = 1) -> dict[str, Any]:
    try:
        return http_get_json(url, sleep_seconds=sleep_seconds)
    except urllib.error.HTTPError as error:
        if error.code == 429 and retries > 0:
            time.sleep(max(2.0, sleep_seconds))
            return _gbif_get_json(url, sleep_seconds=sleep_seconds, retries=retries - 1)
        raise


def match_gbif_taxon_key(
    scientific_name: str,
    *,
    sleep_seconds: float = 0.0,
) -> int | None:
    """Return a SPECIES-rank GBIF usageKey, or None when the name is too weak to trust."""
    name = scientific_name.strip()
    if not name:
        return None
    query = urllib.parse.urlencode({"name": name})
    payload = _gbif_get_json(f"{GBIF_API}/species/match?{query}", sleep_seconds=sleep_seconds)
    match_type = str(payload.get("matchType") or "").upper()
    if match_type in {"NONE", "HIGHERRANK"}:
        return None
    try:
        confidence = int(payload.get("confidence") or 0)
    except (TypeError, ValueError):
        confidence = 0
    if confidence and confidence < MIN_MATCH_CONFIDENCE:
        return None
    rank = str(payload.get("rank") or "").upper()
    if rank and rank != "SPECIES":
        return None
    raw_key = payload.get("acceptedUsageKey") or payload.get("usageKey")
    try:
        key = int(raw_key)
    except (TypeError, ValueError):
        return None
    return key if key > 0 else None


def _score_text(occurrence: dict[str, Any], media: dict[str, Any], scientific_name: str) -> str:
    parts = [
        scientific_name,
        str(media.get("title") or ""),
        str(media.get("description") or ""),
        str(occurrence.get("datasetName") or ""),
        str(media.get("identifier") or ""),
    ]
    return " ".join(part for part in parts if part.strip())


def candidates_from_occurrence(
    occurrence: dict[str, Any],
    scientific_name: str,
    *,
    allow_cc_by: bool,
) -> list[ImageCandidate]:
    basis = str(occurrence.get("basisOfRecord") or "").upper()
    if basis in SKIP_BASIS_OF_RECORD:
        return []

    gbif_id = str(occurrence.get("gbifID") or "").strip()
    dataset = str(occurrence.get("datasetName") or "").strip()
    candidates: list[ImageCandidate] = []
    for media in occurrence.get("media") or []:
        if str(media.get("type") or "") != "StillImage":
            continue
        identifier = _https_identifier(media.get("identifier"))
        if not identifier:
            continue
        license_raw = str(media.get("license") or "")
        if not media_license_allowed(license_raw, allow_cc_by=allow_cc_by):
            continue
        license_label = gbif_license_label(license_raw)
        license_url = license_raw if license_raw.startswith("http") else ""
        title = str(media.get("title") or scientific_name).strip()
        creator = str(media.get("creator") or media.get("rightsHolder") or "").strip()
        attribution = build_attribution(title, creator, license_label, license_url)
        if gbif_id:
            attribution = f"{attribution} GBIF occurrence {gbif_id}."
        try:
            width = int(media.get("width") or 0)
        except (TypeError, ValueError):
            width = 0
        try:
            height = int(media.get("height") or 0)
        except (TypeError, ValueError):
            height = 0
        score, needs_review = score_image_candidate(
            scientific_name,
            title=_score_text(occurrence, media, scientific_name),
            url=identifier,
            license_text=license_label,
            width=width,
            height=height,
        )
        # Taxon-keyed occurrence already identified the species; filenames often omit it.
        score += 40
        if "inaturalist" in dataset.lower():
            score += 6
        candidates.append(
            ImageCandidate(
                url=identifier,
                thumbnail_url=identifier,
                title=title,
                license=license_label,
                license_url=license_url,
                attribution=attribution,
                source="gbif",
                width=width,
                height=height,
                score=score,
                needs_review=needs_review,
            )
        )
    return candidates


def _occurrence_search_url(taxon_key: int, *, licensed: bool) -> str:
    params: list[tuple[str, str]] = [
        ("taxonKey", str(taxon_key)),
        ("mediaType", "StillImage"),
        ("limit", str(OCCURRENCE_PAGE_SIZE)),
    ]
    if licensed:
        params.append(("license", "CC0_1_0"))
        params.append(("license", "CC_BY_4_0"))
    return f"{GBIF_API}/occurrence/search?{urllib.parse.urlencode(params)}"


def _candidates_from_search(
    payload: dict[str, Any],
    scientific_name: str,
    *,
    allow_cc_by: bool,
) -> list[ImageCandidate]:
    collected: list[ImageCandidate] = []
    for occurrence in payload.get("results") or []:
        collected.extend(
            candidates_from_occurrence(
                occurrence,
                scientific_name,
                allow_cc_by=allow_cc_by,
            )
        )
    return collected


def find_gbif_image(
    scientific_name: str,
    *,
    common_name: str | None = None,
    allow_cc_by: bool = True,
    request_delay_seconds: float = 0.25,
) -> ImageCandidate | None:
    """Match a scientific name, then pick the best CC0 / CC BY occurrence still image."""
    del common_name  # Scoring uses the GBIF-matched scientific name.
    taxon_key = match_gbif_taxon_key(scientific_name, sleep_seconds=request_delay_seconds)
    if taxon_key is None:
        return None

    licensed = _gbif_get_json(
        _occurrence_search_url(taxon_key, licensed=True),
        sleep_seconds=request_delay_seconds,
    )
    candidates = _candidates_from_search(licensed, scientific_name, allow_cc_by=allow_cc_by)
    best = pick_best_candidate(candidates, minimum_score=15)
    if best is not None:
        return best

    unfiltered = _gbif_get_json(
        _occurrence_search_url(taxon_key, licensed=False),
        sleep_seconds=request_delay_seconds,
    )
    fallback = _candidates_from_search(unfiltered, scientific_name, allow_cc_by=allow_cc_by)
    return pick_best_candidate(fallback, minimum_score=15)
