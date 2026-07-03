"""Search reefguide.org for Caribbean reef species photos."""

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
from marine_life_image_utils import JUVENILE_HINTS, USER_AGENT

REEFGUIDE_BASE_URL = "https://reefguide.org"
REEFGUIDE_ABOUT_URL = "https://reefguide.org/about.html"
REEFGUIDE_LICENSE = "All Rights Reserved"
REEFGUIDE_SOURCE = "reefguide"
REEFGUIDE_ATTRIBUTION = "Photo © Florent Charpin, reefguide.org"
CACHE_VERSION = "2-carib"

DEFAULT_CARIBBEAN_REGIONS = ("carib", "keys")
DEFAULT_CATALOG_CACHE = PROJECT_DIR / "MockData/reefguide_caribbean_catalog.json"

TOC_SCI_LINK_RE = re.compile(
    r'<a class="tocnamesci" href="([^"]+\.html)">((?:&nbsp;)*)([^<]+)</a>',
    re.IGNORECASE,
)
GALLERY_ITEM_RE = re.compile(
    r'<a class="pixsel" href="(pixhtml/[^"]+)">'
    r'<img[^>]+src="([^"]+)"[^>]*alt="([^"]*)"[^>]*></a>\s*'
    r'<div class="main2">([^<]*)</div>\s*'
    r'<div class="main3">([^<]*)</div>',
    re.IGNORECASE | re.DOTALL,
)
FULL_IMAGE_RE = re.compile(r'<img class="selframe" src="([^"]+)"', re.IGNORECASE)
SPECIES_SCIENTIFIC_RE = re.compile(
    r'<div class="typetitlesn">([^<]+)</div>',
    re.IGNORECASE,
)


@dataclass(frozen=True)
class ReefGuideSpeciesEntry:
    scientific_name: str
    species_page_path: str
    region: str

    @property
    def species_page_url(self) -> str:
        return f"{REEFGUIDE_BASE_URL}/{self.region}/{self.species_page_path}"


@dataclass(frozen=True)
class ReefGuideGalleryPhoto:
    pixhtml_path: str
    thumb_src: str
    alt_text: str
    location: str
    life_stage: str

    @property
    def is_juvenile(self) -> bool:
        combined = f"{self.alt_text} {self.life_stage}".lower()
        return any(hint in combined for hint in JUVENILE_HINTS)


@dataclass(frozen=True)
class ReefGuideImageCandidate:
    url: str
    species_page_url: str
    photo_page_url: str
    location: str
    title: str
    license: str
    attribution: str
    source: str
    needs_review: bool
    score: int


def fetch_url(url: str, *, timeout_seconds: float = 45.0) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=timeout_seconds) as response:
        return response.read().decode("utf-8", errors="replace")


def absolute_reefguide_url(path_or_url: str, *, base_url: str) -> str:
    cleaned = unescape(path_or_url.strip())
    if cleaned.startswith("http://") or cleaned.startswith("https://"):
        return cleaned
    return urllib.parse.urljoin(base_url, cleaned)


def parse_cat_sci_html(html: str, *, region: str) -> dict[str, ReefGuideSpeciesEntry]:
    """Parse reefguide.org/{region}/cat_sci.html into match-key → species entry."""
    catalog: dict[str, ReefGuideSpeciesEntry] = {}
    current_genus = ""

    for href, indent, raw_name in TOC_SCI_LINK_RE.findall(html):
        label = unescape(raw_name).replace("\xa0", " ").strip()
        if not label:
            continue

        if " " in label:
            scientific_name = label
            current_genus = label.split()[0]
        elif current_genus:
            scientific_name = f"{current_genus} {label.rstrip('.')}"
        else:
            continue

        match_key = normalize_scientific_name_for_match(scientific_name)
        if not match_key:
            continue

        catalog[match_key] = ReefGuideSpeciesEntry(
            scientific_name=scientific_name,
            species_page_path=href.strip(),
            region=region,
        )

    return catalog


def parse_species_gallery(html: str) -> list[ReefGuideGalleryPhoto]:
    photos: list[ReefGuideGalleryPhoto] = []
    for pixhtml_path, thumb_src, alt_text, location, life_stage in GALLERY_ITEM_RE.findall(html):
        photos.append(
            ReefGuideGalleryPhoto(
                pixhtml_path=unescape(pixhtml_path.strip()),
                thumb_src=unescape(thumb_src.strip()),
                alt_text=unescape(alt_text.strip()),
                location=unescape(location.strip()),
                life_stage=unescape(life_stage.strip()),
            )
        )
    return photos


def parse_photo_page_image_url(html: str, *, page_url: str) -> str:
    match = FULL_IMAGE_RE.search(html)
    if not match:
        raise ValueError(f"No full-size image on reefguide photo page: {page_url}")
    return absolute_reefguide_url(match.group(1), base_url=page_url)


def reefguide_full_image_url_from_thumb(thumb_src: str) -> str | None:
    """Map ../pix/thumb(2)/species8.jpg -> https://reefguide.org/pix/species8.jpg."""
    filename = thumb_src.strip().split("/")[-1]
    if not filename or not filename.lower().endswith(".jpg"):
        return None
    return f"{REEFGUIDE_BASE_URL}/pix/{filename}"


