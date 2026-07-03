"""Search WoRMS (World Register of Marine Species) photogallery for species images."""

from __future__ import annotations

import json
import re
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from html import unescape
from pathlib import Path
from typing import Any

from fishbase_catalog_utils import PROJECT_DIR, normalize_scientific_name_for_match
from marine_life_image_utils import (
    JUVENILE_HINTS,
    UNDESIRABLE_HINTS,
    USER_AGENT,
    license_allowed,
    normalize_license,
)

WORMS_BASE_URL = "https://www.marinespecies.org"
WORMS_REST_BASE = f"{WORMS_BASE_URL}/rest"
WORMS_IMAGES_BASE = "https://images.marinespecies.org"
WORMS_SOURCE = "worms"
WORMS_ATTRIBUTION_PREFIX = "Photo via WoRMS Photogallery"
CACHE_VERSION = "1-worms"

DEFAULT_CACHE = PROJECT_DIR / "MockData/worms_image_cache.json"

GALLERY_ENTRY_RE = re.compile(
    r'href="aphia\.php\?p=image&pic=(\d+)&tid=(\d+)"[^>]*>.*?'
    r'src="(https://images\.marinespecies\.org/thumbs/[^"]+)"[^>]*'
    r'(?:alt="([^"]*)"|title="([^"]*)")',
    re.IGNORECASE | re.DOTALL,
)
LICENSE_META_RE = re.compile(
    r'<meta\s+itemprop="license"\s+content="([^"]+)"',
    re.IGNORECASE,
)
AUTHOR_RE = re.compile(
    r'photogallery_author.*?photogallery_text">([^<]+)<',
    re.IGNORECASE | re.DOTALL,
)
ROLE_RE = re.compile(
    r'photogallery_role">([^<]+)<',
    re.IGNORECASE,
)
CHECKED_STAR_RE = re.compile(
    r'fa-star aphia_icon_link',
    re.IGNORECASE,
)
UNDESIRABLE_ROLES = frozenset({"stamp", "logo", "icon", "map"})


@dataclass(frozen=True)
class WormsGalleryEntry:
    pic_id: str
    aphia_id: str
    thumb_url: str
    alt_text: str

    @property
    def full_image_url(self) -> str:
        filename = self.thumb_url.split("/")[-1].split("?")[0]
        return f"{WORMS_IMAGES_BASE}/{filename}"


@dataclass(frozen=True)
class WormsImageCandidate:
    url: str
    aphia_id: int
    pic_id: str
    taxon_page_url: str
    image_page_url: str
    title: str
    license: str
    license_url: str
    attribution: str
    source: str
    needs_review: bool
    score: int


def http_get_text(url: str, *, timeout_seconds: float = 45.0) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=timeout_seconds) as response:
        return response.read().decode("utf-8", errors="replace")


