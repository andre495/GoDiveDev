"""Search, score, and normalize CC-licensed marine life hero images."""

from __future__ import annotations

import json
import re
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from typing import Any


USER_AGENT = "GoDiveMVP/1.0 (marine-life-catalog; contact: andre.b.dugas@gmail.com)"
OPENVERSE_API = "https://api.openverse.org/v1/images/"
COMMONS_API = "https://commons.wikimedia.org/w/api.php"

JUVENILE_HINTS = ("juvenile", "juvenil", "larva", "larval", "egg", "fry", "hatchling")
UNDERWATER_POSITIVE_HINTS = (
    "underwater",
    "under water",
    "scuba",
    "diver",
    "diving",
    "snorkel",
    "snorkeling",
    "reef",
    "in situ",
    "insitu",
    "in-situ",
    "marine life",
)
UNDESIRABLE_HINTS = (
    "map",
    "distribution map",
    "range map",
    "fishing",
    "fisherman",
    "caught",
    "catch",
    "hook",
    "trawl",
    "net",
    "sketch",
    "drawing",
    "illustration",
    "diagram",
    "scientific plate",
    "plate ",
    "museum",
    "specimen",
    "preserved",
    "logo",
    "stamp",
    "icon",
    "chart",
    "outline",
    "clipart",
    "vector",
    "fillet",
    "market",
    "restaurant",
    "boat",
    "harbor",
    "harbour",
    "aquarium exhibit",
    "tank shot",
)
DEFAULT_SEARCH_SUFFIXES = ("underwater", "diver", "scuba")
CACHE_VERSION = "2-underwater"
ALLOWED_CC0_LICENSES = frozenset({"cc0", "pdm", "public domain", "publicdomain"})
ALLOWED_BY_LICENSE_PREFIXES = ("cc by", "cc-by")


@dataclass(frozen=True)
class ImageCandidate:
    url: str
    thumbnail_url: str
    title: str
    license: str
    license_url: str
    attribution: str
    source: str
    width: int
    height: int
    score: int
    needs_review: bool


def normalize_license(value: str | None) -> str:
    if not value:
        return ""
    text = re.sub(r"\s+", " ", str(value).strip().lower())
    text = text.replace("cc0 1.0", "cc0").replace("cc zero", "cc0")
    return text


def license_is_cc0(license_text: str) -> bool:
    normalized = normalize_license(license_text)
    return any(token in normalized for token in ALLOWED_CC0_LICENSES)


def license_is_cc_by(license_text: str) -> bool:
    normalized = normalize_license(license_text)
    if license_is_cc0(normalized):
        return False
    if "nc" in normalized or "sa" in normalized or "nd" in normalized:
        return False
    return normalized.startswith(ALLOWED_BY_LICENSE_PREFIXES) or normalized in {
        "cc by",
        "cc by 2.0",
        "cc by 2.5",
        "cc by 3.0",
        "cc by 4.0",
    }


def license_allowed(license_text: str, *, allow_cc_by: bool) -> bool:
    if license_is_cc0(license_text):
        return True
    return allow_cc_by and license_is_cc_by(license_text)


def wikimedia_thumbnail_url(url: str, width: int = 640) -> str:
    if "/thumb/" in url:
        return url
    match = re.match(
        r"(https://upload\.wikimedia\.org/wikipedia/commons/)([a-f0-9]/[a-f0-9]{2}/)(.+)$",
        url,
        flags=re.IGNORECASE,
    )
    if not match:
        return url
    prefix, shard_path, filename = match.groups()
    return f"{prefix}thumb/{shard_path}{filename}/{width}px-{filename}"


def build_species_search_queries(
    scientific_name: str,
    suffixes: tuple[str, ...] | list[str] | None = None,
    *,
    common_name: str | None = None,
) -> list[str]:
    ordered: list[str] = []
    names: list[str] = []
    science = scientific_name.strip()
    if science:
        names.append(science)
    common = (common_name or "").strip()
    if common and common.lower() not in {name.lower() for name in names}:
        names.append(common)

    for base in names:
        for suffix in suffixes or DEFAULT_SEARCH_SUFFIXES:
            cleaned = f"{base} {suffix}".strip()
            if cleaned not in ordered:
                ordered.append(cleaned)
        if base not in ordered:
            ordered.append(base)
    return ordered