def resolve_reefguide_image_url(
    photo: ReefGuideGalleryPhoto,
    *,
    species_page_url: str,
    request_delay_seconds: float = 0.25,
) -> tuple[str, str]:
    """Return (direct JPEG URL, photo page URL used for provenance)."""
    thumb_url = reefguide_full_image_url_from_thumb(photo.thumb_src)
    if thumb_url:
        photo_page_url = absolute_reefguide_url(photo.pixhtml_path, base_url=species_page_url)
        return thumb_url, photo_page_url

    photo_page_url = absolute_reefguide_url(photo.pixhtml_path, base_url=species_page_url)
    photo_html = fetch_url(photo_page_url)
    if request_delay_seconds > 0:
        time.sleep(request_delay_seconds)
    return parse_photo_page_image_url(photo_html, page_url=photo_page_url), photo_page_url


def score_reefguide_photo(photo: ReefGuideGalleryPhoto) -> int:
    score = 50
    if photo.is_juvenile:
        score -= 40
    location = photo.location.lower()
    if any(token in location for token in ("cozumel", "bonaire", "bahamas", "cayman", "florida", "roatan")):
        score += 8
    return score


def pick_best_gallery_photo(photos: list[ReefGuideGalleryPhoto]) -> ReefGuideGalleryPhoto | None:
    if not photos:
        return None
    ranked = sorted(photos, key=score_reefguide_photo, reverse=True)
    best = ranked[0]
    if best.is_juvenile and score_reefguide_photo(best) < 20:
        return None
    return best


def build_reefguide_attribution(*, common_name: str, scientific_name: str, location: str) -> str:
    title = common_name or scientific_name
    location_bit = f" — {location}" if location else ""
    return f"{REEFGUIDE_ATTRIBUTION} — {title} ({scientific_name}){location_bit}"


def load_region_catalog(
    region: str,
    *,
    cache_path: Path = DEFAULT_CATALOG_CACHE,
    refresh: bool = False,
    request_delay_seconds: float = 0.25,
) -> dict[str, ReefGuideSpeciesEntry]:
    cache: dict[str, Any] = {}
    if cache_path.exists():
        cache = json.loads(cache_path.read_text(encoding="utf-8"))

    region_cache = cache.get("regions", {}).get(region, {})
    if region_cache.get("cacheVersion") == CACHE_VERSION and not refresh:
        entries = {
            key: ReefGuideSpeciesEntry(
                scientific_name=value["scientificName"],
                species_page_path=value["speciesPagePath"],
                region=value["region"],
            )
            for key, value in region_cache.get("entries", {}).items()
        }
        return entries

    catalog_url = f"{REEFGUIDE_BASE_URL}/{region}/cat_sci.html"
    html = fetch_url(catalog_url)
    entries = parse_cat_sci_html(html, region=region)

    cache.setdefault("regions", {})[region] = {
        "cacheVersion": CACHE_VERSION,
        "catalogURL": catalog_url,
        "entries": {
            key: {
                "scientificName": entry.scientific_name,
                "speciesPagePath": entry.species_page_path,
                "region": entry.region,
            }
            for key, entry in entries.items()
        },
    }
    cache_path.parent.mkdir(parents=True, exist_ok=True)
    cache_path.write_text(json.dumps(cache, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    if request_delay_seconds > 0:
        time.sleep(request_delay_seconds)
    return entries


def load_caribbean_catalog(
    *,
    regions: tuple[str, ...] = DEFAULT_CARIBBEAN_REGIONS,
    cache_path: Path = DEFAULT_CATALOG_CACHE,
    refresh: bool = False,
    request_delay_seconds: float = 0.25,
) -> dict[str, ReefGuideSpeciesEntry]:
    merged: dict[str, ReefGuideSpeciesEntry] = {}
    for region in regions:
        region_entries = load_region_catalog(
            region,
            cache_path=cache_path,
            refresh=refresh,
            request_delay_seconds=request_delay_seconds,
        )
        for key, entry in region_entries.items():
            merged.setdefault(key, entry)
    return merged


def lookup_species_entry(
    scientific_name: str,
    catalog: dict[str, ReefGuideSpeciesEntry],
) -> ReefGuideSpeciesEntry | None:
    match_key = normalize_scientific_name_for_match(scientific_name)
    if not match_key:
        return None
    return catalog.get(match_key)


def find_reefguide_image(
    scientific_name: str,
    *,
    common_name: str = "",
    catalog: dict[str, ReefGuideSpeciesEntry],
    request_delay_seconds: float = 0.25,
) -> ReefGuideImageCandidate | None:
    entry = lookup_species_entry(scientific_name, catalog)
    if entry is None:
        return None

    species_html = fetch_url(entry.species_page_url)
    if request_delay_seconds > 0:
        time.sleep(request_delay_seconds)

    page_scientific = ""
    scientific_match = SPECIES_SCIENTIFIC_RE.search(species_html)
    if scientific_match:
        page_scientific = unescape(scientific_match.group(1)).strip()
        if normalize_scientific_name_for_match(page_scientific) != normalize_scientific_name_for_match(
            scientific_name
        ):
            return None

    gallery = parse_species_gallery(species_html)
    photo = pick_best_gallery_photo(gallery)
    if photo is None:
        return None

    image_url, photo_page_url = resolve_reefguide_image_url(
        photo,
        species_page_url=entry.species_page_url,
        request_delay_seconds=request_delay_seconds,
    )
    resolved_scientific = page_scientific or entry.scientific_name
    title = common_name or photo.alt_text.split(" - ")[0].strip() or resolved_scientific

    return ReefGuideImageCandidate(
        url=image_url,
        species_page_url=entry.species_page_url,
        photo_page_url=photo_page_url,
        location=photo.location,
        title=title,
        license=REEFGUIDE_LICENSE,
        attribution=build_reefguide_attribution(
            common_name=common_name or title,
            scientific_name=resolved_scientific,
            location=photo.location,
        ),
        source=REEFGUIDE_SOURCE,
        needs_review=True,
        score=score_reefguide_photo(photo),
    )