def http_get_json(url: str, *, timeout_seconds: float = 45.0) -> Any:
    request = urllib.request.Request(
        url,
        headers={"User-Agent": USER_AGENT, "Accept": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout_seconds) as response:
            raw = response.read().decode("utf-8", errors="replace").strip()
    except urllib.error.HTTPError as error:
        if error.code in {404, 204}:
            return None
        raise
    if not raw:
        return None
    return json.loads(raw)


def worms_taxon_page_url(aphia_id: int) -> str:
    return f"{WORMS_BASE_URL}/aphia.php?p=taxdetails&id={aphia_id}"


def worms_image_page_url(*, pic_id: str, aphia_id: int) -> str:
    return f"{WORMS_BASE_URL}/aphia.php?p=image&pic={pic_id}&tid={aphia_id}"


def lookup_aphia_record(
    scientific_name: str,
    *,
    request_delay_seconds: float = 0.2,
) -> dict[str, Any] | None:
    query = urllib.parse.urlencode(
        [
            ("scientificnames[]", scientific_name.strip()),
            ("like", "false"),
            ("marine_only", "true"),
        ]
    )
    url = f"{WORMS_REST_BASE}/AphiaRecordsByNames?{query}"
    payload = http_get_json(url)
    if request_delay_seconds > 0:
        time.sleep(request_delay_seconds)

    if not isinstance(payload, list) or not payload:
        return None
    group = payload[0]
    if not isinstance(group, list) or not group:
        return None

    target_key = normalize_scientific_name_for_match(scientific_name)
    for record in group:
        if not isinstance(record, dict):
            continue
        record_key = normalize_scientific_name_for_match(str(record.get("scientificname") or ""))
        if record_key == target_key and record.get("match_type") == "exact":
            return record

    for record in group:
        if isinstance(record, dict) and record.get("match_type") == "exact":
            return record
    return None


def resolve_aphia_id(record: dict[str, Any]) -> int | None:
    try:
        valid_id = int(record.get("valid_AphiaID") or record.get("AphiaID") or 0)
    except (TypeError, ValueError):
        return None
    return valid_id or None


def parse_taxon_gallery(html: str, *, aphia_id: int) -> list[WormsGalleryEntry]:
    entries: list[WormsGalleryEntry] = []
    seen: set[str] = set()
    for pic_id, tid, thumb_url, alt_text, title_text in GALLERY_ENTRY_RE.findall(html):
        if pic_id in seen:
            continue
        seen.add(pic_id)
        entries.append(
            WormsGalleryEntry(
                pic_id=pic_id,
                aphia_id=str(tid or aphia_id),
                thumb_url=unescape(thumb_url.strip()),
                alt_text=unescape((alt_text or title_text or "").strip()),
            )
        )
    return entries


def score_gallery_entry(
    entry: WormsGalleryEntry,
    *,
    scientific_name: str,
    common_name: str = "",
) -> int:
    score = 40
    alt = entry.alt_text.lower()
    sci = scientific_name.lower()
    common = common_name.lower()

    if sci and sci in alt:
        score += 15
    elif common and common in alt:
        score += 10

    combined = alt
    if any(hint in combined for hint in JUVENILE_HINTS):
        score -= 35
    if any(hint in combined for hint in UNDESIRABLE_HINTS):
        score -= 25
    return score


def parse_image_page_metadata(html: str) -> tuple[str, str, str, bool]:
    license_match = LICENSE_META_RE.search(html)
    license_url = unescape(license_match.group(1).strip()) if license_match else ""
    license_label = license_url.replace("https://creativecommons.org/licenses/", "").replace("/", " ").strip()
    if license_label:
        license_label = license_label.replace("-", " ")
        if license_label.startswith("publicdomain"):
            license_label = "public domain"
        else:
            license_label = f"CC {license_label.upper()}"

    author_match = AUTHOR_RE.search(html)
    author = unescape(author_match.group(1).strip()) if author_match else "WoRMS contributor"

    role_match = ROLE_RE.search(html)
    role = unescape(role_match.group(1).strip()).lower() if role_match else ""
    checked = bool(CHECKED_STAR_RE.search(html))
    return license_label, license_url, author, checked and role not in UNDESIRABLE_ROLES


def score_image_metadata(
    *,
    gallery_score: int,
    license_label: str,
    role: str,
    checked: bool,
    allow_cc_by: bool,
) -> int:
    score = gallery_score
    if checked:
        score += 12
    role_lower = role.lower()
    if role_lower in UNDESIRABLE_ROLES:
        score -= 50
    if license_allowed(license_label, allow_cc_by=allow_cc_by):
        score += 20
    elif "nc" in normalize_license(license_label):
        score -= 15
    return score


def build_worms_attribution(
    *,
    common_name: str,
    scientific_name: str,
    author: str,
    aphia_id: int,
    pic_id: str,
) -> str:
    title = common_name or scientific_name
    return (
        f"{WORMS_ATTRIBUTION_PREFIX} — {title} ({scientific_name}); "
        f"author {author}; AphiaID {aphia_id}, pic {pic_id}"
    )


def fetch_image_candidate_for_entry(
    entry: WormsGalleryEntry,
    *,
    scientific_name: str,
    common_name: str,
    aphia_id: int,
    allow_cc_by: bool,
    include_restricted_licenses: bool,
    request_delay_seconds: float = 0.2,
) -> WormsImageCandidate | None:
    gallery_score = score_gallery_entry(entry, scientific_name=scientific_name, common_name=common_name)
    if gallery_score < 5:
        return None

    image_page_url = worms_image_page_url(pic_id=entry.pic_id, aphia_id=aphia_id)
    html = http_get_text(image_page_url)
    if request_delay_seconds > 0:
        time.sleep(request_delay_seconds)

    license_label, license_url, author, checked = parse_image_page_metadata(html)
    role_match = ROLE_RE.search(html)
    role = unescape(role_match.group(1).strip()) if role_match else ""

    shippable = license_allowed(license_label, allow_cc_by=allow_cc_by)
    if not shippable and not include_restricted_licenses:
        return None

    score = score_image_metadata(
        gallery_score=gallery_score,
        license_label=license_label,
        role=role,
        checked=checked,
        allow_cc_by=allow_cc_by,
    )
    if score < 10:
        return None

    needs_review = not shippable or not checked or role.lower() in UNDESIRABLE_ROLES
    title = common_name or entry.alt_text or scientific_name

    return WormsImageCandidate(
        url=entry.full_image_url,
        aphia_id=aphia_id,
        pic_id=entry.pic_id,
        taxon_page_url=worms_taxon_page_url(aphia_id),
        image_page_url=image_page_url,
        title=title,
        license=license_label or license_url or "WoRMS Photogallery",
        license_url=license_url,
        attribution=build_worms_attribution(
            common_name=common_name or title,
            scientific_name=scientific_name,
            author=author,
            aphia_id=aphia_id,
            pic_id=entry.pic_id,
        ),
        source=WORMS_SOURCE,
        needs_review=needs_review,
        score=score,
    )


def find_worms_image(
    scientific_name: str,
    *,
    common_name: str = "",
    allow_cc_by: bool = True,
    include_restricted_licenses: bool = False,
    max_gallery_candidates: int = 4,
    request_delay_seconds: float = 0.25,
) -> WormsImageCandidate | None:
    record = lookup_aphia_record(scientific_name, request_delay_seconds=request_delay_seconds)
    if record is None:
        return None

    aphia_id = resolve_aphia_id(record)
    if aphia_id is None:
        return None

    taxon_html = http_get_text(worms_taxon_page_url(aphia_id))
    if request_delay_seconds > 0:
        time.sleep(request_delay_seconds)

    gallery = parse_taxon_gallery(taxon_html, aphia_id=aphia_id)
    if not gallery:
        return None

    ranked = sorted(
        gallery,
        key=lambda entry: score_gallery_entry(entry, scientific_name=scientific_name, common_name=common_name),
        reverse=True,
    )[:max_gallery_candidates]

    best: WormsImageCandidate | None = None
    for entry in ranked:
        candidate = fetch_image_candidate_for_entry(
            entry,
            scientific_name=scientific_name,
            common_name=common_name,
            aphia_id=aphia_id,
            allow_cc_by=allow_cc_by,
            include_restricted_licenses=include_restricted_licenses,
            request_delay_seconds=request_delay_seconds,
        )
        if candidate is None:
            continue
        if best is None or candidate.score > best.score:
            best = candidate
    return best