def underwater_content_adjustment(text: str) -> tuple[int, bool]:
    lowered = text.lower()
    score = 0
    rejected = False
    for hint in UNDERWATER_POSITIVE_HINTS:
        if hint in lowered:
            score += 14
    for hint in UNDESIRABLE_HINTS:
        if hint in lowered:
            score -= 28
            rejected = True
    if lowered.endswith(".svg") or ".svg" in lowered:
        score -= 40
        rejected = True
    return score, rejected


def score_image_candidate(
    scientific_name: str,
    *,
    title: str,
    url: str,
    license_text: str,
    width: int,
    height: int,
) -> tuple[int, bool]:
    score = 0
    needs_review = False
    text = f"{title} {url}".lower()
    parts = scientific_name.strip().split(maxsplit=1)
    genus = parts[0].lower() if parts else ""
    species = parts[1].lower() if len(parts) > 1 else ""
    binomial = scientific_name.strip().lower()
    binomial_underscore = binomial.replace(" ", "_")

    if binomial in text or binomial_underscore in text:
        score += 60
    elif genus and species and genus in text and species in text:
        score += 45
    elif genus and genus in text:
        score += 10
        needs_review = True
    else:
        score -= 30
        needs_review = True

    if any(hint in text for hint in JUVENILE_HINTS):
        score -= 20
        needs_review = True

    content_score, rejected = underwater_content_adjustment(text)
    score += content_score
    if rejected:
        score -= 10
        needs_review = True
    elif content_score == 0:
        needs_review = True

    if width >= 900 and height >= 600:
        score += 12
    elif width >= 640 and height >= 480:
        score += 8
    elif width >= 320 and height >= 240:
        score += 4

    if license_is_cc0(license_text):
        score += 6

    return score, needs_review


def build_attribution(title: str, creator: str, license_text: str, license_url: str) -> str:
    clean_title = title.removeprefix("File:").strip()
    creator_text = creator.strip() or "Unknown"
    license_label = license_text.strip() or "Unknown license"
    if license_url.strip():
        return f'"{clean_title}" by {creator_text} ({license_label}). {license_url.strip()}'
    return f'"{clean_title}" by {creator_text} ({license_label}).'


def http_get_json(url: str, *, sleep_seconds: float = 0.0) -> dict[str, Any]:
    if sleep_seconds > 0:
        time.sleep(sleep_seconds)
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.loads(response.read().decode("utf-8"))


def _candidate_from_openverse_hit(hit: dict[str, Any], scientific_name: str) -> ImageCandidate:
    title = str(hit.get("title") or "")
    full_url = str(hit.get("url") or "")
    width = int(hit.get("width") or 0)
    height = int(hit.get("height") or 0)
    license_text = str(hit.get("license") or "")
    license_url = str(hit.get("license_url") or "")
    creator = str(hit.get("creator") or "")
    attribution = str(hit.get("attribution") or "").strip() or build_attribution(
        title, creator, license_text, license_url
    )
    score, needs_review = score_image_candidate(
        scientific_name,
        title=title,
        url=full_url,
        license_text=license_text,
        width=width,
        height=height,
    )
    thumb = wikimedia_thumbnail_url(full_url) if "wikimedia.org" in full_url else full_url
    return ImageCandidate(
        url=full_url,
        thumbnail_url=thumb,
        title=title,
        license=license_text,
        license_url=license_url,
        attribution=attribution,
        source="openverse",
        width=width,
        height=height,
        score=score,
        needs_review=needs_review,
    )


def search_openverse(
    search_query: str,
    scientific_name: str,
    *,
    allow_cc_by: bool,
    page_size: int = 15,
    sleep_seconds: float = 0.0,
) -> list[ImageCandidate]:
    licenses = "cc0,pdm"
    if allow_cc_by:
        licenses = "cc0,pdm,by"
    query = urllib.parse.urlencode(
        {
            "q": search_query,
            "license": licenses,
            "page_size": page_size,
            "mature": "false",
        }
    )
    payload = http_get_json(f"{OPENVERSE_API}?{query}", sleep_seconds=sleep_seconds)
    candidates: list[ImageCandidate] = []
    for hit in payload.get("results", []):
        license_text = str(hit.get("license") or "")
        if not license_allowed(license_text, allow_cc_by=allow_cc_by):
            continue
        candidates.append(_candidate_from_openverse_hit(hit, scientific_name))
    return candidates


def _commons_metadata_value(block: dict[str, Any], key: str) -> str:
    entry = block.get(key) or {}
    if isinstance(entry, dict):
        return str(entry.get("value") or "").strip()
    return str(entry or "").strip()


def search_wikimedia_commons(
    search_query: str,
    scientific_name: str,
    *,
    allow_cc_by: bool,
    limit: int = 12,
    thumb_width: int = 640,
    sleep_seconds: float = 0.0,
) -> list[ImageCandidate]:
    params = urllib.parse.urlencode(
        {
            "action": "query",
            "format": "json",
            "generator": "search",
            "gsrnamespace": "6",
            "gsrsearch": search_query,
            "gsrlimit": str(limit),
            "prop": "imageinfo",
            "iiprop": "url|size|extmetadata",
            "iiurlwidth": str(thumb_width),
        }
    )
    payload = http_get_json(f"{COMMONS_API}?{params}", sleep_seconds=sleep_seconds)
    pages = payload.get("query", {}).get("pages", {})
    candidates: list[ImageCandidate] = []
    for page in pages.values():
        title = str(page.get("title") or "")
        imageinfo = (page.get("imageinfo") or [{}])[0]
        metadata = imageinfo.get("extmetadata") or {}
        license_text = _commons_metadata_value(metadata, "LicenseShortName")
        if not license_allowed(license_text, allow_cc_by=allow_cc_by):
            continue
        full_url = str(imageinfo.get("url") or "")
        thumb_url = str(imageinfo.get("thumburl") or wikimedia_thumbnail_url(full_url, thumb_width))
        width = int(imageinfo.get("width") or imageinfo.get("thumbwidth") or 0)
        height = int(imageinfo.get("height") or imageinfo.get("thumbheight") or 0)
        creator = _commons_metadata_value(metadata, "Artist")
        license_url = _commons_metadata_value(metadata, "LicenseUrl")
        attribution = build_attribution(title, creator, license_text, license_url)
        score, needs_review = score_image_candidate(
            scientific_name,
            title=title,
            url=full_url,
            license_text=license_text,
            width=width,
            height=height,
        )
        candidates.append(
            ImageCandidate(
                url=full_url,
                thumbnail_url=thumb_url,
                title=title,
                license=license_text,
                license_url=license_url,
                attribution=attribution,
                source="wikimedia",
                width=width,
                height=height,
                score=score,
                needs_review=needs_review,
            )
        )
    return candidates


def pick_best_candidate(
    candidates: list[ImageCandidate],
    *,
    minimum_score: int = 15,
) -> ImageCandidate | None:
    if not candidates:
        return None
    ranked = sorted(
        candidates,
        key=lambda item: (item.score, item.width * item.height),
        reverse=True,
    )
    best = ranked[0]
    if best.score < minimum_score:
        return None
    if best.score < 25 or best.needs_review:
        best = ImageCandidate(
            url=best.url,
            thumbnail_url=best.thumbnail_url,
            title=best.title,
            license=best.license,
            license_url=best.license_url,
            attribution=best.attribution,
            source=best.source,
            width=best.width,
            height=best.height,
            score=best.score,
            needs_review=True,
        )
    return best


def _is_strong_match(candidate: ImageCandidate) -> bool:
    return candidate.score >= 35 and not candidate.needs_review


def find_species_image(
    scientific_name: str,
    *,
    common_name: str | None = None,
    allow_cc_by: bool = True,
    search_suffixes: tuple[str, ...] | list[str] | None = None,
    commons_sleep_seconds: float = 0.2,
    openverse_sleep_seconds: float = 0.0,
) -> ImageCandidate | None:
    queries = build_species_search_queries(
        scientific_name,
        search_suffixes,
        common_name=common_name,
    )
    commons_candidates: list[ImageCandidate] = []
    for query in queries:
        commons_candidates.extend(
            search_wikimedia_commons(
                query,
                scientific_name,
                allow_cc_by=allow_cc_by,
                sleep_seconds=commons_sleep_seconds,
            )
        )
        best_commons = pick_best_candidate(commons_candidates, minimum_score=15)
        if best_commons and _is_strong_match(best_commons):
            return best_commons

    openverse_candidates: list[ImageCandidate] = []
    for index, query in enumerate(queries):
        try:
            openverse_candidates.extend(
                search_openverse(
                    query,
                    scientific_name,
                    allow_cc_by=allow_cc_by,
                    sleep_seconds=openverse_sleep_seconds if index == 0 else 0.0,
                )
            )
        except urllib.error.HTTPError:
            continue
        combined = commons_candidates + openverse_candidates
        best = pick_best_candidate(combined, minimum_score=15)
        if best and _is_strong_match(best):
            return best

    return pick_best_candidate(commons_candidates + openverse_candidates, minimum_score=15)
